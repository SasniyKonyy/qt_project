#pragma once
#include <QString>
#include <QDate>

namespace Validators {

inline QString onlyDigits(QString s) {
    QString out; out.reserve(s.size());
    for (auto ch : s) if (ch.isDigit()) out.push_back(ch);
    return out;
}

// Luhn (проверка номера карты)
inline bool luhnCheck(const QString& digits) {
    int sum = 0;
    bool alt = false;
    for (int i = digits.size() - 1; i >= 0; --i) {
        if (!digits[i].isDigit()) return false;
        int n = digits[i].digitValue();
        if (alt) { n *= 2; if (n > 9) n -= 9; }
        sum += n;
        alt = !alt;
    }
    return (sum % 10) == 0;
}

// MM/YY или MMYY
inline bool validExpiry(QString mmYY) {
    mmYY.remove('/');
    if (mmYY.size() != 4) return false;

    bool okM=false, okY=false;
    int mm = mmYY.left(2).toInt(&okM);
    int yy = mmYY.mid(2,2).toInt(&okY);
    if (!okM || !okY || mm < 1 || mm > 12) return false;

    int year = 2000 + yy;
    QDate exp(year, mm, 1);
    exp = exp.addMonths(1).addDays(-1);
    return exp >= QDate::currentDate();
}

inline bool validCvv(const QString& cvv) {
    if (!(cvv.size()==3 || cvv.size()==4)) return false;
    return onlyDigits(cvv).size() == cvv.size();
}

inline bool validPin(const QString& pin) {
    return pin.size()==4 && onlyDigits(pin).size()==4;
}

} // namespace Validators
