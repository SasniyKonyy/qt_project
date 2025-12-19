cmake_minimum_required(VERSION 3.16)
project(RKP LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup()

qt_add_executable(appRKP
    main.cpp
    logger.h logger.cpp
    terminalcontroller.h terminalcontroller.cpp
    terminalcore.h terminalcore.cpp
    validators.h qrcodegen.hpp qrcodegen.cpp
)

qt_add_qml_module(appRKP
    URI RKP
    VERSION 1.0
    QML_FILES
        Main.qml
        SOURCES qrcodegen.h qrcodegen.cpp
        SOURCES qrcodegen.hpp
)

target_link_libraries(appRKP PRIVATE Qt6::Quick)
