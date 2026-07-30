pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root


    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/sys_fetcher.sh"
    readonly property string batteryFetchPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/battery_fetch.sh"
    readonly property string batteryWaitPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/battery_wait.sh"

    // --- Centralized Properties (CPU/RAM/temp/net -- subscribe-gated, unchanged) ---
    property bool onBattery: false
    property int cpu: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int temp: 0
    property real netRx: 0.0
    property real netTx: 0.0

    // --- Battery / AC state (ALWAYS polled, independent of subscriber count,
    //     independent of any popup being open) ---
    property int batCapacity: 100
    property string batStatus: "Unknown"
    property bool hasBattery: false

    // The one signal every consumer (topbar, popup, automation) should use
    // for "is the charger physically connected". NOT derived from
    // batStatus, because a charge-threshold-capped battery
    // (STOP_CHARGE_THRESH_BAT0 in power.nix) reports status="Not charging"
    // once the cap is hit even while plugged in -- keying off the status
    // string alone made the whole system blind to "plugged in" above that %.
    property bool acOnline: true
    readonly property bool isCharging: root.acOnline

    property bool _lowBatteryNotified: false

    // --- Lifecycle Management (CPU/RAM/net poller only) ---
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

    // =========================================================================
    // ALWAYS-ON BATTERY + AC WATCHER (replaces the old fixed-60s-interval
    // batteryWatchTimer/batteryWatchProc). Event-driven via battery_wait.sh
    // (udevadm monitor --subsystem-match=power_supply), so plug/unplug is
    // reflected within a beat instead of up to 60 seconds later -- and,
    // unlike the subscribe-gated fetchProc above, this NEVER stops running,
    // so profile automation keeps working even with every panel closed.
    // battery_wait.sh has its own internal 300s failsafe timeout, so this
    // also self-heals if a udev event is ever missed.
    // =========================================================================

    Process {
        id: batteryProc
        running: true
        command: ["bash", "-c", root.batteryFetchPath]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text ? this.text.trim() : "";
                if (!text) return;

                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    batteryWaiter.running = false;
                    batteryWaiter.running = true;
                    return;
                }

                root.hasBattery = (data.has === "1");

                let cap = parseInt(data.percent);
                if (!isNaN(cap)) root.batCapacity = cap;
                root.batStatus = data.status || "Unknown";

                let wasOnline = root.acOnline;
                root.acOnline = (data.online === "1");

                if (root.hasBattery) {
                    if (root.batStatus === "Discharging" && root.batCapacity <= 20) {
                        if (!root._lowBatteryNotified) {
                            root._lowBatteryNotified = true;
                            Quickshell.execDetached([
                                "notify-send", "-u", "critical", "-a", "System", "-i", "battery-empty",
                                "Low Battery", "Battery is at " + root.batCapacity + "%"
                            ]);
                        }
                    } else {
                        root._lowBatteryNotified = false;
                    }
                }

                root._handleAcTransition(wasOnline, root.acOnline);

                // Restart the event-wait loop for the next change.
                batteryWaiter.running = false;
                batteryWaiter.running = true;
            }
        }
    }

    Process {
        id: batteryWaiter
        running: false
        command: ["bash", "-c", root.batteryWaitPath]
        onExited: {
            batteryProc.running = false;
            batteryProc.running = true;
        }
    }

    Component.onCompleted: {
        batteryWaiter.running = true;
    }

    // =========================================================================
    // POWER PROFILE STATE + AUTOMATION
    // Lives here (a persistent singleton) instead of inside BatteryPopup.qml,
    // because BatteryPopup only exists while that popup is open -- automation
    // living there meant plugging/unplugging did nothing at all until the
    // popup had been opened at least once in the session.
    // =========================================================================

    property string powerProfile: "balanced"

    // Set whenever the user explicitly picks a profile from the UI. Cleared
    // only on an actual plug-in transition, never on unplug -- so a manual
    // choice made while on battery survives incidental AC blips instead of
    // being silently reverted.
    property bool _manualOverride: false
    property bool _acInitialized: false

    function _handleAcTransition(wasOnline, isOnline) {
        if (!root._acInitialized) {
            root._acInitialized = true;
            return;
        }
        if (wasOnline === isOnline) return;

        Quickshell.execDetached([
            "notify-send", "-a", "System", "-u", "low",
            isOnline ? "Charger Connected" : "Charger Disconnected", ""
        ]);

        if (isOnline) {
            root._manualOverride = false;
            if (root.powerProfile !== "performance") root.setPowerProfile("performance", false);
        } else {
            if (!root._manualOverride && root.powerProfile === "performance") {
                root.setPowerProfile("balanced", false);
            }
        }
    }

    function setPowerProfile(name, isManual) {
        if (isManual === undefined) isManual = true;
        if (isManual) root._manualOverride = true;

        let prevProfile = root.powerProfile;

        root.powerProfile = name;
        Quickshell.execDetached(["sh", "-c", "echo '" + name + "' > /tmp/qs_power_profile"]);

        let eppMode = (name === "performance") ? "performance" : (name === "power-saver") ? "power" : "balance_performance";
        let disableTurbo = (name === "power-saver") ? "1" : "0";
        let enableBoost = (name === "power-saver") ? "0" : "1";
        let targetRR = (name === "power-saver") ? "60" : "120";

        // NOTE: intentionally no `sudo tlp ac`/`sudo tlp bat` call here.
        // AC/BAT mode switching is owned exclusively by the udev rule in
        // power.nix. This function only manages the desktop-visible
        // profile label, per-core EPP, CPU turbo/boost, and the
        // internal-monitor refresh rate.
        let bashCmd = `
            sudo ~/.config/hypr/scripts/quickshell/battery/set_epp.sh ${eppMode} 2>/dev/null
            echo ${disableTurbo} | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo ${enableBoost} | sudo tee /sys/devices/system/cpu/cpufreq/boost 2>/dev/null

            INT_MON=$(hyprctl monitors -j | jq -r '.[] | select(.name | test("eDP|LVDS|MIPI")).name' | head -n1)

            if [ -n "$INT_MON" ]; then
                RES=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n) | "\\(.width)x\\(.height)"')
                SCALE=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).scale')

                echo "monitor=$INT_MON,$RES@${targetRR},auto,$SCALE,bitdepth,10" > ~/.cache/hypr_power_monitor.conf

                CUR_RR=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).refreshRate' | awk '{print int($1 + 0.5)}')
                if [ "$CUR_RR" != "${targetRR}" ]; then
                    hyprctl keyword monitor "$INT_MON,$RES@${targetRR},auto,$SCALE,bitdepth,10" 2>/dev/null
                fi
            fi

            if [ "${name}" = "power-saver" ] && [ "${prevProfile}" != "power-saver" ]; then
                hyprctl -j getoption decoration:screen_shader | jq -r '.str' > ~/.cache/qs_pre_saver_shader.conf 2>/dev/null
                hyprctl keyword decoration:screen_shader "" 2>/dev/null
                hyprctl keyword decoration:blur:enabled 0 2>/dev/null
                hyprctl keyword decoration:shadow:enabled 0 2>/dev/null
            elif [ "${name}" != "power-saver" ] && [ "${prevProfile}" = "power-saver" ]; then
                PREV_SHADER=$(cat ~/.cache/qs_pre_saver_shader.conf 2>/dev/null || echo "")
                hyprctl keyword decoration:screen_shader "$PREV_SHADER" 2>/dev/null
                hyprctl keyword decoration:blur:enabled 1 2>/dev/null
                hyprctl keyword decoration:shadow:enabled 1 2>/dev/null
            fi
        `;

        Quickshell.execDetached(["bash", "-c", bashCmd]);
    }
}
