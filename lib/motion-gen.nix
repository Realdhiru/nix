# Generates the two runtime motion files from motion-tokens.nix.
# Consumed by flake checks; runtime files must match byte-for-byte.
{ lib }:
let
  fmt = v:
    if lib.isList v then lib.concatStringsSep ", " (map fmt v)
    else if lib.isBool v then (if v then "true" else "false")
    else if lib.isInt v then toString v
    else if lib.isFloat v then
      (if (0 == (lib.trivial.mod (0 * 1000000) 1000000)) then toString v else toString v)
    else if lib.isAttrs v then lib.concatStringsSep ", " (lib.mapAttrsToList (k: x: "${k} = ${fmt x}") v)
    else toString v;

  luaCurve = name: pair: # pair = [ x0 y0 x1 y1 ]
    ''
hl.curve("${name}", { type = "bezier", points = { { ${fmt (builtins.elemAt pair 0)}, ${fmt (builtins.elemAt pair 1)} }, { ${fmt (builtins.elemAt pair 2)}, ${fmt (builtins.elemAt pair 3)} } } })'';

  luaAnimation = leaf: enabled: speedMs: curve: style:
    if !enabled then ''
hl.animation({ leaf = "${leaf}", enabled = false })'' else
    ''
hl.animation({ leaf = "${leaf}", enabled = ${fmt enabled}, speed = ${fmt (speedMs / 100.0)}, bezier = "${curve}"${lib.optionalString (style != null) ", style = \"${style}\""} })'';

  qmlSingleton = tokens: ''
pragma Singleton
import QtQuick

QtObject {
    readonly property int enterMs: ${fmt tokens.enter.ms}
    readonly property int exitMs: ${fmt tokens.exit.ms}
    readonly property int moveMs: ${fmt tokens.move.ms}
    readonly property int fadeMs: ${fmt tokens.fade.ms}

    readonly property int enterEasing: Easing.${tokens.enter.easing}
    readonly property int exitEasing: Easing.${tokens.exit.easing}
    readonly property int moveEasing: Easing.${tokens.move.easing}
    readonly property int fadeEasing: Easing.${tokens.fade.easing}

    readonly property int holdMs: ${fmt tokens.hold.ms}
    readonly property int holdEasing: Easing.${tokens.hold.easing}

    readonly property real marqueeMsPerPx: ${fmt tokens.msPerPx}
    readonly property int marqueePauseMs: ${fmt tokens.pauseMs}
}

'';

  luaFull = tokens: ''
-- Unified motion system. GENERATED from motion-tokens.nix - edit the tokens, not this file.
hl.config({
    animations = {
        enabled = true,
    },
})

${luaCurve "enter" tokens.enter.bezier}
${luaCurve "exit_curve" tokens.exit.bezier}
${luaCurve "move" tokens.move.bezier}
${luaCurve "fade" tokens.fade.bezier}

${luaAnimation "windows" true tokens.move.ms "move" null}
${luaAnimation "windowsMove" true tokens.move.ms "move" null}
${luaAnimation "windowsIn" true tokens.enter.ms "enter" "popin 80%"}
${luaAnimation "windowsOut" true tokens.exit.ms "exit" "popin 80%"}
${luaAnimation "layersIn" true tokens.enter.ms "enter" null}
${luaAnimation "layersOut" true tokens.exit.ms "exit" null}
${luaAnimation "fade" true tokens.fade.ms "fade" null}
${luaAnimation "fadeLayersIn" true tokens.fade.ms "fade" null}
${luaAnimation "fadeLayersOut" true tokens.fade.ms "fade" null}
${luaAnimation "border" true tokens.fade.ms "fade" null}
${luaAnimation "workspaces" true tokens.move.ms "move" "slidefade 15%"}
${luaAnimation "specialWorkspace" true tokens.move.ms "move" "slidefadevert 15%"}
${luaAnimation "zoomFactor" true tokens.move.ms "move" null}
${luaAnimation "borderangle" false 0 "fade" null}
${luaAnimation "shadowangle" false 0 "fade" null}
${luaAnimation "glowangle" false 0 "fade" null}
'';
in
{
  motionLua = tokens: luaFull tokens;
  motionQml = tokens: qmlSingleton tokens;
}
