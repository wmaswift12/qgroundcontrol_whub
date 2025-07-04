/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Palette

// This QML component displays custom named float values received from a MAVLink vehicle
// via TUNNEL messages. It adapts the layout and interaction pattern from GPSIndicator.qml.

Item {
    id:             flowRatesControl // Changed ID from 'control' to be more specific
    width:          flowRatesRow.width // Adjust width based on its content
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    Row {
        id:             flowRatesRow // Changed ID from 'gpsIndicatorRow'
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 2

        // This Column will hold the dynamically generated custom values
        ColumnLayout {
            id:         flowRatesColumn
            anchors.verticalCenter: parent.verticalCenter
            spacing:    ScreenTools.defaultFontPixelHeight / 4 // Small spacing between items

            // Heading for the custom values section (optional, can be removed if space is tight)
            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Flow Rate") 
                font.pointSize: ScreenTools.defaultFontPointSize
                font.bold: true
                color: qgcPal.text
                // Only visible if there's an active vehicle and some named values to show
                visible: _activeVehicle && Object.keys(_activeVehicle.flowRates).length > 0
            }

            // Repeater to iterate over the keys of the _activeVehicle.flowRates QVariantMap.
            Repeater {
                model: _activeVehicle ? Object.keys(_activeVehicle.flowRates) : []

                // Each item in the repeater represents one named value (e.g., "Volume: 123.45")
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    // Image of the spray, adjusted to the new requirements
                    QGCColoredImage {
                        id:                 sprayIcon
                        height:             ScreenTools.defaultFontPixelHeight // Define height first
                        width:              height // Then set width to match height for square aspect
                        anchors.verticalCenter: parent.verticalCenter // Center vertically within the RowLayout
                        source:             "/qmlimages/Spray.svg" // Path to your spray image
                        fillMode:           Image.PreserveAspectFit
                        sourceSize.height:  height // Ensure sourceSize.height matches the actual height
                        // Opacity based on the current named value's data
                        opacity:            (_activeVehicle && _activeVehicle.flowRates[modelData] > 0) ? 1 : 0.5
                        color:              qgcPal.buttonText
                    }

                    // Label for the actual value
                    QGCLabel {
                        // Adjust width as needed to accommodate image
                        width: ScreenTools.defaultFontPixelWidth * 4
                        // Access the value from the flowRates map using the current key (modelData)
                        text: _activeVehicle.flowRates[modelData].toFixed(2) // Format float to 2 decimal places
                        color: qgcPal.text
                        font.pointSize: ScreenTools.defaultFontPointSize
                        horizontalAlignment: Text.AlignLeft // Align value to the left
                    }

                    // Label for the name of the value
                    QGCLabel {
                        Layout.fillWidth: true
                        text: modelData // modelData = "mL/min"
                        color: qgcPal.text
                        font.pointSize: ScreenTools.defaultFontPointSize
                        horizontalAlignment: Text.AlignRight // Align name to the right
                    }
                }
            }

            // Optional: A message to show if no custom values are available
            Row {
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                spacing: ScreenTools.defaultFontPixelWidth / 2 // Spacing between icon and text
                visible: _activeVehicle && Object.keys(_activeVehicle.flowRates).length === 0

                // Left-side
                QGCColoredImage {
                    id:                 noValuesSprayIcon // New ID for this specific icon
                    height:             ScreenTools.defaultFontPixelHeight // Consistent sizing
                    width:              height
                    source:             "/qmlimages/Spray.svg" // Corrected source to Spray.svg
                    fillMode:           Image.PreserveAspectFit
                    sourceSize.height:  height
                    opacity:            1.0 // Fixed opacity when no values are available
                    color:              qgcPal.buttonText
                }

                // Right-side
                QGCLabel {
                    text: qsTr("No Flow Rate available.")
                    color: qgcPal.text
                    font.pointSize: ScreenTools.defaultFontPointSize
                    // Layout.fillWidth: true // Optional: if you want the text to take available width
                }
            }
        }
    }
    
}
