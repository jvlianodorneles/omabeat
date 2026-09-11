import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "BeatModel.js" as Model

// BarWidget.qml — Swatch Internet Time status bar widget for Omarchy
BarWidget {
  id: root
  moduleName: "dorneles.omabeat"

  // Live settings from shell.json / config
  property string currentFormat: setting("format", "beats")
  property bool showCentibeats: setting("showCentibeats", false)
  property string badgeStyle: setting("badgeStyle", "flat")
  property bool showIcon: setting("showIcon", true)
  property bool showPrefix: setting("showPrefix", true)
  property bool showSuffix: setting("showSuffix", false)
  property bool centuryChime: setting("centuryChime", false)
  property bool copyNotification: setting("copyNotification", true)

  // Live time tracking
  property date currentDate: clock.date
  readonly property var stats: Model.calculateBeats(currentDate)

  // Formatted status bar text
  readonly property string displayText: Model.formatDisplay(
    stats,
    root.currentFormat,
    root.showCentibeats,
    root.showPrefix,
    root.showSuffix
  )

  function sanitizeText(s) {
    return String(s || "").replace(/[<>&]/g, "").slice(0, 50)
  }

  // Multi-line detailed tooltip
  readonly property string tooltipInfo: {
    var lines = [
      "⏱ Swatch Internet Time (.beat)",
      "────────────────────────────────",
      "• Swatch Beat: " + stats.formattedCentibeats + " (" + stats.progressPercent + "% of day)",
      "• Biel Mean Time (BMT): " + stats.bmtTime + " (UTC+1, no DST)",
      "• UTC Time: " + stats.utcTime,
      "• Local Time: " + stats.localTime,
      "• Internet Date: " + stats.internetDate,
      "• Beats Remaining Today: " + stats.beatsRemaining + " beats",
      "────────────────────────────────",
      "• Left-click: Open Panel & Converter",
      "• Middle-click: Toggle Centibeats (" + (root.showCentibeats ? "Active" : "Off") + ")",
      "• Right-click: Copy Beat (" + stats.formattedInt + ")",
      "• Scroll: Cycle Format (" + sanitizeText(root.currentFormat) + ")"
    ]
    return lines.join("\n")
  }

  // Popout panel coordinator contract (Omarchy shell standard)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function copyBeat() {
    var text = root.showCentibeats ? stats.formattedCentibeats : stats.formattedInt
    Quickshell.execDetached(["wl-copy", "--", text])

    if (root.copyNotification) {
      Quickshell.execDetached([
        "notify-send",
        "-a", "OmaBeat",
        "-i", "clock",
        "Swatch Beat Copied",
        text + " (" + stats.localShortTime + " local • " + stats.bmtTime + " BMT)"
      ])
    }
  }

  function toggleCentibeats() {
    root.showCentibeats = !root.showCentibeats
    root.updateSetting("showCentibeats", root.showCentibeats)
  }

  function cycleFormat() {
    var next = Model.nextFormat(root.currentFormat)
    root.currentFormat = next
    root.updateSetting("format", next)
  }

  function updateSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) {
      if (k !== "id") entry[k] = root.settings[k]
    }
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  // Century chime notification check
  property int lastCenturyNotified: -1
  onStatsChanged: {
    if (root.centuryChime && stats.intBeats % 100 === 0 && stats.intBeats !== root.lastCenturyNotified) {
      root.lastCenturyNotified = stats.intBeats
      Quickshell.execDetached([
        "notify-send",
        "-a", "OmaBeat",
        "-i", "clock",
        "Century Beat Milestone!",
        "Universal Internet Time is now @" + String(stats.intBeats).padStart(3, "0") + " (" + stats.progressPercent + "% of day)."
      ])
    }
  }

  // Inject bar properties into popout panel
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // System clock: seconds precision
  SystemClock {
    id: clock
    precision: SystemClock.Seconds
    onDateChanged: root.currentDate = date
  }

  // Faster timer when live centibeats are displayed or panel is opened
  Timer {
    id: centiTimer
    interval: 864
    repeat: true
    running: root.showCentibeats || root.opened
    onTriggered: root.currentDate = new Date()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // IPC handler for keybindings and shell commands
  IpcHandler {
    target: "dorneles.omabeat"

    function toggle(): void { root.togglePanel() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function copy(): void { root.copyBeat() }
    function toggleCentibeats(): void { root.toggleCentibeats() }
    function cycle(): void { root.cycleFormat() }
  }

  implicitWidth: root.vertical
    ? barSize
    : (button.implicitWidth + (root.badgeStyle === "pill" || root.badgeStyle === "progress" ? 8 : 0))
  implicitHeight: root.vertical
    ? (button.implicitHeight + 4)
    : barSize

  // Pill badge background
  Rectangle {
    anchors.fill: parent
    anchors.margins: 2
    visible: (root.badgeStyle === "pill" || root.badgeStyle === "progress") && !root.vertical
    radius: height / 2
    color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.25) : "transparent"
    border.width: 1
    border.color: root.bar ? Qt.rgba(root.bar.barForeground.r, root.bar.barForeground.g, root.bar.barForeground.b, 0.15) : "transparent"
    clip: true

    // Progress bar fill across the day
    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * root.stats.progress
      visible: root.badgeStyle === "progress"
      radius: height / 2
      color: Util.alpha(Color.accent, 0.22)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical
    hasVisualContent: true
    active: root.opened
    tooltipText: root.tooltipInfo
    horizontalMargin: (root.badgeStyle === "pill" || root.badgeStyle === "progress") ? 6 : 8.75

    // Vertical orientation optical display
    Column {
      visible: root.vertical
      anchors.fill: parent

      OpticalGlyph {
        width: button.width
        height: Style.bar.iconSlot
        text: "@"
        fontFamily: button.fontFamily
        fontSize: button.fontSize
        color: Color.accent
      }

      OpticalGlyph {
        width: button.width
        height: Style.bar.iconSlot
        text: root.stats.digitsOnly
        fontFamily: button.fontFamily
        fontSize: button.fontSize * 0.85
        color: button.foreground
      }
    }

    onPressed: function(btn) {
      if (btn === Qt.RightButton) {
        root.copyBeat()
      } else if (btn === Qt.MiddleButton) {
        root.toggleCentibeats()
      } else {
        root.togglePanel()
      }
    }

    onWheelMoved: function(delta) {
      root.cycleFormat()
    }
  }
}
