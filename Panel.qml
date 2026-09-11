import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "BeatModel.js" as Model

Panel {
  id: root
  moduleName: "dorneles.omabeat"
  ipcTarget: "dorneles.omabeat"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Live date & beat calculation
  property date currentDate: new Date()
  readonly property var beatStats: Model.calculateBeats(currentDate)
  readonly property var milestones: Model.getMilestones(beatStats.beats, currentDate)
  readonly property var centuryInfo: Model.getNextCenturyBeat(beatStats.beats)

  // Interactive converter state
  property int sliderBeat: Math.round(beatStats.beats)
  readonly property var sliderLocalResult: Model.beatsToLocalTime(sliderBeat, currentDate)

  // Settings & Toggles
  property bool showCentibeats: hostWidget ? hostWidget.showCentibeats : setting("showCentibeats", false)
  property bool centuryChime: hostWidget ? hostWidget.centuryChime : setting("centuryChime", false)
  property bool copyNotification: hostWidget ? hostWidget.copyNotification : setting("copyNotification", true)

  // Feedback on copy
  property bool copySuccess: false
  property string lastCopiedText: ""

  function open() {
    root.currentDate = new Date()
    root.sliderBeat = Math.round(root.beatStats.beats)
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function copyText(text) {
    if (!text) return
    root.lastCopiedText = text
    Quickshell.execDetached(["wl-copy", text])

    if (root.copyNotification) {
      Quickshell.execDetached([
        "notify-send",
        "-a", "OmaBeat",
        "-i", "clock",
        "Swatch Internet Time Copied",
        text + " (BMT " + root.beatStats.bmtTime + " • Local " + root.beatStats.localTime + ")"
      ])
    }

    root.copySuccess = true
    copyTimer.restart()
  }

  function copyCurrentBeat(withCenti) {
    var str = withCenti ? root.beatStats.formattedCentibeats : root.beatStats.formattedInt
    root.copyText(str)
  }

  function copyFullTimestamp() {
    var str = root.beatStats.formattedInt + " (" + root.beatStats.internetDate + " • " + root.beatStats.bmtTime + " BMT)"
    root.copyText(str)
  }

  function toggleCentibeats() {
    if (hostWidget && typeof hostWidget.toggleCentibeats === "function") {
      hostWidget.toggleCentibeats()
    } else {
      root.showCentibeats = !root.showCentibeats
    }
  }

  function jumpToBeat(targetBeat) {
    root.sliderBeat = Math.max(0, Math.min(1000, targetBeat))
  }

  // Ticking timer when panel is open (864 ms = 1 centibeat)
  Timer {
    id: liveTimer
    interval: 864
    repeat: true
    running: root.opened
    onTriggered: {
      root.currentDate = new Date()
    }
  }

  Timer {
    id: copyTimer
    interval: 1800
    repeat: false
    onTriggered: {
      root.copySuccess = false
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem || (hostWidget ? hostWidget : null)
    owner: root.barIdentity
    bar: root.bar || (hostWidget ? hostWidget.bar : null)
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)
    focusTarget: keyCatcher

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "c" || t === "C") {
          root.copyCurrentBeat(false)
        } else if (t === "p" || t === "P") {
          root.toggleCentibeats()
        } else if (t === "r" || t === "R") {
          root.currentDate = new Date()
        } else if (t === "1") {
          root.jumpToBeat(0)
        } else if (t === "2") {
          root.jumpToBeat(250)
        } else if (t === "3") {
          root.jumpToBeat(500)
        } else if (t === "4") {
          root.jumpToBeat(750)
        }
      }

      ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        spacing: Style.space(12)

        // ---- HEADER ROW
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(26)
          spacing: Style.space(8)

          Text {
            text: "\uf017"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodyLarge
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            text: "SWATCH INTERNET TIME"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            font.letterSpacing: 1.1
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
          }

          Item { Layout.fillWidth: true }

          // Internet date badge (@dDD.MM.YY)
          Rectangle {
            Layout.preferredHeight: Style.space(20)
            Layout.preferredWidth: internetDateText.implicitWidth + Style.space(12)
            radius: Style.radius(10)
            color: Util.alpha(Color.accent, 0.15)

            Text {
              id: internetDateText
              anchors.centerIn: parent
              text: root.beatStats.internetDate
              color: Color.accent
              font.pixelSize: Style.font.caption
              font.bold: true
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
            }
          }

          // Close button
          Rectangle {
            Layout.preferredWidth: Style.space(22)
            Layout.preferredHeight: Style.space(22)
            radius: Style.radius(4)
            color: closeMouse.pressed ? Util.alpha(Color.foreground, 0.20) : (closeMouse.containsMouse ? Util.alpha(Color.foreground, 0.10) : "transparent")

            Text {
              anchors.centerIn: parent
              text: "✕"
              color: Color.popups.text
              font.pixelSize: 11
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }

        // ---- HERO CARD (Massive Beat Display + Progress)
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(112)
          radius: Style.radius(8)
          color: Util.alpha(Color.foreground, 0.04)
          border.width: 1
          border.color: Util.alpha(Color.foreground, 0.08)

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(6)

            // Large Number readout: @ 550 .85
            RowLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignHCenter
              spacing: Style.space(4)

              Item { Layout.fillWidth: true }

              Text {
                text: "@"
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: 34
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignBaseline
              }

              Text {
                text: root.beatStats.digitsOnly
                color: Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: 38
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignBaseline
              }

              Text {
                text: "." + root.beatStats.centibeatsDigits
                color: Util.alpha(Color.accent, 0.85)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: 22
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignBaseline
              }

              Text {
                text: ".beats"
                color: Util.alpha(Color.foreground, 0.50)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: false
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignBaseline
                Layout.leftMargin: Style.space(4)
              }

              Item { Layout.fillWidth: true }
            }

            // Day Beat Progress Bar
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(8)

              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Util.alpha(Color.foreground, 0.10)
              }

              Rectangle {
                width: parent.width * root.beatStats.progress
                height: parent.height
                radius: height / 2
                color: Color.accent
              }
            }

            // Progress labels
            RowLayout {
              Layout.fillWidth: true

              Text {
                text: "@000"
                color: Util.alpha(Color.foreground, 0.45)
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }

              Item { Layout.fillWidth: true }

              Text {
                text: root.beatStats.digitsOnly + " / 1000 • " + root.beatStats.progressPercent + "% of day"
                color: Util.alpha(Color.foreground, 0.70)
                font.pixelSize: Style.font.caption
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }

              Item { Layout.fillWidth: true }

              Text {
                text: "@1000"
                color: Util.alpha(Color.foreground, 0.45)
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }
            }
          }
        }

        // ---- TRI-TIME REFERENCE CHIPS (BMT / UTC / LOCAL)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          // BMT Chip (Biel Mean Time)
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            radius: Style.radius(6)
            color: Util.alpha(Color.foreground, 0.03)
            border.width: 1
            border.color: Util.alpha(Color.accent, 0.25)

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 1

              Text {
                text: "BIEL (BMT • UTC+1)"
                color: Color.accent
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignHCenter
              }

              Text {
                text: root.beatStats.bmtTime
                color: Color.foreground
                font.pixelSize: Style.font.body
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignHCenter
              }
            }
          }

          // UTC Chip
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            radius: Style.radius(6)
            color: Util.alpha(Color.foreground, 0.03)
            border.width: 1
            border.color: Util.alpha(Color.foreground, 0.08)

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 1

              Text {
                text: "UTC"
                color: Util.alpha(Color.foreground, 0.50)
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignHCenter
              }

              Text {
                text: root.beatStats.utcTime
                color: Color.foreground
                font.pixelSize: Style.font.body
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignHCenter
              }
            }
          }

          // Local Time Chip
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            radius: Style.radius(6)
            color: Util.alpha(Color.foreground, 0.03)
            border.width: 1
            border.color: Util.alpha(Color.foreground, 0.08)

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 1

              Text {
                text: "LOCAL TIME"
                color: Util.alpha(Color.foreground, 0.50)
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignHCenter
              }

              Text {
                text: root.beatStats.localTime
                color: Color.foreground
                font.pixelSize: Style.font.body
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignHCenter
              }
            }
          }
        }

        // ---- INTERACTIVE BEAT CONVERTER
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          RowLayout {
            Layout.fillWidth: true

            Text {
              text: "\uf1ec"
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
            }

            Text {
              text: "Beat ⟷ Local Time Converter"
              color: Color.popups.text
              font.pixelSize: Style.font.body
              font.bold: true
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              Layout.preferredHeight: Style.space(22)
              Layout.preferredWidth: convBadgeText.implicitWidth + Style.space(12)
              radius: Style.radius(4)
              color: Util.alpha(Color.accent, 0.18)

              Text {
                id: convBadgeText
                anchors.centerIn: parent
                text: "@" + String(root.sliderBeat).padStart(3, "0") + " = " + root.sliderLocalResult.shortTimeStr + " local"
                color: Color.accent
                font.bold: true
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }
            }
          }

          // Slider for selecting target beat
          PanelSlider {
            Layout.fillWidth: true
            bar: root.bar
            minimum: 0
            maximum: 1000
            step: 5
            integer: true
            value: root.sliderBeat
            tickCount: 11
            onMoved: function(v) { root.sliderBeat = Math.round(v) }
            onReleased: function(v) { root.sliderBeat = Math.round(v) }
          }

          // Milestone Quick-Select Buttons
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            Repeater {
              model: root.milestones

              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(28)
                radius: Style.radius(5)
                color: mBtnMouse.pressed
                  ? Util.alpha(Color.accent, 0.35)
                  : (mBtnMouse.containsMouse ? Util.alpha(Color.accent, 0.20) : (modelData.isCurrent ? Util.alpha(Color.accent, 0.12) : Util.alpha(Color.foreground, 0.04)))
                border.width: 1
                border.color: modelData.isCurrent ? Color.accent : Util.alpha(Color.foreground, 0.08)

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: modelData.formattedBeat
                    color: modelData.isCurrent ? Color.accent : Color.foreground
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                  }

                  Text {
                    text: "(" + modelData.localTime + ")"
                    color: Util.alpha(Color.foreground, 0.55)
                    font.pixelSize: Style.font.caption - 1
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                  }
                }

                MouseArea {
                  id: mBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.jumpToBeat(modelData.beat)
                }
              }
            }
          }
        }

        // ---- ACTIONS ROW (Copy Buttons)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          // Copy Current Beat Button
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(32)
            radius: Style.radius(6)
            color: copyBeatMouse.pressed
              ? Util.alpha(Color.accent, 0.8)
              : (copyBeatMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.16))
            border.width: 1
            border.color: Color.accent

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                text: root.copySuccess ? "\uf00c" : "\uf0c5"
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }

              Text {
                text: root.copySuccess ? "Copied " + root.lastCopiedText + "!" : "Copy " + root.beatStats.formattedInt
                color: Color.foreground
                font.pixelSize: Style.font.caption
                font.bold: true
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }
            }

            MouseArea {
              id: copyBeatMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyCurrentBeat(false)
            }
          }

          // Copy Centibeats Button
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(32)
            radius: Style.radius(6)
            color: copyCentiMouse.pressed
              ? Util.alpha(Color.foreground, 0.15)
              : (copyCentiMouse.containsMouse ? Util.alpha(Color.foreground, 0.08) : Util.alpha(Color.foreground, 0.04))
            border.width: 1
            border.color: Util.alpha(Color.foreground, 0.10)

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                text: "\uf0c5"
                color: Util.alpha(Color.foreground, 0.60)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }

              Text {
                text: "Copy " + root.beatStats.formattedCentibeats
                color: Color.foreground
                font.pixelSize: Style.font.caption
                font.bold: false
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }
            }

            MouseArea {
              id: copyCentiMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyCurrentBeat(true)
            }
          }

          // Full Timestamp Button
          Rectangle {
            Layout.preferredWidth: Style.space(34)
            Layout.preferredHeight: Style.space(32)
            radius: Style.radius(6)
            color: copyFullMouse.pressed
              ? Util.alpha(Color.foreground, 0.15)
              : (copyFullMouse.containsMouse ? Util.alpha(Color.foreground, 0.08) : Util.alpha(Color.foreground, 0.04))
            border.width: 1
            border.color: Util.alpha(Color.foreground, 0.10)

            Text {
              anchors.centerIn: parent
              text: "\uf013"
              color: Util.alpha(Color.foreground, 0.70)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: copyFullMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyFullTimestamp()
            }
          }
        }

        // ---- MILESTONE & STATUS FOOTER
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(26)
          radius: Style.radius(4)
          color: Util.alpha(Color.foreground, 0.03)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)

            Text {
              text: "Next Century: " + root.centuryInfo.formattedNextBeat + " in " + root.centuryInfo.beatsLeft + " beats (~" + root.centuryInfo.minutesLeft + " min)"
              color: Util.alpha(Color.foreground, 0.60)
              font.pixelSize: Style.font.caption - 1
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "[c] Copy • [p] Centi • [1-4] Presets • [Esc]"
              color: Util.alpha(Color.foreground, 0.40)
              font.pixelSize: Style.font.caption - 1
              font.family: "monospace"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
            }
          }
        }
      }
    }
  }
}
