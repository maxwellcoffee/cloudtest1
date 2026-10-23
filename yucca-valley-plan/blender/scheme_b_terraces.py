"""Scheme B -- Hilltop Terraces: house on the high ground for the long views south, pods stepping down the slope."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sitekit as K
from pods import *

out, preview = K.args()
s = K.Site('B', out, preview)

# ---- Phase 1: long climbing drive, first pod mid-slope, solar by the road
s.road([(80, -3), (80, 20), (73, 38), (74, 56), (78, 69)], coll='phase1')
s.pad(78, 74, 12, 9, coll='phase1')                                   # parking + fire turnaround at the top
s.container(CONTAINER, 95, 92, rot=0, coll='phase1', phase=1)
s.solar('Ground-mount solar + batteries (long cable run)', 116, 22, rows=2, cols=8, coll='phase1', phase=1)
s.capsule(P1, 100, 50, rot=0, coll='until3', phase=1, until=3)
s.tanks('Water tanks on the high point (gravity pressure)', 30, 90, n=2, coll='phase1', phase=1)
s.well(WELL, 18, 96, coll='phase1', phase=1)

# ---- Phase 2: hilltop house
s.house('Permitted house on the view terrace', 60, 84, rot=0, coll='phase2', phase=2)
s.septic('Septic leach field below the house (or sewer)', 40, 58, w=9, l=12, coll='phase2', phase=2)
s.beds('Kitchen garden', 64, 70, n=3, coll='phase2', phase=2)

# ---- Phase 3: terraces, pods, trail
for k, yy in enumerate((30, 37.5, 45)):
    s.pad(44, yy, 40, 5.5, coll='phase3', surface=None)               # contour terraces (benches)
s.capsule(ADU, 100, 50, rot=0, coll='phase3', phase=3)
s.capsule(GUEST, 22, 66, rot=0, coll='phase3', phase=3)
s.capsule(STUDIO, 112, 72, rot=180, coll='phase3', phase=3)
s.path([(78, 70), (92, 60), (100, 54)])
s.path([(104, 54), (110, 66)])
s.path([(52, 86), (34, 89)])
s.path([(52, 80), (30, 68)])
s.path([(32, 62), (36, 49)])
s.path([(106, 52), (128, 62), (150, 80)])
s.orchard('Orchard on contour terraces', 44, 37.5, nx=6, ny=3, sx=7, sy=7.5, coll='phase3', phase=3)
s.windbreak('Native windbreak: mesquite, desert willow, saltbush', [(6, 52), (6, 90)], coll='phase3', phase=3)
s.ramada('Shade ramada + outdoor kitchen', 44, 92, coll='phase3', phase=3)
s.hot_tub('Ofuro soaking tub on the view deck', 40, 84, coll='phase3', phase=3)
s.fire_pit(70, 62)
s.lookout('Lookout across the wash: a bench, no clearing', 150, 80, coll='phase3', phase=3)

s.gate('Gate + address post', 80, 1, coll='phase1', phase=1)
s.car(76, 74, rot=90, coll='phase1')
s.neighbor(-55, 60, rot=10)
s.neighbor(255, 25, rot=-5)
s.neighbor(95, -45, rot=0)
s.poles()

K.finish(s, defensible=[(60, 84, 30.5)])
