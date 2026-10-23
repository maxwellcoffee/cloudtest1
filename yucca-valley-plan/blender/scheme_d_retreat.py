"""Scheme D -- Scattered Retreat: a service hub at the gate, house on the west rise, pods spread out for privacy."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sitekit as K
from pods import *

out, preview = K.args()
s = K.Site('D', out, preview)

# ---- Phase 1: service hub at the gate, first pod up the lane
s.road([(112, -3), (112, 15)], coll='phase1')
s.pad(112, 20, 14, 10, coll='phase1')                                 # hub parking / turnaround
s.solar('Solar + batteries (service hub)', 126, 27, rows=2, cols=8, coll='phase1', phase=1)
s.tanks(TANKS + ' (service hub)', 88, 38, n=2, coll='phase1', phase=1)
s.well(WELL, 96, 28, coll='phase1', phase=1)
s.road([(112, 25), (100, 36), (84, 46)], width=3.7, coll='phase1')   # lane to pod #1
s.road([(84, 46), (86, 64)], width=3.7, coll='phase1')                # spur to the container
s.capsule(P1, 72, 50, rot=0, coll='until3', phase=1, until=3)
s.container(CONTAINER, 86, 70, rot=0, coll='phase1', phase=1)

# ---- Phase 2
s.road([(84, 46), (62, 58), (46, 64)], width=4.9, coll='phase2')     # drive extended to the house
s.house('Permitted house on the west rise', 34, 66, rot=0, coll='phase2', phase=2)
s.septic('Septic leach field (or sewer lateral)', 30, 46, w=12, l=8, coll='phase2', phase=2)
s.beds('Kitchen garden', 54, 76, n=3, coll='phase2', phase=2)

# ---- Phase 3: pods spread out, each with its own view
s.capsule(ADU, 72, 50, rot=0, coll='phase3', phase=3)
s.capsule(GUEST, 20, 33, rot=20, coll='phase3', phase=3)
s.capsule(STUDIO + ', east of the wash', 162, 50, rot=-15, coll='phase3', phase=3)
s.path([(108, 26), (132, 40), (156, 48)])
s.path([(30, 58), (24, 40)])
s.path([(166, 56), (172, 74)])
s.orchard('Orchard between the hub and the house', 60, 30, nx=5, ny=3, sx=7, sy=7, coll='phase3', phase=3)
s.windbreak('Native windbreak: mesquite, desert willow, saltbush', [(16, 52), (16, 82), (30, 92)], coll='phase3', phase=3)
s.ramada('Ramada', 50, 66, coll='phase3', phase=3, anchor=False)
s.hot_tub('Ofuro soaking tub by the windbreak', 24, 80, coll='phase3', phase=3)
s.lookout('Sunset lookout: a bench on the rocks, no clearing', 172, 77, coll='phase3', phase=3)
s.ramada('Meditation / yoga platform', 112, 78, w=5, l=5, coll='phase3', phase=3)

s.gate('Gate + address post', 112, 1, coll='phase1', phase=1)
s.car(108, 20, rot=90, coll='phase1')
s.neighbor(-55, 60, rot=10)
s.neighbor(255, 25, rot=-5)
s.neighbor(95, -45, rot=0)
s.poles()

K.finish(s, defensible=[(34, 66, 30.5)])
