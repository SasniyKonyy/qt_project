#pragma once
#include <QString>
#include <QFile>

class Logger {
public:
    explicit Logger(const QString& filePath);
    void write(const QString& line);
    QString filePath() const { return m_path; }

private:
    QString m_path;
    QFile m_file;
};
