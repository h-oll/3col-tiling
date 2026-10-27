#!/usr/bin/env bash
# 3col-tiling.sh - Three-column window tiling for KDE Plasma 6
#
# Usage: 3col-tiling.sh <action>
#
# Actions:
#   next            — cycle through five base zones and unique splits
#   prev            — cycle backward through the five zones
#   <zone_number>   — select unique zone geometry 0 through 22
#   l, m, r, L, R and split names such as ll, mr, Lu, Rb
#   screen-next     — move the window to the same zone on the next screen
#   screen-prev     — move the window to the same zone on the previous screen
#
# Base zones, in cycle order: l, m, r, L (l+m), R (m+r).
# Split suffixes: l/r = left/right half; u/b = upper/bottom half.
# L-l and L-r are named aliases of l and m, so cycling avoids duplicates.
# The right column has portrait US Letter width-to-height ratio (17:22).
# The left and middle columns have equal widths. GAP is configurable.

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '2,47s/^# \?//p' "$0"
    exit 0
fi

ACTION="next"
TARGET_SCREEN=""
TARGET_WINDOW=""
GAP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --screen) TARGET_SCREEN="$2"; shift 2 ;;
        --window) TARGET_WINDOW="$2"; shift 2 ;;
        *) ACTION="$1"; shift ;;
    esac
done

KWINSCRIPT_NAME="three-column-tiling-$$"
KWINSCRIPT_FILE=$(mktemp /tmp/3col-tiling-XXXXXX.js)
trap 'rm -f "$KWINSCRIPT_FILE"' EXIT

