#include "terminalcore.h"
#include "validators.h"

#include <QDateTime>
#include <QRandomGenerator>

static QString rndDigits(int n) {
    QString s; s.reserve(n);
    for (int i=0;i<n;++i)
        s += QChar('0' + QRandomGenerator::global()->bounded(10));
    return s;
}

PaymentResponse TerminalCore::process(const PaymentRequest& req) {
    PaymentResponse r;
    r.rrn = QDateTime::currentDateTime().toString("yyMMddHHmmss") + rndDigits(2);
    r.authCode = rndDigits(6);

    const QString panDigits = Validators::onlyDigits(req.pan);

    // проверки
    if (panDigits.size() < 13 || panDigits.size() > 19 || !Validators::luhnCheck(panDigits)) {
        r.respCode = "14"; r.message = "Неверный номер карты"; return r;
    }
    if (!Validators::validExpiry(req.expiry)) {
        r.respCode = "54"; r.message = "Истек срок действия карты"; return r;
    }
    if (!Validators::validCvv(req.cvv)) {
        r.respCode = "N7"; r.message = "Неверный CVV"; return r;
    }
    if (!Validators::validPin(req.pin)) {
        r.respCode = "55"; r.message = "Неверный PIN"; return r;
    }
    if (req.op != PaymentRequest::Operation::Balance && req.amount <= 0.0) {
        r.respCode = "13"; r.message = "Неверная сумма"; return r;
    }

    // имитация банка
    int roll = QRandomGenerator::global()->bounded(100);
    if (roll < 80) {            // 80% одобрение
        r.approved = true;
        r.respCode = "00";
        r.message = "Одобрено";
    } else if (roll < 90) {     // 10% недостаточно средств
        r.respCode = "51";
        r.message = "Недостаточно средств";
    } else {                    // 10% отказ
        r.respCode = "05";
        r.message = "Отказано";
    }

    return r;
}
