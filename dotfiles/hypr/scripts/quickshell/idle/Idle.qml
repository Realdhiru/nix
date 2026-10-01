import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../"

Item {
    id: idleRoot

    Theme { id: _theme }

    property bool idleEnabled: true
    property bool manualInhibit: false
    property bool isDimmed: false
    property bool isLocked: false

    property bool isMediaPlaying: {
        try {
            return Mpris.players && Mpris.players.values ? Mpris.players.values.some(p => p.playbackState === MprisPlaybackState.Playing) : false;
        } catch (e) {
            return false;
        }
    }

    property var actions: [
        { id: "lock", timeout: 300, enabled: true },
        { id: "dpms", timeout: 360, enabled: true }
    ]

    function lockSession() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"]);
    }

    function dpmsOff() {
        Quickshell.execDetached(["sh", "-c", "hyprctl dispatch dpms off"]);
    }

    function dpmsOn() {
        Quickshell.execDetached(["sh", "-c", "hyprctl dispatch dpms on"]);
    }

    function triggerAction(id, ignoreInhibitor) {
        let allow = ignoreInhibitor || (!isMediaPlaying || manualInhibit);
        if (id === "dim") {
            if (!isLocked && allow) {
                isDimmed = true;
            }
        } else if (id === "lock") {
            isDimmed = false;
            if (!isLocked && allow) {
                isLocked = true;
                lockSession();
            }
        } else if (id === "dpms") {
            if (allow) {
                dpmsOff();
            }
        }
    }

    function resumeAction(id) {
        if (id === "dim") {
            isDimmed = false;
        } else if (id === "lock") {
            isLocked = false;
        } else if (id === "dpms") {
            dpmsOn();
        }
    }

    IpcHandler {
        target: "idle"
        function trigger(name: string): void { idleRoot.triggerAction(name.toLowerCase(), false); }
        function forceTrigger(name: string): void { idleRoot.triggerAction(name.toLowerCase(), true); }
        function resume(name: string): void { idleRoot.resumeAction(name.toLowerCase()); }
        function toggleDim(): void {
            if (idleRoot.isDimmed) {
                idleRoot.resumeAction("dim");
            } else {
                idleRoot.triggerAction("dim", true);
            }
        }
    }

    Dim {
        active: idleRoot.idleEnabled && idleRoot.isDimmed
    }

    Repeater {
        model: idleRoot.actions
        delegate: Item {
            id: monitorDelegate
            required property var modelData

            IdleMonitor {
                timeout: monitorDelegate.modelData.timeout
                enabled: idleRoot.idleEnabled && monitorDelegate.modelData.enabled
                respectInhibitors: true

                onIsIdleChanged: {
                    if (isIdle) {
                        idleRoot.triggerAction(monitorDelegate.modelData.id);
                    } else {
                        idleRoot.resumeAction(monitorDelegate.modelData.id);
                    }
                }
            }
        }
    }
}