cat > "$KWINSCRIPT_FILE" <<JSEOF
(function() {
    var gap = ${GAP};
    var action = "${ACTION}";
    var targetScreenName = "${TARGET_SCREEN}";
    var targetWindowId = "${TARGET_WINDOW}";

    // Prefer resolving the caller-supplied window UUID over whatever is
    // currently focused — an overlay may have taken focus in the meantime.
    var win = null;
    if (targetWindowId) {
        var list = (typeof workspace.windowList === 'function')
                   ? workspace.windowList() : (workspace.windows || []);
        for (var i = 0; i < list.length; i++) {
            if (String(list[i].internalId) === targetWindowId) {
                win = list[i];
                break;
            }
        }
    }
    if (!win) win = workspace.activeWindow;
    if (!win || win.specialWindow) return;

    function zonesForArea(area) {
        var ax = area.x, ay = area.y, W = area.width, H = area.height;
        var usableW = W - 2 * gap;
        var usableH = H - 2 * gap;
        var rightW = usableH * 17 / 22;
        var smallW = (usableW - 2 * gap - rightW) / 2;
        var leftX = ax + gap;
        var middleX = leftX + smallW + gap;
        var rightX = middleX + smallW + gap;
        var topY = ay + gap;
        var l = { x: leftX, y: topY, w: smallW, h: usableH };
        var m = { x: middleX, y: topY, w: smallW, h: usableH };
        var r = { x: rightX, y: topY, w: rightW, h: usableH };
        var L = { x: leftX, y: topY, w: 2 * smallW + gap, h: usableH };
        var R = { x: middleX, y: topY,
                  w: smallW + gap + rightW, h: usableH };

        function split(zone) {
            var halfW = zone.w / 2, halfH = zone.h / 2;
            return {
                l: { x: zone.x, y: zone.y, w: halfW, h: zone.h },
                r: { x: zone.x + halfW, y: zone.y, w: halfW, h: zone.h },
                u: { x: zone.x, y: zone.y, w: zone.w, h: halfH },
                b: { x: zone.x, y: zone.y + halfH, w: zone.w, h: halfH },
            };
        }

        var ls = split(l), ms = split(m), rs = split(r);
        var Ls = split(L), Rs = split(R);

        // Cycle through the five base zones first, then unique split geometries.
        // Ls.l and Ls.r duplicate l and m, so they are named aliases only.
        return [
            l, m, r, L, R,
            ls.l, ls.r, ls.u, ls.b,
            ms.l, ms.r, ms.u, ms.b,
            rs.l, rs.r, rs.u, rs.b,
            Ls.u, Ls.b,
            Rs.l, Rs.r, Rs.u, Rs.b,
        ];
    }

    // Detect which zone best matches the window geometry
    function detectZone(zones, fg) {
        var current = 0;
        var bestDist = Infinity;
        for (var i = 0; i < zones.length; i++) {
            var z = zones[i];
            var dist = Math.abs(fg.x - z.x) + Math.abs(fg.y - z.y)
                     + Math.abs(fg.width - z.w) + Math.abs(fg.height - z.h);
            if (dist < bestDist) {
                bestDist = dist;
                current = i;
            }
        }
        return current;
    }

    // Sort screens spatially: left-to-right, then top-to-bottom
    var screens = workspace.screens.slice().sort(function(a, b) {
        if (a.geometry.x !== b.geometry.x) return a.geometry.x - b.geometry.x;
        return a.geometry.y - b.geometry.y;
    });

    // Find current screen index
    var curScreenIdx = 0;
    for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === win.output.name) {
            curScreenIdx = i;
            break;
        }
    }

    // Determine which screen to tile on: --screen override or the window's current screen
    var tileOutput = win.output;
    if (targetScreenName) {
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === targetScreenName) {
                tileOutput = screens[i];
                break;
            }
        }
    }

    var curArea = workspace.clientArea(KWin.MaximizeArea, tileOutput, win.desktops[0]);
    var curZones = zonesForArea(curArea);
    var curZone = detectZone(curZones, win.frameGeometry);

    var targetZone = curZone;
    var targetZones = curZones;

    if (action === "screen-next" || action === "screen-prev") {
        var dir = (action === "screen-next") ? 1 : -1;
        var newIdx = (curScreenIdx + dir + screens.length) % screens.length;
        var targetScreen = screens[newIdx];
        var targetArea = workspace.clientArea(KWin.MaximizeArea, targetScreen, win.desktops[0]);
        targetZones = zonesForArea(targetArea);
    } else if (action === "next") {
        targetZone = (curZone + 1) % curZones.length;
    } else if (action === "prev") {
        targetZone = (curZone - 1 + curZones.length) % curZones.length;
    } else {
        var zoneNames = {
            'l': 0, 'm': 1, 'r': 2, 'L': 3, 'R': 4,
            'll': 5, 'lr': 6, 'lu': 7, 'lb': 8,
            'ml': 9, 'mr': 10, 'mu': 11, 'mb': 12,
            'rl': 13, 'rr': 14, 'ru': 15, 'rb': 16,
            'Ll': 0, 'Lr': 1, 'Lu': 17, 'Lb': 18,
            'Rl': 19, 'Rr': 20, 'Ru': 21, 'Rb': 22,
        };
        if (action in zoneNames) {
            targetZone = zoneNames[action];
        } else {
            targetZone = parseInt(action);
            if (isNaN(targetZone) || targetZone < 0 || targetZone >= curZones.length) return;
        }
    }

    var tg = targetZones[targetZone];
    // Clear any KDE tile so geometry can be set freely
    if (win.tile) win.tile = null;
    win.frameGeometry = {x: tg.x, y: tg.y, width: tg.w, height: tg.h};

    // Keep the window focused. Moving geometry onto another output does not
    // carry activation with it — KWin hands focus to whatever is next in the
    // focus chain on that output (and the closing overlay makes that
    // worse). Re-assert it explicitly.
    workspace.raiseWindow(win);
    workspace.activeWindow = win;
})();
JSEOF

# Load and run (unique plugin name per invocation; cleanup in EXIT trap)
KWINSCRIPT_ID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$KWINSCRIPT_FILE" "$KWINSCRIPT_NAME")
qdbus org.kde.KWin "/Scripting/Script${KWINSCRIPT_ID}" org.kde.kwin.Script.run
