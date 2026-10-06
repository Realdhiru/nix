import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    width: Screen.width
    height: parent ? parent.height : Screen.height

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    Theme { id: _theme }

    property string widgetArg: ""
    property string targetWallName: ""
    property bool initialFocusSet: false
    property int visibleItemCount: -1
    property int scrollAccum: 0
    property real scrollThreshold: window.s(120)
    property int scrollVelocity: 1
    property int scrollDirection: 0
    property double lastWheelMs: 0

    property string currentFilter: "All"
    property string _lastFilter: "All"

    property string searchQuery: ""
    property bool isOnlineSearch: false
    property bool isSearchPaused: false
    property bool hasSearched: false
    property int cacheVersion: 0 
    
    property bool isDownloadingWallpaper: false
    property string currentDownloadName: ""
    
    property bool isApplying: false
    property bool isMonitorSelectorOpen: false

    property bool allowAddAnimation: false
    
    Timer {
        id: applyUnlockTimer
        interval: 250
        onTriggered: window.isApplying = false
    }
    
    property bool isStartup: localFolderModel.status === FolderListModel.Loading || srcModel.status === FolderListModel.Loading
    property bool isReady: visible && localFolderModel.status === FolderListModel.Ready
    property bool isSearchActive: window.currentFilter === "Search" && window.hasSearched && searchFolderModel.status === FolderListModel.Loading
    
    property string lastSearchName: ""
    property bool isModelChanging: false
    property bool searchIndexRestored: false
    
    property bool isScrollingBlocked: false
    property bool jumpToLastOnFilterChange: false

    property var discoveredCategories: ["dark", "emerald", "gruvbox", "light", "nord", "ocean", "sakura", "sunset", "synthwave"]

    FolderListModel {
        id: categoryFolderModel
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: window.updateDiscoveredCategories()
        onStatusChanged: { if (status === FolderListModel.Ready) window.updateDiscoveredCategories(); }
    }

    function updateDiscoveredCategories() {
        let list = [];
        let excluded = ["previews", "scripts", "gifs", "videos", "flat", ".git"];
        for (let i = 0; i < categoryFolderModel.count; i++) {
            let fn = categoryFolderModel.get(i, "fileName");
            if (fn && excluded.indexOf(fn.toLowerCase()) === -1 && !fn.startsWith(".")) {
                list.push(fn);
            }
        }
        if (list.length > 0) {
            window.discoveredCategories = list;
        }
    }

    readonly property var filterData: [
        { name: "All", label: "All" },
        { name: "Gruvbox", label: "Gruvbox" },
        { name: "Sakura", label: "Sakura" },
        { name: "Nord", label: "Nord" },
        { name: "Ocean", label: "Ocean" },
        { name: "Emerald", label: "Emerald" },
        { name: "Sunset", label: "Sunset" },
        { name: "Synthwave", label: "Synthwave" },
        { name: "Crimson", label: "Crimson" },
        { name: "Violet", label: "Violet" },
        { name: "Monochrome", label: "Mono" },
        { name: "Dark", label: "Dark" },
        { name: "Light", label: "Light" },
        { name: "GIFs", label: "GIF" },
        { name: "Videos", label: "Vid" },
        { name: "Search", label: "Search" }
    ]

    ListModel { id: monitorModel }

    property var downloadedSearchMap: ({})

    Timer {
        id: downloadTimeoutTimer
        interval: 25000
        onTriggered: {
            if (downloadProc.running) {
                downloadProc.running = false;
            }
            window.isDownloadingWallpaper = false;
        }
    }

    Process {
        id: downloadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                window.isDownloadingWallpaper = false;
                downloadTimeoutTimer.stop();
                window.hasPendingOrganize = true;
                if (window.currentDownloadName !== "") {
                    let map = window.downloadedSearchMap;
                    map[window.currentDownloadName] = true;
                    window.downloadedSearchMap = map;
                }
            }
        }
    }

    property var wallpaperCategoryMap: ({})
    property var wallpaperColorMap: ({})
    property var wallpaperScoreMap: ({})
    property bool hasPendingOrganize: false

    Process {
        id: markersProc
        command: ["bash", "-c", "python3 \"$HOME/.config/hypr/scripts/quickshell/wallpaper/indexer.py\" \"$HOME/Pictures/Wallpapers\" \"$HOME/.cache/quickshell/wallpaper_index.json\" && cat \"$HOME/.cache/quickshell/wallpaper_index.json\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text;
                if (!output || output.trim().length === 0) return;
                try {
                    let data = JSON.parse(output);
                    let catMap = {};
                    let colorMap = {};
                    let scoreMap = {};
                    if (data && data.items) {
                        for (let i = 0; i < data.items.length; i++) {
                            let item = data.items[i];
                            if (item && item.fileName) {
                                let fn = item.fileName;
                                let clean = window.getCleanName(fn);
                                let hex = item.hex || "#1e1e2e";
                                let bucket = item.bucket || "Dark";
                                let score = (item.band !== undefined && item.colorKey !== undefined) ?
                                    { band: item.band, key: item.colorKey } :
                                    window.hexToColorScore(hex);
                                catMap[fn] = bucket;
                                colorMap[fn] = hex.replace("#", "");
                                scoreMap[fn] = score;
                                if (clean.length > 0) {
                                    catMap[clean] = bucket;
                                    colorMap[clean] = hex.replace("#", "");
                                    scoreMap[clean] = score;
                                }
                            }
                        }
                    }
                    window.wallpaperCategoryMap = catMap;
                    window.wallpaperColorMap = colorMap;
                    window.wallpaperScoreMap = scoreMap;
                    window.updateCategoryCounts();
                    if (localProxyModel.count > 0) {
                        window.sortListModel(localProxyModel);
                        window.sortListModel(gifsProxyModel);
                        window.sortListModel(videosProxyModel);
                        if (window.currentFilter !== "All" && window.currentFilter !== "GIFs" && window.currentFilter !== "Videos" && window.currentFilter !== "Search") {
                            window.updateCategoryProxyModel();
                        }

                        let targetModel = window.getModelForFilter(window.currentFilter);
                        let wallToFind = window.activeWallpaperName !== "" ? window.activeWallpaperName : window.targetWallName;
                        if (targetModel && targetModel.count > 0 && wallToFind !== "" && window.visible && view.width > 0) {
                            let cleanTarget = window.getCleanName(wallToFind);
                            let foundIdx = -1;
                            for (let i = 0; i < targetModel.count; i++) {
                                let fn = targetModel.get(i).fileName || "";
                                if (fn === wallToFind || window.getCleanName(fn) === cleanTarget) {
                                    foundIdx = i;
                                    break;
                                }
                            }
                            if (foundIdx !== -1) {
                                window.targetWallName = targetModel.get(foundIdx).fileName || wallToFind;
                                window.executeFocusRestore(foundIdx, false, true);
                            }
                        }
                    }
                } catch (e) {
                    console.log("[WALLPAPER_PICKER] Error loading index json:", e);
                }
            }
        }
    }

    function processMarkers() {
        markersProc.running = true;
    }

    function loadMonitors() {
        monitorModel.clear();
        let screens = Quickshell.screens;
        let batch = [];
        for (let i = 0; i < screens.length; i++) {
            batch.push({ "name": screens[i].name, "selected": true });
        }
        monitorModel.append(batch);
    }

    function getMonitorOutputs() {
        if (monitorModel.count <= 1) return "all"; 
        let selected = [];
        for (let i = 0; i < monitorModel.count; i++) {
            if (monitorModel.get(i).selected) {
                selected.push(monitorModel.get(i).name);
            }
        }
        if (selected.length === 0) return "none";
        if (selected.length === monitorModel.count) return "all";
        return selected.join(",");
    }

    readonly property string activeWallpaperFile: Quickshell.env("HOME") + "/.cache/current_wallpaper.txt"
    property string activeWallpaperPath: (activeWallWatcher.text() || "").trim()
    property string activeWallpaperName: {
        let p = window.activeWallpaperPath;
        if (!p) return "";
        let parts = p.split("/");
        return parts[parts.length - 1];
    }

    FileView {
        id: activeWallWatcher
        path: window.activeWallpaperFile
        watchChanges: true
        onFileChanged: {
            activeWallWatcher.reload();
            window.activeWallpaperPath = (activeWallWatcher.text() || "").trim();
        }
    }

    function applyWallpaper(safeFileName, isVideo) {
        if (!safeFileName || window.isApplying) return;
        
        let cleanTarget = window.getCleanName(safeFileName);
        let cleanActive = window.getCleanName(window.activeWallpaperName);
        if (cleanTarget !== "" && cleanTarget === cleanActive) {
            console.log("[WALLPAPER_PICKER] Clicked wallpaper is already active, ignoring re-apply:", safeFileName);
            return;
        }
        
        let outputs = window.getMonitorOutputs();
        if (outputs === "none") return;
        
        window.isApplying = true;
        applyUnlockTimer.restart();
        
        window.targetWallName = safeFileName;
        let cleanName = window.getCleanName(safeFileName);

        const escapeBash = (str) => String(str).replace(/(["\\$`])/g, '\\$1');
        
        if (window.currentFilter === "Search" && window.hasSearched) {
            let alreadyExists = window.isDownloaded(safeFileName);
            let destFile = window.srcDir + "/" + safeFileName;
            let finalThumb = "file://" + window.srcDir + "/" + safeFileName;
            let tempThumb = decodeURIComponent(window.searchDir.replace("file://", "")) + "/" + safeFileName;
            let mapFile = Caching.getCacheDir("wallpaper_picker") + "/search_map.txt";

            if (alreadyExists) {
                const applyScript = `
                    export DEST_FILE="${escapeBash(destFile)}"
                    export FINAL_THUMB="${escapeBash(finalThumb)}"
                    
                    ~/.config/hypr/scripts/set_wallpaper.sh "$DEST_FILE"
                `;
                Quickshell.execDetached(["bash", "-c", applyScript]);
            } else {
                window.isDownloadingWallpaper = true;
                window.currentDownloadName = safeFileName;

                const downloadScript = `
                    export SAFE_NAME="${escapeBash(safeFileName)}"
                    export DEST_FILE="${escapeBash(destFile)}"
                    export MAP_FILE="${escapeBash(mapFile)}"
                    export SEARCH_THUMB="${escapeBash(tempThumb)}"
                    
                    URL=\$(awk -F'|' -v fname="\$SAFE_NAME" '\$1 == fname {print \$2; exit}' "\$MAP_FILE")
                    if [ -z "\$URL" ]; then
                        echo "ERROR: URL not found for \$SAFE_NAME in \$MAP_FILE"
                        exit 1
                    fi
                    
                    TMP_FILE="\${DEST_FILE}.tmp"
                    curl -s -L --max-time 20 --connect-timeout 5 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "\$URL" -o "\$TMP_FILE"
                    
                    if [ -s "\$TMP_FILE" ] && file -b --mime-type "\$TMP_FILE" | grep -q "^image/"; then
                        if file -b --mime-type "\$TMP_FILE" | grep -q "image/webp"; then
                            magick "\$TMP_FILE" "\$DEST_FILE" 2>/dev/null || mv "\$TMP_FILE" "\$DEST_FILE"
                            rm -f "\$TMP_FILE"
                        else
                            mv "\$TMP_FILE" "\$DEST_FILE"
                        fi
                    elif [ -s "\$SEARCH_THUMB" ]; then
                        cp "\$SEARCH_THUMB" "\$DEST_FILE"
                        rm -f "\$TMP_FILE"
                    else
                        rm -f "\$TMP_FILE"
                        echo "ERROR: Download failed and no fallback preview"
                        exit 1
                    fi
                    
                    ~/.config/hypr/scripts/set_wallpaper.sh "\$DEST_FILE"
                    ~/.config/hypr/scripts/wallpaper_thumbnail.sh &
                `;
                downloadProc.command = ["bash", "-c", downloadScript];
                downloadProc.running = true;
                downloadTimeoutTimer.restart();
            }
            return;
        }

        const originalFile = window.flatSrcDir.replace("file://", "") + "/" + safeFileName;
        const escOriginal = escapeBash(originalFile);

        const fullScript = `
            ~/.config/hypr/scripts/set_wallpaper.sh "${escOriginal}"
        `;
        Quickshell.execDetached(["bash", "-c", fullScript]);
    }
    
    QtObject {
        id: searchState
        property string query: ""
        property bool searched: false
        property string lastName: ""
    }

    // FIXED: Property handlers are now strictly bound directly under the root 'window' Item
    onIsSearchPausedChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + (isSearchPaused ? "pause" : "run") + "' > " + Caching.getRunDir("wallpaper_picker") + "/ddg_search_control"]);
    }

    onVisibleChanged: {
        if (!visible) {
            window.initialFocusSet = false;
            window.allowAddAnimation = false;
            window.searchIndexRestored = false;
            window.isApplying = false;
            window.isMonitorSelectorOpen = false;
            if (window.hasSearched) {
                window.isSearchPaused = true;
            }
            if (window.hasPendingOrganize) {
                window.hasPendingOrganize = false;
                Quickshell.execDetached(["bash", "-c", "rm -f '" + Caching.getRunDir("wallpaper_picker") + "/picker_active'; python3 ~/Pictures/Wallpapers/scripts/auto_organize.py"]);
            } else {
                Quickshell.execDetached(["bash", "-c", "rm -f '" + Caching.getRunDir("wallpaper_picker") + "/picker_active'"]);
            }
        } else {
            Quickshell.execDetached(["bash", "-c", "mkdir -p '" + Caching.getRunDir("wallpaper_picker") + "'; touch '" + Caching.getRunDir("wallpaper_picker") + "/picker_active'"]);
            window.isFilterAnimating = true;
            filterAnimationTimer.restart();
            if (window.currentFilter !== "Search") {
                window.applyFilters(true);
                centerOnActiveTimer.restart();
            } else if (window.hasSearched) {
                window.searchIndexRestored = false;
                window.isSearchPaused = true;
                window.trySearchFocus();
                window.syncSearchModel();
            }
            Qt.callLater(() => { view.forceActiveFocus(); });
        }
    }

    onCurrentFilterChanged: {
        if (window.currentFilter !== "Search" && window.currentFilter !== "GIFs" && window.currentFilter !== "Videos" && window.currentFilter !== "All") {
            window.updateCategoryProxyModel();
        }
        window.isFilterAnimating = true;
        filterAnimationTimer.restart();
        let returningFromSearch = (window._lastFilter === "Search" && window.currentFilter !== "Search");
        window._lastFilter = window.currentFilter;
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/state_ctl.sh", "set", "ui.wallpaperFilter", window.currentFilter]);
        
        if (returningFromSearch) window.searchIndexRestored = false;
        
        Qt.callLater(() => {
            view.forceActiveFocus();
            if (window.currentFilter === "Search") {
                if (window.hasSearched) {
                    window.searchIndexRestored = false;
                    window.trySearchFocus();
                }
            } else {
                window.applyFilters(returningFromSearch);
            }
            window.isModelChanging = false;
        });
    }

    property bool isLoading: localFolderModel.status === FolderListModel.Loading || 
                             srcModel.status === FolderListModel.Loading ||
                             (window.currentFilter === "Search" && searchFolderModel.status === FolderListModel.Loading)

    property bool showSpinner: window.isDownloadingWallpaper || 
                               (window.currentFilter === "Search" && window.hasSearched && !window.isSearchPaused && window.visibleItemCount === 0) || 
                               (window.currentFilter !== "Search" && window.isLoading)

    property string statusToast: ""
    Timer {
        id: toastTimer
        interval: 2000
        onTriggered: window.statusToast = ""
    }

    property string currentNotification: {
        if (window.statusToast !== "") return window.statusToast;
        if (window.isDownloadingWallpaper) return "Downloading wallpaper...";
        if (window.currentFilter === "Search") {
            if (!window.hasSearched) return "Type something to search...";
            if (window.isSearchPaused) return "Search Paused";
            if (window.visibleItemCount === 0) return "Searching DDG (FHD+)...";
            return window.visibleItemCount > 0 ? (window.visibleItemCount + " wallpapers found") : "";
        }
        if (isLoading) return "Parsing wallpapers...";
        if (window.visibleItemCount === 0) return "No wallpapers found";
        if (window.currentFilter === "All") return "";
        if (window.currentFilter === "Videos" || window.currentFilter === "Video") return "Videos";
        if (window.currentFilter === "GIFs" || window.currentFilter === "GIF") return "GIFs";
        return window.currentFilter;
    }
    
    property bool showNotification: !window.isStartup && currentNotification !== ""

    function getCleanName(name) {
        if (!name) return "";
        let clean = String(name);
        if (clean.startsWith("000_")) {
            clean = clean.substring(4);
        }
        let hashRegex = /^[a-f0-9]{32}_/;
        if (hashRegex.test(clean)) {
            clean = clean.substring(33);
        }
        return clean;
    }

    readonly property var categoryRankMap: ({
        "gifs": 0,
        "gruvbox": 1,
        "sakura": 2,
        "nord": 3,
        "ocean": 4,
        "emerald": 5,
        "sunset": 6,
        "synthwave": 7,
        "crimson": 8,
        "violet": 9,
        "monochrome": 10,
        "dark": 11,
        "light": 12,
        "videos": 13
    })



    function getFileTypeRank(fileName) {
        if (!fileName) return 1;
        let fn = String(fileName).toLowerCase();
        if (fn.endsWith(".gif")) return 0; // 1. GIFs FIRST
        if (window.isVideoFile(fileName)) return 2; // 3. Videos last
        return 1; // 2. Static images second (sorted by color score)
    }

    function hexToColorScore(hex) {
        if (!hex || hex.length < 6) return { band: 2, key: 999 };
        let r = parseInt(hex.substring(0, 2), 16) / 255.0;
        let g = parseInt(hex.substring(2, 4), 16) / 255.0;
        let b = parseInt(hex.substring(4, 6), 16) / 255.0;
        let max = Math.max(r, g, b), min = Math.min(r, g, b);
        let d = max - min;
        let l = (max + min) / 2.0;
        let s = 0.0;
        let h = 0.0;
        if (d !== 0) {
            s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
            switch (max) {
                case r: h = ((g - b) / d + (g < b ? 6.0 : 0.0)); break;
                case g: h = ((b - r) / d + 2.0); break;
                case b: h = ((r - g) / d + 4.0); break;
            }
            h *= 60.0;
        }
        // Achromatic / neutral (very low saturation or near black/white): sort band 0 by lightness
        if (s < 0.14 || l < 0.08 || l > 0.92) {
            return { band: 0, key: l * 100.0 };
        }
        // Chromatic: sort band 1 by hue wheel (0° to 360°)
        return { band: 1, key: h };
    }

    function sortListModel(model) {
        if (!model || model.count === 0) return;
        let arr = [];
        for (let i = 0; i < model.count; i++) {
            let fn = model.get(i).fileName;
            let fu = model.get(i).fileUrl;
            if (fn !== undefined) {
                arr.push({ "fileName": fn, "fileUrl": String(fu) });
            }
        }
        arr.sort(function(a, b) {
            let aType = window.getFileTypeRank(a.fileName);
            let bType = window.getFileTypeRank(b.fileName);
            if (aType !== bType) return aType - bType;

            let aClean = window.getCleanName(a.fileName);
            let bClean = window.getCleanName(b.fileName);

            let aScore = window.wallpaperScoreMap[a.fileName] || window.wallpaperScoreMap[aClean] || null;
            if (!aScore) {
                let aHex = window.wallpaperColorMap[a.fileName] || window.wallpaperColorMap[aClean] || "";
                aScore = window.hexToColorScore(aHex);
            }

            let bScore = window.wallpaperScoreMap[b.fileName] || window.wallpaperScoreMap[bClean] || null;
            if (!bScore) {
                let bHex = window.wallpaperColorMap[b.fileName] || window.wallpaperColorMap[bClean] || "";
                bScore = window.hexToColorScore(bHex);
            }

            // Continuous color gradient sorting:
            // Band 1: Chromatic (sorted by hue angle 0° to 360°)
            // Band 0: Achromatic / Monochrome (sorted by lightness 0 to 100)
            if (aScore.band !== bScore.band) return bScore.band - aScore.band;
            if (Math.abs(aScore.key - bScore.key) > 0.5) return aScore.key - bScore.key;

            let aName = aClean.toLowerCase();
            let bName = bClean.toLowerCase();
            return aName.localeCompare(bName);
        });

        // Skip clear/append if order has not changed (prevents delegate churn and scroll reset)
        let changed = false;
        if (arr.length !== model.count) {
            changed = true;
        } else {
            for (let j = 0; j < arr.length; j++) {
                if (model.get(j).fileName !== arr[j].fileName) {
                    changed = true;
                    break;
                }
            }
        }

        if (changed) {
            window.isModelChanging = true;
            model.clear();
            model.append(arr);
            window.isModelChanging = false;
        }
    }

    // Previously "is this a video" was inferred from a "000_" filename
    // prefix — a convention meant for sorting freshly-downloaded search
    // results first, not an actual video marker. Any locally-added mp4/mkv
    // wallpaper that didn't happen to start with "000_" was silently
    // misclassified as a non-video everywhere (thumbnail path resolution,
    // the "Video" filter, apply-time routing), which is why local video
    // wallpapers never got a real thumbnail: the delegate looked for
    // "thumbs/yourfile.mp4" (no .jpg suffix, and QML's Image can't decode
    // raw video anyway) instead of the actual generated
    // "thumbs/yourfile.mp4.jpg". This checks the real file extension
    // instead, matching set_wallpaper.sh and wallpaper_thumbnail.sh.
    function isVideoFile(name) {
        if (!name) return false;
        let m = String(name).match(/\.([a-zA-Z0-9]+)$/);
        if (!m) return false;
        let ext = m[1].toLowerCase();
        return ext === "mp4" || ext === "mkv" || ext === "mov" || ext === "webm";
    }

    function isDownloaded(name) {
        if (!name) return false;
        if (window.downloadedSearchMap && window.downloadedSearchMap[name]) return true;
        for (let i = 0; i < srcModel.count; i++) {
            if (srcModel.get(i, "fileName") === name) return true;
        }
        return false;
    }

    function deleteCurrentWallpaper() {
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (!targetModel || targetModel.count === 0) return;
        let idx = view.currentIndex;
        if (idx < 0 || idx >= targetModel.count) return;

        let item = targetModel.get(idx);
        if (!item || !item.fileName) return;

        let fileName = String(item.fileName);
        const escapeBash = (str) => String(str).replace(/(["\\$`])/g, '\\$1');

        if (window.currentFilter === "Search") {
            let destFile = window.srcDir + "/" + fileName;
            let thumbPath = decodeURIComponent(window.searchDir.replace("file://", "")) + "/" + fileName;
            let mapFile = Caching.getCacheDir("wallpaper_picker") + "/search_map.txt";

            let deleteSearchScript = `
                export DEST_FILE="${escapeBash(destFile)}"
                export THUMB_PATH="${escapeBash(thumbPath)}"
                export MAP_FILE="${escapeBash(mapFile)}"
                export FILE_NAME="${escapeBash(fileName)}"

                gio trash "$DEST_FILE" 2>/dev/null || rm -f "$DEST_FILE"
                rm -f "${DEST_FILE}.tmp"
                rm -f "$THUMB_PATH"
                if [ -f "$MAP_FILE" ]; then
                    grep -v "^\$FILE_NAME|" "\$MAP_FILE" > "\${MAP_FILE}.tmp" 2>/dev/null && mv "\${MAP_FILE}.tmp" "\$MAP_FILE" || rm -f "\${MAP_FILE}.tmp"
                fi
            `;
            Quickshell.execDetached(["bash", "-c", deleteSearchScript]);

            if (window.downloadedSearchMap && window.downloadedSearchMap[fileName]) {
                let map = window.downloadedSearchMap;
                delete map[fileName];
                window.downloadedSearchMap = map;
            }

            window.isModelChanging = true;
            targetModel.remove(idx);
            window.isModelChanging = false;

            if (idx >= targetModel.count) idx = Math.max(0, targetModel.count - 1);
            view.currentIndex = idx;
            window.updateVisibleCount();
            window.statusToast = "Wallpaper deleted";
            toastTimer.restart();
            return;
        }

        // Local filters (All, GIFs, Videos)
        window._suppressSync = true;
        let flatPath = window.flatSrcDir.replace("file://", "") + "/" + fileName;
        let deleteLocalScript = `
            export FLAT_PATH="${escapeBash(flatPath)}"
            export FILE_NAME="${escapeBash(fileName)}"

            REAL_PATH="$(readlink -f "$FLAT_PATH" 2>/dev/null || true)"
            if [ -z "$REAL_PATH" ] || [ ! -f "$REAL_PATH" ]; then
                REAL_PATH="$HOME/Pictures/Wallpapers/$FILE_NAME"
            fi

            if [ -n "$REAL_PATH" ] && [ -f "$REAL_PATH" ]; then
                python3 "$HOME/Pictures/Wallpapers/scripts/auto_organize.py" --delete "$REAL_PATH" || gio trash "$REAL_PATH" 2>/dev/null || rm -f "$REAL_PATH"
            fi

            rm -f "$FLAT_PATH"
            rm -f "$HOME/.cache/quickshell/wallpaper_picker/thumbs/\${FILE_NAME}"*
            rm -f "$HOME/.cache/quickshell/wallpaper_picker/colors_markers/\${FILE_NAME}"*
            rm -f "$HOME/.cache/converted_gifs/\${FILE_NAME}"*
            rm -f "$HOME/Pictures/Wallpapers/previews/"*"/\${FILE_NAME}"*
        `;
        Quickshell.execDetached(["bash", "-c", deleteLocalScript]);

        window.isModelChanging = true;
        targetModel.remove(idx);
        if (targetModel !== localProxyModel) {
            for (let i = 0; i < localProxyModel.count; i++) {
                if (localProxyModel.get(i).fileName === fileName) {
                    localProxyModel.remove(i);
                    break;
                }
            }
        }
        if (targetModel === localProxyModel) {
            for (let i = 0; i < gifsProxyModel.count; i++) {
                if (gifsProxyModel.get(i).fileName === fileName) {
                    gifsProxyModel.remove(i);
                    break;
                }
            }
            for (let i = 0; i < videosProxyModel.count; i++) {
                if (videosProxyModel.get(i).fileName === fileName) {
                    videosProxyModel.remove(i);
                    break;
                }
            }
        }
        window.isModelChanging = false;

        if (idx >= targetModel.count) idx = Math.max(0, targetModel.count - 1);
        let nextTarget = "";
        if (targetModel.count > 0 && idx < targetModel.count) {
            let nextItem = targetModel.get(idx);
            if (nextItem && nextItem.fileName) nextTarget = String(nextItem.fileName);
        }
        window.targetWallName = nextTarget;
        window._pendingDeleteTarget = nextTarget;
        window._pendingDeleteIndex = idx;
        view.currentIndex = idx;

        let isCurrentActive = (window.activeWallpaperName === fileName || window.getCleanName(window.activeWallpaperName) === window.getCleanName(fileName));
        if (isCurrentActive && nextTarget !== "") {
            window.applyWallpaper(nextTarget, window.isVideoFile(nextTarget));
        }

        window.updateVisibleCount();
        window.statusToast = "Wallpaper deleted";
        toastTimer.restart();
    }

    Timer {
        id: centerOnActiveTimer
        interval: 35
        repeat: false
        onTriggered: window.centerActiveWallpaper()
    }

    function centerActiveWallpaper() {
        if (!window.visible) return;
        window.currentFilter = "All";
        let activeWall = window.activeWallpaperName !== "" ? window.activeWallpaperName : window.targetWallName;
        if (activeWall === "") {
            activeWallWatcher.reload();
            let p = (activeWallWatcher.text() || "").trim();
            if (p !== "") {
                window.activeWallpaperPath = p;
                activeWall = window.activeWallpaperName;
            }
        }
        if (activeWall === "") return;

        let cleanActive = window.getCleanName(activeWall);
        let foundIdx = -1;
        for (let i = 0; i < localProxyModel.count; i++) {
            let fn = localProxyModel.get(i).fileName || "";
            if (fn === activeWall || window.getCleanName(fn) === cleanActive) {
                foundIdx = i;
                break;
            }
        }
        if (foundIdx !== -1) {
            view.currentIndex = foundIdx;
            view.forceLayout();
            view.positionViewAtIndex(foundIdx, ListView.Center);
            window.initialFocusSet = true;
        }
    }

    function showWidget() {
        window.processMarkers();
        window.currentFilter = "All";
        activeWallWatcher.reload();
        let p = (activeWallWatcher.text() || "").trim();
        if (p !== "") window.activeWallpaperPath = p;
        let activeWall = window.activeWallpaperName !== "" ? window.activeWallpaperName : window.targetWallName;
        if (activeWall !== "") {
            window.targetWallName = activeWall;
        }
        window.applyFilters(true);
        view.forceActiveFocus();
        centerOnActiveTimer.restart();
    }


    onWidgetArgChanged: {
        if (widgetArg !== "") {
            targetWallName = widgetArg;
            initialFocusSet = false;
            tryFocus();
        }
    }

    function executeFocusRestore(targetIndex, isSearchRestore, requirePositioning) {
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (targetIndex !== -1 && targetIndex < targetModel.count) {
            window.isModelChanging = true;
            view.currentIndex = targetIndex;
            if (requirePositioning && window.visible && view.width > 0) {
                view.forceLayout();
                view.positionViewAtIndex(targetIndex, ListView.Center);
                window.initialFocusSet = true;
            } else if (!requirePositioning) {
                window.initialFocusSet = true;
            }
            if (isSearchRestore) {
                window.searchIndexRestored = true;
            }
            window.isModelChanging = false;
            allowAddAnimationTimer.restart();
        } else if (isSearchRestore) {
            window.searchIndexRestored = true;
        }
    }

    Timer {
        id: allowAddAnimationTimer
        interval: 600
        onTriggered: window.allowAddAnimation = true
    }

    function tryFocus() {
        if (initialFocusSet) return;
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (targetModel && targetModel.count > 0) {
            let foundIndex = -1;
            let cleanTarget = window.getCleanName(targetWallName);
            if (cleanTarget !== "") {
                for (let i = 0; i < targetModel.count; i++) {
                    let fname = targetModel.get(i).fileName || "";
                    if (window.getCleanName(fname) === cleanTarget) {
                        foundIndex = i;
                        break;
                    }
                }
            }
            let finalIndex = foundIndex !== -1 ? foundIndex : 0;
            window.executeFocusRestore(finalIndex, false, true);
        }
    }
    
    function trySearchFocus() {
        if (window.searchIndexRestored || searchProxyModel.count === 0) return;
        if (window.lastSearchName === "") {
             window.searchIndexRestored = true;
             return;
        }
        for (let i = 0; i < searchProxyModel.count; i++) {
            let fname = searchProxyModel.get(i).fileName || "";
            if (fname === window.lastSearchName) {
                window.executeFocusRestore(i, true, true);
                return;
            }
        }
        if (searchFolderModel.status === FolderListModel.Ready && searchProxyModel.count === searchFolderModel.count) {
             window.searchIndexRestored = true;
        }
    }

    function getCategoryColor(catName) {
        let name = String(catName).toLowerCase();
        switch (name) {
            case "gruvbox": return "#d79921";
            case "sakura": return "#f38ba8";
            case "nord": return "#88c0d0";
            case "ocean": return "#1e66f5";
            case "emerald": return "#50fa7b";
            case "sunset": return "#ffb86c";
            case "synthwave": return "#bd93f9";
            case "crimson": case "red": return "#e63946";
            case "violet": case "purple": return "#9d4edd";
            case "monochrome": case "slate": case "gray": return "#778899";
            case "dark": return "#1e1e2e";
            case "light": case "white": return "#f5f5f5";
            default: return _theme.primary;
        }
    }

    function getCategoryColors(catName) {
        let name = String(catName).toLowerCase();
        switch (name) {
            case "gruvbox": return { c1: "#d79921", c2: "#fabd2f" };
            case "sakura": return { c1: "#f38ba8", c2: "#ffb4c6" };
            case "nord": return { c1: "#88c0d0", c2: "#81a1c1" };
            case "ocean": return { c1: "#1e66f5", c2: "#74c7ec" };
            case "emerald": return { c1: "#50fa7b", c2: "#2ee6a8" };
            case "sunset": return { c1: "#ffb86c", c2: "#ff5555" };
            case "synthwave": return { c1: "#bd93f9", c2: "#ff79c6" };
            case "crimson": case "red": return { c1: "#e63946", c2: "#ff4d6d" };
            case "violet": case "purple": return { c1: "#9d4edd", c2: "#c77dff" };
            case "monochrome": case "slate": case "gray": return { c1: "#6c757d", c2: "#adb5bd" };
            case "dark": return { c1: "#1e1e2e", c2: "#45475a" };
            case "light": case "white": return { c1: "#ffffff", c2: "#cbd5e1" };
            default: return { c1: _theme.primary, c2: _theme.mauve };
        }
    }

    function getWallpaperCategory(fileName) {
        if (!fileName) return "";
        let fn = String(fileName);
        let clean = window.getCleanName(fn);
        let mapped = window.wallpaperCategoryMap[fn] || window.wallpaperCategoryMap[clean] || "";
        return mapped.toLowerCase();
    }

    property var categoryCountMap: ({})

    function updateCategoryCounts() {
        let counts = {};
        for (let i = 0; i < localProxyModel.count; i++) {
            let item = localProxyModel.get(i);
            if (item && item.fileName) {
                let cat = window.getWallpaperCategory(item.fileName);
                if (cat) {
                    counts[cat] = (counts[cat] || 0) + 1;
                }
            }
        }
        window.categoryCountMap = counts;
    }

    function getCategoryCount(catName) {
        let cat = String(catName).toLowerCase();
        if (cat === "all") return localProxyModel.count;
        if (cat === "gifs" || cat === "gif") return gifsProxyModel.count;
        if (cat === "videos" || cat === "video") return videosProxyModel.count;
        if (cat === "search") return 1;
        return window.categoryCountMap[cat] || 0;
    }

    function isFilterVisible(fName) {
        if (fName === "Search") return false;
        if (fName === "All" || fName === "GIFs" || fName === "Videos" || fName === "Video") return true;
        return window.getCategoryCount(fName) > 0;
    }

    function updateCategoryProxyModel() {
        let cat = String(window.currentFilter).toLowerCase();
        if (cat === "all" || cat === "gifs" || cat === "videos" || cat === "search") return;
        
        categoryProxyModel.clear();
        let batch = [];
        for (let i = 0; i < localProxyModel.count; i++) {
            let item = localProxyModel.get(i);
            if (item && item.fileName) {
                let itemCat = window.getWallpaperCategory(item.fileName);
                if (itemCat === cat) {
                    batch.push({ "fileName": item.fileName, "fileUrl": item.fileUrl });
                }
            }
        }
        if (batch.length > 0) {
            categoryProxyModel.append(batch);
        }
        window.sortListModel(categoryProxyModel);
    }

    function getModelForFilter(filter) {
        if (filter === "Search") return searchProxyModel;
        if (filter === "GIFs" || filter === "GIF") return gifsProxyModel;
        if (filter === "Videos" || filter === "Video") return videosProxyModel;
        if (filter === "All") return localProxyModel;
        return categoryProxyModel;
    }

    function updateVisibleCount() {
        let targetModel = window.getModelForFilter(window.currentFilter);
        window.visibleItemCount = targetModel ? targetModel.count : 0;
    }

    function triggerOnlineSearch() {
        if (searchInput.text.trim() === "") return;
        window.isModelChanging = true;
        searchProxyModel.clear();
        window.lastSearchName = "";
        searchState.lastName = "";
        if (window.currentFilter === "Search") {
            view.currentIndex = 0;
            view.positionViewAtIndex(0, ListView.Center);
        }
        window.isModelChanging = false;
        window.searchIndexRestored = true;
        window.isOnlineSearch = true;
        window.hasSearched = true;
        window.visibleItemCount = 0;
        searchState.searched = true;
        searchState.query = searchInput.text.trim();
        window.isSearchPaused = false;
        window.searchQuery = searchInput.text.trim();
        
        let rawSearchDir = decodeURIComponent(window.searchDir.replace(/^file:\/\//, ""));
        let scriptPath = decodeURIComponent(Qt.resolvedUrl("ddg_search.sh").toString().replace(/^file:\/\//, ""));
        
        const cmd = `
            exec > ${Caching.logDir}/ddg_run.log 2>&1
            echo 'stop' > ${Caching.getRunDir("wallpaper_picker")}/ddg_search_control
            for p in \$(pgrep -f ddg_search.sh); do
                if [ "\$p" != "\$\$" ] && [ "\$p" != "\$BASHPID" ]; then
                    kill -9 \$p 2>/dev/null || true
                fi
            done
            pkill -f "[g]et_ddg_links.py" || true
            sleep 0.2
            rm -rf "${rawSearchDir}"/* || true
            rm -f "${rawSearchDir}/../search_map.txt" || true
            echo 'run' > ${Caching.getRunDir("wallpaper_picker")}/ddg_search_control
            bash "${scriptPath}" "${window.searchQuery}" &
        `;
        Quickshell.execDetached(["bash", "-c", cmd]);
        searchInput.focus = false;
        view.forceActiveFocus();
    }

    readonly property string homeDir: "file://" + Quickshell.env("HOME")
    readonly property string searchDir: "file://" + Caching.getCacheDir("wallpaper_picker") + "/search_thumbs"
    readonly property string flatSrcDir: "file://" + Caching.getCacheDir("wallpaper_picker") + "/flat"
    readonly property string srcDir: {
        const dir = Quickshell.env("WALLPAPER_DIR")
        return (dir && dir !== "") ? dir : Quickshell.env("HOME") + "/Pictures/Wallpapers"
    }

    readonly property real itemWidth: window.s(400)
    readonly property real itemHeight: window.s(420)
    readonly property real borderWidth: window.s(3)
    readonly property real spacing: window.s(10)
    readonly property real skewFactor: -0.35
    readonly property real selectedCenterOffset: (window.skewFactor * (window.itemHeight)) / 2

    Timer { id: scrollThrottle; interval: 150 }

    property bool isFilterAnimating: false
    Timer {
        id: filterAnimationTimer
        interval: 300
        onTriggered: window.isFilterAnimating = false
    }

    property bool isItemAnimating: false
    Timer {
        id: itemAnimationTimer
        interval: 400
        onTriggered: window.isItemAnimating = false
    }

    function checkItemMatchesFilter(fileName, isVid, cv, filter) {
        if (filter === "Search") return true;
        if (filter === "All") return true;
        let fStr = String(fileName);
        if (filter === "Videos" || filter === "Video") {
            return isVid || window.isVideoFile(fStr);
        }
        if (filter === "GIFs" || filter === "GIF") {
            return fStr.toLowerCase().endsWith(".gif");
        }
        return true;
    }

    FolderListModel {
        id: srcModel
        folder: "file://" + window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF", "*.MP4", "*.MKV", "*.MOV", "*.WEBM"]
        showDirs: false
        onCountChanged: {
            if (window.isDownloadingWallpaper && window.isDownloaded(window.currentDownloadName)) {
                window.isDownloadingWallpaper = false;
                downloadTimeoutTimer.stop();
            }
        }
    }

    function stepToNextValidIndex(direction) {
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (!targetModel || targetModel.count === 0) return;
        
        let nextIndex = view.currentIndex + direction;
        if (nextIndex >= 0 && nextIndex < targetModel.count) {
            view.currentIndex = nextIndex;
        }
    }

    function cycleFilter(direction) {
        let visibleFilters = window.filterData.filter(f => window.isFilterVisible(f.name)).map(f => f.name);
        if (visibleFilters.length === 0) return;
        let currentIdx = visibleFilters.indexOf(window.currentFilter);
        if (currentIdx === -1) currentIdx = 0;
        let nextIdx = (currentIdx + direction + visibleFilters.length) % visibleFilters.length;
        window.currentFilter = visibleFilters[nextIdx];
    }

    function applyFilters(forceSnap) {
        if (!window.isFilterVisible(window.currentFilter) && window.currentFilter !== "Search") {
            window.currentFilter = "All";
        }
        if (window.currentFilter !== "Search" && window.currentFilter !== "GIFs" && window.currentFilter !== "Videos" && window.currentFilter !== "All") {
            window.updateCategoryProxyModel();
        }
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (!targetModel || targetModel.count === 0) {
            window.updateVisibleCount();
            return;
        }
        if (window.currentFilter === "Search") {
            window.updateVisibleCount();
            return;
        }

        let cleanTarget = window.getCleanName(window.targetWallName);
        let targetIndex = -1;

        if (cleanTarget !== "") {
            for (let i = 0; i < targetModel.count; i++) {
                let fname = targetModel.get(i).fileName || "";
                if (window.getCleanName(fname) === cleanTarget) {
                    targetIndex = i;
                    break;
                }
            }
        }

        let indexToFocus = 0;
        if (targetIndex !== -1) indexToFocus = targetIndex;
        else if (window.jumpToLastOnFilterChange && targetModel.count > 0) indexToFocus = targetModel.count - 1;

        window.jumpToLastOnFilterChange = false;
        window.executeFocusRestore(indexToFocus, false, forceSnap === true);
        window.updateVisibleCount();
    }

    Shortcut { 
        sequence: "Left"; 
        enabled: window.visible && !window.isApplying && !searchInput.activeFocus
        onActivated: window.stepToNextValidIndex(-1) 
    }
    Shortcut { 
        sequence: "Right"; 
        enabled: window.visible && !window.isApplying && !searchInput.activeFocus
        onActivated: window.stepToNextValidIndex(1) 
    }
    Shortcut { 
        sequence: "Return"
        enabled: !searchInput.activeFocus && !window.isApplying
        onActivated: { 
            let targetModel = window.getModelForFilter(window.currentFilter);
            if (view.currentIndex >= 0 && view.currentIndex < targetModel.count) {
                let fname = targetModel.get(view.currentIndex).fileName;
                if (fname) window.applyWallpaper(String(fname), window.isVideoFile(String(fname)));
            }
        } 
    }
    Shortcut { 
        sequence: "Delete"
        enabled: !searchInput.activeFocus && !window.isApplying && view.currentIndex >= 0
        onActivated: window.deleteCurrentWallpaper()
    }
    Shortcut { sequence: "Escape"; enabled: !window.isApplying && window.currentFilter === "Search"; onActivated: { if (window.currentFilter === "Search") { window.currentFilter = "All"; } } }
    Shortcut { sequence: "Tab"; enabled: !window.isApplying; onActivated: window.cycleFilter(1) }
    Shortcut { sequence: "Backtab"; enabled: !window.isApplying; onActivated: window.cycleFilter(-1) }

    ListModel { id: localProxyModel }
    ListModel { id: categoryProxyModel }
    ListModel { id: gifsProxyModel }
    ListModel { id: videosProxyModel }
    ListModel { id: searchProxyModel }
    readonly property var activeModel: window.getModelForFilter(window.currentFilter)

    FolderListModel {
        id: localFolderModel
        folder: window.flatSrcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF", "*.MP4", "*.MKV", "*.MOV", "*.WEBM"]
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: window.syncLocalModel()
        onStatusChanged: { if (status === FolderListModel.Ready) window.syncLocalModel() }
    }

    property bool _suppressSync: false
    property int _localSyncedCount: 0
    property string _pendingDeleteTarget: ""
    property int _pendingDeleteIndex: -1

    function syncLocalModel() {
        if (window._suppressSync) {
            window._suppressSync = false;
            return;
        }
        let folderCount = localFolderModel.count;
        let preservedTarget = window._pendingDeleteTarget || window.targetWallName || "";
        let fallbackIndex = window._pendingDeleteIndex !== -1 ? window._pendingDeleteIndex : view.currentIndex;
        window._pendingDeleteTarget = "";
        window._pendingDeleteIndex = -1;

        if (folderCount < window._localSyncedCount) {
            if (window.visible) {
                // Keep carousel stable while user is viewing; item was already removed from UI models
                window._localSyncedCount = folderCount;
                return;
            }
            let wasAllowing = window.allowAddAnimation;
            window.allowAddAnimation = false;
            window.isModelChanging = true;
            localProxyModel.clear();
            gifsProxyModel.clear();
            videosProxyModel.clear();
            window._localSyncedCount = 0;
            window.isModelChanging = false;
            window.syncLocalModel();
            if (wasAllowing) allowAddAnimationTimer.restart();
            return;
        }

        if (folderCount > window._localSyncedCount) {
            let batchAll = [];
            let batchGifs = [];
            let batchVids = [];
            for (let i = window._localSyncedCount; i < folderCount; i++) {
                let fn = localFolderModel.get(i, "fileName");
                let fu = localFolderModel.get(i, "fileUrl");
                if (fn !== undefined) {
                    let item = { "fileName": fn, "fileUrl": String(fu) };
                    batchAll.push(item);
                    let fnLower = String(fn).toLowerCase();
                    if (fnLower.endsWith(".gif")) {
                        batchGifs.push(item);
                    } else if (window.isVideoFile(fn)) {
                        batchVids.push(item);
                    }
                }
            }
            if (batchAll.length > 0) localProxyModel.append(batchAll);
            if (batchGifs.length > 0) gifsProxyModel.append(batchGifs);
            if (batchVids.length > 0) videosProxyModel.append(batchVids);
            window._localSyncedCount = folderCount;
            window.updateCategoryCounts();
        }

        let isReady = localFolderModel.status === FolderListModel.Ready;
        if (isReady && window._localSyncedCount > 0 && (!window.initialFocusSet || !window.visible)) {
            window.isModelChanging = true;
            window.sortListModel(localProxyModel);
            window.sortListModel(gifsProxyModel);
            window.sortListModel(videosProxyModel);
            window.isModelChanging = false;
        }

        if (window.currentFilter !== "Search") window.updateVisibleCount();
        
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (targetModel && targetModel.count > 0 && window.currentFilter !== "Search" && window.visible && view.width > 0) {
            let foundIndex = -1;
            if (preservedTarget !== "") {
                let cleanTarget = window.getCleanName(preservedTarget);
                for (let i = 0; i < targetModel.count; i++) {
                    let fn = targetModel.get(i).fileName || "";
                    if (fn === preservedTarget || window.getCleanName(fn) === cleanTarget) {
                        foundIndex = i;
                        break;
                    }
                }
            }
            let finalIndex = foundIndex !== -1 ? foundIndex : Math.min(Math.max(0, fallbackIndex), targetModel.count - 1);
            window.executeFocusRestore(finalIndex, false, true);
        }
        if (window.visible && !window.initialFocusSet) {
            centerOnActiveTimer.restart();
        }
    }


    function syncSearchModel() {
        let folderCount = searchFolderModel.count;
        if (folderCount === 0 && searchProxyModel.count > 0) {
            window.isModelChanging = true;
            searchProxyModel.clear();
            window.isModelChanging = false;
            window.updateVisibleCount();
            return;
        }

        let known = new Set();
        for (let i = 0; i < searchProxyModel.count; i++) {
            let item = searchProxyModel.get(i);
            if (item && item.fileName) {
                known.add(item.fileName);
            }
        }

        let batch = [];
        for (let i = 0; i < folderCount; i++) {
            let fn = searchFolderModel.get(i, "fileName");
            let fu = searchFolderModel.get(i, "fileUrl");
            if (fn !== undefined && !known.has(fn)) {
                batch.push({ "fileName": fn, "fileUrl": String(fu) });
                known.add(fn);
            }
        }
        if (batch.length > 0) {
            searchProxyModel.append(batch);
        }

        if (window.currentFilter === "Search") {
            window.updateVisibleCount();
            if (window.hasSearched && !window.searchIndexRestored) {
                window.trySearchFocus();
            }
        }
    }

    FolderListModel {
        id: searchFolderModel
        folder: window.searchDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF", "*.MP4", "*.MKV", "*.MOV", "*.WEBM"]
        showDirs: false
        sortField: FolderListModel.Name
        onFolderChanged: {
            window.isModelChanging = true;
            searchProxyModel.clear();
            window.isModelChanging = false;
        }
        onCountChanged: window.syncSearchModel()
        onStatusChanged: { if (status === FolderListModel.Ready) window.syncSearchModel() }
    }

    ListView {
        id: view
        anchors.fill: parent
        opacity: 1.0
        scale: 1.0

        spacing: 0
        orientation: ListView.Horizontal
        clip: false
        interactive: !window.isApplying
        reuseItems: false
        cacheBuffer: Math.round(window.itemWidth * 2)

        highlightRangeMode: window.initialFocusSet ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: Math.max(0, (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset)
        preferredHighlightEnd: Math.max(0, (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset)
        highlightMoveDuration: (window.initialFocusSet && !window.isFilterAnimating && !window.isModelChanging) ? 350 : 0
        focus: true
        
        onWidthChanged: {
            if (!window.initialFocusSet && width > 0 && window.visible) {
                centerOnActiveTimer.restart();
            }
        }
        
        onContentXChanged: {}
        
        onCurrentIndexChanged: {
            window.isItemAnimating = true;
            itemAnimationTimer.restart();
            if (!window.isModelChanging && currentIndex >= 0 && currentIndex < window.activeModel.count) {
                let item = window.activeModel.get(currentIndex);
                if (item && item.fileName) {
                    let fname = String(item.fileName);
                    window.targetWallName = fname;
                    if (window.currentFilter === "Search" && window.hasSearched && window.searchIndexRestored) {
                        window.lastSearchName = fname;
                        searchState.lastName = fname;
                    }
                }
            }
        }
        
        add: Transition {
            enabled: window.allowAddAnimation && !window.isModelChanging && !window.isFilterAnimating
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: 400; easing.type: Easing.OutBack }
            }
        }
        addDisplaced: Transition {
            enabled: window.allowAddAnimation && !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { property: "x"; duration: 400; easing.type: Easing.OutCubic }
        }

        header: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset) }
        footer: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2) - window.selectedCenterOffset) }

        model: window.activeModel

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (window.isApplying) {
                    wheel.accepted = true;
                    return;
                }
                let dx = wheel.angleDelta.x;
                let dy = wheel.angleDelta.y;
                let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
                if (delta === 0) {
                    wheel.accepted = true;
                    return;
                }
                let now = Date.now();
                let dt = now - window.lastWheelMs;
                let dir = delta > 0 ? 1 : -1;
                if (dt > 300 || dt < 0) {
                    window.scrollVelocity = 1;
                }
                if (window.scrollDirection !== 0 && dir !== window.scrollDirection) {
                    window.scrollVelocity = 1;
                    window.scrollAccum = 0;
                }
                if (dt > 0 && dt <= 180 && dir === window.scrollDirection) {
                    window.scrollVelocity = Math.min(3, window.scrollVelocity + 1);
                }
                window.scrollDirection = dir;
                window.lastWheelMs = now;

                if (window.scrollVelocity === 1 && scrollThrottle.running) {
                    wheel.accepted = true;
                    return;
                }

                window.scrollAccum += delta;
                if (Math.abs(window.scrollAccum) >= window.scrollThreshold) {
                    let steps = Math.abs(delta) >= 90 ? window.scrollVelocity : 1;
                    let targetModel = window.getModelForFilter(window.currentFilter);
                    if (targetModel && targetModel.count > 0) {
                        let stepDelta = (dir > 0 ? -steps : steps);
                        let nextIdx = Math.max(0, Math.min(targetModel.count - 1, view.currentIndex + stepDelta));
                        view.currentIndex = nextIdx;
                    }
                    window.scrollAccum = 0;
                    if (window.scrollVelocity === 1) {
                        scrollThrottle.start();
                    }
                }
                wheel.accepted = true;
            }        
        }

        delegate: Item {
            id: delegateRoot
            readonly property string safeFileName: fileName !== undefined ? String(fileName) : ""
            readonly property bool isCurrent: view.currentIndex === index
            readonly property bool isFakeSelected: false
            readonly property bool isVisuallyEnlarged: isCurrent
            readonly property bool isVideo: window.isVideoFile(safeFileName)
            readonly property bool matchesFilter: true
            readonly property real targetWidth: isVisuallyEnlarged ? (window.itemWidth * 1.5) : (window.itemWidth * 0.5)
            readonly property real targetHeight: isVisuallyEnlarged ? (window.itemHeight + window.s(30)) : window.itemHeight
            
            readonly property string thumbPath: {
                if (!safeFileName) return "";
                return window.currentFilter === "Search"
                    ? encodeURI(window.searchDir + "/" + safeFileName)
                    : encodeURI("file://" + Caching.getCacheDir("wallpaper_picker") + "/thumbs/" + (isVideo ? safeFileName + ".jpg" : safeFileName));
            }

            readonly property bool isValidItem: safeFileName !== "" && index >= 0 && index < window.activeModel.count
            width: isValidItem ? (targetWidth + window.spacing) : 0
            visible: isValidItem
            opacity: isVisuallyEnlarged ? 1.0 : 0.6
            scale: 1.0
            height: targetHeight
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.verticalCenterOffset: window.s(15)
            z: isVisuallyEnlarged ? 10 : 1
            
            Behavior on scale { enabled: window.initialFocusSet && !window.isModelChanging && !window.isFilterAnimating; NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
            Behavior on width { enabled: window.initialFocusSet && !window.isModelChanging && !window.isFilterAnimating; NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
            Behavior on height { enabled: window.initialFocusSet && !window.isModelChanging && !window.isFilterAnimating; NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
            Behavior on opacity { enabled: window.initialFocusSet && !window.isModelChanging && !window.isFilterAnimating; NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            Item {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -(window.skewFactor * height) / 2
                width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + window.spacing)) : 0

                height: parent.height

                transform: Matrix4x4 {
                    property real s: window.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
                
                MouseArea {
                    anchors.fill: parent
                    enabled: delegateRoot.matchesFilter && !window.isApplying
                    onClicked: {
                        view.currentIndex = index;
                        window.applyWallpaper(delegateRoot.safeFileName, delegateRoot.isVideo);
                    }
                }

                Image {
                    anchors.fill: parent
                    source: thumbPath
                    sourceSize: Qt.size(256, 256)
                    fillMode: Image.Stretch
                    asynchronous: true
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: window.borderWidth
                    Rectangle { anchors.fill: parent; color: _theme.base }
                    clip: true

                    Image {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: window.s(-50)
                        width: (window.itemWidth * 1.5) + ((window.itemHeight + window.s(30)) * Math.abs(window.skewFactor)) + window.s(50)
                        height: window.itemHeight + window.s(30)
                        fillMode: Image.PreserveAspectCrop
                        source: thumbPath
                        sourceSize: Qt.size(400, 400)
                        asynchronous: true

                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }

                }
            }
        }
    }

    Rectangle {
        id: filterBarBackground
        anchors.top: parent.top
        anchors.topMargin: window.isReady ? window.s(40) : window.s(-100)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.topMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(56)
        width: filterRow.width + window.s(24)
        radius: window.s(16)
        clip: true
        color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, Config.effectivePopupOpacity)
        border.color: Config.borderWidth > 0 ? Qt.rgba(255, 255, 255, Config.borderOpacity) : Qt.rgba(255, 255, 255, Config.glassSpecular)
        border.width: Math.max(1, Config.borderWidth)

        // Anti-bleed base layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, Config.antiBleedOpacity)
            z: -1
        }


        Row {
            id: filterRow
            anchors.centerIn: parent
            spacing: window.s(12)

            Rectangle {
                id: notifDrawer
                height: window.s(44)
                property real paddingLeft: window.showSpinner ? window.s(40) : window.s(16)
                property real targetWidth: window.showNotification ? Math.min(notifTextDrawer.implicitWidth + paddingLeft + window.s(20), window.s(300)) : 0
                width: targetWidth
                visible: width > 0.1
                radius: window.s(12)
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                color: window.showNotification ? Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, Config.effectiveCardOpacity > 0 ? Config.effectiveCardOpacity : 0.75) : "transparent"
                border.color: window.showNotification ? Qt.alpha(_theme.surface1, 0.4) : "transparent"
                border.width: Config.borderWidth

                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on border.color { ColorAnimation { duration: 400 } }

                Item {
                    visible: window.showSpinner
                    width: window.s(44)
                    height: window.s(44)
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: notifSpinner
                        width: window.s(14)
                        height: window.s(14)
                        anchors.centerIn: parent
                        property real scaleTrigger: window.s(1)
                        onScaleTriggerChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            var s = window.s;
                            ctx.reset();
                            ctx.lineWidth = s(2);
                            ctx.strokeStyle = Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.3);
                            ctx.beginPath();
                            ctx.arc(s(7), s(7), s(5), 0, Math.PI * 2);
                            ctx.stroke();
                            
                            ctx.strokeStyle = Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.9);
                            ctx.beginPath();
                            ctx.arc(s(7), s(7), s(5), 0, Math.PI * 0.5);
                            ctx.stroke();
                        }
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 800
                            running: window.showSpinner && window.showNotification
                        }
                    }
                }

                Text {
                    id: notifTextDrawer
                    anchors.left: parent.left
                    anchors.leftMargin: window.showSpinner ? window.s(40) : window.s(16)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, window.s(300) - anchors.leftMargin - window.s(16))
                    text: window.currentNotification
                    color: _theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(14)
                    font.bold: true
                    elide: Text.ElideRight
                    opacity: window.showNotification ? 0.9 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                }
            }

            Rectangle {
                id: monitorDrawer
                visible: monitorModel.count > 1
                height: window.s(44)
                property real expandedWidth: window.s(44) + monitorListRow.width + window.s(8)
                width: visible ? (window.isMonitorSelectorOpen ? expandedWidth : window.s(44)) : 0
                radius: window.s(12)
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                color: window.isMonitorSelectorOpen ? Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.85) : "transparent"
                border.color: window.isMonitorSelectorOpen ? _theme.text : Qt.alpha(_theme.surface1, 0.4)
                border.width: window.isMonitorSelectorOpen ? window.s(2) : Config.borderWidth
                
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on border.color { ColorAnimation { duration: 400 } }

                MouseArea {
                    id: monitorIconMouse
                    width: window.s(44)
                    height: window.s(44)
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    hoverEnabled: true
                    enabled: !window.isApplying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.isMonitorSelectorOpen = !window.isMonitorSelectorOpen
                }

                Canvas {
                    id: monitorIcon
                    width: window.s(18)
                    height: window.s(18)
                    anchors.centerIn: monitorIconMouse
                    property string activeColor: window.isMonitorSelectorOpen ? _theme.text : (monitorIconMouse.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7))
                    onActiveColorChanged: requestPaint()
                    property real scaleTrigger: window.s(1)
                    onScaleTriggerChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        var s = window.s;
                        ctx.reset();
                        ctx.lineWidth = s(2);
                        ctx.strokeStyle = activeColor;
                        ctx.lineJoin = "round";
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.rect(s(2), s(3), s(14), s(9));
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.moveTo(s(9), s(12));
                        ctx.lineTo(s(9), s(16));
                        ctx.moveTo(s(5), s(16));
                        ctx.lineTo(s(13), s(16));
                        ctx.stroke();
                    }
                }

                Row {
                    id: monitorListRow
                    anchors.left: monitorIconMouse.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: window.s(8)
                    opacity: window.isMonitorSelectorOpen ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Repeater {
                        model: monitorModel
                        delegate: Item {
                            width: monitorText.contentWidth + window.s(16)
                            height: window.s(32)
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: window.s(6)
                                color: model.selected ? _theme.text : _theme.surface1
                                border.color: model.selected ? _theme.text : _theme.surface2
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 250 } }
                                Behavior on border.color { ColorAnimation { duration: 250 } }
                                
                                Text {
                                    id: monitorText
                                    text: model.name
                                    anchors.centerIn: parent
                                    color: model.selected ? _theme.base : _theme.text
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(12)
                                    font.bold: model.selected
                                    Behavior on color { ColorAnimation { duration: 250 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: window.isMonitorSelectorOpen && !window.isApplying
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (model.selected) {
                                        let activeCount = 0;
                                        for (let i = 0; i < monitorModel.count; i++) {
                                            if (monitorModel.get(i).selected) activeCount++;
                                        }
                                        if (activeCount > 1) {
                                            monitorModel.setProperty(index, "selected", false);
                                        }
                                    } else {
                                        monitorModel.setProperty(index, "selected", true);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: window.filterData
                delegate: Item {
                    visible: window.isFilterVisible(modelData.name)
                    width: !visible ? 0 : window.s(44)
                    height: !visible ? 0 : window.s(36)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    readonly property bool isCategory: modelData.name !== "All" && modelData.name !== "GIFs" && modelData.name !== "Videos" && modelData.name !== "Video" && modelData.name !== "Search"
                    
                    Rectangle {
                        id: swatchCard
                        anchors.fill: parent
                        radius: window.s(10)
                        color: window.currentFilter === modelData.name ? Qt.rgba(_theme.primary.r, _theme.primary.g, _theme.primary.b, 0.28) : (filterMouse.containsMouse ? Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.40) : Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, Config.effectiveCardOpacity))
                        border.color: window.currentFilter === modelData.name ? _theme.primary : (filterMouse.containsMouse ? Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.25) : Qt.alpha(_theme.surface1, 0.3))
                        border.width: window.currentFilter === modelData.name ? window.s(2) : Config.borderWidth
                        property real popScale: 1.0
                        property real targetScale: filterMouse.pressed ? 0.90 : (window.currentFilter === modelData.name ? 1.08 : (filterMouse.containsMouse ? 1.04 : 1.0))
                        scale: targetScale * popScale
                        
                        SequentialAnimation {
                            id: swatchPopAnim
                            NumberAnimation { target: swatchCard; property: "popScale"; to: 1.25; duration: 110; easing.type: Easing.OutQuad }
                            NumberAnimation { target: swatchCard; property: "popScale"; to: 1.0; duration: 420; easing.type: Easing.OutQuint }
                        }
                        
                        Behavior on targetScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                        Behavior on color { ColorAnimation { duration: 250 } }

                        Rectangle {
                            id: categorySwatch
                            visible: isCategory
                            width: window.s(16)
                            height: window.s(16)
                            radius: window.s(8)
                            anchors.centerIn: parent
                            color: window.getCategoryColor(modelData.name)
                            border.color: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(1, 1, 1, 0.20)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Text {
                            visible: modelData.name === "GIFs" || modelData.name === "GIF"
                            text: "GIF"
                            anchors.centerIn: parent
                            color: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(12)
                            font.bold: true
                        }

                        Canvas {
                            visible: modelData.name === "Videos" || modelData.name === "Video"
                            width: window.s(14); height: window.s(16)
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: window.s(2)
                            property string activeColor: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            onActiveColorChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                var s = window.s;
                                ctx.reset();
                                ctx.fillStyle = activeColor;
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                ctx.lineTo(s(14), s(8));
                                ctx.lineTo(0, s(16));
                                ctx.closePath();
                                ctx.fill();
                            }
                        }

                        Canvas {
                            visible: modelData.name === "All"
                            width: window.s(14); height: window.s(14)
                            anchors.centerIn: parent
                            property string activeColor: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            onActiveColorChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                var s = window.s;
                                ctx.reset();
                                ctx.fillStyle = activeColor;
                                ctx.fillRect(0, 0, s(6), s(6));
                                ctx.fillRect(s(8), 0, s(6), s(6));
                                ctx.fillRect(0, s(8), s(6), s(6));
                                ctx.fillRect(s(8), s(8), s(6), s(6));
                            }
                        }
                    }

                    MouseArea {
                        id: filterMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !window.isApplying
                        onClicked: {
                            swatchPopAnim.restart();
                            window.currentFilter = modelData.name;
                        }
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Rectangle {
                id: searchControlBtn
                visible: window.currentFilter === "Search" && window.hasSearched
                width: visible ? window.s(44) : 0
                height: window.s(44)
                radius: window.s(10)
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                color: window.isSearchPaused ? _theme.surface2 : "transparent"
                border.color: window.isSearchPaused ? _theme.text : _theme.surface1
                border.width: window.isSearchPaused ? window.s(2) : 1
                
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
                
                MouseArea {
                    id: scMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !window.isApplying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.isSearchPaused = !window.isSearchPaused
                }
                
                Canvas {
                    width: window.s(44); height: window.s(44)
                    anchors.centerIn: parent
                    property bool paused: window.isSearchPaused
                    property string activeColor: paused ? _theme.text : (scMouse.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7))
                    onActiveColorChanged: requestPaint()
                    onPausedChanged: requestPaint()
                    property real scaleTrigger: window.s(1)
                    onScaleTriggerChanged: requestPaint()
                    
                    onPaint: {
                        var ctx = getContext("2d");
                        var s = window.s;
                        ctx.reset();
                        ctx.fillStyle = activeColor;
                        if (!paused) {
                            ctx.fillRect(s(15), s(14), s(4), s(16));
                            ctx.fillRect(s(25), s(14), s(4), s(16));
                        } else {
                            ctx.beginPath();
                            ctx.moveTo(s(16), s(12));
                            ctx.lineTo(s(32), s(22));
                            ctx.lineTo(s(16), s(32));
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }
            }

            Rectangle {
                id: searchBox
                height: window.s(44)
                width: window.currentFilter === "Search" ? window.s(360) : window.s(44)
                radius: window.s(12)
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                color: window.currentFilter === "Search" ? Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.90) : "transparent"
                border.color: window.currentFilter === "Search" ? _theme.text : Qt.alpha(_theme.surface1, 0.4)
                border.width: window.currentFilter === "Search" ? window.s(2) : Config.borderWidth
                
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on border.color { ColorAnimation { duration: 400 } }

                MouseArea {
                    id: searchMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !window.isApplying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (window.currentFilter !== "Search") {
                            window.currentFilter = "Search";
                        } else {
                            window.currentFilter = "All";
                        }
                    }
                }

                Canvas {
                    id: searchIcon
                    width: window.s(44)
                    height: window.s(44)
                    anchors.left: parent.left
                    anchors.leftMargin: window.currentFilter === "Search" ? window.s(5) : 0
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                    property string activeColor: window.currentFilter === "Search" ? _theme.text : (searchMouseArea.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7))
                    onActiveColorChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        var s = window.s;
                        ctx.reset();
                        ctx.lineWidth = s(3);
                        ctx.strokeStyle = activeColor;
                        ctx.beginPath();
                        ctx.arc(s(18), s(18), s(7), 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.moveTo(s(23), s(23));
                        ctx.lineTo(s(31), s(31));
                        ctx.stroke();
                    }
                }

                Text {
                    id: placeholderLabel
                    anchors.left: searchIcon.right
                    anchors.right: submitBtn.left
                    anchors.rightMargin: window.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Type something to search..."
                    color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.5)
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(14)
                    visible: window.currentFilter === "Search" && searchInput.text.length === 0 && !searchInput.activeFocus
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.right: submitBtn.left
                    anchors.rightMargin: window.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: window.currentFilter === "Search" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    color: _theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(15)
                    clip: true
                    
                    onTextEdited: {
                        window.hasSearched = false;
                        searchState.searched = false;
                    }
                    onAccepted: {
                        window.triggerOnlineSearch();
                        searchInput.focus = false;
                        view.forceActiveFocus();
                    }
                }

                Rectangle {
                    id: submitBtn
                    width: window.s(32)
                    height: window.s(32)
                    radius: window.s(8)
                    anchors.right: parent.right
                    anchors.rightMargin: window.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: window.currentFilter === "Search" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    color: submitMouseArea.containsMouse ? _theme.surface1 : "transparent"
                    border.color: submitMouseArea.containsMouse ? _theme.text : _theme.surface2
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 300 } }

                    MouseArea {
                        id: submitMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        enabled: !window.isApplying
                        onClicked: window.triggerOnlineSearch()
                    }

                    Canvas {
                        width: window.s(16)
                        height: window.s(16)
                        anchors.centerIn: parent
                        property string activeColor: submitMouseArea.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                        onActiveColorChanged: requestPaint()
                        property real scaleTrigger: window.s(1)
                        onScaleTriggerChanged: requestPaint()
                        
                        onPaint: {
                            var ctx = getContext("2d");
                            var s = window.s;
                            ctx.reset();
                            ctx.lineWidth = s(2);
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.strokeStyle = activeColor;
                            ctx.beginPath();
                            ctx.moveTo(s(2), s(8));
                            ctx.lineTo(s(14), s(8));
                            ctx.moveTo(s(9), s(3));
                            ctx.lineTo(s(14), s(8));
                            ctx.lineTo(s(9), s(13));
                            ctx.stroke();
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + decodeURIComponent(window.searchDir.replace("file://", "")) + "'; mkdir -p '" + Caching.getRunDir("wallpaper_picker") + "'; touch '" + Caching.getRunDir("wallpaper_picker") + "/picker_active'"]);
        window.loadMonitors();

        if (searchState.searched) {
            searchInput.text = searchState.query;
            window.searchQuery = searchState.query;
            window.hasSearched = true;
            window.lastSearchName = searchState.lastName;
            window.isSearchPaused = true;
        }

        view.forceActiveFocus();
        window.processMarkers();
        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/wallpaper_thumbnail.sh"]);
    }

    Component.onDestruction: {
        if (window.hasPendingOrganize) {
            Quickshell.execDetached(["bash", "-c", "rm -f '" + Caching.getRunDir("wallpaper_picker") + "/picker_active'; python3 ~/Pictures/Wallpapers/scripts/auto_organize.py &"]);
        } else {
            Quickshell.execDetached(["bash", "-c", "rm -f '" + Caching.getRunDir("wallpaper_picker") + "/picker_active'"]);
        }
        if (window.hasSearched) {
            searchState.query = searchInput.text;
            searchState.searched = window.hasSearched;
            searchState.lastName = window.lastSearchName;
            Quickshell.execDetached(["bash", "-c", "echo 'pause' > " + Caching.getRunDir("wallpaper_picker") + "/ddg_search_control"]);
        } else {
            Quickshell.execDetached(["bash", "-c", "echo 'stop' > " + Caching.getRunDir("wallpaper_picker") + "/ddg_search_control; for p in \$(pgrep -f ddg_search.sh); do if [ \"\$p\" != \"\$\$\" ] && [ \"\$p\" != \"\$BASHPID\" ]; then kill -9 \$p 2>/dev/null || true; fi; done; pkill -f '[g]et_ddg_links.py'"]);
        }
    }
}
