#!/bin/sh
# Render every spa scheme at full resolution (Blender 4.2, Cycles CPU), then annotate the plans.
# usage: blender/render_all.sh        (from the gazebo-spa folder)
set -e
cd "$(dirname "$0")"
RAW=../renders/raw
mkdir -p "$RAW"
for k in a_glasshouse b_jeongja c_octagon d_courtyard e_starter; do
  blender -b --python spa_$k.py -- "$RAW" > "$RAW/$k.log" 2>&1
  echo "rendered $k"
done
python3 post.py "$RAW" ../renders
