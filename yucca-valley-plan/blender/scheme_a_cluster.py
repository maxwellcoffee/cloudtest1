"""Scheme A -- Road-Front Cluster: everything within ~80 m of the gate, cheapest utilities and least grading."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sitekit as K
from pods import *

out, preview = K.args()
s = K.Site('A', out, preview)

# ---- Phase 1: move-in kit
s.road([(40, -3), (40, 31)], coll='phase1')
s.pad(40, 36, 14, 10, coll='phase1')                                  # parking / fire turnaround
s.capsule(P1, 24, 42, rot=0, coll='until3', phase=1, until=3)
s.container(CONTAINER, 58, 86, rot=0, coll='phase1', phase=1)
s.solar('Ground-mount solar + batteries', 62, 47, rows=2, cols=8, coll='phase1', phase=1)
s.tanks(TANKS, 62, 68, n=2, coll='phase1', phase=1)
s.well(WELL, 70, 59, coll='phase1', phase=1)

# ---- Phase 2: permitted house
s.house('Permitted house (640 sq ft)', 30, 60, rot=0, coll='phase2', phase=2)
s.septic('Septic leach field (or sewer lateral)', 10, 34, w=9, l=14, coll='phase2', phase=2)
s.beds('Kitchen garden + shade cloth', 46, 70, coll='phase2', phase=2)

# ---- Phase 3: grow
s.capsule(ADU, 24, 42, rot=0, coll='phase3', phase=3)
s.capsule(GUEST, 12, 62, rot=0, coll='phase3', phase=3)
s.capsule(STUDIO, 82, 50, rot=180, coll='phase3', phase=3)
s.path([(34, 41), (28, 47), (30, 53)])
s.path([(46, 52), (62, 56), (76, 52)])
s.path([(50, 74), (90, 78), (125, 82), (158, 80)])
s.ramada('Ramada / outdoor kitchen', 44, 58, coll='phase3', phase=3)
s.hot_tub('Ofuro soaking tub', 47, 49, coll='phase3', phase=3)
s.fire_pit(36, 76)
s.orchard('Orchard: pomegranate, fig, jujube, grapes, pistachio pair', 92, 26, nx=5, ny=4, sx=7, sy=7, coll='phase3', phase=3)
s.windbreak('Native windbreak: mesquite, desert willow, saltbush', [(6, 8), (6, 92)], coll='phase3', phase=3)
s.lookout('Sunset lookout: a bench on the rocks, no clearing', 160, 80, coll='phase3', phase=3)

s.gate('Gate + address post', 40, 1, coll='phase1', phase=1)
s.car(37, 35, rot=90, coll='phase1')
s.neighbor(-55, 60, rot=10)
s.neighbor(255, 25, rot=-5)
s.neighbor(95, -45, rot=0)
s.poles()

K.finish(s, defensible=[(30, 60, 30.5)])
