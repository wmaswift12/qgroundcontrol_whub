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
import QtQuick.Layouts 1.15
import QtCharts 2.15

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Controllers 1.0
import QGroundControl.ScreenTools 1.0

AnalyzePage {
    id: droneStatisticsPage

    pageDescription: qsTr("Drone Statistical Dashboard")
    
    property int totalFlights: 0
    property double totalFlightTime: 0.0
    property double totalSprayVolume: 0.0
    property double totalSprayArea: 0.0
    property var todaySummary: {}

    // Property to hold all history text for display
    property string historyTable: "Date\tFlight Start Time\tFlight End Time\tTotal Flight Time\tFlight Distance\tRemaining Battery (%)\tFuel Consumed\tSpray Volume (L)\tFlow Rate (L/min)\n"

    Component.onCompleted: {
         // Try to directly load history text file first
        logDownloadController.loadHistoryFile()

        // Step 1: Auto load all CSV files in folder + save summaries into txt
        logDownloadController.loadAllCsvFiles("C:/Users/PC/Documents/QGroundControl Daily/Telemetry/")

        // Step 2: After loop finishes, C++ already calls loadHistoryFile()
        csvArea.text = logDownloadController.historyText
    }

    pageComponent: Component {
        RowLayout {
            width: availableWidth
            height: availableHeight

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: ScreenTools.defaultFontPixelHeight

                // --- Summary blocks above chart ---
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        radius: 8; color: "#2E2E2E"; Layout.fillWidth: true
                        Layout.preferredHeight: parent.height
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Label { text: "Total Flights"; font.bold: true; color: "white" }
                            Label { text: droneStatisticsPage.totalFlights; color: "lightgray" }
                        }
                    }

                    Rectangle {
                        radius: 8; color: "#2E2E2E"; Layout.fillWidth: true
                        Layout.preferredHeight: parent.height
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Label { text: "Total Time (min)"; font.bold: true; color: "white" }
                            Label { text: droneStatisticsPage.totalFlightTime; color: "lightgray" }
                        }
                    }

                    Rectangle {
                        radius: 8; color: "#2E2E2E"; Layout.fillWidth: true
                        Layout.preferredHeight: parent.height
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Label { text: "Spray Vol (L)"; font.bold: true; color: "white" }
                            Label { text: droneStatisticsPage.totalSprayVolume; color: "lightgray" }
                        }
                    }

                    Rectangle {
                        radius: 8; color: "#2E2E2E"; Layout.fillWidth: true
                        Layout.preferredHeight: parent.height
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Label { text: "Spray Area (ha)"; font.bold: true; color: "white" }
                            Label { text: droneStatisticsPage.totalSprayArea; color: "lightgray" }
                        }
                    }
                }

                ChartView {  
                    width: 600; height: 300
                    title: "Work Done Today"
                    backgroundColor: "transparent"
                    theme: ChartView.ChartThemeDark

                    PieSeries {
                        id: todaySeries
                        PieSlice { label: "Spray Volume " + todaySummary.sprayVolToday.toFixed(1) + " L"; value: todaySummary.sprayVolToday || 0 }
                        PieSlice { label: "Area Sprayed " + todaySummary.sprayAreaToday.toFixed(1) + " ha"; value: todaySummary.sprayAreaToday || 0 }
                        PieSlice { label: "Fuel " + todaySummary.fuelToday.toFixed(1) + " L"; value: todaySummary.fuelToday || 0 }
                        PieSlice { label: "Flight Time " + todaySummary.timeTodayMin.toFixed(1) + " min"; value: todaySummary.timeTodayMin || 0 }
                    }
                }

                // --- Block 3: Chart (independent from table size) ---
                ChartView {
                    id: historyChart
                    Layout.fillWidth: true
                    Layout.fillHeight: true   
                    antialiasing: true
                    backgroundColor: "transparent"
                    legend.visible: true
                    legend.alignment: Qt.AlignBottom
                    theme: ChartView.ChartThemeDark
                    
                    WheelHandler {
                        onWheel: (event) => {
                            if (event.modifiers & Qt.ControlModifier) {
                                // Ctrl + Wheel = zoom in/out
                                if (event.angleDelta.y > 0)
                                    historyChart.zoomIn()
                                else
                                    historyChart.zoomOut()
                            } else if (event.modifiers & Qt.ShiftModifier) {
                                // Shift + Wheel = pan up/down
                                if (event.angleDelta.y > 0)
                                    historyChart.scrollUp(20)
                                else
                                    historyChart.scrollDown(20)
                            } else {
                                // Normal Wheel = pan left/right
                                if (event.angleDelta.y > 0)
                                    historyChart.scrollLeft(20)
                                else
                                    historyChart.scrollRight(20)
                            }
                            event.accepted = true
                        }
                    }

                    ValueAxis { id: distanceAxis; titleText: "Flight Distance (m)"; min: 0 ; visible: false }
                    ValueAxis { id: batteryAxis;  titleText: "Battery (%)"; min: 0; max: 100; visible: false }
                    ValueAxis { id: timeAxisY;   titleText: "Total Flight Time (min)"; min: 0; visible: false }
                    ValueAxis { id: sprayAxis;   titleText: "Spray Volume (L)"; min: 0; visible: false }
                    ValueAxis { id: fuelAxis;    titleText: "Fuel Consumed"; min: 0; visible: false }
                    ValueAxis { id: flowAxis;    titleText: "Flow Rate (L/min)"; min: 0; visible: false }
                    ValueAxis { id: areaAxis;    titleText: "Spray Area"; min: 0; visible: false }
                    DateTimeAxis { id: timeAxis; format: "MM/dd HH:mm"; tickCount: 6 }

                    LineSeries { id: distanceSeries; name: "Distance"; axisX: timeAxis; axisY: distanceAxis; visible: false }
                    LineSeries { id: batterySeries;  name: "Battery %"; axisX: timeAxis; axisY: batteryAxis; visible: false }
                    LineSeries { id: timeSeries;     name: "Total Flight Time (min)"; axisX: timeAxis; axisY: timeAxisY; visible: false }
                    LineSeries { id: spraySeries;    name: "Spray Volume (L)"; axisX: timeAxis; axisY: sprayAxis; visible: false }
                    LineSeries { id: fuelSeries;     name: "Fuel"; axisX: timeAxis; axisY: fuelAxis; visible: false }
                    LineSeries { id: flowSeries;     name: "Flow Rate (L/min)"; axisX: timeAxis; axisY: flowAxis; visible: false }
                    LineSeries { id: areaSeries;     name: "Spray Area"; axisX: timeAxis; axisY: areaAxis; visible: false }

                    onSeriesAdded: (s, idx) => {
                        if (s === distanceSeries && !historyChart.axes(Qt.Vertical, distanceSeries).includes(distanceAxis)) {
                            historyChart.addAxis(distanceAxis, Qt.AlignLeft); distanceSeries.attachAxis(distanceAxis)
                        }
                        if (s === batterySeries && !historyChart.axes(Qt.Vertical, batterySeries).includes(batteryAxis)) {
                            historyChart.addAxis(batteryAxis, Qt.AlignLeft); batterySeries.attachAxis(batteryAxis)
                        }
                        if (s === timeSeries && !historyChart.axes(Qt.Vertical, timeSeries).includes(timeAxisY)) {
                            historyChart.addAxis(timeAxisY, Qt.AlignLeft); timeSeries.attachAxis(timeAxisY)
                        }
                        if (s === spraySeries && !historyChart.axes(Qt.Vertical, spraySeries).includes(sprayAxis)) {
                            historyChart.addAxis(sprayAxis, Qt.AlignLeft); spraySeries.attachAxis(sprayAxis)
                        }
                        if (s === fuelSeries && !historyChart.axes(Qt.Vertical, fuelSeries).includes(fuelAxis)) {
                            historyChart.addAxis(fuelAxis, Qt.AlignLeft); fuelSeries.attachAxis(fuelAxis)
                        }
                        if (s === flowSeries && !historyChart.axes(Qt.Vertical, flowSeries).includes(flowAxis)) {
                            historyChart.addAxis(flowAxis, Qt.AlignLeft); flowSeries.attachAxis(flowAxis)
                        }
                        if (s === areaSeries && !historyChart.axes(Qt.Vertical, areaSeries).includes(areaAxis)) {
                            historyChart.addAxis(areaAxis, Qt.AlignLeft); areaSeries.attachAxis(areaAxis)
                        }
                    }

                    function updateSeries(points, limits) {
                        distanceSeries.clear()
                        batterySeries.clear()
                        timeSeries.clear()
                        spraySeries.clear()
                        fuelSeries.clear()
                        flowSeries.clear()
                        areaSeries.clear()

                        if (!points || points.length === 0) return

                        for (let i = 0; i < points.length; i++) {
                            let p = points[i]
                            distanceSeries.append(p.tMs, p.distance)
                            batterySeries.append(p.tMs, p.battery)
                            timeSeries.append(p.tMs, p.flightTime)
                            spraySeries.append(p.tMs, p.sprayVolume)
                            fuelSeries.append(p.tMs, p.fuel)
                            flowSeries.append(p.tMs, p.flowRate)
                            areaSeries.append(p.tMs, p.sprayArea)
                        }

                        timeAxis.min = new Date(limits.timeMin)
                        timeAxis.max = new Date(limits.timeMax)
                        distanceAxis.max = limits.distMax
                        timeAxisY.max = limits.timeMaxY
                        sprayAxis.max = limits.sprayMax
                        fuelAxis.max = limits.fuelMax
                        flowAxis.max = limits.flowMax
                        areaAxis.max = limits.areaMax
                    }

                    Connections {
                        target: logDownloadController
                        function onHistoryTextChanged() {
                            let points = logDownloadController.parseHistory(logDownloadController.historyText)
                            let limits = logDownloadController.rebuildSeries(points)
                            historyChart.updateSeries(points, limits)

                            todaySummary = logDownloadController.computeSummary(points) // store summary
                            droneStatisticsPage.totalFlights     = todaySummary.flights
                            droneStatisticsPage.totalFlightTime  = todaySummary.totalTimeMin.toFixed(1)
                            droneStatisticsPage.totalSprayVolume = todaySummary.totalSprayVol.toFixed(2)
                            droneStatisticsPage.totalSprayArea   = todaySummary.totalSprayArea.toFixed(2)
                        }
                    }
                }

                // === Toggle Buttons ===
                Row {
                    id: toggleRow
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCButton { 
                        text: "Distance"; checkable: true
                        onToggled: {
                            distanceSeries.visible = checked
                            distanceAxis.visible = checked
                        }
                    }
                    
                    QGCButton { 
                        text: "Battery"; checkable: true
                        onToggled: {
                            batterySeries.visible = checked
                            batteryAxis.visible   = checked
                        }
                    }

                    QGCButton { 
                        text: "Flight Time"; checkable: true
                        onToggled: {
                            timeSeries.visible = checked
                            timeAxisY.visible  = checked
                        }
                    }

                    QGCButton { 
                        text: "Spray Volume"; checkable: true
                        onToggled: {
                            spraySeries.visible = checked
                            sprayAxis.visible   = checked
                        }
                    }

                    QGCButton { 
                        text: "Fuel"; checkable: true
                        onToggled: {
                            fuelSeries.visible = checked
                            fuelAxis.visible   = checked
                        }
                    }

                    QGCButton { 
                        text: "Flow Rate"; checkable: true
                        onToggled: {
                            flowSeries.visible = checked
                            flowAxis.visible   = checked
                        }
                    }

                    QGCButton { 
                        text: "Spray Area"; checkable: true
                        onToggled: {
                            areaSeries.visible = checked
                            areaAxis.visible   = checked
                        }
                    }

                    QGCButton {
                        text: "Zoom Reset"
                        onClicked: historyChart.zoomReset()
                    }
                }
            }
        }
    }
}




