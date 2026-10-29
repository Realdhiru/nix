pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root


    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/sys_fetcher.sh"

    // --- Centralized Properties (CPU/RAM/temp/net -- subscribe-gated, unchanged) ---
    readonly property bool onBattery: !root.acOnline
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
    property bool acOnline: !UPower.onBattery
    readonly property bool isCharging: root.acOnline

    property bool _lowBatteryNotified: false

    // --- Coffee mode (idle inhibit) — single shared source ---
    // Canonical state lives in $DESKTOP_STATE_DIR/modes/modes.json
    // written by mode_ctl.sh / power.sh inhibit. Both the battery popup
    // tray and the sidebar tray read root.coffeeActive; all writes go
    // through mode_ctl so the two trays can never disagree.
    property bool coffeeActive: false

    function syncCoffeeState() {
        let raw = (typeof coffeeStateView.text === "function") ? coffeeStateView.text() : coffeeStateView.text;
        let t = (raw || "").trim();
        if (!t) { root.coffeeActive = false; return; }
        try {
            let d = JSON.parse(t);
            root.coffeeActive = !!(d.active && d.active.coffee);
        } catch(e) {
            root.coffeeActive = false;
        }
    }

    function setCoffee(on) {
        root.coffeeActive = on ? true : false;
        Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/power.sh inhibit " + (on ? "on" : "off")]);
    }

    FileView {
        id: coffeeStateView
        path: Caching.modesJsonFile
        watchChanges: true
        onLoadedChanged: root.syncCoffeeState()
        onTextChanged: root.syncCoffeeState()
        onFileChanged: {
            coffeeStateView.reload();
            root.syncCoffeeState();
        }
    }

    // --- Lifecycle Management (CPU/RAM/net poller only) ---
    property int subscribers: 0

    function subscribe() {
        subscribers++;
        console.log("[SYSDATA] subscribe count:", subscribers, "fetchTimer running:", true);
        if (subscribers === 1) {
            fetchTimer.restart();
            fetchProc.running = false;
            fetchProc.running = true;
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        console.log("[SYSDATA] unsubscribe count:", subscribers, "fetchTimer running:", subscribers > 0);
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
            `export QS_CACHE_SYSDATA="${Caching.getCacheDir('sysdata')}"; bash "${root.scriptPath}"`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text ? this.text.trim() : "";
                if (!text) return;

                let p = text.split("|");
                if (p.length >= 6) {
                    // Safe parsing prevents UI crashes if the bash script returns empty or malformed strings
                    let parsedCpu = parseInt(p[0]);
                    let parsedRamP = parseInt(p[1]);
                    let parsedRamGb = parseFloat(p[2]);
                    let parsedTemp = parseInt(p[3]);
                    let parsedRx = parseFloat(p[4]);
                    let parsedTx = parseFloat(p[5]);

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
    // ALWAYS-ON BATTERY + AC WATCHER
    // Event-driven via udevadm monitor and 30s failsafe timer syncing sysfs.
    // =========================================================================

    // =========================================================================
    // ALWAYS-ON BATTERY + AC WATCHER (Native UPower signals & properties)
    // Zero sysfs reads, zero poll timers, zero subshells. Driven by UPower D-Bus.
    // =========================================================================

    function _updateBatteryTelemetry() {
        let d = UPower.displayDevice;
        if (!d || !d.isPresent) {
            root.hasBattery = false;
            return;
        }
        root.hasBattery = true;
        let pct = d.percentage <= 1.0 ? Math.round(d.percentage * 100) : Math.round(d.percentage);
        root.batCapacity = Math.max(0, Math.min(100, pct));

        let state = d.state;
        let stat = "Unknown";
        if (state === 1) stat = "Charging";
        else if (state === 2) stat = "Discharging";
        else if (state === 3) stat = "Empty";
        else if (state === 4) stat = "Fully charged";
        else if (state === 5) stat = "Pending charge";
        else if (state === 6) stat = "Pending discharge";
        else stat = UPower.onBattery ? "Discharging" : "Charging";
        root.batStatus = stat;

        let wasOnline = root.acOnline;
        root.acOnline = !UPower.onBattery;

        // EMA filter applied on each UPower signal (alpha = 0.35)
        let onBat = UPower.onBattery || (stat === "Discharging");
        if (onBat) {
            let rawRate = Math.abs(d.changeRate);
            if (rawRate >= 0.5) {
                if (root._smoothedDischargeRate <= 0.1) {
                    root._smoothedDischargeRate = rawRate;
                } else {
                    root._smoothedDischargeRate = 0.35 * rawRate + 0.65 * root._smoothedDischargeRate;
                }
            }
        } else {
            root._smoothedDischargeRate = 0.0;
        }

        if (stat === "Discharging" && root.batCapacity <= 20) {
            if (!root._lowBatteryNotified) {
                root._lowBatteryNotified = true;
                Quickshell.execDetached([
                    "notify-send", "-u", "critical", "-a", "Battery", "-i", "battery-empty",
                    "Battery Low (" + root.batCapacity + "%)"
                ]);
            }
        } else {
            root._lowBatteryNotified = false;
        }

        root._handleAcTransition(wasOnline, root.acOnline);
    }

    Connections {
        target: UPower.displayDevice
        function onReadyChanged() { root._updateBatteryTelemetry(); }
        function onIsPresentChanged() { root._updateBatteryTelemetry(); }
        function onEnergyChanged() { root._updateBatteryTelemetry(); }
        function onChangeRateChanged() { root._updateBatteryTelemetry(); }
        function onTimeToFullChanged() { root._updateBatteryTelemetry(); }
        function onTimeToEmptyChanged() { root._updateBatteryTelemetry(); }
        function onPercentageChanged() { root._updateBatteryTelemetry(); }
        function onStateChanged() { root._updateBatteryTelemetry(); }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root._smoothedDischargeRate = 0.0;
            root._updateBatteryTelemetry();
        }
    }

    onPowerProfileChanged: {
        // Fast convergence on profile change within 1-2s
        root._smoothedDischargeRate = 0.0;
        root._updateBatteryTelemetry();
    }

    // =========================================================================
    // BATTERY RUNTIME TELEMETRY (native UPower, event-driven)
    // UPower.displayDevice is the canonical aggregate battery object on the
    // system bus (org.freedesktop.UPower). Every property below is a native
    // C++ QBindable fed by UPower D-Bus PropertiesChanged -- no FileView,
    // no Process, no Timer. batRuntimeText re-evaluates only when UPower
    // actually emits.
    // =========================================================================

    function _fmtRuntime(seconds, charging) {
        if (seconds <= 0) return charging ? "+0m" : "<1m";
        let h = Math.floor(seconds / 3600);
        let m = Math.floor((seconds % 3600) / 60);
        let mm = m < 10 ? "0" + m : "" + m;
        if (h > 0) return (charging ? "+" : "") + h + "h" + mm + "m";
        return (charging ? "+" : "") + m + "m";
    }

    function batIcon(percent, online) {
        let p = (typeof percent === "number") ? percent : (parseInt(percent) || 0);
        if (online) {
            if (p >= 95) return "󰂅";
            if (p >= 85) return "󰂋";
            if (p >= 75) return "󰂊";
            if (p >= 65) return "󰢞";
            if (p >= 55) return "󰂉";
            if (p >= 45) return "󰢝";
            if (p >= 35) return "󰂈";
            if (p >= 25) return "󰂇";
            if (p >= 15) return "󰂆";
            if (p >= 5)  return "󰢜";
            return "󰢟";
        }
        if (p >= 95) return "󰁹";
        if (p >= 85) return "󰂂";
        if (p >= 75) return "󰂁";
        if (p >= 65) return "󰂀";
        if (p >= 55) return "󰁿";
        if (p >= 45) return "󰁾";
        if (p >= 35) return "󰁽";
        if (p >= 25) return "󰁼";
        if (p >= 15) return "󰁻";
        if (p >= 5)  return "󰁺";
        return "󰂃";
    }

    // Public API consumed by the SideBar battery hover text.
    // Direction comes from UPower.onBattery — never from timeToFull, which
    // is 0 when UPower can't estimate. The old code then ran DISCHARGE math
    // while charging, yielding absurd "25h" readings on AC.
    // Discharging: energy_now * 3600 / power_now
    // Charging:    (energy_full - energy_now) * 3600 / power_now
    // On AC without active fill (trickle/capped/full, or estimate > 10h):
    // "AC". Pill display clamps at 11:59 (never "99h00m" overflow).
    // Exponential moving average for discharge rate to eliminate momentary spike distortion
    property real _smoothedDischargeRate: 0.0

    readonly property int batRuntimeSeconds: {
        if (!root.hasBattery) return 0;
        let d = UPower.displayDevice;
        if (!d) return 0;
        let onBat = !root.acOnline || (root.batStatus === "Discharging") || (d && d.onBattery);
        let rem = 0;

        if (onBat) {
            let rawRate = Math.abs(d.changeRate);
            let rate = (root._smoothedDischargeRate >= 0.5) ? root._smoothedDischargeRate : rawRate;
            if (rate >= 0.5 && d.energy > 0) {
                rem = (d.energy * 3600) / rate;
            } else if (d.timeToEmpty > 0) {
                rem = d.timeToEmpty;
            }
        } else {
            // Charging math
            if (d.timeToFull > 0) {
                rem = d.timeToFull;
            } else {
                let rawRate = Math.abs(d.changeRate);
                let cap = d.energyCapacity > 0 ? d.energyCapacity : d.energy;
                if (rawRate >= 0.5 && cap > d.energy) {
                    rem = ((cap - d.energy) * 3600) / rawRate;
                }
            }
            if (rem > 36000) return 0;
        }
        if (rem > 43199) rem = 43199;
        if (rem < 0) rem = 0;
        return Math.round(rem);
    }
    readonly property int batHours: Math.floor(root.batRuntimeSeconds / 3600)
    readonly property int batMins: Math.floor((root.batRuntimeSeconds % 3600) / 60)

    readonly property string batRuntimeText: {
        if (!root.hasBattery) return "";
        let rem = root.batRuntimeSeconds;
        let charging = root.acOnline || (root.batStatus === "Charging");
        if (charging && rem <= 0) return "AC";
        return root._fmtRuntime(rem, charging);
    }

    readonly property real batPowerWatts: {
        if (!root.hasBattery) return 0.0;
        let d = UPower.displayDevice;
        if (!d) return 0.0;
        return Math.round(Math.abs(d.changeRate) * 10) / 10;
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
                    // TLP power-saver sets PLATFORM_PROFILE_ON_SAV=balanced in hardware ACPI node.
                    // Preserve power-saver if user explicitly requested power-saver!
                    if (root.requestedProfile === "power-saver") {
                        root.powerProfile = "power-saver";
                    } else {
                        root.powerProfile = "balanced";
                    }
                } else {
                    root.powerProfile = root.requestedProfile || "balanced";
                }
            }
        }
    }

    Component.onCompleted: {
        root._updateBatteryTelemetry();
        root.syncCoffeeState();
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
    readonly property int displayTransform: _displayTransform
    property int _displayTransform: 0
    readonly property bool isRotated: _displayTransform === 2

    FileView {
        id: monitorConfView
        path: Quickshell.env("HOME") + "/.cache/hypr_power_monitor.conf"
        watchChanges: true
        onLoaded: root._updateTransformFromConf()
        onFileChanged: root._updateTransformFromConf()
    }

    function _updateTransformFromConf() {
        let raw = (typeof monitorConfView.text === "function") ? monitorConfView.text() : monitorConfView.text;
        let content = (raw || "").trim();
        if (!content) return;
        let match = content.match(/transform,(\d+)/);
        if (match) {
            root._displayTransform = parseInt(match[1]);
        } else {
            root._displayTransform = 0;
        }
    }

    property bool _profileLoaded: false
    property bool _manualOverride: false
    property bool _acInitialized: false

    FileView {
        id: profileCacheFile
        path: Caching.powerProfileFile
        watchChanges: true
        onLoaded: root._handleProfileFileUpdate()
        onTextChanged: root._handleProfileFileUpdate()
        onFileChanged: {
            profileCacheFile.reload();
            root._handleProfileFileUpdate();
        }
    }

    function _handleProfileFileUpdate() {
        let raw = (typeof profileCacheFile.text === "function") ? profileCacheFile.text() : profileCacheFile.text;
        let t = (raw || "").trim();
        if (!t) return;
        if (!root._profileLoaded) {
            root._profileLoaded = true;
            root._reconcileStartupProfile(root.acOnline, t);
        } else {
            // Reactive external sync (e.g. from mode_ctl.sh preemption or power.sh CLI)
            if (t === "power-saver" || t === "performance" || t === "balanced") {
                if (root.powerProfile !== t) {
                    root.powerProfile = t;
                    root.requestedProfile = t;
                    root._applyVisualOverrides(t);
                }
            }
        }
    }

    Process {
        id: initProfileReader
        command: ["bash", "-c", "cat " + Caching.powerProfileFile + " 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let prof = this.text ? this.text.trim() : "";
                if (!root._profileLoaded && (prof === "power-saver" || prof === "performance" || prof === "balanced")) {
                    root._profileLoaded = true;
                    root._reconcileStartupProfile(root.acOnline, prof);
                }
            }
        }
    }

    function _applyVisualOverrides(targetProfile) {
        // power.sh profile handles mode_ctl.sh sync directly.
        // We track saverVisualState cleanly without race conditions.
        root.saverVisualState = (targetProfile === "power-saver") ? "saver-applied" : "normal";
    }

    function _reconcileStartupProfile(isOnline, explicitCached) {
        let raw = explicitCached || (typeof profileCacheFile.text === "function" ? profileCacheFile.text() : profileCacheFile.text);
        let cached = raw ? raw.trim() : "";

        // If on battery, never boot/restore into performance profile
        if (!isOnline && cached === "performance") {
            cached = "balanced";
        }

        if (cached === "power-saver" || cached === "performance" || cached === "balanced") {
            root._manualOverride = (cached === "power-saver");
            root.requestedProfile = cached;
            root.powerProfile = cached;
            Quickshell.execDetached(["sh", "-c", "echo '" + cached + "' > " + Caching.powerProfileFile + ".tmp && mv -f " + Caching.powerProfileFile + ".tmp " + Caching.powerProfileFile + "; bash $HOME/.config/hypr/scripts/quickshell/state_ctl.sh set power.profile '" + cached + "'"]);
            root._applyVisualOverrides(cached);
            let tlpCmd = (cached === "performance") ? "performance" : (cached === "power-saver") ? "power-saver" : "balanced";
            Quickshell.execDetached(["bash", "-c", "$HOME/.config/hypr/scripts/power.sh profile " + tlpCmd]);
            return;
        }

        if (isOnline) {
            root._manualOverride = false;
            root.requestedProfile = "performance";
            root.powerProfile = "performance";
            Quickshell.execDetached(["sh", "-c", "echo 'performance' > " + Caching.powerProfileFile + ".tmp && mv -f " + Caching.powerProfileFile + ".tmp " + Caching.powerProfileFile + "; bash $HOME/.config/hypr/scripts/quickshell/state_ctl.sh set power.profile 'performance'"]);
            root._applyVisualOverrides("performance");
            Quickshell.execDetached(["bash", "-c", "$HOME/.config/hypr/scripts/power.sh profile performance"]);
        } else {
            root._manualOverride = false;
            root.requestedProfile = "balanced";
            root.powerProfile = "balanced";
            Quickshell.execDetached(["sh", "-c", "echo 'balanced' > " + Caching.powerProfileFile + ".tmp && mv -f " + Caching.powerProfileFile + ".tmp " + Caching.powerProfileFile + "; bash $HOME/.config/hypr/scripts/quickshell/state_ctl.sh set power.profile 'balanced'"]);
            root._applyVisualOverrides("balanced");
            Quickshell.execDetached(["bash", "-c", "$HOME/.config/hypr/scripts/power.sh profile balanced"]);
        }
    }

    function _handleAcTransition(wasOnline, isOnline) {
        if (!root._acInitialized) {
            root._acInitialized = true;
            // On startup initialization, ensure hardware profile matches power source
            if (!isOnline && (root.powerProfile === "performance" || root.requestedProfile === "performance")) {
                root._manualOverride = false;
                root.setPowerProfile("balanced", false);
            }
            return;
        }
        if (wasOnline === isOnline) return;

        Quickshell.execDetached([
            "notify-send", "-a", "Power", "-u", "low",
            isOnline ? "AC Connected" : "AC Disconnected"
        ]);

        if (isOnline) {
            root._manualOverride = false;
            root.setPowerProfile("performance", false);
        } else {
            // Disconnecting AC always resets override and switches to balanced
            root._manualOverride = false;
            root.setPowerProfile("balanced", false);
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
        Quickshell.execDetached(["sh", "-c", "echo '" + name + "' > " + Caching.powerProfileFile + ".tmp && mv -f " + Caching.powerProfileFile + ".tmp " + Caching.powerProfileFile + "; bash $HOME/.config/hypr/scripts/quickshell/state_ctl.sh set power.profile '" + name + "'"]);

        root._applyVisualOverrides(name);

        let tlpCmd = (name === "performance") ? "performance" : (name === "power-saver") ? "power-saver" : "balanced";
        Quickshell.execDetached(["bash", "-c", "$HOME/.config/hypr/scripts/power.sh profile " + tlpCmd]);
        profileRefreshTimer.restart();
    }
}
