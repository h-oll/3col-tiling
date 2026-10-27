# 3col-tiling

A Bash script for placing the active window into a three-column layout on KDE Plasma 6. It runs a one-shot KWin script through D-Bus; it does not draw an overlay.

## Requirements

- KDE Plasma 6 with KWin and an active user D-Bus session
- Bash
- `qdbus` (provided by the Guix `qttools` package)
- `sed`, `cat`, and `mktemp`

## Layout

The script uses KWin's available tiling area, which excludes desktop panels. The right column has the portrait US Letter width-to-height ratio, 17:22. The left and middle columns have equal widths and fill the remaining space. `GAP=0` in the script controls the outer margins and spaces between columns.

The five full-height zones are:

| Name | Region |
| --- | --- |
| `l` | Left column |
| `m` | Middle column |
| `r` | Right column |
| `L` | Left + middle |
| `R` | Middle + right |

Each zone has four equal halves. The suffix `l` or `r` selects its left or right half; `u` or `b` selects its upper or bottom half. For example, `ll` and `lr` are the left and right halves of `l`; `Ru` and `Rb` are the upper and bottom halves of `R`.

`Ll` and `Lr` are aliases for `l` and `m`: splitting `L` left-to-right produces the same two rectangles. There are 25 names and 23 unique rectangles. `next` and `prev` cycle through the five full-height zones first, followed by the unique split rectangles. Numeric indices `0`–`22` select those unique rectangles in that cycle order.

## Usage

Run the script from a KDE Plasma session. It acts on the currently focused window.

```sh
./3col-tiling.sh l
./3col-tiling.sh mr
./3col-tiling.sh R
./3col-tiling.sh next
./3col-tiling.sh prev
./3col-tiling.sh --screen DP-1 Ru
./3col-tiling.sh screen-next
```

Use `--help` for the built-in action summary. On Guix, run it with `qttools` available so `qdbus` is on `PATH`:

```sh
guix shell qttools -- ./3col-tiling.sh l
```
