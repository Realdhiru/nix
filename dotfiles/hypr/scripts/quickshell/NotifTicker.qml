pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    ListModel { id: globalNotificationHistory }
    property var notifModel: globalNotificationHistory

    property var liveNotifs: ({})
    property int _popupCounter: 0
    property bool isStartup: true
    Timer { interval: 500; running: true; onTriggered: root.isStartup = false }

    property var tickerNotif: null
    readonly property bool tickerVisible: tickerNotif !== null
    property bool tickerIsSticky: false

    function _notifKey(appName, summary) { return appName + "\u0000" + summary; }

    Timer {
        id: tickerTimeoutTimer
        onTriggered: { if (root.tickerNotif) root.tickerNotif = null; }
    }

    function _showTicker(notifData, timeoutMs) {
        root.tickerNotif = notifData;
        root.tickerIsSticky = (timeoutMs === 0);
        tickerTimeoutTimer.stop();
        if (timeoutMs > 0) {
            tickerTimeoutTimer.interval = timeoutMs;
            tickerTimeoutTimer.start();
        }
    }

    function dismiss(uid) {
        if (root.tickerNotif && root.tickerNotif.uid === uid) {
            root.tickerNotif = null;
            tickerTimeoutTimer.stop();
            root.tickerIsSticky = false;
        }
        let liveN = root.liveNotifs[uid];
        if (liveN) {
            try { liveN.dismiss(); } catch(e) {}
        }
    }

    function invokeDefault() {
        let n = root.tickerNotif;
        if (!n) return;
        let liveN = root.liveNotifs[n.uid];
        if (liveN && liveN.actions) {
            for (let i = 0; i < liveN.actions.length; i++) {
                if (liveN.actions[i].identifier === "default") { liveN.actions[i].invoke(); break; }
            }
        }
        root.dismiss(n.uid);
    }

    function invokeAction(actionId) {
        let n = root.tickerNotif;
        if (!n) return;
        let liveN = root.liveNotifs[n.uid];
        if (liveN && liveN.actions) {
            for (let i = 0; i < liveN.actions.length; i++) {
                if (liveN.actions[i].identifier === actionId) { liveN.actions[i].invoke(); break; }
            }
        }
        root.dismiss(n.uid);
    }

    NotificationServer {
        id: globalNotificationServer
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: (n) => {
            n.tracked = true;

            let extractedActions = [];
            if (n.actions) {
                for (let i = 0; i < n.actions.length; i++) {
                    extractedActions.push({
                        "id": n.actions[i].identifier || "",
                        "text": n.actions[i].text || n.actions[i].name || "Action"
                    });
                }
            }

            let notifAppName = n.appName !== "" ? n.appName : "System";
            let notifSummary  = n.summary !== "" ? n.summary : "No Title";
            let key = root._notifKey(notifAppName, notifSummary);

            let isTransientOsd = (notifAppName === "System" &&
                (notifSummary === "Volume" || notifSummary === "Brightness" || notifSummary === "Microphone"));

            if (!isTransientOsd) {
                let existingHistIdx = -1;
                for (let i = 0; i < globalNotificationHistory.count; i++) {
                    let e = globalNotificationHistory.get(i);
                    if (e.appName === notifAppName && e.summary === notifSummary) { existingHistIdx = i; break; }
                }
                if (existingHistIdx !== -1) globalNotificationHistory.remove(existingHistIdx);
            }

            let currentUid;
            let isSameAsShowing = root.tickerNotif && root._notifKey(root.tickerNotif.appName, root.tickerNotif.summary) === key;

            if (isSameAsShowing) {
                currentUid = root.tickerNotif.uid;
            } else {
                root._popupCounter++;
                currentUid = root._popupCounter;
            }

            root.liveNotifs[currentUid] = n;

            // Automatically clean up when the notification is closed by the client
            // (e.g. phone call answered, declined, or ended on the phone)
            n.closed.connect((reason) => {
                if (root.tickerNotif && root.tickerNotif.uid === currentUid) {
                    root.tickerNotif = null;
                    tickerTimeoutTimer.stop();
                    root.tickerIsSticky = false;
                }
                delete root.liveNotifs[currentUid];
                let isCall = (notifAppName.toLowerCase().includes("kde") &&
                    (notifSummary.toLowerCase().includes("call") || notifSummary.toLowerCase().includes("incoming")));
                if (isCall) {
                    for (let i = 0; i < globalNotificationHistory.count; i++) {
                        if (globalNotificationHistory.get(i).uid === currentUid) {
                            globalNotificationHistory.remove(i);
                            break;
                        }
                    }
                }
            });

            let notifData = {
                "appName":     notifAppName,
                "summary":     notifSummary,
                "body":        n.body     !== "" ? n.body     : "",
                "iconPath":    n.appIcon  !== "" ? n.appIcon  : "",
                "actionsJson": JSON.stringify(extractedActions),
                "uid":         currentUid,
                "notif":       n
            };

            if (!isTransientOsd) globalNotificationHistory.insert(0, notifData);

            if (!root.isStartup) {
                let hasActions = extractedActions.length > 0;
                let isCall = (notifAppName.toLowerCase().includes("kde") &&
                    (notifSummary.toLowerCase().includes("call") || notifSummary.toLowerCase().includes("incoming")));

                let timeoutMs = 4000;
                let exp = (n.expireTimeout !== undefined && !isNaN(n.expireTimeout)) ? n.expireTimeout : -1;

                if (isCall) {
                    // Incoming phone call: stays on ticker while ringing (with a 45s safety bound),
                    // but automatically disappears the exact millisecond the call is picked or hung up.
                    timeoutMs = 45000;
                } else if (exp === 0) {
                    timeoutMs = 0; // Explicitly sticky from sender
                } else if (exp > 0) {
                    timeoutMs = exp;
                } else if (hasActions) {
                    // Actions present: give 12 seconds so user can react, then expire from ticker
                    // (persists safely in the Battery/Notification history panel).
                    timeoutMs = 12000;
                } else {
                    timeoutMs = 4000;
                }

                let incomingIsSticky = (timeoutMs === 0 || isCall);
                if (root.tickerIsSticky && !isSameAsShowing && !incomingIsSticky) {
                    // dropped from the ticker, but it's still in history above
                } else {
                    root._showTicker(notifData, timeoutMs);
                }
            }
        }
    }
}
