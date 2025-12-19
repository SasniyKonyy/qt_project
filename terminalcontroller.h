#pragma once
#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <memory>

#include "terminalcore.h"

class Logger;

class TerminalController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString logText READ logText NOTIFY logTextChanged)

public:
    explicit TerminalController(QObject* parent = nullptr);
    ~TerminalController();

    QString logText() const { return m_logText; }

    Q_INVOKABLE QVariantMap process(int op,
                                    double amount,
                                    const QString& pan,
                                    const QString& holder,
                                    const QString& expiry,
                                    const QString& cvv,
                                    const QString& pin);

    Q_INVOKABLE QString saveHistoryJson(const QVariantList& items);

    // ✅ Реальный QR: вернёт data:image/png;base64,...
    Q_INVOKABLE QString makeQrDataUrl(const QString& payload,
                                      int pixelsPerModule = 8,
                                      int borderModules = 4);

signals:
    void logTextChanged();

private:
    void appendLog(const QString& line);
    QString maskPan(const QString& pan) const;
    QString buildReceipt(const QString& opName,
                         const QString& maskedPan,
                         double amount,
                         const PaymentResponse& resp) const;

    TerminalCore m_core;
    std::unique_ptr<Logger> m_logger;
    QString m_logText;
};
