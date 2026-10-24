#!/bin/sh
# Render the three trailer setups and the lineup (Blender 4.2, Cycles CPU), then annotate the plans.
# usage: blender/render_all.sh        (from the rv-trailer folder)
set -e
cd "$(dirname "$0")"
RAW=../renders/raw
mkdir -p "$RAW"
for k in rv_lineup rv_a_lean rv_b_balanced rv_c_premium; do
  blender -b --python $k.py -- "$RAW" > "$RAW/$k.log" 2>&1
  echo "rendered $k"
done
python3 ../../gazebo-spa/blender/post.py "$RAW" ../renders
python3 lineup_post.py "$RAW" ../renders
