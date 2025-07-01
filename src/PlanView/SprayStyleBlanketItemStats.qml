import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls

// Statistics section for TransectStyleComplexItems
Grid {
    // The following properties must be available up the hierarchy chain
    //property var    missionItem       ///< Mission Item for editor

    columns:        2
    columnSpacing:  ScreenTools.defaultFontPixelWidth

    property double _numericAreaM2: missionItem.coveredArea
    property string _surveyAreaString: QGroundControl.unitsConversion.squareMetersToAppSettingsAreaUnits(_numericAreaM2).toFixed(2) + " " + QGroundControl.unitsConversion.appSettingsAreaUnitsString
    property string _surveyAreaHectaresString: (_numericAreaM2 * 0.0001).toFixed(4) // 1 m^2 = 0.0001 ha.

    QGCLabel { text: qsTr("Spray Area (m^2)") }
    QGCLabel { text: _surveyAreaString }

    QGCLabel { text: qsTr("Spray Area (ha)") }
    QGCLabel { text: _surveyAreaHectaresString + " " + qsTr("ha")}

    QGCLabel { text: qsTr(" ") }
    QGCLabel { text: qsTr(" ") }

}
