#!/bin/sh
# Labelled copies of mockup screenshots, run on the sandbox VM by /cas:mockup step 4.
#   sh label-shots.sh <draft-dir>
# <draft-dir>/labels.tsv holds one line per artboard: <stem><TAB><label>, e.g.
#   option-a-settings<TAB>Option A · Calm — Settings · draft 1
# For <stem>.png (and <stem>.mobile.png, when present) it writes labelled/<stem>[.mobile].html,
# a page with the label as a title strip above the screenshot, and screenshots it to
# labelled/<stem>[.mobile].png at the screenshot's own width. The raw screenshots are not changed.
set -eu

dir=${1:?usage: label-shots.sh <draft-dir>}
tsv="$dir/labels.tsv"
[ -r "$tsv" ] || { echo "label-shots: no $tsv" >&2; exit 2; }
mkdir -p "$dir/labelled"
tab=$(printf '\t')
fail=0

esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

# The PNG's width, from its IHDR chunk (bytes 16-19, big-endian).
png_width() {
  set -- $(od -An -tu1 -j16 -N4 "$1")
  echo $(( ($1 << 24) + ($2 << 16) + ($3 << 8) + $4 ))
}

while IFS="$tab" read -r stem label || [ -n "$stem" ]; do
  [ -n "$stem" ] || continue
  if ! printf '%s' "$stem" | grep -qE '^option-[abc](-[a-z0-9]+)*$'; then
    echo "label-shots: skipped bad stem: $stem" >&2; fail=1; continue
  fi
  found=0
  for shot in "$stem" "$stem.mobile"; do
    png="$dir/$shot.png"
    [ -f "$png" ] && [ ! -L "$png" ] || continue
    found=1
    text=$(esc "$label")
    [ "$shot" = "$stem" ] || text="$text · mobile"
    w=$(png_width "$png")
    cat > "$dir/labelled/$shot.html" <<EOF
<!doctype html>
<html><head><meta charset="utf-8"><title>$text</title></head>
<body style="margin:0;background:#fff">
<div style="box-sizing:border-box;width:${w}px;padding:12px 16px;background:#111;color:#fff;border-bottom:3px solid #fff;font:600 18px/1.35 system-ui,-apple-system,'Segoe UI',sans-serif">$text</div>
<img src="../$shot.png" alt="$text" style="display:block;width:${w}px">
</body></html>
EOF
    npx playwright screenshot --viewport-size="$w,600" --full-page \
      "file://$(cd "$dir/labelled" && pwd)/$shot.html" "$dir/labelled/$shot.png" >/dev/null
    echo "labelled/$shot.png"
  done
  [ "$found" = 1 ] || { echo "label-shots: no screenshot for $stem" >&2; fail=1; }
done < "$tsv"
exit "$fail"
