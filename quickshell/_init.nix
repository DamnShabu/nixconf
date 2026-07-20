{pkgs}: {
  desktop = pkgs.writeText "desktop.qml" ''
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Variants {
  model: Quickshell.screens

  PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "qs-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    readonly property string desktopPath: Quickshell.env("HOME") + "/Desktop"
    readonly property string posFile: Quickshell.env("HOME") + "/.cache/quickshell/desktop-positions.json"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/thumbs/"
    readonly property color text: "#E6E1CF"
    readonly property color surface: Qt.rgba(1, 1, 1, 0.1)
    readonly property color blue: "#59C2FF"

    property var menuTarget: null
    property string menuFilePath: ""
    property string menuFileName: ""
    property int menuX: 0
    property int menuY: 0

    property var positions: ({})
    property var selectedFiles: []
    property var delegateMap: ({})
    property bool multiDragActive: false

    FolderListModel {
      id: folderModel
      folder: Qt.resolvedUrl(desktopPath)
      showDirs: true; showFiles: true; showHidden: false
      sortField: FolderListModel.Name
    }

    Timer {
      interval: 2000; running: true; repeat: true
      onTriggered: {
        folderModel.folder = Qt.resolvedUrl(root.desktopPath)
        savePos()
      }
    }

    Process {
      id: posLoader
      command: ["/bin/sh", "-c", "cat '" + root.posFile + "' 2>/dev/null || echo '{}'"]
      running: true
      stdout: StdioCollector {
        onStreamFinished: {
          try { root.positions = JSON.parse(this.text) } catch(e) { root.positions = {} }
        }
      }
    }

    function gridPos(index) {
      var cols = Math.max(1, Math.floor((root.width - 80) / 100))
      return { x: 40 + (index % cols) * 100, y: 40 + Math.floor(index / cols) * 120 }
    }

    function getPos(fileName, index) {
      if (positions[fileName]) return positions[fileName]
      var gp = gridPos(index)
      positions[fileName] = gp
      return gp
    }

    function snapToGrid(x, y) {
      return { x: 40 + Math.round((x - 40) / 100) * 100, y: 40 + Math.round((y - 40) / 120) * 120 }
    }

    function snapKey(x, y) { return snapToGrid(x, y).x + "," + snapToGrid(x, y).y }

    function isCellFree(cx, cy, excludeFile) {
      for (var fn in delegateMap) {
        if (fn === excludeFile) continue
        var del = delegateMap[fn]
        if (del && snapKey(del.x, del.y) === cx + "," + cy) return false
      }
      return true
    }

    function resolveConflicts(fileNames) {
      var cw = 100, ch = 120, ox = 40, oy = 40
      for (var j = 0; j < fileNames.length; j++) {
        var fn = fileNames[j]
        var del = delegateMap[fn]
        if (!del) continue
        var sg = snapToGrid(del.x, del.y)
        if (!isCellFree(sg.x, sg.y, fn)) {
          var found = false
          var startRow = Math.max(0, Math.round((sg.y - oy) / ch))
          var startCol = Math.max(0, Math.round((sg.x - ox) / cw))
          for (var dr = 0; dr < 200 && !found; dr++) {
            for (var dc = 0; dc < 200 && !found; dc++) {
              var nx = ox + (startCol + dc) * cw, ny = oy + (startRow + dr) * ch
              if (isCellFree(nx, ny, fn)) {
                del.x = nx; del.y = ny
                del.itemX = nx; del.itemY = ny
                found = true
              }
            }
          }
        } else {
          del.x = sg.x; del.y = sg.y
          del.itemX = sg.x; del.itemY = sg.y
        }
      }
    }

    function savePos() {
      var json = JSON.stringify(positions)
      Quickshell.execDetached(["/bin/sh", "-c", "mkdir -p " + Quickshell.env("HOME") + "/.cache/quickshell && printf '%s' \"$1\" > '" + root.posFile + "'", "_", json])
    }

    function rectsOverlap(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2) {
      return !(ax2 < bx1 || ax1 > bx2 || ay2 < by1 || ay1 > by2)
    }

    function selectNone() {
      root.selectedFiles = []
      root.multiDragActive = false
    }

    function toggleSelection(fileName, ctrlHeld) {
      var idx = root.selectedFiles.indexOf(fileName)
      if (ctrlHeld) {
        if (idx >= 0) {
          var copy = root.selectedFiles.slice()
          copy.splice(idx, 1)
          root.selectedFiles = copy
        } else {
          root.selectedFiles = root.selectedFiles.concat([fileName])
        }
      } else {
        root.selectedFiles = [fileName]
      }
    }

    function moveSelectedBy(dx, dy, excludeName) {
      for (var i = 0; i < root.selectedFiles.length; i++) {
        var fn = root.selectedFiles[i]
        if (fn === excludeName) continue
        var del = root.delegateMap[fn]
        if (del) {
          del.itemX += dx
          del.itemY += dy
          del.x = del.itemX
          del.y = del.itemY
        }
      }
    }

    Item {
      anchors.fill: parent

      Rectangle {
        id: selRect
        visible: false; z: 50
        color: Qt.rgba(89, 194, 255, 0.12)
        border.color: root.blue
        border.width: 1
        radius: 3
      }

      Canvas {
        id: gridCanvas
        anchors.fill: parent; z: 0
        visible: root.multiDragActive
        opacity: 0.25
        onVisibleChanged: { if (visible) requestPaint() }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          if (!ctx) return
          ctx.clearRect(0, 0, width, height)
          ctx.strokeStyle = "#59C2FF"
          ctx.lineWidth = 0.5
          var ox = 40, oy = 40
          for (var x = ox; x < width; x += 100) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
          for (var y = oy; y < height; y += 120) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
        }
      }

      Repeater {
        id: repeater
        model: folderModel
        delegate: Item {
          id: delegateItem
          width: 100; height: 120

          readonly property string delegateFileName: model.fileName
          property real itemX: root.getPos(model.fileName, index).x
          property real itemY: root.getPos(model.fileName, index).y
          property bool isSelected: root.selectedFiles.indexOf(model.fileName) >= 0
          property bool isHovered: false
          property bool wasDragged: false
          property real grabX: 0
          property real grabY: 0
          property real prevX: 0
          property real prevY: 0

          z: root.multiDragActive && isSelected ? 15 : wasDragged ? 20 : isSelected ? 10 : (isHovered ? 5 : 1)

          Component.onCompleted: {
            x = itemX
            y = itemY
            root.delegateMap[model.fileName] = delegateItem
          }
          Component.onDestruction: delete root.delegateMap[model.fileName]

          Rectangle {
            anchors.fill: parent; anchors.margins: 3; radius: 8
            color: wasDragged ? Qt.rgba(89, 194, 255, 0.2) : isHovered ? root.surface : isSelected ? Qt.rgba(89, 194, 255, 0.1) : "transparent"
            border.color: isSelected && !wasDragged ? root.blue : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
          }

          ColumnLayout {
            anchors.centerIn: parent; spacing: 4; width: parent.width - 8

            Loader {
              Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 48; Layout.preferredHeight: 48
              sourceComponent: {
                var ext = model.fileSuffix.toLowerCase()
                if (["jpg","jpeg","png","gif","bmp","webp"].indexOf(ext) >= 0) return imageThumb
                else if (["mp4","avi","mkv","mov","webm","flv"].indexOf(ext) >= 0) return videoThumb
                else return iconThumb
              }

              Component { id: imageThumb
                Image { source: "file://" + model.filePath; fillMode: Image.PreserveAspectFit; width: 48; height: 48; asynchronous: true; cache: true; sourceSize { width: 96; height: 96 } }
              }

              Component { id: videoThumb
                Item {
                  width: 48; height: 48
                  property string thumbFile: root.thumbDir + model.fileName.replace("/", "_") + ".png"
                  property bool thumbReady: false
                  Image {
                    anchors.fill: parent
                    source: parent.thumbReady ? "file://" + parent.thumbFile : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true; visible: parent.thumbReady
                  }
                  IconImage {
                    anchors.fill: parent
                    visible: !parent.thumbReady
                    source: Quickshell.iconPath("video-x-generic", true)
                  }
                  Process {
                    command: ["/bin/sh", "-c", "test -f \"$4\" || { mkdir -p \"$1\" && \"$2\" -y -ss 00:00:02 -i \"$3\" -vframes 1 -s 96x96 \"$4\" 2>/dev/null; }", "_", root.thumbDir, "${pkgs.ffmpeg}/bin/ffmpeg", model.filePath, parent.thumbFile]
                    running: !parent.thumbReady
                    onExited: { if (exitCode === 0) parent.thumbReady = true }
                  }
                }
              }

              Component { id: iconThumb
                IconImage { source: Quickshell.iconPath("text-x-generic", true); width: 48; height: 48 }
              }
            }

            Text {
              Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter
              text: model.fileName
              color: isHovered || wasDragged ? "white" : isSelected ? root.blue : root.text
              font.family: "JetBrains Mono"; font.pixelSize: 11
              horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
            }
          }

          MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: parent
            drag.axis: Drag.XAndYAxis
            drag.smoothed: false

            onEntered: delegateItem.isHovered = true
            onExited: delegateItem.isHovered = false

            onPressed: mouse => {
              selRect.visible = false
              bgMouse.bandActive = false
              if (mouse.button === Qt.LeftButton) {
                delegateItem.grabX = mouse.x
                delegateItem.grabY = mouse.y
                delegateItem.wasDragged = false
                var ctrl = mouse.modifiers & Qt.ControlModifier
                if (ctrl) {
                  root.toggleSelection(model.fileName, true)
                } else if (root.selectedFiles.indexOf(model.fileName) < 0) {
                  root.selectedFiles = [model.fileName]
                }
                mouse.accepted = true
              }
            }

            onPositionChanged: mouse => {
              if (mouse.buttons & Qt.LeftButton) {
                delegateItem.itemX = parent.x
                delegateItem.itemY = parent.y
                if (!delegateItem.wasDragged &&
                    (Math.abs(mouse.x - delegateItem.grabX) > 5 ||
                     Math.abs(mouse.y - delegateItem.grabY) > 5)) {
                  delegateItem.wasDragged = true
                  root.multiDragActive = true
                  delegateItem.prevX = parent.x
                  delegateItem.prevY = parent.y
                  return
                }
                if (delegateItem.wasDragged) {
                  var dx = parent.x - delegateItem.prevX
                  var dy = parent.y - delegateItem.prevY
                  if (dx !== 0 || dy !== 0) {
                    root.moveSelectedBy(dx, dy, model.fileName)
                    delegateItem.prevX = parent.x
                    delegateItem.prevY = parent.y
                  }
                }
              }
            }

            onReleased: mouse => {
              selRect.visible = false
              if (delegateItem.wasDragged) {
                delegateItem.isHovered = false
                var moved = root.selectedFiles.slice()
                var sg = root.snapToGrid(parent.x, parent.y)
                parent.x = sg.x; parent.y = sg.y
                delegateItem.itemX = sg.x; delegateItem.itemY = sg.y
                root.resolveConflicts(moved)
                for (var i = 0; i < moved.length; i++) {
                  var del = root.delegateMap[moved[i]]
                  if (del) root.positions[moved[i]] = { x: del.x, y: del.y }
                }
                root.savePos()
                delegateItem.wasDragged = false
                root.multiDragActive = false
                root.selectedFiles = []
              }
            }

            onClicked: mouse => {
              if (delegateItem.wasDragged) return
              if (mouse.button === Qt.LeftButton) {
                if (!(mouse.modifiers & Qt.ControlModifier)) {
                  root.selectedFiles = [model.fileName]
                }
              } else if (mouse.button === Qt.RightButton) {
                if (!(mouse.modifiers & Qt.ControlModifier)) {
                  root.selectedFiles = [model.fileName]
                }
                root.menuTarget = parent
                root.menuFilePath = model.filePath
                root.menuFileName = model.fileName
                root.menuX = parent.x + 50
                root.menuY = parent.y + 30
                menuPopup.close()
                menuPopup.open()
              }
            }

            onDoubleClicked: Quickshell.execDetached(["xdg-open", model.filePath])
          }
        }
      }

      MouseArea {
        id: bgMouse
        anchors.fill: parent; z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real bandX1: 0
        property real bandY1: 0
        property bool bandActive: false

        onPressed: mouse => {
          if (mouse.button === Qt.LeftButton) {
            bandX1 = mouse.x
            bandY1 = mouse.y
            bandActive = true
            selRect.visible = true
            selRect.x = bandX1; selRect.y = bandY1
            selRect.width = 0; selRect.height = 0
            if (!(mouse.modifiers & Qt.ControlModifier)) root.selectNone()
          }
        }

        onPositionChanged: mouse => {
          if (bandActive) {
            var rx = Math.min(bandX1, mouse.x)
            var ry = Math.min(bandY1, mouse.y)
            var rw = Math.abs(mouse.x - bandX1)
            var rh = Math.abs(mouse.y - bandY1)
            selRect.x = rx; selRect.y = ry
            selRect.width = rw; selRect.height = rh

            if (root.delegateMap) {
              var sel = []
              for (var fn in root.delegateMap) {
                var del = root.delegateMap[fn]
                if (del && root.rectsOverlap(rx, ry, rx + rw, ry + rh,
                                              del.x, del.y, del.x + del.width, del.y + del.height)) {
                  sel.push(fn)
                }
              }
            }

            if (mouse.modifiers & Qt.ControlModifier) {
              var merged = root.selectedFiles.slice()
              for (var i = 0; i < sel.length; i++) {
                if (merged.indexOf(sel[i]) < 0) merged.push(sel[i])
              }
              root.selectedFiles = merged
            } else {
              root.selectedFiles = sel
            }
          }
        }

        onReleased: mouse => {
          bandActive = false
          selRect.visible = false
          selRect.x = 0; selRect.y = 0
          selRect.width = 0; selRect.height = 0
        }

        onClicked: mouse => {
          menuPopup.close()
          if (mouse.button === Qt.LeftButton) {
            root.selectNone()
          } else if (mouse.button === Qt.RightButton) {
            root.menuTarget = null
            root.menuFilePath = ""
            root.menuFileName = ""
            root.menuX = mouse.x
            root.menuY = mouse.y
            menuPopup.open()
          }
        }
      }
    }

    Popup {
      id: menuPopup
      x: root.menuX; y: root.menuY
      width: 180; height: menuCol.implicitHeight + 8; padding: 0
      closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
      background: Rectangle { radius: 8; color: "#131721"; border.color: "#3E4B59"; border.width: 1 }

      ColumnLayout {
        id: menuCol; anchors.fill: parent; anchors.margins: 4; spacing: 2

        Item { height: 28; Layout.fillWidth: true
          Rectangle { anchors.fill: parent; radius: 4; color: b1.containsMouse ? "#272D38" : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
          Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "Open"; color: b1.containsMouse ? "white" : "#E6E1CF"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
          MouseArea { id: b1; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["xdg-open", root.menuFilePath]); menuPopup.close() } }
        }

        Item { height: 28; Layout.fillWidth: true
          Rectangle { anchors.fill: parent; radius: 4; color: b2.containsMouse ? "#272D38" : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
          Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "Open in Terminal"; color: b2.containsMouse ? "white" : "#E6E1CF"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
          MouseArea { id: b2; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["kitty", "-d", root.menuFilePath]); menuPopup.close() } }
        }

        Repeater {
          model: root.menuTarget !== null ? ["Copy Path", "Rename", "Move to Trash", "Properties"] : ["Paste", "Open in Terminal", "Properties"]
          delegate: Item { id: rit; required property string modelData; height: 28; Layout.fillWidth: true
            Rectangle { anchors.fill: parent; radius: 4; color: b3.containsMouse ? "#272D38" : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
            Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: rit.modelData; color: b3.containsMouse ? "white" : "#E6E1CF"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
            MouseArea { id: b3; anchors.fill: parent; hoverEnabled: true
              onClicked: {
                if (rit.modelData === "Copy Path") {
                  Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | \"$2\"", "_", root.menuFilePath, "${pkgs.wl-clipboard}/bin/wl-copy"])
                } else if (rit.modelData === "Move to Trash") {
                  Quickshell.execDetached(["mv", root.menuFilePath, Quickshell.env("HOME") + "/.local/share/Trash/files/"])
                  Qt.callLater(function() { folderModel.folder = Qt.resolvedUrl(root.desktopPath) })
                } else if (rit.modelData === "Rename") {
                  renameDialog.open()
                }
                menuPopup.close()
              }
            }
          }
        }
      }
    }

    Dialog {
      id: renameDialog; title: "Rename"
      standardButtons: Dialog.Ok | Dialog.Cancel
      x: (parent.width - width) / 2; y: (parent.height - height) / 2; modal: true
      background: Rectangle { radius: 8; color: "#131721"; border.color: "#3E4B59"; border.width: 1 }
      contentItem: ColumnLayout { spacing: 8
        Text { text: "Rename " + root.menuFileName; color: "#E6E1CF"; font.family: "JetBrains Mono"; font.pixelSize: 13 }
        TextInput { id: renameInput; text: root.menuFileName; color: "#E6E1CF"; font.family: "JetBrains Mono"; font.pixelSize: 12; selectByMouse: true; Layout.fillWidth: true
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.blue } }
      }
      onAccepted: {
        var old = root.menuFilePath
        var dir = old.substring(0, old.lastIndexOf("/") + 1)
        Quickshell.execDetached(["mv", old, dir + renameInput.text])
        Qt.callLater(function() { folderModel.folder = Qt.resolvedUrl(root.desktopPath) })
      }
    }
  }
}
  '';

  notifd = pkgs.writeText "notifd.qml" ''
    import QtQuick
    import QtQuick.Window
    import QtQuick.Controls
    import QtQuick.Layouts
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import Quickshell.Services.Notifications

    PanelWindow {
      id: root

      WlrLayershell.namespace: "qs-notifd"
      WlrLayershell.layer: WlrLayer.Overlay
      anchors { top: true; right: true }
      margins { top: 60; right: 20 }
      exclusionMode: ExclusionMode.Ignore
      focusable: false
      color: "transparent"
      width: 350
      height: Math.min(popupList.contentHeight, Screen.height * 0.8)

      Behavior on height {
        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
      }

      property bool isStartup: true
      Timer {
        interval: 500
        running: true
        onTriggered: root.isStartup = false
      }

      readonly property string dndFile: Quickshell.env("HOME") + "/.cache/quickshell/dnd/state"
      property bool dndEnabled: false

      Process {
        id: dndReader
        command: ["bash", "-c", "cat '" + root.dndFile + "' 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
          onStreamFinished: root.dndEnabled = (this.text.trim() === "1")
        }
      }
      Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dndReader.running = true
      }

      // --- Theme colors ---
      readonly property color base: "#0F1419"
      readonly property color text: "#E6E1CF"
      readonly property color subtext0: "#BFBDB6"
      readonly property color surface0: "#272D38"
      readonly property color surface1: "#3E4B59"
      readonly property color surface2: "#3E4B59"
      readonly property color overlay1: "#7F849C"
      readonly property color crust: "#0F1419"
      readonly property color blue: "#59C2FF"
      readonly property color mauve: "#D2A6FF"
      readonly property color peach: "#FF8F40"
      readonly property color green: "#B8CC52"
      readonly property color pink: "#F5C2E7"
      readonly property color sapphire: "#74C7EC"
      readonly property color teal: "#95E6CB"
      readonly property color maroon: "#E6B673"
      readonly property color yellow: "#FFB454"
      readonly property color red: "#F07178"

      readonly property var blobPalette1: [mauve, blue, peach, green, pink]
      readonly property var blobPalette2: [sapphire, teal, maroon, yellow, red]
      property real globalOrbitAngle: 0

      NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 25000; loops: Animation.Infinite; running: true
      }

      // --- Notification models ---
      ListModel { id: activePopups }
      property var liveNotifs: ({})
      property int popupCounter: 0

      // --- Notification Server (DBus) ---
      NotificationServer {
        id: notifServer
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: (n) => {
          n.tracked = true;

          let actions = [];
          if (n.actions) {
            for (let i = 0; i < n.actions.length; i++) {
              actions.push({
                "id": n.actions[i].identifier || "",
                "text": n.actions[i].text || n.actions[i].name || "Action"
              });
            }
          }

          root.popupCounter++;
          let uid = root.popupCounter;
          root.liveNotifs[uid] = n;

          let data = {
            "appName":     n.appName  !== "" ? n.appName  : "System",
            "summary":     n.summary  !== "" ? n.summary  : "No Title",
            "body":        n.body     !== "" ? n.body     : "",
            "iconPath":    n.appIcon  !== "" ? n.appIcon  : "",
            "actionsJson": JSON.stringify(actions),
            "uid":         uid
          };

          if (!root.isStartup) {
            activePopups.append(data);
          }
        }
      }

      function removePopup(uid) {
        for (let i = 0; i < activePopups.count; i++) {
          if (activePopups.get(i).uid === uid) {
            activePopups.remove(i);
            break;
          }
        }
      }

      // --- Popup rendering ---
      Item {
        anchors.fill: parent
        opacity: root.dndEnabled ? 0.0 : 1.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 300 } }

        ListView {
          id: popupList
          anchors.fill: parent
          model: activePopups
          spacing: 12
          interactive: false
          clip: false

          add: Transition {
            ParallelAnimation {
              NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
              NumberAnimation { property: "x"; from: 140; to: 0; duration: 500; easing.type: Easing.OutQuint }
              NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 500; easing.type: Easing.OutQuint }
            }
          }

          remove: Transition {
            ParallelAnimation {
              NumberAnimation { property: "opacity"; to: 0.0; duration: 350; easing.type: Easing.OutQuint }
              NumberAnimation { property: "x"; to: 140; duration: 400; easing.type: Easing.OutQuint }
              NumberAnimation { property: "scale"; to: 0.9; duration: 400; easing.type: Easing.OutQuint }
            }
          }

          displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 450; easing.type: Easing.OutQuint }
          }

          delegate: Item {
            id: delegateRoot
            width: ListView.view.width
            height: contentCol.height + 24

            property string fullSummary: model.summary || ""
            property string fullBody: model.body || ""
            property int typeLenSum: 0
            property int typeLenBody: 0
            property int popupUid: model.uid

            property var sourceNotif: root.liveNotifs[model.uid]

            property var actionArray: {
              try {
                let parsed = model.actionsJson ? JSON.parse(model.actionsJson) : [];
                return parsed;
              } catch (e) { return []; }
            }

            property int effectiveTimeout: {
              var n = root.liveNotifs[model.uid];
              if (!n || n.timeout === undefined) return 5000;
              if (n.timeout === 0) return 0;
              if (n.timeout > 0) return n.timeout;
              return 5000;
            }

            Connections {
              target: delegateRoot.sourceNotif || null
              function onClosed() {
                root.removePopup(delegateRoot.popupUid);
              }
            }

            // Typewriter animation
            ParallelAnimation {
              running: true
              NumberAnimation {
                target: delegateRoot; property: "typeLenSum"
                from: 0; to: fullSummary.length
                duration: Math.min(fullSummary.length * 20, 600)
                easing.type: Easing.OutCubic
              }
              SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation {
                  target: delegateRoot; property: "typeLenBody"
                  from: 0; to: fullBody.length
                  duration: Math.min(fullBody.length * 15, 1200)
                  easing.type: Easing.OutCubic
                }
              }
            }

            Rectangle {
              id: popupCard
              anchors.fill: parent
              radius: 14
              color: root.base
              border.color: root.surface1
              border.width: 1
              clip: true

              property color blob1Color: root.blobPalette1[index % 5]
              property color blob2Color: root.blobPalette2[index % 5]

              // Orbiting blob decorations
              Rectangle {
                width: parent.width * 0.7; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2 + index) * 60
                y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2 + index) * 30
                color: popupCard.blob1Color
                opacity: 0.12
              }
              Rectangle {
                width: parent.width * 0.5; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5 - index) * -50
                y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5 - index) * -40
                color: popupCard.blob2Color
                opacity: 0.10
              }

              // Auto-dismiss timer
              Timer {
                interval: delegateRoot.effectiveTimeout > 0 ? delegateRoot.effectiveTimeout : 5000
                running: delegateRoot.effectiveTimeout > 0
                onTriggered: root.removePopup(delegateRoot.popupUid)
              }

              // Card click -> default action
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                  var n = root.liveNotifs[delegateRoot.popupUid];
                  if (n && n.actions) {
                    for (var i = 0; i < n.actions.length; i++) {
                      if (n.actions[i].identifier === "default") {
                        n.actions[i].invoke(); break;
                      }
                    }
                  }
                  Qt.callLater(function() { root.removePopup(delegateRoot.popupUid); });
                }

                Rectangle {
                  anchors.fill: parent
                  radius: popupCard.radius
                  color: root.surface0
                  opacity: parent.containsMouse ? 0.3 : 0.0
                  Behavior on opacity { NumberAnimation { duration: 250 } }
                }
              }

              // Content
              ColumnLayout {
                id: contentCol
                z: 1
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12
                spacing: 6

                Text {
                  text: model.appName || "System"
                  font.family: "JetBrains Mono"
                  font.weight: Font.Medium
                  font.pixelSize: 12
                  color: root.overlay1
                  Layout.fillWidth: true
                }

                // Summary (typewriter)
                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: hiddenSummary.implicitHeight

                  Text {
                    id: hiddenSummary
                    text: delegateRoot.fullSummary
                    width: parent.width
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.pixelSize: 15
                    wrapMode: Text.Wrap
                    visible: false
                  }
                  Text {
                    anchors.fill: parent
                    text: delegateRoot.fullSummary.substring(0, delegateRoot.typeLenSum)
                    font: hiddenSummary.font
                    color: root.text
                    wrapMode: Text.Wrap
                  }
                }

                // Body (typewriter)
                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: hiddenBody.implicitHeight
                  visible: delegateRoot.fullBody !== ""

                  Text {
                    id: hiddenBody
                    text: delegateRoot.fullBody
                    width: parent.width
                    font.family: "JetBrains Mono"
                    font.weight: Font.Medium
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    visible: false
                  }
                  Text {
                    anchors.fill: parent
                    text: delegateRoot.fullBody.substring(0, delegateRoot.typeLenBody)
                    font: hiddenBody.font
                    color: root.subtext0
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                  }
                }

                // Inline action buttons
                RowLayout {
                  Layout.fillWidth: true
                  Layout.topMargin: delegateRoot.actionArray.length > 0 ? 6 : 0
                  spacing: 8
                  visible: delegateRoot.actionArray.length > 0

                  Repeater {
                    model: delegateRoot.actionArray
                    delegate: Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 32
                      radius: 8

                      property bool isPrimary: index === 0

                      color: {
                        if (isPrimary) {
                          return actionMouse.containsMouse ? root.blue : Qt.darker(root.blue, 1.2)
                        } else {
                          return actionMouse.containsMouse ? root.surface2 : root.surface1
                        }
                      }

                      border.color: isPrimary ? root.blue : root.surface2
                      border.width: 1
                      Behavior on color { ColorAnimation { duration: 150 } }

                      Text {
                        anchors.centerIn: parent
                        text: modelData.text || "Action"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        color: isPrimary ? root.crust : root.text
                      }

                      MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: 10

                        onClicked: {
                          var n = root.liveNotifs[delegateRoot.popupUid];
                          if (n && n.actions) {
                            for (var i = 0; i < n.actions.length; i++) {
                              if (n.actions[i].identifier === modelData.id) {
                                n.actions[i].invoke(); break;
                              }
                            }
                          }
                          Qt.callLater(function() { root.removePopup(delegateRoot.popupUid); });
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  '';

  swayosdCSS = pkgs.writeText "swayosd-style.css" ''
    window { background: transparent; }
    window#osd {
      background: transparent;
      border: none;
      box-shadow: none;
    }
    window#osd #container,
    window#osd-container {
      background-color: #131721;
      border: 2px solid #59C2FF;
      border-radius: 32px;
      padding: 16px;
      margin: 16px;
      min-width: 250px;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
    }
    trough {
      background-color: #272D38;
      border-radius: 99px;
      border: none;
      min-height: 12px;
      min-width: 200px;
    }
    progress {
      background-image: linear-gradient(to right, #59C2FF, #D2A6FF);
      border-radius: 99px;
      border: none;
      min-height: 12px;
      margin: 0px;
      padding: 0px;
      min-width: 0px;
    }
    label {
      color: #E6E1CF;
      font-weight: 800;
      font-size: 18px;
      margin-bottom: 8px;
    }
    image {
      color: #59C2FF;
      -gtk-icon-style: symbolic;
    }
  '';
}
