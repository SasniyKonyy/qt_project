#pragma once
#include <QString>

struct PaymentRequest {
    enum class Operation { Pay, Refund, Balance } op;
    double amount = 0.0;
    QString pan;
    QString holder;
    QString expiry;
    QString cvv;
    QString pin;
};

struct PaymentResponse {
    bool approved = false;
    QString rrn;
    QString authCode;
    QString respCode;
    QString message;
};

class TerminalCore {
public:
    PaymentResponse process(const PaymentRequest& req);
};
