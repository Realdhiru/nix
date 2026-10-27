pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string xdgStateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string desktopStateDir: Quickshell.env("DESKTOP_STATE_DIR") || (xdgStateHome + "/desktop")
    readonly property string xdgRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string euid: Quickshell.env("UID") || "1000"

    // Persistent data on disk
    readonly property string cacheDir: home + "/.cache/quickshell"
    readonly property string stateDir: desktopStateDir

    // Canonical persistent state paths
    readonly property string stateJsonFile: desktopStateDir + "/quickshell/state.json"
    readonly property string powerProfileFile: desktopStateDir + "/power/profile"
    readonly property string recPidFile: desktopStateDir + "/recording/rec_pid"
    readonly property string wallpaperKilledFile: desktopStateDir + "/modes/wallpaper_killed"
    readonly property string gamingModeFile: desktopStateDir + "/modes/gaming_mode"

    // Ephemeral data in RAM (tmpfs) - Secure fallback matching caching.sh
    readonly property string runDir: (xdgRuntimeDir !== "" ? xdgRuntimeDir : ("/run/user/" + euid)) + "/quickshell"
    readonly property string logDir: runDir + "/logs"

    // Memoization map to prevent subprocess flooding.
    // Now a true singleton, so this map is genuinely shared across the whole
    // Quickshell process — every file that calls getCacheDir/getStateDir/etc.
    // hits the SAME map, so mkdir -p only ever runs once per directory,
    // process-wide, instead of once per consumer file.
    property var _initializedPaths: ({})

    function _ensureDir(path) {
        if (!_initializedPaths[path]) {
            Quickshell.execDetached(["mkdir", "-p", path]);
            _initializedPaths[path] = true;
        }
        return path;
    }

    function getCacheDir(widgetName) {
        var envPath = Quickshell.env("QS_CACHE_" + widgetName.toUpperCase());
        return _ensureDir(envPath ? envPath : (cacheDir + "/" + widgetName));
    }

    function getStateDir(widgetName) {
        var envPath = Quickshell.env("QS_STATE_" + widgetName.toUpperCase());
        return _ensureDir(envPath ? envPath : (desktopStateDir + "/" + widgetName));
    }

    function getRunDir(widgetName) {
        var envPath = Quickshell.env("QS_RUN_" + widgetName.toUpperCase());
        return _ensureDir(envPath ? envPath : (runDir + "/" + widgetName));
    }

    function getLogDir(widgetName) {
        var envPath = Quickshell.env("QS_LOG_" + widgetName.toUpperCase());
        return _ensureDir(envPath ? envPath : (logDir + "/" + widgetName));
    }
}