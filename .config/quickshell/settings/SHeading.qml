import QtQuick
import "../Colors.js" as Colors

// Nadpis sekce; odsazení zleva sedí s textem řádků (SRow má leftMargin 14)
Text {
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
    color: Colors.primary
    topPadding: 18
    bottomPadding: 6
    leftPadding: 14
}
