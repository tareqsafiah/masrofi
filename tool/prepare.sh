#!/usr/bin/env bash
# يجهّز الخطوط والأيقونة قبل البناء
set -e
mkdir -p assets/fonts
BASE="https://raw.githubusercontent.com/notofonts/notofonts.github.io/main/fonts/NotoKufiArabic/hinted/ttf"
for w in Regular Medium SemiBold Bold ExtraBold Black; do
  f="assets/fonts/NotoKufiArabic-$w.ttf"
  [ -f "$f" ] || curl -fsSL -o "$f" "$BASE/NotoKufiArabic-$w.ttf"
done
if [ ! -f assets/icon.png ]; then
  python3 -m venv /tmp/venv
  /tmp/venv/bin/pip install -q pillow
  /tmp/venv/bin/python tool/make_icon.py
fi
