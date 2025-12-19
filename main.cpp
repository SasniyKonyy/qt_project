#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "terminalcontroller.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    TerminalController controller;
    engine.rootContext()->setContextProperty("terminal", &controller);

    const QUrl url(u"qrc:/RKP/Main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
