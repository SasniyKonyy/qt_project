#include "logger.h"
#include <QDateTime>
#include <QTextStream>

Logger::Logger(const QString& filePath)
    : m_path(filePath), m_file(filePath)
{
    m_file.open(QIODevice::Append | QIODevice::Text);
}

void Logger::write(const QString& line) {
    if (!m_file.isOpen()) return;
    QTextStream out(&m_file);
    out << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss")
        << " | " << line << "\n";
    out.flush();
}
