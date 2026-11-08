import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Gaming Hub: Comprehensive Linux Gaming Optimization, MangoHud FPS Overlay Controller,
// Low-Latency Hyprland Tearing/VRR Engine, Active Game Radar, Hardware Telemetry, and On-Screen Crosshair.
Panel {
  id: root
  moduleName: "sushantkr.gaming"
  ipcTarget: "sushantkr.gaming"

  readonly property color barFg: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property color barUrgent: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property color accentColor: Commons.Color.accent
  readonly property string barFont: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property bool vertical: root.bar ? root.bar.vertical : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string helperPath: String(Qt.resolvedUrl("scripts/game-ctl")).replace(/^file:\/\//, "")

  // Live state from game-ctl
  property bool gameBoost: false
  property string powerProfile: "balanced"
  property bool animEnabled: true
  property bool blurEnabled: true
  property bool tearingEnabled: false
  property bool vrrEnabled: false
  property bool mangohudInstalled: false
  property bool gamemodeInstalled: false
  property bool steamInstalled: true
  property bool heroicInstalled: true
  property bool fpsOverlayEnabled: true
  property string mangohudPos: "top-left"
  property int fpsCap: 0
  property var features: ({ fps: true, frametime: true, cpu: true, gpu: true, vram: true, ram: true, battery: false })
  property var gpuInfo: ({ name: "NVIDIA GPU", temp: 0, util: 0, vram_used: 0, vram_total: 4096, power: 0 })
  property var cpuInfo: ({ governor: "powersave", freq_mhz: 0 })
  property bool micMuted: false
  property var activeGame: ({ running: false, title: "", class: "", pid: 0 })

  // Crosshair state
  property bool crosshairEnabled: false
  property string crosshairStyle: "dot"
  property color crosshairColor: "#00FF66"
  property int crosshairSize: 16

  // UI state
  property string currentTab: "perf" // "perf", "fps", "radar", "tools"
  property string statusMsg: ""

  // Translations
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // Status parser
  function parseStatus(raw) {
    try {
      var data = JSON.parse(raw)
      root.gameBoost = Boolean(data.game_boost)
      root.powerProfile = String(data.power_profile || "balanced")
      root.animEnabled = Boolean(data.animations_enabled)
      root.blurEnabled = Boolean(data.blur_enabled)
      root.tearingEnabled = Boolean(data.tearing_enabled)
      root.vrrEnabled = Boolean(data.vrr_enabled)
      root.mangohudInstalled = Boolean(data.mangohud_installed)
      root.gamemodeInstalled = Boolean(data.gamemode_installed)
      root.steamInstalled = Boolean(data.steam_installed)
      root.heroicInstalled = Boolean(data.heroic_installed)
      root.fpsOverlayEnabled = Boolean(data.fps_overlay_enabled)
      root.mangohudPos = String(data.mangohud_pos || "top-left")
      root.fpsCap = parseInt(data.fps_cap) || 0
      root.features = data.features || root.features
      root.gpuInfo = data.gpu || root.gpuInfo
      root.cpuInfo = data.cpu || root.cpuInfo
      root.micMuted = Boolean(data.mic_muted)
      root.activeGame = data.active_game || root.activeGame

      if (data.crosshair) {
        root.crosshairEnabled = Boolean(data.crosshair.enabled)
        root.crosshairStyle = String(data.crosshair.style || "dot")
        root.crosshairColor = String(data.crosshair.color || "#00FF66")
        root.crosshairSize = parseInt(data.crosshair.size) || 16
      }
    } catch (e) {
      // Ignore transient parse error
    }
  }

  // Action runners
  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runCmd(args, msg) {
    if (cmdProc.running) return
    if (msg) {
      statusMsg = msg
      statusTimer.restart()
    }
    var full = [helperPath]
    for (var i = 0; i < args.length; i++) full.push(String(args[i]))
    cmdProc.command = full
    cmdProc.running = true
  }

  function toggleBoost() {
    runCmd(["boost", "toggle"], gameBoost ? "Restoring normal desktop…" : "Activating Game Boost…")
  }

  function toggleFps() {
    runCmd(["toggle-fps", "toggle"], fpsOverlayEnabled ? "FPS Overlay: OFF" : "FPS Overlay: ON")
  }

  function setFpsPreset(name) {
    runCmd(["set-preset", name], "Applied " + name + " HUD preset")
  }

  function setFpsCap(limit) {
    runCmd(["set-fps-cap", String(limit)], limit === 0 ? "FPS Cap: Unlocked" : "FPS Cap: " + limit)
  }

  function setFpsPos(pos) {
    runCmd(["set-position", pos], "HUD position: " + pos)
  }

  function toggleFeature(feat) {
    runCmd(["toggle-feature", feat], "Toggled " + feat)
  }

  function toggleHypr(opt) {
    runCmd(["toggle-hypr", opt], "Toggled " + opt)
  }

  function setPowerProfile(prof) {
    runCmd(["set-power-profile", prof], "Power profile: " + prof)
  }

  function toggleMic() {
    runCmd(["toggle-mic"], micMuted ? "Microphone Unmuted" : "Microphone Muted")
  }

  function boostGame(pid) {
    runCmd(["boost-game", String(pid)], "Boosted Game Priority (PID " + pid + ")")
  }

  function killGame(pid) {
    runCmd(["kill-game", String(pid)], "Terminated Game Process")
  }

  function sendHudToggleKey() {
    runCmd(["send-hud-toggle"], "Sent HUD Toggle (Shift+F12)")
  }

  function installTools() {
    runCmd(["install-tools"], "Opening installer terminal…")
  }

  function launchGame(target) {
    runCmd(["launch-game", target], "Launching " + target + "…")
  }

  function saveCrosshair(en, sty, col, sz) {
    root.crosshairEnabled = en
    root.crosshairStyle = sty
    root.crosshairColor = col
    root.crosshairSize = sz
    runCmd(["save-crosshair", String(en), sty, String(col), String(sz)])
  }

  // Background processes
  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Process {
    id: cmdProc
    onExited: {
      root.refresh()
    }
  }

  onOpenedChanged: {
    if (opened) root.refresh()
  }

  // Periodic polling timers
  Timer {
    id: pollTimer
    interval: root.opened ? 2500 : (root.activeGame && root.activeGame.running ? 6000 : 20000)
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: statusTimer
    interval: 3500
    onTriggered: root.statusMsg = ""
  }

  // Dynamic bar icon and label
  readonly property string barLabel: {
    if (root.activeGame && root.activeGame.running) {
      var t = root.activeGame.title || root.activeGame.class || "Game"
      if (t.length > 14) t = t.substring(0, 12) + "…"
      return t
    }
    if (root.gameBoost) return "BOOST"
    return ""
  }

  readonly property color barIconColor: {
    if (root.gameBoost) return root.accentColor
    if (root.activeGame && root.activeGame.running) return root.accentColor
    return root.barFg
  }

  // Bar Widget: Controller icon with game/boost label
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰊴"
    labelText: !vertical ? root.barLabel : ""
    slotSize: Style.bar.iconSlot * (!vertical && root.barLabel !== "" ? 2.2 : 1)
    foreground: root.barIconColor
    tooltipText: {
      var tip = "Gaming Hub"
      if (root.activeGame && root.activeGame.running) tip += "\nIn-Game: " + root.activeGame.title
      tip += "\nBoost: " + (root.gameBoost ? "ACTIVE (Performance)" : "Off (" + root.powerProfile + ")")
      tip += "\nFPS Overlay: " + (root.fpsOverlayEnabled ? "ON" : "OFF")
      if (root.gpuInfo.name) tip += "\nGPU: " + root.gpuInfo.name + " (" + root.gpuInfo.temp + "°C)"
      tip += "\n• Left-Click: Open Panel\n• Right-Click: Toggle Game Boost\n• Middle-Click: Toggle FPS HUD"
      return tip
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.toggleBoost()
      } else if (b === Qt.MiddleButton) {
        root.toggleFps()
      } else {
        root.toggle()
      }
    }
  }

  // Popover Panel Window
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.toggleBoost()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ================= HERO HEADER =================
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroSwitch.implicitHeight)

          Text {
            id: heroIcon
            text: "󰊴"
            color: root.barIconColor
            font.family: root.barFont
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: heroSwitch.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "Gaming Hub"
              color: root.barFg
              font.family: root.barFont
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: {
                if (root.statusMsg !== "") return root.statusMsg
                if (root.activeGame && root.activeGame.running) return "In Game: " + root.activeGame.title
                if (root.gameBoost) return "Game Boost Active • Low Latency Mode"
                return root.gpuInfo.name + " • " + root.powerProfile
              }
              color: root.gameBoost ? root.accentColor : Qt.darker(root.barFg, 1.3)
              font.family: root.barFont
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          // Master Boost Switch in Header
          ToggleSwitch {
            id: heroSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.gameBoost
            onToggled: root.toggleBoost()
          }
        }

        // ================= NAVIGATION TABS =================
        Row {
          width: parent.width
          spacing: Style.space(4)

          Button {
            width: (parent.width - Style.space(12)) / 4
            text: "Boost"
            iconText: "󰓅"
            fontSize: Style.font.caption
            selected: root.currentTab === "perf"
            bordered: true
            onClicked: root.currentTab = "perf"
          }

          Button {
            width: (parent.width - Style.space(12)) / 4
            text: "FPS HUD"
            iconText: "󰍹"
            fontSize: Style.font.caption
            selected: root.currentTab === "fps"
            bordered: true
            onClicked: root.currentTab = "fps"
          }

          Button {
            width: (parent.width - Style.space(12)) / 4
            text: "Games"
            iconText: "󰊴"
            fontSize: Style.font.caption
            selected: root.currentTab === "radar"
            bordered: true
            onClicked: root.currentTab = "radar"
          }

          Button {
            width: (parent.width - Style.space(12)) / 4
            text: "Crosshair"
            iconText: "󰹑"
            fontSize: Style.font.caption
            selected: root.currentTab === "tools"
            bordered: true
            onClicked: root.currentTab = "tools"
          }
        }

        PanelSeparator {}

        // ================= TAB 1: PERFORMANCE & BOOST =================
        Column {
          visible: root.currentTab === "perf"
          width: parent.width
          spacing: Style.space(10)

          // Power Profiles Row
          PanelSectionHeader { text: "POWER GOVERNOR PROFILE" }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(12)) / 3
              text: "Performance"
              iconText: "󰓅"
              fontSize: Style.font.caption
              selected: root.powerProfile === "performance"
              bordered: true
              onClicked: root.setPowerProfile("performance")
            }

            Button {
              width: (parent.width - Style.space(12)) / 3
              text: "Balanced"
              iconText: "󰾆"
              fontSize: Style.font.caption
              selected: root.powerProfile === "balanced"
              bordered: true
              onClicked: root.setPowerProfile("balanced")
            }

            Button {
              width: (parent.width - Style.space(12)) / 3
              text: "Power Saver"
              iconText: "󰌪"
              fontSize: Style.font.caption
              selected: root.powerProfile === "power-saver"
              bordered: true
              onClicked: root.setPowerProfile("power-saver")
            }
          }

          // Hyprland Low Latency Toggles
          PanelSectionHeader { text: "HYPRLAND LOW LATENCY & DISPLAY" }

          Toggle {
            label: "Zero-Latency Tearing"
            description: "Allows tearing for raw competitive response"
            checked: root.tearingEnabled
            onClicked: root.toggleHypr("tearing")
          }

          Toggle {
            label: "Variable Refresh Rate (VRR)"
            description: "Adaptive Sync on capable monitors"
            checked: root.vrrEnabled
            onClicked: root.toggleHypr("vrr")
          }

          Toggle {
            label: "Disable Compositor Animations"
            description: "Zero window animation lag during gaming"
            checked: !root.animEnabled
            onClicked: root.toggleHypr("animations")
          }

          Toggle {
            label: "Disable Compositor Blur"
            description: "Frees up GPU fillrate & memory bandwidth"
            checked: !root.blurEnabled
            onClicked: root.toggleHypr("blur")
          }

          // Hardware Monitor Card
          PanelSectionHeader { text: "HARDWARE TELEMETRY" }

          BorderSurface {
            width: parent.width
            implicitHeight: hwCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: Style.controlFill(false, false, root.barFg, root.accentColor)

            Column {
              id: hwCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              StatPair {
                label: "Dedicated GPU"
                value: root.gpuInfo.name + " (" + root.gpuInfo.temp + "°C)"
              }

              StatPair {
                label: "GPU Load & Power"
                value: root.gpuInfo.util + "% • " + root.gpuInfo.power + "W"
              }

              StatPair {
                label: "VRAM Used"
                value: root.gpuInfo.vram_used + " MB / " + root.gpuInfo.vram_total + " MB"
              }

              StatPair {
                label: "CPU Governor & Freq"
                value: root.cpuInfo.governor + " • " + root.cpuInfo.freq_mhz + " MHz"
              }
            }
          }
        }

        // ================= TAB 2: FPS & MANGOHUD =================
        Column {
          visible: root.currentTab === "fps"
          width: parent.width
          spacing: Style.space(10)

          // Missing Tools Banner
          BorderSurface {
            visible: !root.mangohudInstalled
            width: parent.width
            implicitHeight: bannerCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: Qt.rgba(root.barUrgent.r, root.barUrgent.g, root.barUrgent.b, 0.15)
            borderSpec: Border.surfaceSpec("popups", "border", root.barUrgent, 1)

            Column {
              id: bannerCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Row {
                spacing: Style.space(6)
                Text {
                  text: "󰅙"
                  color: root.barUrgent
                  font.family: root.barFont
                  font.pixelSize: Style.font.subtitle
                }
                Text {
                  textFormat: Text.PlainText
                  text: "MangoHud & GameMode Not Installed"
                  color: root.barUrgent
                  font.family: root.barFont
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "Install them with one click to enable the Vulkan/OpenGL in-game telemetry overlay."
                color: root.barFg
                font.family: root.barFont
                font.pixelSize: Style.font.caption
                width: parent.width
                wrapMode: Text.Wrap
              }

              Button {
                text: "Install MangoHud & GameMode"
                iconText: "󰇚"
                fontSize: Style.font.caption
                bordered: true
                foreground: root.barUrgent
                onClicked: root.installTools()
              }
            }
          }

          // Master FPS Switch
          Toggle {
            label: "Toggle FPS Overlay"
            description: "Show real-time FPS and telemetry in running games"
            checked: root.fpsOverlayEnabled
            onClicked: root.toggleFps()
          }

          // Quick Live HUD Hotkey Action
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: parent.width
              text: "Send Toggle Hotkey (Shift + F12)"
              iconText: "󰌌"
              fontSize: Style.font.caption
              bordered: true
              tooltipText: "Simulates Shift+F12 to toggle MangoHud in the currently focused game"
              onClicked: root.sendHudToggleKey()
            }
          }

          // Preset Buttons
          PanelSectionHeader { text: "HUD OVERLAY PRESETS" }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(12)) / 3
              text: "Minimal"
              iconText: "󰓅"
              fontSize: Style.font.caption
              bordered: true
              tooltipText: "FPS counter and frametime only"
              onClicked: root.setFpsPreset("minimal")
            }

            Button {
              width: (parent.width - Style.space(12)) / 3
              text: "Compact"
              iconText: "󰍹"
              fontSize: Style.font.caption
              bordered: true
              tooltipText: "FPS + CPU & GPU load & temperatures"
              onClicked: root.setFpsPreset("compact")
            }

            Button {
              width: (parent.width - Style.space(12)) / 3
              text: "Full Telemetry"
              iconText: "󰄛"
              fontSize: Style.font.caption
              bordered: true
              tooltipText: "Full telemetry, VRAM, RAM, clocks, and frametime graph"
              onClicked: root.setFpsPreset("full")
            }
          }

          // Screen Position
          PanelSectionHeader { text: "HUD SCREEN CORNER" }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "Top-L"
              fontSize: Style.font.caption
              selected: root.mangohudPos === "top-left"
              bordered: true
              onClicked: root.setFpsPos("top-left")
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "Top-R"
              fontSize: Style.font.caption
              selected: root.mangohudPos === "top-right"
              bordered: true
              onClicked: root.setFpsPos("top-right")
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "Bot-L"
              fontSize: Style.font.caption
              selected: root.mangohudPos === "bottom-left"
              bordered: true
              onClicked: root.setFpsPos("bottom-left")
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "Bot-R"
              fontSize: Style.font.caption
              selected: root.mangohudPos === "bottom-right"
              bordered: true
              onClicked: root.setFpsPos("bottom-right")
            }
          }

          // FPS Limiter Selector
          PanelSectionHeader { text: "FPS LIMITER (CAP)" }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "Off (0)"
              fontSize: Style.font.caption
              selected: root.fpsCap === 0
              bordered: true
              onClicked: root.setFpsCap(0)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "60"
              fontSize: Style.font.caption
              selected: root.fpsCap === 60
              bordered: true
              onClicked: root.setFpsCap(60)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "120"
              fontSize: Style.font.caption
              selected: root.fpsCap === 120
              bordered: true
              onClicked: root.setFpsCap(120)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "144"
              fontSize: Style.font.caption
              selected: root.fpsCap === 144
              bordered: true
              onClicked: root.setFpsCap(144)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "240"
              fontSize: Style.font.caption
              selected: root.fpsCap === 240
              bordered: true
              onClicked: root.setFpsCap(240)
            }
          }

          // Individual Feature Toggles
          PanelSectionHeader { text: "INDIVIDUAL HUD ELEMENTS" }

          Toggle {
            label: "Frametime Graph"
            description: "Show real-time frametime consistency curve"
            checked: root.features.frametime
            onClicked: root.toggleFeature("frametime")
          }

          Toggle {
            label: "CPU Stats & Temperature"
            description: "Show processor utilization and heat"
            checked: root.features.cpu
            onClicked: root.toggleFeature("cpu_stats")
          }

          Toggle {
            label: "GPU Stats & Temperature"
            description: "Show graphics card load and temperature"
            checked: root.features.gpu
            onClicked: root.toggleFeature("gpu_stats")
          }

          Toggle {
            label: "VRAM & System RAM"
            description: "Show memory consumption"
            checked: root.features.vram
            onClicked: root.toggleFeature("vram")
          }
        }

        // ================= TAB 3: ACTIVE GAMES RADAR =================
        Column {
          visible: root.currentTab === "radar"
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader { text: "ACTIVE GAME DETECTION" }

          // When a game is running
          BorderSurface {
            visible: root.activeGame && root.activeGame.running
            width: parent.width
            implicitHeight: gameActiveCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: Style.controlFill(false, false, root.barFg, root.accentColor)

            Column {
              id: gameActiveCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Row {
                spacing: Style.space(8)
                Text {
                  text: "󰊴"
                  color: root.accentColor
                  font.family: root.barFont
                  font.pixelSize: Style.font.title
                }
                Column {
                  Text {
                    textFormat: Text.PlainText
                    text: root.activeGame ? (root.activeGame.title || root.activeGame.class) : ""
                    color: root.barFg
                    font.family: root.barFont
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: root.activeGame ? ("PID " + root.activeGame.pid + " • Class: " + root.activeGame.class) : ""
                    color: Qt.darker(root.barFg, 1.4)
                    font.family: root.barFont
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Button {
                  width: (parent.width - Style.space(8)) / 2
                  text: "Boost Priority (-5)"
                  iconText: "󰓅"
                  fontSize: Style.font.caption
                  bordered: true
                  foreground: root.accentColor
                  onClicked: if (root.activeGame) root.boostGame(root.activeGame.pid)
                }

                Button {
                  width: (parent.width - Style.space(8)) / 2
                  text: "Terminate Game"
                  iconText: "󰅙"
                  fontSize: Style.font.caption
                  bordered: true
                  foreground: root.barUrgent
                  onClicked: if (root.activeGame) root.killGame(root.activeGame.pid)
                }
              }
            }
          }

          // When no game is running
          BorderSurface {
            visible: !(root.activeGame && root.activeGame.running)
            width: parent.width
            implicitHeight: noGameCol.implicitHeight + Style.space(20)
            radius: Style.cornerRadius
            color: Style.controlFill(false, false, root.barFg, root.accentColor)

            Column {
              id: noGameCol
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                text: "󰊴"
                color: Qt.darker(root.barFg, 1.5)
                font.family: root.barFont
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: "No Active Games Detected"
                color: root.barFg
                font.family: root.barFont
                font.pixelSize: Style.font.subtitle
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: "Launch a game from Steam, Heroic, or Lutris below to monitor and optimize it."
                color: Qt.darker(root.barFg, 1.4)
                font.family: root.barFont
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
              }
            }
          }

          PanelSectionHeader { text: "QUICK GAME LAUNCHERS" }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "Launch Steam"
              iconText: "󰓓"
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.launchGame("steam")
            }

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "Launch Heroic"
              iconText: "󰊴"
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.launchGame("heroic")
            }
          }
        }

        // ================= TAB 4: CROSSHAIR & TOOLS =================
        Column {
          visible: root.currentTab === "tools"
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader { text: "ON-SCREEN CROSSHAIR RETICLE" }

          Toggle {
            label: "Enable Crosshair Overlay"
            description: "Click-through centered reticle for hip-fire and hardcore games"
            checked: root.crosshairEnabled
            onClicked: root.saveCrosshair(!root.crosshairEnabled, root.crosshairStyle, root.crosshairColor, root.crosshairSize)
          }

          // Crosshair Style Selector
          PanelSectionHeader { text: "CROSSHAIR RETICLE SHAPE" }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "• Dot"
              fontSize: Style.font.caption
              selected: root.crosshairStyle === "dot"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, "dot", root.crosshairColor, root.crosshairSize)
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "+ Cross"
              fontSize: Style.font.caption
              selected: root.crosshairStyle === "cross"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, "cross", root.crosshairColor, root.crosshairSize)
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "⊙ Circle"
              fontSize: Style.font.caption
              selected: root.crosshairStyle === "circle"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, "circle", root.crosshairColor, root.crosshairSize)
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "T-Cross"
              fontSize: Style.font.caption
              selected: root.crosshairStyle === "t_cross"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, "t_cross", root.crosshairColor, root.crosshairSize)
            }
          }

          // Crosshair Color Selector
          PanelSectionHeader { text: "RETICLE COLOR" }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "Green"
              fontSize: Style.font.caption
              foreground: "#00FF66"
              selected: String(root.crosshairColor) === "#00ff66" || String(root.crosshairColor) === "#00FF66"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, "#00FF66", root.crosshairSize)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "Red"
              fontSize: Style.font.caption
              foreground: "#FF3366"
              selected: String(root.crosshairColor) === "#ff3366" || String(root.crosshairColor) === "#FF3366"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, "#FF3366", root.crosshairSize)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "Cyan"
              fontSize: Style.font.caption
              foreground: "#00E5FF"
              selected: String(root.crosshairColor) === "#00e5ff" || String(root.crosshairColor) === "#00E5FF"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, "#00E5FF", root.crosshairSize)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "Accent"
              fontSize: Style.font.caption
              foreground: root.accentColor
              selected: String(root.crosshairColor) === String(root.accentColor)
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, root.accentColor, root.crosshairSize)
            }

            Button {
              width: (parent.width - Style.space(24)) / 5
              text: "White"
              fontSize: Style.font.caption
              foreground: "#FFFFFF"
              selected: String(root.crosshairColor) === "#ffffff" || String(root.crosshairColor) === "#FFFFFF"
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, "#FFFFFF", root.crosshairSize)
            }
          }

          // Crosshair Size Selector
          PanelSectionHeader { text: "RETICLE SIZE" }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "Small (12px)"
              fontSize: Style.font.caption
              selected: root.crosshairSize === 12
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, root.crosshairColor, 12)
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "Medium (16px)"
              fontSize: Style.font.caption
              selected: root.crosshairSize === 16
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, root.crosshairColor, 16)
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "Large (22px)"
              fontSize: Style.font.caption
              selected: root.crosshairSize === 22
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, root.crosshairColor, 22)
            }

            Button {
              width: (parent.width - Style.space(18)) / 4
              text: "XL (28px)"
              fontSize: Style.font.caption
              selected: root.crosshairSize === 28
              bordered: true
              onClicked: root.saveCrosshair(root.crosshairEnabled, root.crosshairStyle, root.crosshairColor, 28)
            }
          }

          PanelSectionHeader { text: "VOICE CHAT & COMMS" }

          Toggle {
            label: "Microphone Mute"
            description: "Instant toggle for voice chat without Alt-Tabbing"
            checked: root.micMuted
            onClicked: root.toggleMic()
          }
        }
      }
    }
  }

  // ================= FLOATING ON-SCREEN CROSSHAIR OVERLAY =================
  OverlayWindow {
    id: crosshairWindow
    shown: root.crosshairEnabled
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "omarchy-crosshair"
    // Crucial: Empty region ensures zero interference with mouse/gameplay inputs
    mask: Region {}

    Item {
      anchors.centerIn: parent
      width: root.crosshairSize * 2
      height: root.crosshairSize * 2

      // 1. Dot Reticle
      Rectangle {
        visible: root.crosshairStyle === "dot"
        anchors.centerIn: parent
        width: Math.max(4, root.crosshairSize / 3)
        height: width
        radius: width / 2
        color: root.crosshairColor
        border.color: "#000000"
        border.width: 1
      }

      // 2. Cross Reticle (+)
      Item {
        visible: root.crosshairStyle === "cross"
        anchors.fill: parent

        // Horizontal line Left
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.horizontalCenter
          anchors.rightMargin: 3
          width: root.crosshairSize / 2
          height: 2
          color: root.crosshairColor
          border.color: "#000000"
          border.width: 0.5
        }
        // Horizontal line Right
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.horizontalCenter
          anchors.leftMargin: 3
          width: root.crosshairSize / 2
          height: 2
          color: root.crosshairColor
          border.color: "#000000"
          border.width: 0.5
        }
        // Vertical line Top
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.verticalCenter
          anchors.bottomMargin: 3
          width: 2
          height: root.crosshairSize / 2
          color: root.crosshairColor
          border.color: "#000000"
          border.width: 0.5
        }
        // Vertical line Bottom
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.verticalCenter
          anchors.topMargin: 3
          width: 2
          height: root.crosshairSize / 2
          color: root.crosshairColor
          border.color: "#000000"
          border.width: 0.5
        }
        // Center tiny dot
        Rectangle {
          anchors.centerIn: parent
          width: 2
          height: 2
          color: root.crosshairColor
        }
      }

      // 3. Circle Reticle (⊙)
      Item {
        visible: root.crosshairStyle === "circle"
        anchors.fill: parent

        Rectangle {
          anchors.centerIn: parent
          width: root.crosshairSize
          height: root.crosshairSize
          radius: root.crosshairSize / 2
          color: "transparent"
          border.color: root.crosshairColor
          border.width: 2
        }

        Rectangle {
          anchors.centerIn: parent
          width: 3
          height: 3
          radius: 1.5
          color: root.crosshairColor
        }
      }

      // 4. T-Cross Reticle
      Item {
        visible: root.crosshairStyle === "t_cross"
        anchors.fill: parent

        // Horizontal Left
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.horizontalCenter
          anchors.rightMargin: 3
          width: root.crosshairSize / 2
          height: 2
          color: root.crosshairColor
        }
        // Horizontal Right
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.horizontalCenter
          anchors.leftMargin: 3
          width: root.crosshairSize / 2
          height: 2
          color: root.crosshairColor
        }
        // Vertical Bottom only
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.verticalCenter
          anchors.topMargin: 3
          width: 2
          height: root.crosshairSize / 2
          color: root.crosshairColor
        }
      }
    }
  }

  // StatPair helper component
  component StatPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: label
      color: root.barFg
      opacity: 0.6
      font.family: root.barFont
      font.pixelSize: Style.font.caption
    }

    Item {
      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
      height: 1
    }

    Text {
      textFormat: Text.PlainText
      text: value
      color: root.barFg
      font.family: root.barFont
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }
}
