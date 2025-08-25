/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.qmlmodels

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.ScreenTools

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtCharts 2.15
import QGroundControl 1.0

AnalyzePage {
    id: logDownloadPage
    pageComponent: pageComponent
    pageDescription: qsTr("Log Download allows you to download binary log files from your vehicle. Click Refresh to get list of available logs.")

    // Property to hold all history text for display
    property string historyTable: "Date\tFlight Start Time\tFlight End Time\tTotal Flight Time\tFlight Distance\tRemaining Battery (%)\tFuel Consumed\tSpray Volume (L)\tFlow Rate (mL/min)\tSpray Area (ha)\n"

    Component.onCompleted: {
        // Step 1: Auto load all CSV files in folder + save summaries into txt
        logDownloadController.loadAllCsvFiles("/home/wm_lenovo/Documents/QGroundControl Daily/Telemetry/")

        // Step 2: After loop finishes, C++ already calls loadHistoryFile()
        csvArea.text = logDownloadController.historyText
    }

    Component {
        id: pageComponent

        RowLayout {
            width: availableWidth
            height: availableHeight

            QGCFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: gridLayout.width
                contentHeight: gridLayout.height

                ColumnLayout {
                    id: columnContent

                    // === Button to open popup graph ===
                    QGCButton {
                        text: qsTr("Show Graph")
                        Layout.fillWidth: true
                        onClicked: graphPopup.open()
                    }

                     // === Graph Popup ===   
                    Popup {
                        id: graphPopup
                        modal: true
                        focus: true
                        width: 900
                        height: 600
                        anchors.centerIn: Overlay.overlay

                        background: Rectangle {
                            color: "white"
                            radius: 10
                            border.color: "gray"
                        }

                        property var points: []

                        function parseHistory(text) {
                            const lines = (text || "").trim().split(/\r?\n/).filter(l => l.length > 0);
                            if (lines.length === 0) return [];

                            let startIdx = 0;
                            if (/^Date\s*,/i.test(lines[0])) {
                                startIdx = 1;
                            }

                            const out = [];
                            for (let i = startIdx; i < lines.length; i++) {
                                const cols = lines[i].split(",");
                                if (cols.length < 7) continue;

                                const dateStr  = cols[0].trim();
                                const startStr = cols[1].trim();
                                const distStr  = cols[4].trim();
                                const battStr  = cols[5].trim();
                                const timeStr  = cols[3].trim();   // <-- totalFlightTime column
                                const sprayStr = (cols.length > 7) ? cols[7].trim() : "0";  // <-- spray volume
                                const areaStr = (cols.length > 9) ? cols[9].trim() : "0";  // <-- spray Area

                                let t = Date.fromLocaleString(Qt.locale(), startStr, "yyyy-MM-dd hh:mm:ss.zzz");
                                if (isNaN(t)) {
                                    t = Date.fromLocaleString(Qt.locale(), startStr, "yyyy-MM-dd hh:mm:ss");
                                }
                                if (isNaN(t)) {
                                    let timeOnly = startStr.split(" ")[1] || "00:00:00";
                                    t = Date.fromLocaleString(Qt.locale(), dateStr + " " + timeOnly, "M/d/yyyy hh:mm:ss");
                                }
                                if (isNaN(t)) continue;

                                // Convert totalFlightTime "HH:MM:SS" -> seconds
                                let totalSeconds = 0;
                                if (/^\d{2}:\d{2}:\d{2}$/.test(timeStr)) {
                                    const parts = timeStr.split(":").map(Number);
                                    totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
                                } else {
                                    totalSeconds = Number(timeStr); // fallback
                                }

                                const tMs = t.getTime();
                                const distance = Number(distStr);
                                const battery  = Number(battStr);
                                const sprayVol = Number(sprayStr);
                                const sprayAr = Number(areaStr);

                                if (!isNaN(distance) && !isNaN(battery) && !isNaN(totalSeconds) && !isNaN(sprayVol) && !isNaN(sprayAr)) {
                                    out.push({
                                        tMs: tMs,
                                        distance: distance,
                                        battery: battery,
                                        flightTime: totalSeconds / 60.0,   // store in minutes
                                        sprayVolume: sprayVol,
                                        sprayArea:   sprayAr
                                    });
                                }
                            }
                            out.sort((a,b) => a.tMs - b.tMs);
                            return out;
                        }

                        Connections {
                            target: logDownloadController
                            function onHistoryTextChanged() {
                                graphPopup.points = graphPopup.parseHistory(logDownloadController.historyText);
                                historyChart.rebuildSeries();
                            }
                        }

                        Component.onCompleted: {
                            points = parseHistory(logDownloadController.historyText);
                            historyChart.rebuildSeries();
                        }

                        ChartView {
                            id: historyChart
                            anchors.fill: parent
                            anchors.margins: 50
                            antialiasing: true
                            legend.visible: true
                            legend.alignment: Qt.AlignBottom

                            ValueAxis { id: distanceAxis; titleText: "Flight Distance (m)"; min: 0 }
                            ValueAxis { id: batteryAxis;  titleText: "Battery (%)"; min: 0; max: 100 }
                            ValueAxis { id: timeAxisY;   titleText: "Total Flight Time (min)"; min: 0 }
                            ValueAxis { id: sprayAxis;   titleText: "Spray Volume (L)"; min: 0 }
                            ValueAxis { id: areaAxis; titleText: "Spray Area (ha)"; min: 0 }
                            DateTimeAxis { id: timeAxis; format: "MM/dd HH:mm"; tickCount: 6 }

                            LineSeries {
                                id: distanceSeries
                                name: "Distance"
                                axisX: timeAxis
                                axisY: distanceAxis
                                visible: true
                            }

                            LineSeries {
                                id: batterySeries
                                name: "Battery %"
                                axisX: timeAxis
                                axisYRight: batteryAxis
                                visible: false
                            }

                            LineSeries {
                                id: timeSeries
                                name: "Total Flight Time (min)"
                                axisX: timeAxis
                                axisY: timeAxisY
                                visible: false
                            }

                            LineSeries {
                                id: spraySeries
                                name: "Spray Volume (L)"
                                axisX: timeAxis
                                axisYRight: sprayAxis
                                visible: false
                            }

                            LineSeries {
                                id: areaSeries
                                name: "Spray Area (ha)"
                                axisX: timeAxis
                                axisYRight: areaAxis
                                visible: false
                            }

                            onSeriesAdded: (s, idx) => {
                                if (s === batterySeries && !historyChart.axes(Qt.Vertical, batterySeries).includes(batteryAxis)) {
                                    historyChart.addAxis(batteryAxis, Qt.AlignRight)
                                    batterySeries.attachAxis(batteryAxis)
                                }
                                if (s === timeSeries && !historyChart.axes(Qt.Vertical, timeSeries).includes(timeAxisY)) {
                                    historyChart.addAxis(timeAxisY, Qt.AlignLeft)
                                    timeSeries.attachAxis(timeAxisY)
                                }
                                if (s === spraySeries && !historyChart.axes(Qt.Vertical, spraySeries).includes(sprayAxis)) {
                                    historyChart.addAxis(sprayAxis, Qt.AlignRight)
                                    spraySeries.attachAxis(sprayAxis)
                                }
                                if (s === areaSeries && !historyChart.axes(Qt.Vertical, areaSeries).includes(areaAxis)) {
                                    historyChart.addAxis(areaAxis, Qt.AlignRight)
                                    areaSeries.attachAxis(areaAxis)
                                }
                            }

                            function rebuildSeries() {
                                distanceSeries.clear()
                                batterySeries.clear()
                                timeSeries.clear()
                                spraySeries.clear()
                                areaSeries.clear()

                                if (!graphPopup.points || graphPopup.points.length === 0) return

                                let minTime = graphPopup.points[0].tMs
                                let maxTime = graphPopup.points[graphPopup.points.length - 1].tMs
                                let maxDist = 0
                                let maxFlightTime = 0
                                let maxSpray = 0
                                let maxArea = 0

                                for (let i = 0; i < graphPopup.points.length; i++) {
                                    let p = graphPopup.points[i]
                                    if (p.distance > maxDist) maxDist = p.distance
                                    if (p.flightTime > maxFlightTime) maxFlightTime = p.flightTime
                                    if (p.sprayVolume > maxSpray) maxSpray = p.sprayVolume
                                    if (p.sprayArea > maxArea) maxArea = p.sprayArea

                                    distanceSeries.append(p.tMs, p.distance)
                                    batterySeries.append(p.tMs, p.battery)
                                    timeSeries.append(p.tMs, p.flightTime)
                                    spraySeries.append(p.tMs, p.sprayVolume)
                                    areaSeries.append(p.tMs, p.sprayArea)
                                }

                                const padMs = Math.max(60000, Math.round((maxTime - minTime) * 0.1))
                                timeAxis.min = new Date(minTime - padMs)
                                timeAxis.max = new Date(maxTime + padMs)
                                distanceAxis.max = Math.max(10, Math.ceil(maxDist * 1.2))
                                timeAxisY.max = Math.max(5, Math.ceil(maxFlightTime * 1.2))
                                sprayAxis.max = Math.max(1, Math.ceil(maxSpray * 1.2))
                                areaAxis.max = Math.max(1, Math.ceil(maxArea * 1.2))
                            }
                        }

                        // === Toggle Controls ===
                        Row {
                            id: toggleRow
                            spacing: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 50

                            Button {
                                text: "Distance"
                                checkable: true
                                checked: true
                                onToggled: distanceSeries.visible = checked
                            }

                            Button {
                                text: "Battery"
                                checkable: true
                                checked: false
                                onToggled: batterySeries.visible = checked
                            }

                            Button {
                                text: "Flight Time"
                                checkable: true
                                checked: false
                                onToggled: timeSeries.visible = checked
                            }

                            Button {
                                text: "Spray Volume"
                                checkable: true
                                checked: false
                                onToggled: spraySeries.visible = checked
                            }

                            Button {
                                text: "Spray Area"
                                checkable: true
                                checked: false
                                onToggled: areaSeries.visible = checked
                            }
                        }

                        Button {
                            text: qsTr("Close")
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            onClicked: graphPopup.close()
                        }
                    }

                    GridLayout {
                        id: gridLayout
                        rows: logDownloadController.model.count + 1
                        columns: 5
                        flow: GridLayout.TopToBottom
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: 0

                        QGCCheckBox {
                            id: headerCheckBox
                            enabled: false
                        }

                        Repeater {
                            model: logDownloadController.model

                            QGCCheckBox {
                                Binding on checkState {
                                    value: object.selected ? Qt.Checked : Qt.Unchecked
                                }

                                onClicked: object.selected = checked
                            }
                        }

                        QGCLabel { text: qsTr("Id") }

                        Repeater {
                            model: logDownloadController.model

                            QGCLabel { text: object.id }
                        }

                        QGCLabel { text: qsTr("Date") }

                        Repeater {
                            model: logDownloadController.model

                            QGCLabel {
                                text: {
                                    if (!object.received) {
                                        return ""
                                    }

                                    if (object.time.getUTCFullYear() < 2010) {
                                        return qsTr("Date Unknown")
                                    }

                                    return object.time.toLocaleString(undefined)
                                }
                            }
                        }

                        QGCLabel { text: qsTr("Size") }

                        Repeater {
                            model: logDownloadController.model

                            QGCLabel { text: object.sizeStr }
                        }

                        QGCLabel { text: qsTr("Status") }

                        Repeater {
                            model: logDownloadController.model
                            QGCLabel { text: object.status }
                        }
                    }
                }               
            }

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !logDownloadController.requestingList && !logDownloadController.downloadingLogs
                    text: qsTr("Refresh")

                    onClicked: {
                        if (!QGroundControl.multiVehicleManager.activeVehicle || QGroundControl.multiVehicleManager.activeVehicle.isOfflineEditingVehicle) {
                            mainWindow.showMessageDialog(qsTr("Log Refresh"), qsTr("You must be connected to a vehicle in order to download logs."))
                            return
                        }

                        logDownloadController.refresh()
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !logDownloadController.requestingList && !logDownloadController.downloadingLogs
                    text: qsTr("Download")

                    onClicked: {
                        var logsSelected = false
                        for (var i = 0; i < logDownloadController.model.count; i++) {
                            if (logDownloadController.model.get(i).selected) {
                                logsSelected = true
                                break
                            }
                        }

                        if (!logsSelected) {
                            mainWindow.showMessageDialog(qsTr("Log Download"), qsTr("You must select at least one log file to download."))
                            return
                        }

                        if (ScreenTools.isMobile) {
                            logDownloadController.download()
                            return
                        }

                        fileDialog.title = qsTr("Select save directory")
                        fileDialog.folder = QGroundControl.settingsManager.appSettings.logSavePath
                        fileDialog.selectFolder = true
                        fileDialog.openForLoad()
                    }

                    QGCFileDialog {
                        id: fileDialog
                        onAcceptedForLoad: (file) => {
                            logDownloadController.download(file)
                            close()
                        }
                    }
                }

            QGCButton {
                Layout.fillWidth: true
                enabled: !logDownloadController.requestingList && !logDownloadController.downloadingLogs && (logDownloadController.model.count > 0)
                text: qsTr("Erase All")
                onClicked: mainWindow.showMessageDialog(
                    qsTr("Delete All Log Files"),
                    qsTr("All log files will be erased permanently. Is this really what you want?"),
                    Dialog.Yes | Dialog.No,
                    function() { logDownloadController.eraseAll() }
                )
            }

            QGCButton {
                Layout.fillWidth: true
                text: qsTr("Cancel")
                enabled: logDownloadController.requestingList || logDownloadController.downloadingLogs
                onClicked: logDownloadController.cancel()
                }
            }     
        }
    }
}

