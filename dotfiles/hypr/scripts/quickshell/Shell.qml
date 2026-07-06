//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    Connections {
        target: Quickshell
        
        function onReloadCompleted() { 
            Quickshell.inhibitReloadPopup();
        }
        
        function onReloadFailed(errorString) { 
            Quickshell.inhibitReloadPopup();
            console.error("Quickshell Reload Failed: " + errorString);
        }
    }

    Main {}
    TopBar {}
    Floating {}
}