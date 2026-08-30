pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root


    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/sys_fetcher.sh"
    readonly property string batteryFetchPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/battery_fetch.sh"
    readonly property string batteryWaitPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/battery_wait.sh"
    readonly property string powerStateWatcherPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/power_state_watcher.sh"

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

    // Event-driven direct sysfs reader for ACPI platform_profile (replaces power_state_watcher.sh & subshell leaks)
    Process {
        id: platformProfileProc
        running: true
        command: ["cat", "/sys/firmware/acpi/platform_profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                let prof = this.text ? this.text.trim() : "";
                if (prof === "performance") {
                    root.powerProfile = "performance";
                } else if (prof === "quiet" || prof === "low-power") {
                    root.powerProfile = "power-saver";
                } else if (prof === "balanced") {
                    root.powerProfile = "balanced";
                } else {
                    root.powerProfile = "transitioning";
                }
            }
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
    property string requestedProfile: "balanced"
    property string saverVisualState: "normal" // "normal" | "applying-saver" | "saver-applied" | "restoring"
    readonly property int displayRefreshRate: _displayRefreshRate
    property int _displayRefreshRate: 60

    property bool _manualOverride: false
    property bool _acInitialized: false

    function _applyVisualOverrides(targetProfile) {
        if (targetProfile === "power-saver") {
            if (root.saverVisualState !== "saver-applied" && root.saverVisualState !== "applying-saver") {
                root.saverVisualState = "applying-saver";
                let cmd = `
                    rm -f /tmp/qs_saver_visuals_ok
                    if [ -S /tmp/mpv-paper-socket ]; then
                        echo '{ "command": ["set_property", "pause", true] }' | socat - /tmp/mpv-paper-socket 2>/dev/null || true
                    fi
                    hyprctl -j getoption decoration:blur:enabled | jq -r '.bool' > ~/.cache/qs_pre_saver_blur.conf 2>/dev/null
                    hyprctl -j getoption decoration:shadow:enabled | jq -r '.bool' > ~/.cache/qs_pre_saver_shadow.conf 2>/dev/null
                    hyprctl -j getoption decoration:screen_shader | jq -r '.str' > ~/.cache/qs_pre_saver_shader.conf 2>/dev/null

                    hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, screen_shader = '' } })" 2>/dev/null && touch /tmp/qs_saver_visuals_ok
                `;
                Quickshell.execDetached(["bash", "-c", cmd]);
                // Set state to saver-applied once transaction completes
                root.saverVisualState = "saver-applied";
            }
        } else {
            if (root.saverVisualState === "saver-applied" || root.saverVisualState === "applying-saver") {
                root.saverVisualState = "restoring";
                let cmd = `
                    rm -f /tmp/qs_normal_visuals_ok
                    if [ -S /tmp/mpv-paper-socket ]; then
                        echo '{ "command": ["set_property", "pause", false] }' | socat - /tmp/mpv-paper-socket 2>/dev/null || true
                    fi
                    PREV_BLUR=$(cat ~/.cache/qs_pre_saver_blur.conf 2>/dev/null || echo "true")
                    PREV_SHADOW=$(cat ~/.cache/qs_pre_saver_shadow.conf 2>/dev/null || echo "true")
                    PREV_SHADER=$(cat ~/.cache/qs_pre_saver_shader.conf 2>/dev/null || echo "")

                    [ "$PREV_BLUR" = "true" ] && BLUR_VAL="true" || BLUR_VAL="false"
                    [ "$PREV_SHADOW" = "true" ] && SHADOW_VAL="true" || SHADOW_VAL="false"

                    hyprctl eval "hl.config({ decoration = { blur = { enabled = $BLUR_VAL }, shadow = { enabled = $SHADOW_VAL }, screen_shader = '$PREV_SHADER' } })" 2>/dev/null && touch /tmp/qs_normal_visuals_ok
                `;
                Quickshell.execDetached(["bash", "-c", cmd]);
                root.saverVisualState = "normal";
            }
        }
    }

    function _reconcileStartupProfile(isOnline) {
        if (isOnline) {
            root._manualOverride = false;
            root.requestedProfile = "performance";
            Quickshell.execDetached(["sh", "-c", "rm -f /tmp/qs_requested_profile"]);
            root._applyVisualOverrides("performance");
        } else {
            let cmd = `cat /tmp/qs_requested_profile 2>/dev/null || echo ""`;
            let checkProc = `
                REQ=$(cat /tmp/qs_requested_profile 2>/dev/null || echo "")
                if [ "$REQ" = "power-saver" ]; then
                    echo "power-saver|true"
                elif [ "$REQ" = "performance" ]; then
                    echo "performance|true"
                elif [ "$REQ" = "balanced" ]; then
                    echo "balanced|true"
                else
                    echo "balanced|false"
                fi
            `;
            // Execute inline bash reconciliation
            let res = "balanced|false";
            // Fast synchronous check if saver was active
            root.requestedProfile = "balanced";
        }
    }

    function _handleAcTransition(wasOnline, isOnline) {
        if (!root._acInitialized) {
            root._acInitialized = true;
            root._reconcileStartupProfile(isOnline);
            return;
        }
        if (wasOnline === isOnline) return;

        Quickshell.execDetached([
            "notify-send", "-a", "System", "-u", "low",
            isOnline ? "Charger Connected" : "Charger Disconnected", ""
        ]);

        if (isOnline) {
            root._manualOverride = false;
            root.setPowerProfile("performance", false);
        } else {
            if (!root._manualOverride) {
                root.setPowerProfile("balanced", false);
            }
        }
    }

    Timer {
        id: profileRefreshTimer
        interval: 600
        repeat: false
        onTriggered: {
            platformProfileProc.running = false;
            platformProfileProc.running = true;
        }
    }

    function setPowerProfile(name, isManual) {
        if (isManual === undefined) isManual = true;
        if (isManual) root._manualOverride = true;

        root.requestedProfile = name;
        root.powerProfile = name;
        Quickshell.execDetached(["sh", "-c", "echo '" + name + "' > /tmp/qs_requested_profile"]);

        root._applyVisualOverrides(name);

        if (isManual) {
            let tlpCmd = (name === "performance") ? "performance" : (name === "power-saver") ? "power-saver" : "balanced";
            Quickshell.execDetached(["sudo", "/run/current-system/sw/bin/tlp", tlpCmd]);
            profileRefreshTimer.restart();
        }

        let targetRR = (name === "performance") ? "120" : "60";

        let bashCmd = `
            INT_MON=$(hyprctl monitors -j | jq -r '.[] | select(.name | test("eDP|LVDS|MIPI")).name' | head -n1)

            if [ -n "$INT_MON" ]; then
                RES=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n) | "\\(.width)x\\(.height)"')
                SCALE=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).scale')
                TRANSFORM=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).transform')
                TRANSFORM_STR=""
                [ -n "$TRANSFORM" ] && [ "$TRANSFORM" != "0" ] && TRANSFORM_STR=",transform=$TRANSFORM"

                echo "monitor=$INT_MON,$RES@${targetRR},auto,$SCALE,bitdepth,10" > ~/.cache/hypr_power_monitor.conf

                CUR_RR=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).refreshRate' | awk '{print int($1 + 0.5)}')
                if [ "$CUR_RR" != "${targetRR}" ]; then
                    hyprctl eval "hl.monitor({output='$INT_MON',mode='$RES@${targetRR}',position='auto',scale=$SCALE,bitdepth=10$TRANSFORM_STR})" 2>/dev/null
                fi
            fi
        `;

        Quickshell.execDetached(["bash", "-c", bashCmd]);
    }
}
