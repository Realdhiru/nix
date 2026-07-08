pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root


    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/sys_fetcher.sh"

    // --- Centralized Properties ---
    property bool onBattery: false
    property int cpu: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int temp: 0
    property real netRx: 0.0
    property real netTx: 0.0

    // --- Battery State (always polled, independent of subscriber count) ---
    property int batCapacity: 100
    property string batStatus: "Unknown"
    property bool hasBattery: false

    property bool _lowBatteryNotified: false

    // --- Lifecycle Management ---
    property int subscribers: 0

    function subscribe() {
        subscribers++;
        if (subscribers === 1) {
            fetchTimer.restart();
            fetchProc.running = false;
            fetchProc.running = true;
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            fetchTimer.stop();
            fetchProc.running = false;
        }
    }

    Timer {
        id: fetchTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            fetchProc.running = false;
            fetchProc.running = true;
        }
    }

    Process {
        id: fetchProc
        running: false
        command: [
            "bash", 
            "-c", 
            `export QS_CACHE_SYSDATA="${Caching.getCacheDir('sysdata')}"; AC=$(cat /sys/class/power_supply/*/online 2>/dev/null | head -n1 || echo 1); STATS=$(bash "${root.scriptPath}"); echo "$AC|$STATS"`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text ? this.text.trim() : "";
                if (!text) return;

                let p = text.split("|");
                if (p.length >= 7) {
                    // Safe parsing prevents UI crashes if the bash script returns empty or malformed strings
                    let parsedCpu = parseInt(p[1]);
                    let parsedRamP = parseInt(p[2]);
                    let parsedRamGb = parseFloat(p[3]);
                    let parsedTemp = parseInt(p[4]);
                    let parsedRx = parseFloat(p[5]);
                    let parsedTx = parseFloat(p[6]);

                    root.onBattery = (p[0] === "0");
                    if (!isNaN(parsedCpu)) root.cpu = parsedCpu;
                    if (!isNaN(parsedRamP)) root.ramPercent = parsedRamP;
                    if (!isNaN(parsedRamGb)) root.ramGb = parsedRamGb;
                    if (!isNaN(parsedTemp)) root.temp = parsedTemp;
                    if (!isNaN(parsedRx)) root.netRx = parsedRx;
                    if (!isNaN(parsedTx)) root.netTx = parsedTx;
                }
            }
        }
    }

    // Always-on low-battery watcher. Unlike fetchTimer/fetchProc above,
    // this is NOT gated by subscribe()/unsubscribe() — it must keep running
    // even when no widget is currently visible, since it replaces the
    // standalone `exec-once` shell loop that used to live in startup.conf.
    Timer {
        id: batteryWatchTimer
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            batteryWatchProc.running = false;
            batteryWatchProc.running = true;
        }
    }

    Process {
        id: batteryWatchProc
        running: false
        command: [
            "bash", "-c",
            "cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); " +
            "stat=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); " +
            "if [ -n \"$cap\" ]; then echo \"1|$cap|$stat\"; else echo \"0|0|Unknown\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length < 3) return;

                root.hasBattery = (parts[0] === "1");
                let cap = parseInt(parts[1]);
                if (!isNaN(cap)) root.batCapacity = cap;
                root.batStatus = parts[2];

                if (!root.hasBattery) return;

                if (root.batStatus === "Discharging" && root.batCapacity <= 20) {
                    if (!root._lowBatteryNotified) {
                        root._lowBatteryNotified = true;
                        Quickshell.execDetached([
                            "notify-send", "-u", "critical", "-a", "System", "-i", "battery-empty",
                            "Low Battery", "Battery is at " + root.batCapacity + "%"
                        ]);
                    }
                } else {
                    // Reset the one-shot guard once we're no longer in the
                    // low/discharging state, so the next dip below 20% fires again.
                    root._lowBatteryNotified = false;
                }
            }
        }
    }
}