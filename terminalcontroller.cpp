#include "terminalcontroller.h"
#include "logger.h"
#include "validators.h"
#include <QImage>
#include <QBuffer>
#include <QByteArray>
#include <QPainter>

// QR lib:
#include "qrcodegen.hpp"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

TerminalController::TerminalController(QObject* parent)
    : QObject(parent)
{
    const QString logPath =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + "/terminal.log";

    QDir().mkpath(QFileInfo(logPath).absolutePath());
    m_logger = std::make_unique<Logger>(logPath);

    appendLog("Старт приложения. Лог: " + m_logger->filePath());
}

TerminalController::~TerminalController() = default;

void TerminalController::appendLog(const QString& line)
{
    const QString t = QDateTime::currentDateTime().toString("HH:mm:ss");
    m_logText += "[" + t + "] " + line + "\n";
    emit logTextChanged();

    if (m_logger) m_logger->write(line);
}

QString TerminalController::maskPan(const QString& pan) const
{
    QString d = Validators::onlyDigits(pan);
    if (d.size() < 8) return "****";

    for (int i = 4; i < d.size() - 4; ++i) d[i] = '*';

    QString pretty;
    for (int i = 0; i < d.size(); ++i) {
        pretty += d[i];
        if ((i + 1) % 4 == 0 && i + 1 < d.size())
            pretty += ' ';
    }
    return pretty;
}

QString TerminalController::buildReceipt(const QString& opName,
                                         const QString& maskedPan,
                                         double amount,
                                         const PaymentResponse& resp) const
{
    QString s;
    s += "========= PAYMENT TERMINAL SIM =========\n";
    s += "Дата/время: " + QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") + "\n";
    s += "Операция:   " + opName + "\n";
    s += "Карта:      " + maskedPan + "\n";
    if (opName != "Проверка баланса")
        s += QString("Сумма:      %1\n").arg(amount, 0, 'f', 2);
    s += "RRN:        " + resp.rrn + "\n";
    s += "AUTH:       " + resp.authCode + "\n";
    s += "RESP:       " + resp.respCode + "\n";
    s += "Сообщение:  " + resp.message + "\n";
    s += "Статус:     " + QString(resp.approved ? "ОДОБРЕНО" : "ОТКАЗ") + "\n";
    s += "=======================================\n";
    return s;
}

QVariantMap TerminalController::process(int op,
                                        double amount,
                                        const QString& pan,
                                        const QString& holder,
                                        const QString& expiry,
                                        const QString& cvv,
                                        const QString& pin)
{
    PaymentRequest req;
    if (op == 0) req.op = PaymentRequest::Operation::Pay;
    else if (op == 1) req.op = PaymentRequest::Operation::Refund;
    else req.op = PaymentRequest::Operation::Balance;

    req.amount = amount;
    req.pan = pan;
    req.holder = holder;
    req.expiry = expiry;
    req.cvv = cvv;
    req.pin = pin;

    if (req.op == PaymentRequest::Operation::Balance)
        req.amount = 0.0;

    const QString opName = (op == 0 ? "Оплата" : (op == 1 ? "Возврат" : "Проверка баланса"));
    const QString masked = maskPan(req.pan);

    appendLog(QString("Запрос: %1 | %2 | amount=%3")
                  .arg(opName, masked)
                  .arg(req.amount, 0, 'f', 2));

    PaymentResponse resp = m_core.process(req);

    appendLog(QString("Ответ: approved=%1 code=%2 msg=%3 rrn=%4 auth=%5")
                  .arg(resp.approved ? "true" : "false",
                       resp.respCode,
                       resp.message,
                       resp.rrn,
                       resp.authCode));

    QVariantMap out;
    out["approved"] = resp.approved;
    out["respCode"] = resp.respCode;
    out["message"] = resp.message;
    out["rrn"] = resp.rrn;
    out["authCode"] = resp.authCode;
    out["maskedPan"] = masked;
    out["receipt"] = buildReceipt(opName, masked, req.amount, resp);

    return out;
}

QString TerminalController::saveHistoryJson(const QVariantList& items)
{
    QJsonArray arr;

    for (const QVariant& v : items) {
        const QVariantMap m = v.toMap();
        QJsonObject o;

        o["dt"] = m.value("dt").toString();
        o["type"] = m.value("type").toString();
        o["method"] = m.value("method").toString();
        o["amount"] = m.value("amount").toDouble();
        o["approved"] = m.value("approved").toBool();
        o["respCode"] = m.value("respCode").toString();
        o["rrn"] = m.value("rrn").toString();
        o["receipt"] = m.value("receipt").toString();

        arr.append(o);
    }

    QJsonDocument doc(arr);

    const QString dirPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dirPath);

    const QString fileName =
        "history_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".json";
    const QString filePath = dirPath + "/" + fileName;

    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        appendLog("Ошибка: не удалось записать JSON истории: " + filePath);
        return "";
    }

    f.write(doc.toJson(QJsonDocument::Indented));
    f.close();

    appendLog("История сохранена в JSON: " + filePath);
    return filePath;
}
QString TerminalController::makeQrDataUrl(const QString& payload,
                                          int pixelsPerModule,
                                          int borderModules)
{
    using qrcodegen::QrCode;

    if (payload.trimmed().isEmpty())
        return "";

    // Генерируем QR (уровень коррекции M — нормально для реальности)
    const QrCode qr = QrCode::encodeText(payload.toUtf8().constData(), QrCode::Ecc::MEDIUM);

    const int size = qr.getSize(); // кол-во модулей
    const int border = std::max(0, borderModules);
    const int ppm = std::max(1, pixelsPerModule);

    const int imgSize = (size + border * 2) * ppm;

    QImage img(imgSize, imgSize, QImage::Format_ARGB32);
    img.fill(Qt::white);

    QPainter p(&img);
    p.setPen(Qt::NoPen);
    p.setBrush(Qt::black);

    for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
            if (qr.getModule(x, y)) {
                const int rx = (x + border) * ppm;
                const int ry = (y + border) * ppm;
                p.drawRect(rx, ry, ppm, ppm);
            }
        }
    }
    p.end();

    QByteArray bytes;
    QBuffer buf(&bytes);
    buf.open(QIODevice::WriteOnly);
    img.save(&buf, "PNG");

    const QString b64 = QString::fromLatin1(bytes.toBase64());
    return "data:image/png;base64," + b64;
}
