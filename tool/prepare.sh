#!/usr/bin/env bash
# يجهّز الخطوط والأيقونة قبل البناء
set -e
mkdir -p assets/fonts
for w in Regular Medium SemiBold Bold; do
  f="assets/fonts/IBMPlexSansArabic-$w.ttf"
  [ -f "$f" ] || curl -sSL -o "$f" "https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexsansarabic/IBMPlexSansArabic-$w.ttf"
done
if [ ! -f assets/icon.png ]; then
  python3 -m venv /tmp/venv
  /tmp/venv/bin/pip install -q pillow
  /tmp/venv/bin/python tool/make_icon.py
fi
