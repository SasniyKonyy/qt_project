import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQml

ApplicationWindow {
    id: win
    visible: true
    width: 1100
    height: 720
    title: "POS/Терминал оплаты — симулятор"

    Material.theme: Material.Dark
    Material.accent: Material.Teal

    // ====== Корзина ======
    ListModel { id: cartModel } // {name, qty, price}
    property real totalSum: 0

    function recalcTotal() {
        let t = 0
        for (let i = 0; i < cartModel.count; i++) {
            const it = cartModel.get(i)
            t += it.qty * it.price
        }
        totalSum = t
    }

    function rnd(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min }

    property var goods: [
        { n: "Хлеб пшеничный", p: 59.90 },
        { n: "Молоко 2.5%", p: 99.90 },
        { n: "Сыр голландский", p: 219.50 },
        { n: "Шоколад", p: 89.90 },
        { n: "Кофе 250г", p: 349.00 },
        { n: "Яйца 10шт", p: 139.90 },
        { n: "Колбаса варёная", p: 279.90 },
        { n: "Вода 1.5л", p: 54.90 },
        { n: "Пакет", p: 9.90 },
        { n: "Печенье", p: 119.90 }
    ]

    function addRandomItem() {
        const g = goods[rnd(0, goods.length - 1)]
        for (let i = 0; i < cartModel.count; i++) {
            const it = cartModel.get(i)
            if (it.name === g.n && it.price === g.p) {
                cartModel.setProperty(i, "qty", it.qty + 1)
                recalcTotal()
                return
            }
        }
        cartModel.append({ name: g.n, qty: 1, price: g.p })
        recalcTotal()
    }

    function removeLast() {
        if (cartModel.count > 0) cartModel.remove(cartModel.count - 1)
        recalcTotal()
    }

    function clearCart() {
        cartModel.clear()
        recalcTotal()
    }

    // ====== История ======
    ListModel { id: historyModel } // {dt,type,method,amount,approved,respCode,rrn,receipt}

    function nowStr() { return Qt.formatDateTime(new Date(), "dd.MM.yyyy  HH:mm:ss") }

    function addHistory(type, method, amount, r) {
        historyModel.insert(0, {
                                dt: nowStr(),
                                type: type,
                                method: method,
                                amount: amount,
                                approved: r.approved,
                                respCode: r.respCode,
                                rrn: r.rrn,
                                receipt: r.receipt
                            })
    }

    function historyAsArray() {
        let arr = []
        for (let i = 0; i < historyModel.count; i++) arr.push(historyModel.get(i))
        return arr
    }

    // ====== Диалоги ======
    property string lastReceipt: ""
    property string errorText: ""
    property string infoText: ""

    // QR
    property bool qrWaiting: false
    property int qrSecondsLeft: 30
    property int qrSeed: 12345

    readonly property string qrPan: "4242 4242 4242 4242"
    readonly property string qrHolder: "QR CUSTOMER"
    readonly property string qrExpiry: "12/28"
    readonly property string qrCvv: "123"
    readonly property string qrPin: "0000"

    // ====== Фон ======
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0b1220" }
            GradientStop { position: 1.0; color: "#05070d" }
        }
    }

    // ====== Корпус ======
    Rectangle {
        id: terminalBody
        width: Math.min(980, win.width - 40)
        height: Math.min(640, win.height - 40)
        anchors.centerIn: parent
        radius: 28
        color: "#121826"
        border.color: "#1f2a44"
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: -10
            radius: 32
            color: "#000000"
            opacity: 0.25
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // ===== Верхняя панель =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 18
                color: "#0f1523"
                border.color: "#233252"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Label {
                        text: "POS TERMINAL"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: "#e8eefc"
                    }

                    Item { Layout.fillWidth: true }

                    Button { text: "История"; onClicked: historyDialog.open() }
                    Button { text: "Лог"; onClicked: logDialog.open() }

                    Label {
                        text: Qt.formatDateTime(new Date(), "dd.MM.yyyy  HH:mm")
                        color: "#a9b7d6"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: cartModel.count > 0 ? "#22c55e" : "#f59e0b"
                    }
                    Label {
                        text: cartModel.count > 0 ? "Готов к оплате" : "Ожидание пробития"
                        color: "#a9b7d6"
                        font.pixelSize: 14
                    }
                }
            }

            // ===== Основная зона =====
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // ===== ЛЕВО: товары =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 640
                    radius: 18
                    color: "#0f1523"
                    border.color: "#233252"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: "Пробитые товары"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                color: "#e8eefc"
                            }

                            Item { Layout.fillWidth: true }

                            Flow {
                                spacing: 8
                                Button { text: "Пробить товар"; onClicked: addRandomItem() }
                                Button { text: "Отменить"; enabled: cartModel.count > 0; onClicked: removeLast() }
                                Button { text: "Очистить"; enabled: cartModel.count > 0; onClicked: clearCart() }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 10
                            color: "#121c2e"
                            border.color: "#233252"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Label { text: "Товар"; Layout.fillWidth: true; color: "#a9b7d6" }
                                Label { text: "Кол-во"; width: 70; horizontalAlignment: Text.AlignRight; color: "#a9b7d6" }
                                Label { text: "Цена";  width: 90; horizontalAlignment: Text.AlignRight; color: "#a9b7d6" }
                                Label { text: "Сумма"; width: 100; horizontalAlignment: Text.AlignRight; color: "#a9b7d6" }
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: cartView
                                model: cartModel
                                spacing: 8

                                delegate: Rectangle {
                                    width: cartView.width
                                    height: 52
                                    radius: 12
                                    color: "#0b1020"
                                    border.color: "#1f2a44"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Label {
                                            text: name
                                            Layout.fillWidth: true
                                            color: "#e8eefc"
                                            elide: Text.ElideRight
                                        }

                                        RowLayout {
                                            width: 70
                                            spacing: 6

                                            ToolButton {
                                                text: "−"
                                                onClicked: {
                                                    if (qty > 1) cartModel.setProperty(index, "qty", qty - 1)
                                                    else cartModel.remove(index)
                                                    recalcTotal()
                                                }
                                            }
                                            Label {
                                                text: qty
                                                width: 24
                                                horizontalAlignment: Text.AlignHCenter
                                                color: "#e8eefc"
                                            }
                                            ToolButton {
                                                text: "+"
                                                onClicked: {
                                                    cartModel.setProperty(index, "qty", qty + 1)
                                                    recalcTotal()
                                                }
                                            }
                                        }

                                        Label {
                                            text: price.toFixed(2)
                                            width: 90
                                            horizontalAlignment: Text.AlignRight
                                            color: "#a9b7d6"
                                        }

                                        Label {
                                            text: (qty * price).toFixed(2)
                                            width: 100
                                            horizontalAlignment: Text.AlignRight
                                            color: "#e8eefc"
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            radius: 14
                            color: "#121c2e"
                            border.color: "#233252"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                Label {
                                    text: "ИТОГО:"
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    color: "#e8eefc"
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    text: totalSum.toFixed(2) + " ₽"
                                    font.pixelSize: 24
                                    font.weight: Font.Bold
                                    color: "#22c55e"
                                }
                            }
                        }
                    }
                }

                // ===== ПРАВО: оплата =====
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 320
                    radius: 18
                    color: "#0f1523"
                    border.color: "#233252"
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        clip: true

                        Item {
                            width: parent.width
                            implicitHeight: payCol.implicitHeight

                            ColumnLayout {
                                id: payCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 12

                                Label {
                                    text: "Оплата"
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    color: "#e8eefc"
                                }

                                Label {
                                    text: "Карта — реквизиты. QR — отдельный экран."
                                    color: "#a9b7d6"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                TextField {
                                    id: tfPan
                                    Layout.fillWidth: true
                                    placeholderText: "PAN (9999 9999 9999 9999)"
                                    inputMask: "9999 9999 9999 9999 999;_"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                }

                                TextField {
                                    id: tfHolder
                                    Layout.fillWidth: true
                                    placeholderText: "Держатель (IVAN IVANOV)"
                                    maximumLength: 26
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    TextField {
                                        id: tfExpiry
                                        Layout.fillWidth: true
                                        placeholderText: "MM/YY"
                                        inputMask: "99/99;_"
                                        inputMethodHints: Qt.ImhDigitsOnly
                                    }

                                    TextField {
                                        id: tfCvv
                                        width: 96
                                        placeholderText: "CVV"
                                        echoMode: TextInput.Password
                                        maximumLength: 4
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: RegularExpressionValidator { regularExpression: /^\d{0,4}$/ }
                                    }
                                }

                                TextField {
                                    id: tfPin
                                    Layout.fillWidth: true
                                    placeholderText: "PIN (4 цифры)"
                                    echoMode: TextInput.Password
                                    inputMask: "9999;_"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: "#1f2a44" }

                                Button {
                                    Layout.fillWidth: true
                                    height: 54
                                    enabled: cartModel.count > 0
                                    text: cartModel.count > 0
                                          ? ("Оплатить картой " + totalSum.toFixed(2) + " ₽")
                                          : "Сначала пробей товары"
                                    font.pixelSize: 16

                                    onClicked: {
                                        const r = terminal.process(
                                                    0, totalSum,
                                                    tfPan.text, tfHolder.text, tfExpiry.text, tfCvv.text, tfPin.text
                                                    )
                                        lastReceipt = r.receipt
                                        receiptDialog.open()
                                        addHistory("Оплата", "Карта", totalSum, r)

                                        if (!r.approved) {
                                            errorText = "Операция отклонена\nКод: " + r.respCode + "\n" + r.message
                                            errorDialog.open()
                                        } else {
                                            clearCart()
                                        }
                                    }
                                }

                                Button {
                                    Layout.fillWidth: true
                                    height: 54
                                    enabled: cartModel.count > 0
                                    text: "Оплатить по QR (СБП)"
                                    font.pixelSize: 16
                                    onClicked: {
                                        qrSeed = rnd(10000, 99999)
                                        qrSecondsLeft = 30
                                        qrWaiting = true
                                        qrDialog.open()
                                        qrTimer.restart()
                                    }
                                }

                                Button {
                                    Layout.fillWidth: true
                                    text: "Возврат (Refund)"
                                    onClicked: refundDialog.open()
                                }

                                Item { height: 6 }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== QR Timer =====
    Timer {
        id: qrTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (!qrWaiting) { stop(); return }
            qrSecondsLeft--
            if (qrSecondsLeft <= 0) {
                qrWaiting = false
                stop()
                errorText = "QR-оплата не выполнена: таймаут ожидания"
                errorDialog.open()
            }
        }
        function restart() { running = true }
    }

    // ===== QR Dialog =====
    Dialog {
        id: qrDialog
        title: "QR-оплата"
        modal: true
        standardButtons: Dialog.Cancel
        onRejected: { qrWaiting = false; qrTimer.running = false }

        contentItem: Item {
            implicitWidth: 520
            implicitHeight: 520

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Label { text: "Отсканируйте QR в приложении банка"; color: "#e8eefc"; font.pixelSize: 16 }
                Label { text: "Сумма: " + totalSum.toFixed(2) + " ₽"; color: "#a9b7d6" }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 320
                    height: 320
                    radius: 16
                    color: "#ffffff"
                    border.color: "#111827"
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        // payload можешь сделать “SBP-like”
                        source: terminal.makeQrDataUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ", 8, 4)


                            //terminal.makeQrDataUrl(
                              //      "sbp://pay?sum=" + Math.round(totalSum*100) + "&order=" + qrSeed,
                                //    8, 4
                                //)
                    }
                }

                Label {
                    text: qrWaiting ? ("Ожидание оплаты… " + qrSecondsLeft + " сек") : "Ожидание остановлено"
                    color: "#a9b7d6"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        Layout.fillWidth: true
                        text: "Симулировать оплату"
                        enabled: cartModel.count > 0
                        onClicked: {
                            qrWaiting = false
                            qrTimer.running = false
                            qrDialog.close()

                            const r = terminal.process(0, totalSum, qrPan, qrHolder, qrExpiry, qrCvv, qrPin)
                            lastReceipt = r.receipt
                            receiptDialog.open()
                            addHistory("Оплата", "QR", totalSum, r)

                            if (!r.approved) {
                                errorText = "QR-оплата отклонена\nКод: " + r.respCode + "\n" + r.message
                                errorDialog.open()
                            } else {
                                clearCart()
                            }
                        }
                    }

                    Button {
                        text: "Отмена"
                        onClicked: { qrWaiting = false; qrTimer.running = false; qrDialog.close() }
                    }
                }
            }
        }
    }

    // ===== History Dialog =====
    Dialog {
        id: historyDialog
        title: "История операций"
        modal: true
        standardButtons: Dialog.Close

        contentItem: Item {
            implicitWidth: 920
            implicitHeight: 520

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label { text: "Всего: " + historyModel.count; color: "#a9b7d6" }
                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Экспорт в JSON"
                        enabled: historyModel.count > 0
                        onClicked: {
                            const path = terminal.saveHistoryJson(historyAsArray())
                            infoText = (path && path.length > 0) ? ("JSON сохранён:\n" + path) : "Не удалось сохранить JSON."
                            infoDialog.open()
                        }
                    }

                    Button {
                        text: "Очистить"
                        enabled: historyModel.count > 0
                        onClicked: historyModel.clear()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 10
                    color: "#121c2e"
                    border.color: "#233252"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Label { text: "Время"; width: 170; color: "#a9b7d6" }
                        Label { text: "Тип"; width: 90; color: "#a9b7d6" }
                        Label { text: "Метод"; width: 80; color: "#a9b7d6" }
                        Label { text: "Сумма"; width: 110; horizontalAlignment: Text.AlignRight; color: "#a9b7d6" }
                        Label { text: "Статус"; width: 110; color: "#a9b7d6" }
                        Label { text: "Код"; width: 60; color: "#a9b7d6" }
                        Label { text: "RRN"; Layout.fillWidth: true; color: "#a9b7d6" }
                        Label { text: ""; width: 120 }
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: historyView
                        model: historyModel
                        spacing: 8

                        delegate: Rectangle {
                            width: historyView.width
                            height: 54
                            radius: 12
                            color: "#0b1020"
                            border.color: "#1f2a44"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Label { text: dt; width: 170; color: "#e8eefc" }
                                Label { text: type; width: 90; color: "#a9b7d6" }
                                Label { text: method; width: 80; color: "#a9b7d6" }
                                Label { text: amount.toFixed(2) + " ₽"; width: 110; horizontalAlignment: Text.AlignRight; color: "#e8eefc" }

                                Label {
                                    width: 110
                                    text: approved ? "ОДОБРЕНО" : "ОТКАЗ"
                                    color: approved ? "#22c55e" : "#ef4444"
                                    font.weight: Font.DemiBold
                                }

                                Label { text: respCode; width: 60; color: "#a9b7d6" }
                                Label { text: rrn; Layout.fillWidth: true; color: "#a9b7d6"; elide: Text.ElideRight }

                                Button {
                                    width: 120
                                    text: "Чек"
                                    onClicked: { lastReceipt = receipt; receiptDialog.open() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== Log Dialog =====
    Dialog {
        id: logDialog
        title: "Лог (C++)"
        modal: true
        standardButtons: Dialog.Close

        contentItem: Item {
            implicitWidth: 900
            implicitHeight: 520

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        readOnly: true
                        text: terminal ? terminal.logText : ""
                        wrapMode: TextArea.Wrap
                    }
                }
            }
        }
    }

    // ===== Receipt Dialog =====
    Dialog {
        id: receiptDialog
        title: "Чек"
        modal: true
        standardButtons: Dialog.Ok

        contentItem: ScrollView {
            implicitWidth: 720
            implicitHeight: 480
            TextArea { text: lastReceipt; readOnly: true; wrapMode: TextArea.Wrap }
        }
    }

    // ===== Error Dialog =====
    Dialog {
        id: errorDialog
        title: "Ошибка"
        modal: true
        standardButtons: Dialog.Ok

        contentItem: Item {
            implicitWidth: 460
            implicitHeight: 170
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                Label { text: errorText; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
        }
    }

    // ===== Info Dialog =====
    Dialog {
        id: infoDialog
        title: "Информация"
        modal: true
        standardButtons: Dialog.Ok

        contentItem: Item {
            implicitWidth: 520
            implicitHeight: 170
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                Label { text: infoText; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
        }
    }

    // ===== Refund Dialog =====
    Dialog {
        id: refundDialog
        title: "Возврат"
        modal: true
        standardButtons: Dialog.Cancel

        contentItem: Item {
            implicitWidth: 460
            implicitHeight: 280

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Label { text: "Введите сумму возврата:"; color: "#e8eefc" }
                SpinBox { id: refundAmount; from: 1; to: 999999; value: 100 }

                Button {
                    text: "Провести возврат"
                    Layout.fillWidth: true
                    onClicked: {
                        const r = terminal.process(1, refundAmount.value,
                                                  tfPan.text, tfHolder.text, tfExpiry.text, tfCvv.text, tfPin.text)
                        refundDialog.close()
                        lastReceipt = r.receipt
                        receiptDialog.open()
                        addHistory("Возврат", "Карта", refundAmount.value, r)

                        if (!r.approved) {
                            errorText = "Возврат отклонён\nКод: " + r.respCode + "\n" + r.message
                            errorDialog.open()
                        }
                    }
                }
            }
        }
    }
}
