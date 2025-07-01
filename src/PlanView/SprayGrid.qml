import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette

// Camera calculator "Grid" section for mission item editors
Column {
    spacing: _margin

    property var    sprayCalc
    property bool   vehicleFlightIsFrontal:         true
    property string distanceToSurfaceLabel
    property string frontalDistanceLabel
    property string sideDistanceLabel

    property string param1WaypointLabel

    property real   _margin:            ScreenTools.defaultFontPixelWidth / 2
    property real   _fieldWidth:        ScreenTools.defaultFontPixelWidth * 10.5
    property var    _vehicle:           QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property bool   _cameraComboFilled: false

    readonly property int _gridTypeManual:          0
    readonly property int _gridTypeCustomCamera:    1
    readonly property int _gridTypeCamera:          2

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    /*
    Column {
        anchors.left:   parent.left
        anchors.right:  parent.right
        spacing:        _margin
        visible:        !sprayCalc.isManualCamera

        RowLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        _margin
            Item { Layout.fillWidth: true }
            QGCLabel {
                Layout.preferredWidth:  _root._fieldWidth
                text:                   qsTr("Front Lap")
            }
            QGCLabel {
                Layout.preferredWidth:  _root._fieldWidth
                text:                   qsTr("Side Lap")
            }
        }

        RowLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        _margin
            QGCLabel { text: qsTr("Overlap"); Layout.fillWidth: true }
            FactTextField {
                Layout.preferredWidth:  _root._fieldWidth
                fact:                   sprayCalc.frontalOverlap
            }
            FactTextField {
                Layout.preferredWidth:  _root._fieldWidth
                fact:                   sprayCalc.sideOverlap
            }
        }

        QGCLabel {
            wrapMode:               Text.WordWrap
            text:                   qsTr("Select one:")
            Layout.preferredWidth:  parent.width
            Layout.columnSpan:      2
        }

        GridLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            columnSpacing:  _margin
            rowSpacing:     _margin
            columns:        2

            QGCRadioButton {
                id:                     fixedDistanceRadio
                leftPadding:            0
                text:                   distanceToSurfaceLabel
                checked:                !!sprayCalc.valueSetIsDistance.value
                onClicked:              sprayCalc.valueSetIsDistance.value = 1
            }

            AltitudeFactTextField {
                fact:                       sprayCalc.distanceToSurface
                altitudeMode:               sprayCalc.distanceMode
                enabled:                    fixedDistanceRadio.checked
                Layout.fillWidth:           true
            }

            QGCRadioButton {
                id:                     fixedImageDensityRadio
                leftPadding:            0
                text:                   qsTr("Grnd Res")
                checked:                !sprayCalc.valueSetIsDistance.value
                onClicked:              sprayCalc.valueSetIsDistance.value = 0
            }

            FactTextField {
                fact:                   sprayCalc.imageDensity
                enabled:                fixedImageDensityRadio.checked
                Layout.fillWidth:       true
            }
        }
    } // Column - Camera spec based ui
    */

    // No camera spec ui
    GridLayout {
        anchors.left:   parent.left
        anchors.right:  parent.right
        columnSpacing:  _margin
        rowSpacing:     _margin
        columns:        2
        visible:        sprayCalc.isManualCamera

        QGCLabel { text: distanceToSurfaceLabel }
        AltitudeFactTextField {
            fact:                       sprayCalc.distanceToSurface
            altitudeMode:               sprayCalc.distanceMode
            Layout.fillWidth:           true
        }

        QGCLabel { text: frontalDistanceLabel }
        FactTextField {
            Layout.fillWidth:   true
            fact:               sprayCalc.adjustedFootprintFrontal
        }

        QGCLabel { text: sideDistanceLabel }
        FactTextField {
            Layout.fillWidth:   true
            fact:               sprayCalc.adjustedFootprintSide
        }
    } // GridLayout
} // Column
