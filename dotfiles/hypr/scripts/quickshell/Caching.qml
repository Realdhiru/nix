import QtQuick
import Quickshell

QtObject {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string xdgRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string euid: Quickshell.env("UID") || "1000"
    
    // Persistent data on disk
    readonly property string cacheDir: home + "/.cache/quickshell"
    readonly property string stateDir: home + "/.local/state/quickshell"
    
    // Ephemeral data in RAM (tmpfs) - Secure fallback matching caching.sh
    readonly property string runDir: (xdgRuntimeDir !== "" ? xdgRuntimeDir : ("/run/user/" + euid)) + "/quickshell"
    readonly property string logDir: runDir + "/logs"

    // Memoization map to prevent subprocess flooding
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
        return _ensureDir(envPath ? envPath : (stateDir + "/" + widgetName));
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