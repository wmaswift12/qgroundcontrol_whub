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

Item {
    id:             sprayAreaControl
    width:          sprayAreaRow.width
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    
    Row {
        id:             sprayAreaRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 2

        ColumnLayout {
            id:         sprayAreaColumn
            anchors.verticalCenter: parent.verticalCenter
            spacing:    ScreenTools.defaultFontPixelHeight / 4

            // Heading for the custom values section
            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Spray Area") 
                font.pointSize: ScreenTools.defaultFontPointSize
                font.bold: true
                color: qgcPal.text
                // CORRECTED: This check prevents the crash
                visible: _activeVehicle && _activeVehicle.sprayArea && Object.keys(_activeVehicle.sprayArea).length > 0
            }

            // Repeater to iterate over the keys
            Repeater {
                // CORRECTED: This check prevents the crash
                model: _activeVehicle && _activeVehicle.sprayArea ? Object.keys(_activeVehicle.sprayArea) : []

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCColoredImage {
                        height:             ScreenTools.defaultFontPixelHeight
                        width:              height
                        anchors.verticalCenter: parent.verticalCenter
                        source:             "/qmlimages/sprayDistance.svg"
                        fillMode:           Image.PreserveAspectFit
                        sourceSize.height:  height
                        opacity:            (_activeVehicle.sprayArea[modelData] > 0) ? 1 : 0.5
                        color:              qgcPal.buttonText
                    }

                    QGCLabel {
                        width: ScreenTools.defaultFontPixelWidth * 4
                        text: _activeVehicle.sprayArea[modelData].toFixed(2)
                        color: qgcPal.text
                        font.pointSize: ScreenTools.defaultFontPointSize
                        horizontalAlignment: Text.AlignLeft
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text: modelData
                        color: qgcPal.text
                        font.pointSize: ScreenTools.defaultFontPointSize
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // "No data" message
            Row {
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                spacing: ScreenTools.defaultFontPixelWidth / 2
                // This logic was already robust and correct
                visible: _activeVehicle && (!_activeVehicle.sprayArea || Object.keys(_activeVehicle.sprayArea).length === 0)

                QGCColoredImage {
                    height:             ScreenTools.defaultFontPixelHeight
                    width:              height
                    source:             "/qmlimages/sprayDistance.svg"
                    fillMode:           Image.PreserveAspectFit
                    sourceSize.height:  height
                    opacity:            1.0
                    color:              qgcPal.buttonText
                }

                QGCLabel {
                    text: qsTr("No Area available.")
                    color: qgcPal.text
                    font.pointSize: ScreenTools.defaultFontPointSize
                }
            }
        }
    }
}