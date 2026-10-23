#!/bin/bash
# Render every scheme, the house and the floor diagram, then add numbered markers.
cd "$(dirname "$0")"
R=../renders/raw
mkdir -p $R
for f in scheme_a_cluster scheme_b_terraces scheme_c_courtyard scheme_d_retreat house floor; do
  echo "== $f"
  blender -b --python $f.py -- $R 2>&1 | grep -E "RENDERED|STATS|Error|Traceback|line [0-9]"
done
python3 annotate.py $R ../renders
