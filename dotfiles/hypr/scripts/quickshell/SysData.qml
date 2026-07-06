pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    Caching { id: paths }

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/sys_fetcher.sh"

    // --- Centralized Properties ---
    property bool onBattery: false
    property int cpu: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int temp: 0
    property real netRx: 0.0
    property real netTx: 0.0

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
            `export QS_CACHE_SYSDATA="${paths.getCacheDir('sysdata')}"; AC=$(cat /sys/class/power_supply/*/online 2>/dev/null | head -n1 || echo 1); STATS=$(bash "${root.scriptPath}"); echo "$AC|$STATS"`
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
}