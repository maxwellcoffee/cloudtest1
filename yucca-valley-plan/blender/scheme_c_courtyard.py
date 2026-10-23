"""Scheme C -- Courtyard Compound: house and pods wrap a wind-sheltered courtyard on one mid-slope bench."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sitekit as K
from pods import *

out, preview = K.args()
s = K.Site('C', out, preview)

# ---- Phase 1
s.road([(60, -3), (60, 27)], coll='phase1')
s.pad(60, 32, 14, 10, coll='phase1')                                  # parking / turnaround
s.pad(58, 50, 30, 14, coll='phase1', surface='pad')                   # shared courtyard bench
s.capsule(P1, 38, 52, rot=90, coll='until3', phase=1, until=3)
s.container(CONTAINER + ' / west wind wall', 26, 66, rot=90, coll='phase1', phase=1)
s.solar('Ground-mount solar + batteries', 96, 44, rows=2, cols=8, coll='phase1', phase=1)
s.tanks('Water tanks uphill (gravity pressure)', 72, 84, n=2, coll='phase1', phase=1)
s.well(WELL, 86, 74, coll='phase1', phase=1)

# ---- Phase 2
s.house('Permitted house closes the north side', 58, 68, rot=0, coll='phase2', phase=2)
s.septic('Septic leach field (or sewer lateral)', 34, 19, w=12, l=8, coll='phase2', phase=2)
s.beds('Courtyard kitchen garden', 69, 49, n=3, coll='phase2', phase=2)

# ---- Phase 3
s.capsule(ADU, 38, 52, rot=90, coll='phase3', phase=3)
s.capsule(GUEST, 78, 52, rot=270, coll='phase3', phase=3)
s.capsule(STUDIO, 36, 37, rot=0, coll='phase3', phase=3)
s.ramada('Ramada / outdoor kitchen + long table', 51, 53, w=6, l=4.5, coll='phase3', phase=3)
s.hot_tub('Ofuro soaking tub', 45, 46, coll='phase3', phase=3)
s.fire_pit(60, 46)
s.windbreak('Native windbreak: mesquite, desert willow, saltbush', [(15, 28), (15, 70), (28, 86), (40, 92)], coll='phase3', phase=3)
s.orchard('Orchard near the road (easy water + access)', 95, 21, nx=5, ny=3, sx=7, sy=7, coll='phase3', phase=3)
s.path([(60, 37), (58, 43)])
s.path([(84, 50), (92, 44)])
s.path([(66, 74), (72, 81)])
s.path([(74, 58), (100, 70), (126, 80), (158, 80)])
s.lookout('Sunset lookout: a bench on the rocks, no clearing', 160, 80, coll='phase3', phase=3)

s.gate('Gate + address post', 60, 1, coll='phase1', phase=1)
s.car(56, 32, rot=90, coll='phase1')
s.neighbor(-55, 60, rot=10)
s.neighbor(255, 25, rot=-5)
s.neighbor(95, -45, rot=0)
s.poles()

K.finish(s, defensible=[(58, 68, 30.5)])
