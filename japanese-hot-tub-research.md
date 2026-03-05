# Japanese Wood Hot Tub Research Project - Agent Coordination

## Agent Roster & Specialties

| Agent # | Specialty | Focus Area |
|---------|-----------|------------|
| 1 | **Tub Design & Construction** | Japanese ofuro designs, dimensions for 2-person and 4-person, wood joinery |
| 2 | **Wood & Materials Sourcing** | Best wood species, lumber costs, hardware, sealants |
| 3 | **Labor & Contracting** | Hiring a high school student, labor laws, pay rates, contracts |
| 4 | **Heating Systems** | Smallest possible heating devices, energy costs, wood-fired vs electric |
| 5 | **Salt Water Chemistry** | Salt-only water treatment, no chlorine, salt types, concentrations |
| 6 | **Water Management & Delivery** | Fresh water delivery services, frequency, costs, dumping schedules |
| 7 | **Maintenance Planning** | Short/medium/long-term maintenance under different scenarios |
| 8 | **Budget Analysis** | Total project budget breakdown, ongoing costs |
| 9 | **Timeline & Project Management** | Super fast / fast / medium build scenarios |
| 10 | **Scaling: 2-Person to 4-Person** | Added complexity, cost, and maintenance for 4-person variant |

---

## Loop Tracking

### Loop 1 - Initial Research
- **Status**: COMPLETE
- **Objective**: Each agent conducts independent research on their specialty
- **Results**: All 10 agents completed initial research

### Loop 2 - Cross-Pollination
- **Status**: COMPLETE
- **Objective**: Agents review Loop 1 findings and refine with cross-agent context
- **Results**: All 10 agents completed cross-pollination refinements

### Loop 3 - Integration
- **Status**: COMPLETE
- **Objective**: Agents integrate findings, resolve conflicts, align numbers
- **Results**: 3 integration agents resolved all cross-agent conflicts

### Loop 4 - Optimization
- **Status**: PENDING
- **Objective**: Agents optimize recommendations, find cost savings, refine timelines

### Loop 5 - Final Synthesis
- **Status**: PENDING
- **Objective**: Final consolidated recommendations with complete budget and timeline

---

## Findings by Loop

(Results will be appended below as each loop completes)

---

### Agent 8 - Budget Analysis (Loop 1 Findings)

**File:** `agent-8-budget-analysis.md`

**Key Findings:**

1. **2-Person Construction Cost (self-build, cedar):** $1,264 (low) / $2,510 (mid) / $4,521 (high)
2. **4-Person Construction Cost (self-build, cedar):** $1,760 (low) / $3,350 (mid) / $5,640 (high)
3. **Monthly operating cost is $30-75/mo** across all three sanitization scenarios -- heating energy dominates, not water or chemicals
4. **Annual cost of ownership (years 2+):** ~$530/yr (2-person) / ~$855/yr (4-person) including maintenance reserve
5. **Recommended Year 1 budget with contingency:** $3,235 (2-person) / $4,450 (4-person)
6. **Absolute minimum viable build:** ~$315-445 (spartan, 120V heater, no pump, frequent drains)
7. **Biggest cost-saving levers:** Borrow tools ($100-500 saved), buy rough-sawn from mill ($100-300), skip UV/ozone ($100-250)
8. **4-person costs ~33-39% more to build** than 2-person, not double
9. **Insulated cover is the single best operating-cost investment** -- reduces heating energy significantly
10. **Budget for a licensed electrician ($150-400)** for the 240V heater circuit -- non-negotiable safety item

---

## Agent 9: Timeline & Project Management - Loop 1 Research

### OVERVIEW

Three build scenarios for a Japanese wooden hot tub (ofuro), built by a high school
student with adult guidance. All timelines assume a 2-person tub as baseline, with
notes on added time for a 4-person variant.

**Key Assumptions Across All Scenarios:**
- Adult mentor available for guidance and supervision on critical steps
- Basic shop available (table saw or track saw, planer, clamps, drill)
- Build location has weather cover or is indoors (garage/shop)
- Student has basic comfort with hand/power tools (or will learn)

**Tub Specifications (2-Person Baseline):**
- ~36" diameter x 24-27" tall, ~60 staves
- Stave-and-hoop (cooperage) construction with flat bottom panel
- 3 steel or stainless steel bands/hoops
- Single drain fitting, heater/pump connection

**4-Person Variant Adds:**
- ~48" diameter, ~80 staves — roughly 30-40% more wood prep and assembly time
- Larger/stronger bands, heavier bottom panel
- Add approximately 25-35% to wood prep and assembly phases

---

### CRITICAL PATH ANALYSIS

The critical path (longest chain of dependent tasks) runs:

```
Design Finalized → Lumber Ordered → Lumber Delivered → Milling/Planing
→ Stave Cutting & Shaping → Bottom Panel Assembly → Stave Assembly
→ Band Fitting → Drain Install → Fill & Swell Test → Final Install
```

**Items that CAN overlap with the critical path:**
- Site/foundation prep (Phase 7) — can happen anytime before final install
- Hardware ordering (bands, drain, heater) — order during Phase 1-2
- Plumbing/heater procurement — order early, install after tub is built
- Sealant/finish application — can happen during assembly downtime

**Items that CANNOT be parallelized:**
- Lumber must arrive before milling
- Staves must be milled before assembly
- Bottom must be assembled before staves go up
- Bands must be fitted before water testing
- Tub must hold water before plumbing connections are finalized

---

### MATERIAL LEAD TIMES (Critical Planning Input)

| Item | Lead Time | Notes |
|------|-----------|-------|
| Hinoki/Port Orford Cedar (specialty) | 2-4 weeks | Order from specialty mill; may need longer |
| Western Red Cedar (common) | 1-2 weeks | Available at many lumber yards; may find locally |
| Pre-cut stave kit (if available) | 2-4 weeks | Specialty order from cooperage/tub suppliers |
| CNC-cut stave kit (custom order) | 2-3 weeks | If you find a CNC shop willing to cut |
| Stainless steel bands (custom) | 1-3 weeks | Fabrication shop or online supplier |
| Adjustable hose clamp bands (off-shelf) | 2-5 days | Amazon/hardware store; less authentic |
| Drain fitting (brass or SS) | 2-5 days | Standard plumbing supply |
| Electric heater + pump | 1-2 weeks | Online order typical |
| Wood-fired heater (snorkel/submersible) | 2-4 weeks | Specialty item, fewer suppliers |
| Food-grade sealant / tung oil | 2-5 days | Online or hardware store |

---

### WEATHER & SEASON CONSIDERATIONS

- **Ideal build temps:** 50-80 deg F (glue cures properly, comfortable to work)
- **Avoid:** Extreme cold (<35 deg F) for glue-ups; extreme heat for extended outdoor work
- **Rain:** Indoor/covered build space eliminates weather as a factor
- **Water testing:** Can be done in any season, but freezing temps risk cracking a filled tub
- **Outdoor final placement:** Foundation/pad work best in dry, above-freezing conditions

---

## ═══════════════════════════════════════════════════════════════
## SCENARIO A: SUPER FAST (2-3 Weeks)
## ═══════════════════════════════════════════════════════════════

**Profile:** Pre-cut or CNC-cut stave kit, 15-20 hrs/week, aggressive schedule
**Total estimated hours:** 45-55 hours (2-person) / 55-70 hours (4-person)

### Prerequisites (Done BEFORE Week 1 clock starts):
- Design finalized and stave kit ordered 2-3 weeks prior
- All hardware (bands, drain, heater, pump) ordered and in-hand
- Site prep completed or nearly done
- Full tool set confirmed and ready

### Week-by-Week Gantt Chart

```
SUPER FAST SCENARIO — 2-Person Tub (3 Weeks)
═══════════════════════════════════════════════════════════════════

Phase / Task                  Wk1          Wk2          Wk3
                           MTWTFSS      MTWTFSS      MTWTFSS
─────────────────────────────────────────────────────────────────
P1: Design & Planning
  Finalize plans           [DONE PRE-START]
  Order materials          [DONE PRE-START]

P2: Materials Procurement
  Receive stave kit        ██░░░░░  (arrive Mon-Wed)
  Receive hardware/bands   ██░░░░░  (arrive early week)
  Receive heater/pump      ██░░░░░  (arrive early week)

P3: Wood Preparation
  Inspect & sort staves    ░░██░░░
  Light sanding/fitting    ░░███░░
  Cut bottom panel boards  ░░░░███
  Plane/joint bottom pcs   ░░░░███

P4: Assembly
  Glue up bottom panel     ░░░░░░░  ███░░░░
  Trim bottom to circle    ░░░░░░░  ░███░░░
  Cut dado/groove in staves░░░░░░░  ░░███░░
  Dry-fit staves around    ░░░░░░░  ░░░████
    bottom
  Fit & tighten bands      ░░░░░░░  ░░░░░██  █░░░░░░
  Final band tensioning    ░░░░░░░  ░░░░░░░  ██░░░░░

P5: Plumbing & Heating
  Install drain fitting    ░░░░░░░  ░░░░░░░  ░██░░░░
  Connect heater/pump      ░░░░░░░  ░░░░░░░  ░░██░░░

P6: Testing & Sealing
  First fill — check leaks ░░░░░░░  ░░░░░░░  ░░░██░░
  Let wood swell (24-48hr) ░░░░░░░  ░░░░░░░  ░░░░██░
  Drain, inspect, re-tightn░░░░░░░  ░░░░░░░  ░░░░░█░

P7: Site Preparation
  Foundation/pad work       ███████  ███░░░░  (overlap!)

P8: Final Installation
  Move tub to final site   ░░░░░░░  ░░░░░░░  ░░░░░██
  Final connections        ░░░░░░░  ░░░░░░░  ░░░░░░█
  FIRST SOAK!              ░░░░░░░  ░░░░░░░  ░░░░░░█
─────────────────────────────────────────────────────────────────
Hours/week target:          ~18 hrs     ~20 hrs     ~15 hrs

█ = active work on this task
░ = not active this day
```

### Super Fast: Key Risks & Mitigations
1. **Stave kit delayed** → Entire schedule shifts. Mitigation: confirm shipping before starting clock.
2. **Bottom panel glue-up needs 24hr cure** → Cannot rush. Plan overnight cure Fri→Sat.
3. **Band fitting is fiddly** → Budget extra time; this is where first-timers get stuck.
4. **Leaks on first fill** → Normal. Budget 1-2 days for swell. Most leaks self-seal in 24-48 hrs.
5. **Student fatigue at 15-20 hrs/week** → Spread across evenings (2-3 hrs) + weekends (6-8 hrs/day).

### Super Fast: 4-Person Adjustment
- Add 0.5 to 1 full week → **3-4 weeks total**
- More staves to inspect, sort, fit (~80 vs ~60)
- Bottom panel is larger and heavier — may need extra hands for glue-up
- Bands are larger diameter — potentially harder to source quickly

---

## ═══════════════════════════════════════════════════════════════
## SCENARIO B: FAST (4-6 Weeks)
## ═══════════════════════════════════════════════════════════════

**Profile:** Rough lumber purchased, student works 8-12 hrs/week (weekends)
**Total estimated hours:** 55-70 hours (2-person) / 70-90 hours (4-person)

### Week-by-Week Gantt Chart

```
FAST SCENARIO — 2-Person Tub (6 Weeks)
═══════════════════════════════════════════════════════════════════════════════

Phase / Task              Wk1    Wk2    Wk3    Wk4    Wk5    Wk6
                          S  S   S  S   S  S   S  S   S  S   S  S
                          a  u   a  u   a  u   a  u   a  u   a  u
                          t  n   t  n   t  n   t  n   t  n   t  n
──────────────────────────────────────────────────────────────────────────────
P1: Design & Planning
  Finalize dimensions      ██
  Create cut list          ██
  Order lumber             ░█

P2: Materials Procurement
  WAIT for lumber delivery ░░    ██    ░░
  (1-2 week lead time)          ^^arrive
  Order bands/hardware     ░█    ░░
  Receive bands/hardware   ░░    ░█    ░░

P3: Wood Preparation
  Joint & plane rough lmbr ░░    ░░    ██    ██
  Rip staves to width      ░░    ░░    ░█    ██
  Cut staves to length     ░░    ░░    ░░    ░█
  Shape stave edges (bevel)░░    ░░    ░░    ██    █░
  Cut bottom panel boards  ░░    ░░    ░░    ░█    █░
  Plane bottom pieces      ░░    ░░    ░░    ░░    █░

P4: Assembly
  Glue bottom panel        ░░    ░░    ░░    ░░    █░
  (overnight cure)                                 ↕
  Trim bottom to circle    ░░    ░░    ░░    ░░    ░█
  Cut dado groove in staves░░    ░░    ░░    ░░    ░█
  Dry-fit staves on bottom ░░    ░░    ░░    ░░    ░█    █░
  Install bands & tighten  ░░    ░░    ░░    ░░    ░░    ██
  Sand interior            ░░    ░░    ░░    ░░    ░░    █░

P5: Plumbing & Heating
  Order heater/pump        ░█    ░░    (arrives wk 3-4)
  Install drain fitting    ░░    ░░    ░░    ░░    ░░    ░█
  Connect heater/pump      ░░    ░░    ░░    ░░    ░░    ░█

P6: Testing & Sealing
  First fill & leak check  ░░    ░░    ░░    ░░    ░░    ░█
  Swell period (2-3 days)  ░░    ░░    ░░    ░░    ░░    ░█→
  Re-tighten bands         ░░    ░░    ░░    ░░    ░░    ░░→

P7: Site Preparation
  Build foundation/pad     ░░    ░░    ██    ██    ░░    ░░
  (overlaps with wood prep)

P8: Final Installation
  Move & connect           ░░    ░░    ░░    ░░    ░░    ░█
  FIRST SOAK!              ░░    ░░    ░░    ░░    ░░    ░█
──────────────────────────────────────────────────────────────────────────────
Hours/week:               ~6     ~4*   ~10    ~12    ~12    ~10
                          *waiting for lumber

█ = active work (Sat and/or Sun, ~4-6 hrs each day)
░ = no work this weekend day
→ = extends into following week (water swell period)
```

### Fast: Phase Overlap Strategy
- **Wk 1:** Design + order everything (lumber, hardware, heater). Light work day.
- **Wk 2:** Mostly waiting for deliveries. Good week to prep site/foundation.
- **Wk 3-4:** Heavy wood prep. This is the most labor-intensive phase.
- **Wk 5:** Assembly begins. Exciting — tub takes shape.
- **Wk 6:** Finish assembly, plumbing, test. Target first soak end of Wk 6.

### Fast: Key Risks & Mitigations
1. **Rough lumber needs significant milling** → This is the biggest time sink. If student is learning to plane/joint, add 1 week buffer.
2. **Lumber delivery late** → 2-week lead time is common. Order Day 1. If delayed, Wk 2-3 are dead time.
3. **Stave shaping is precision work** → Beveling ~60 staves to form a tight circle takes patience. Budget generously.
4. **Glue-up timing** → Bottom panel glue needs 24hr cure minimum. Plan Saturday glue, Sunday trim.
5. **Band sourcing** → Custom SS bands may take 2-3 weeks. Order in Week 1 with lumber.

### Fast: 4-Person Adjustment
- Add 1.5 to 2 weeks → **6-8 weeks total**
- Wood prep phase extends significantly (more staves to mill, bevel, fit)
- Assembly is more complex with larger diameter
- May need helper for lifting/positioning larger bottom panel

---

## ═══════════════════════════════════════════════════════════════
## SCENARIO C: MEDIUM / LEARNING PACE (8-12 Weeks)
## ═══════════════════════════════════════════════════════════════

**Profile:** Student learning as they go, 4-8 hrs/week, no rush
**Total estimated hours:** 60-85 hours (2-person) / 80-110 hours (4-person)
(More total hours due to learning curve, re-dos, and careful pace)

### Week-by-Week Gantt Chart

```
MEDIUM SCENARIO — 2-Person Tub (10 Weeks)
══════════════════════════════════════════════════════════════════════════

Phase / Task           Wk1  Wk2  Wk3  Wk4  Wk5  Wk6  Wk7  Wk8  Wk9  Wk10
──────────────────────────────────────────────────────────────────────────────
P1: Design & Planning
  Research & sketch     ██
  Finalize dimensions   ░█
  Create detailed plans ░█   █░

P2: Procurement
  Order lumber          ░░   █░
  WAIT for delivery     ░░   ░█   ██
  Order hardware/bands  ░░   █░
  Order heater/pump     ░░   █░
  Receive hardware      ░░   ░░   ░█   █░
  Receive heater/pump   ░░   ░░   ░░   ██

P3: Wood Preparation
  Learn to use planer   ░░   ░░   ░░   █░
  & jointer (practice)
  Joint & plane lumber  ░░   ░░   ░░   ██   ██
  (slow, learning pace)
  Rip staves to width   ░░   ░░   ░░   ░░   ░█   █░
  Cut staves to length  ░░   ░░   ░░   ░░   ░░   █░
  Bevel stave edges     ░░   ░░   ░░   ░░   ░░   ██   █░
  (most difficult step
   — expect re-cuts)
  Prepare bottom boards ░░   ░░   ░░   ░░   ░░   ░░   █░

P4: Assembly
  Glue bottom panel     ░░   ░░   ░░   ░░   ░░   ░░   ░█
  (cure overnight+)                                     ↕
  Trim bottom to circle ░░   ░░   ░░   ░░   ░░   ░░   ░░   █░
  Route/cut dado groove ░░   ░░   ░░   ░░   ░░   ░░   ░░   █░
  Dry-fit staves        ░░   ░░   ░░   ░░   ░░   ░░   ░░   ██
  (expect adjustments)
  Install bands         ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█   █░
  Final tightening      ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   █░
  Sand & finish interior░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   █░

P5: Plumbing & Heating
  Install drain         ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█
  Connect heater/pump   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█

P6: Testing & Sealing
  First fill            ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█
  Swell period (3-5 day)░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█   █░
  Check, re-tighten     ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   █░
  Second fill if needed ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   █░

P7: Site Preparation
  Plan foundation       ░░   ░░   █░
  Build pad/base        ░░   ░░   ░░   ░░   █░   █░   ██
  (overlaps wood prep)

P8: Final Installation
  Move tub to site      ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█
  Final connections     ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█
  FIRST SOAK!           ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░░   ░█
──────────────────────────────────────────────────────────────────────────────
Hours/week:             ~5   ~4   ~3*  ~7   ~8   ~8   ~8   ~8   ~7   ~5
                             *waiting for deliveries

█ = active work (one or both weekend days, ~3-5 hrs each)
░ = no work
→ = extends into following days (swell period)
```

### Medium: Learning Milestones (What the Student Gains)
- **Wk 1-2:** Design thinking, measurement, ordering/logistics
- **Wk 3-4:** Machine setup, safety, planer/jointer technique
- **Wk 5-6:** Precision cutting, understanding wood grain, bevel geometry
- **Wk 7:** Glue-up technique, clamping strategy, panel work
- **Wk 8-9:** Cooperage assembly, band fitting, problem solving
- **Wk 10:** Plumbing basics, water testing, project completion pride

### Medium: Key Risks & Mitigations
1. **Learning curve on milling** → Budget extra lumber (15-20% waste factor for beginner).
2. **Stave bevel mistakes** → Have student practice on scrap first. Expect to re-cut 5-10 staves.
3. **Motivation dip around Wk 5-6** → This is the repetitive milling phase. Mix in other tasks.
4. **Band fitting frustration** → Adult mentor should be hands-on for this phase.
5. **Longer swell time** → Beginner joints may have larger gaps. Allow 3-5 days swell vs 1-2.

### Medium: 4-Person Adjustment
- Add 2-4 weeks → **10-14 weeks total** (up to ~16 if very relaxed)
- Significantly more staves to mill and bevel (great practice, but time-consuming)
- Assembly with 80 staves requires more patience and dry-fitting iterations
- Heavier components — adult help essential for lifting

---

## ═══════════════════════════════════════════════════════════════
## COMPARATIVE SUMMARY
## ═══════════════════════════════════════════════════════════════

```
                        SUPER FAST    FAST         MEDIUM
                        ──────────    ────         ──────
Duration (2-person):    2-3 weeks     4-6 weeks    8-12 weeks
Duration (4-person):    3-4 weeks     6-8 weeks    10-14+ weeks
Hours/week:             15-20         8-12         4-8
Total hours (2p):       45-55         55-70        60-85
Total hours (4p):       55-70         70-90        80-110
Lumber state:           Pre-cut kit   Rough sawn   Rough sawn
Skill assumed:          Intermediate  Basic+       Beginner
Risk of burnout:        MODERATE      LOW          VERY LOW
Learning value:         Low-Medium    Medium       HIGH
Stress level:           High          Moderate     Low
Adult involvement:      Medium        Medium       High
Waste factor:           5-10%         10-15%       15-20%
```

### Recommended Scenario by Situation

| Situation | Recommended | Why |
|-----------|-------------|-----|
| Science fair / deadline project | SUPER FAST | Speed is priority; use pre-cut kit |
| Summer project, some experience | FAST | Good balance of learning and completion |
| Semester-long class project | MEDIUM | Maximizes learning, minimal stress |
| Student never used power tools | MEDIUM | Safety requires unhurried pace |
| Budget is very tight | FAST or MEDIUM | Time to shop deals, use cheaper rough lumber |
| Student is very motivated | FAST | Keeps momentum without burnout risk |

---

## POTENTIAL DELAY FACTORS (All Scenarios)

| Delay Risk | Probability | Impact | Mitigation |
|------------|-------------|--------|------------|
| Lumber delivery late | MEDIUM | 1-2 weeks | Order ASAP; have backup supplier |
| Specialty wood unavailable | LOW-MED | 2-4 weeks | Switch to W. Red Cedar (widely available) |
| Custom bands delayed | MEDIUM | 1-2 weeks | Order early; have backup plan (large hose clamps) |
| Student schedule conflict | HIGH | scattered | Build buffer weeks into schedule |
| Tool breakdown | LOW | 1-3 days | Identify backup shop / tool rental |
| Stave fitting issues | HIGH | 2-5 days | Budget re-cut time; buy 15% extra lumber |
| Leaks during testing | HIGH | 1-5 days | Normal — plan for swell time; not a "failure" |
| Weather (outdoor build) | MEDIUM | variable | Indoor/covered build space eliminates this |
| Glue failure (wrong type/temp) | LOW | 2-3 days | Use waterproof glue (Titebond III); follow temp specs |

---

## PHASE DEPENDENCY MAP

```
                    ┌─────────────┐
                    │ P1: DESIGN  │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │P2: ORDER │ │P2: ORDER │ │P7: SITE  │
        │ LUMBER   │ │HARDWARE  │ │  PREP    │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │             │            │
             ▼             │         (independent,
        ┌──────────┐       │       do anytime before
        │P3: WOOD  │       │        final install)
        │  PREP    │       │
        └────┬─────┘       │
             │             │
             ▼             ▼
        ┌─────────────────────┐
        │   P4: ASSEMBLY      │
        │ (needs staves AND   │
        │      bands)         │
        └─────────┬───────────┘
                  │
                  ▼
        ┌──────────────────┐
        │ P5: PLUMBING &   │◄── needs heater/pump in hand
        │    HEATING       │
        └────────┬─────────┘
                 │
                 ▼
        ┌──────────────────┐
        │ P6: TESTING &    │
        │    SEALING       │
        └────────┬─────────┘
                 │
                 ▼
        ┌──────────────────┐
        │ P8: FINAL INSTALL│◄── needs site prep done (P7)
        │   & FIRST SOAK   │
        └──────────────────┘
```

**Key Insight:** The two longest lead-time items are lumber delivery and custom band
fabrication. Ordering both on Day 1 is the single most important schedule optimization
across all three scenarios. Every day of delay in ordering shifts the entire project.

---

*Agent 9 — Loop 1 Research Complete*

---

## Agent 10: Scaling Specialist — 2-Person vs 4-Person Tub Analysis (Loop 1)

### 1. Dimension Changes & Structural Impact

| Specification | 2-Person | 4-Person (Rectangular) | 4-Person (Round) | Change |
|---|---|---|---|---|
| Length | 48" | 60" | 54" diameter | +25% (rect) |
| Width | 30" | 48" | 54" diameter | +60% (rect) |
| Depth | 24" | 24" | 24" | Same |
| Water Volume | ~100 gal | ~200 gal | ~200 gal | +100% |
| Floor Area | 10 sq ft | 20 sq ft | ~16 sq ft (round) | +60-100% |

**Structural implications of wider span:**
- A 48" wide tub vs 30" wide means floor boards span 60% farther unsupported. Deflection increases with the cube of span length, so a 60% wider span produces roughly **4x the deflection** under the same load per board. This demands thicker floor boards (2" vs 1.5") or mid-span floor support joists.
- Longer staves (needed for the wider rectangular walls) flex more and are harder to keep watertight. The 60" long wall staves on a rectangular 4-person tub have 56% more flex than the 48" staves of a 2-person.
- A round 54" diameter tub distributes forces more evenly (each stave is in compression), making it structurally superior to the rectangular option at this size.

### 2. Structural Complexity Comparison

| Factor | 2-Person | 4-Person | Notes |
|---|---|---|---|
| Stave count (round) | ~24-28 | ~34-40 | +40-45% more staves to mill and fit |
| Steel bands required | 3 | 4-5 | More bands, larger diameter |
| Band circumference | ~36" | ~55-60" | +55-67% more steel per band |
| Floor support | Simple slab | Needs mid-span support or 2" boards | Critical difference |
| Joinery precision | Important | Critical | Errors compound over more staves |
| Total loaded weight | ~1,300 lbs | ~2,500-2,800 lbs | +100-115% |

**Foundation requirements:**
- **2-person (~1,300 lbs):** Can sit on a reinforced deck, compacted gravel pad, or patio blocks. ~130 PSF on 10 sq ft footprint. Most existing decks rated at 40-60 PSF will NOT support this without reinforcement.
- **4-person (~2,800 lbs):** Requires a 4" reinforced concrete pad minimum ($1,000-$3,000 installed). At ~140-175 PSF on 16-20 sq ft, this exceeds all standard deck ratings. A structural engineer consultation is recommended.

**Weight breakdown (4-person):**
- Water: 200 gal x 8.34 lbs = **1,668 lbs**
- Tub (empty): **350-400 lbs**
- 4 occupants (avg): **740 lbs**
- **Total: ~2,758-2,808 lbs**

### 3. Material Cost Increase

| Material | 2-Person Cost | 4-Person Cost | Increase |
|---|---|---|---|
| Lumber (Western Red Cedar) | $600-$900 | $1,100-$1,700 | +80-90% |
| Stainless steel bands + hardware | $150-$250 | $300-$450 | +80-100% |
| Drain assembly | $40-$60 | $60-$100 | +50-65% |
| Benches/seating | $100-$150 | $200-$350 | +100-130% |
| Sealant/finish | $40-$60 | $70-$100 | +65-75% |
| **Materials subtotal** | **$930-$1,420** | **$1,730-$2,700** | **+85-90%** |

**Heater sizing:**
- 100 gal tub: A 1.5-2 kW inline heater or small wood-fired stove is sufficient. Heats in 2-4 hours.
- 200 gal tub: Needs 3-5 kW heater or larger wood-fired stove. Heats in 3-6 hours. A 1.5 kW heater would take 8+ hours.
- Heater cost increase: $200-$500 more for the larger capacity unit.
- 100 gal requires ~12.2 kWh to heat from 50F to 100F; 200 gal requires ~24.4 kWh. Exactly **2x the energy** per heating cycle.

### 4. Build Time Increase

| Phase | 2-Person (Student) | 4-Person (Student) | Increase |
|---|---|---|---|
| Planning & layout | 4-6 hrs | 6-8 hrs | +40% |
| Milling staves | 16-24 hrs | 28-40 hrs | +65-75% |
| Floor assembly | 4-6 hrs | 8-12 hrs | +100% |
| Stave assembly & fitting | 12-20 hrs | 24-36 hrs | +85-100% |
| Banding & tightening | 4-6 hrs | 8-12 hrs | +100% |
| Bench installation | 3-5 hrs | 6-10 hrs | +100% |
| Drain & plumbing | 3-4 hrs | 4-6 hrs | +40% |
| Sanding & finishing | 6-10 hrs | 12-18 hrs | +90-100% |
| Foundation prep | 2-4 hrs | 8-16 hrs (concrete pad) | +300% |
| **Total build hours** | **54-85 hrs** | **104-158 hrs** | **+85-95%** |

**Difficulty assessment:**
- The 4-person tub is not just "more of the same" — it is disproportionately harder:
  - **Joinery precision compounds**: With 35-40 staves instead of 25-28, small angle errors multiply. A 1/32" error per stave becomes a 1.1" gap over 35 staves vs 0.8" over 25. The margin for error shrinks.
  - **Handling**: Longer, heavier staves are harder for one person to position and clamp.
  - **Floor complexity**: Mid-span support adds a step that does not exist in the 2-person build.
  - **Overall difficulty increase: approximately 120-150%** (not just 85-95% like raw hours suggest). The skill threshold is meaningfully higher.

### 5. Operational Cost Increase

| Operating Cost | 2-Person (monthly) | 4-Person (monthly) | Increase |
|---|---|---|---|
| Water (weekly changes, ~$5/1000 gal) | $2.00 | $4.00 | +100% |
| Electricity for heating (maintain temp) | $15-$25 | $30-$50 | +100% |
| Salt (0.5% salinity) | $1.50 | $3.00 | +100% |
| Linseed oil treatment (amortized) | $2-$3 | $4-$6 | +100% |
| **Monthly operating total** | **$20-$32** | **$41-$63** | **+100%** |

**Per-heating-cycle costs:**
- 100 gal from cold: ~$1.41 electricity (at $0.115/kWh national avg)
- 200 gal from cold: ~$2.82 electricity
- One BTU heats one gallon of water by 1 degree F. Formula: gallons x 8.33 BTU x temp rise = total BTUs needed. The relationship is perfectly linear with volume.
- Wooden tubs lose heat through the walls, and a larger tub has more surface area (~60-80% more), so heat maintenance cost increases by more than 2x in practice: closer to **2.2-2.5x**.

### 6. Maintenance Complexity Increase

| Maintenance Task | 2-Person | 4-Person | Impact |
|---|---|---|---|
| Interior surface area | ~28 sq ft | ~48-55 sq ft | +70-95% more to scrub |
| Drain time (gravity) | ~10-15 min | ~20-30 min | +100% |
| Refill time (garden hose) | ~20-25 min | ~40-50 min | +100% |
| Band inspection/tightening | 3 bands | 4-5 bands, larger | +50-65% |
| Mold/algae risk | Moderate | Higher | More surface area, harder to dry completely |
| Wood treatment (linseed oil) | 30-45 min | 60-90 min | +100% |
| Seasonal winterization | Straightforward | More complex | More water to drain, more wood to protect |

**Key maintenance concerns for 4-person:**
- Interior corners (on rectangular) are harder to reach and scrub, promoting mold/algae growth.
- A round 4-person eliminates corner issues but increases overall surface area.
- Drying time between uses is longer — important because wood tubs must not stay empty too long (staves shrink and leak on refill) but also must be cleaned. The 4-person tub hits a worse balance point here.
- More weight means more stress on bands over time — bands need re-tightening more frequently.

### 7. Recommendation & Cost-Benefit Analysis

#### Side-by-Side Summary

| Category | 2-Person | 4-Person | Delta |
|---|---|---|---|
| Material cost | $930-$1,420 | $1,730-$2,700 | +85-90% |
| Build hours (student) | 54-85 hrs | 104-158 hrs | +85-95% |
| Build difficulty | Moderate | Hard | +120-150% |
| Foundation cost | $0-$500 | $1,000-$3,000 | +$1,000-2,500 |
| Monthly operating | $20-$32 | $41-$63 | +100% |
| Total first-year cost | $1,500-$2,500 | $3,500-$6,500 | +130-160% |
| Weight (loaded) | ~1,300 lbs | ~2,800 lbs | +115% |

#### Is the 4-person worth it for casual use?

**Generally, no.** For casual/occasional use (2-4 times per week), the 4-person tub roughly doubles every cost category while providing marginal benefit unless you regularly have 3-4 people soaking simultaneously. Specific reasons:

1. **Diminishing returns on enjoyment**: Two people in a 4-person tub is a worse experience — water cools faster, feels less intimate, and wastes resources.
2. **Student builder difficulty**: The jump from 2-person to 4-person crosses a meaningful skill threshold. A 2-person is achievable for a careful beginner; a 4-person demands intermediate woodworking competence, especially for watertight joinery over 35+ staves.
3. **Foundation cost is a hidden multiplier**: The 2-person can sit on a simple gravel pad; the 4-person almost certainly needs poured concrete.

#### The "Compact 4-Person" Compromise

A strong middle option exists: a **round tub, 48" diameter x 26" deep** (~150 gallons):

| Spec | Compact 4-Person |
|---|---|
| Capacity | 3-4 people (cozy) |
| Volume | ~150 gal (50% more than 2-person, 25% less than full 4-person) |
| Weight loaded | ~2,050 lbs |
| Material cost | ~$1,300-$1,900 |
| Build hours | ~80-115 hrs |
| Foundation | Reinforced gravel pad or thin concrete slab |
| Monthly operating | ~$30-$45 |

This compromise:
- Keeps weight under the threshold where a full concrete pad is mandatory
- Uses a round shape for better structural integrity (staves in compression)
- Fits 4 people for short soaks while being comfortable for 2
- Reduces build difficulty vs. full 4-person by ~30%
- Saves ~$1,000-$2,000 in total first-year costs vs. full 4-person

#### Final Recommendation

**For this project (student builder, casual use): Build the 2-person tub.** If social soaking is important, consider the compact 48" round as a stretch goal. Avoid the full 60"x48" rectangular 4-person — it crosses into territory where professional construction experience becomes important for a watertight result, and the foundation requirements add significant cost and complexity.

---

*Agent 10 — Loop 1 Research Complete*

---

## Agent 7 - Maintenance Planning: Loop 1 Findings

### Overview

This section covers maintenance requirements for a Japanese wooden hot tub (ofuro-style) using salt water with minimal or no chemical treatment. Three usage scenarios are analyzed: LOW (1-2x/week), MEDIUM (3-4x/week), and HIGH (daily). All costs are in USD and assume a 2-person tub (~100-175 gallons). A 4-person tub (~200-400 gallons) would roughly double water and energy costs.

**Critical principle for wooden tubs:** The interior wood must remain unfinished/raw so it can absorb water and swell to maintain a watertight seal. Oil treatments (tung oil, teak oil) are for the EXTERIOR only. The interior relies on the wood's natural water resistance (cedar, hinoki, or teak).

---

### 1. WATER CHANGE FREQUENCY AND PROCEDURE

#### Scenario 1 — LOW USE (1-2x/week)
- **Frequency:** Every 3-4 weeks (salt water extends intervals vs. fresh water's 7-10 days)
- **Procedure:** Drain via gravity plug or submersible pump (15-20 min). Scrub interior with soft-bristle brush and plain water — no soap, no chlorine. Rinse thoroughly. Refill at slow rate to allow wood to re-swell gradually (30-45 min for ~175 gallons). Total time: ~1.5 hours per water change.
- **Water cost per change:** $1-3 (municipal water for 175 gallons)
- **Annual water changes:** ~13-17

#### Scenario 2 — MEDIUM USE (3-4x/week)
- **Frequency:** Every 2-3 weeks
- **Procedure:** Same as above, but scrub more thoroughly due to higher bather load. Check for biofilm along waterline before draining.
- **Water cost per change:** $1-3
- **Annual water changes:** ~17-26

#### Scenario 3 — HIGH USE (daily)
- **Frequency:** Every 7-14 days
- **Procedure:** Same as above. With daily use and no chemical sanitizer, bacterial load accumulates faster. Salt water buys some extra time (7-10 days vs. 3-4 days for plain fresh water), but weekly changes are safest for daily soakers.
- **Water cost per change:** $1-3
- **Annual water changes:** ~26-52

---

### 2. TUB INTERIOR CLEANING

**What to use:** Soft-bristle brush (natural fiber, not metal). Plain water only. For stubborn buildup, a paste of baking soda and water can be gently applied. NEVER use soap, chlorine, bleach, or abrasive cleaners — these damage wood fibers, stain the wood, and leave residue.

#### Scenario 1 — LOW USE
- **Between uses:** Quick wipe-down of waterline and interior surfaces with a damp cloth after each soak. ~5 min.
- **Deep scrub:** At each water change (every 3-4 weeks). Scrub entire interior with brush and rinse. ~20-30 min.

#### Scenario 2 — MEDIUM USE
- **Between uses:** Wipe-down after each soak. ~5 min.
- **Light scrub:** Weekly, scrub waterline and seating area. ~10 min.
- **Deep scrub:** At each water change (every 2-3 weeks). ~20-30 min.

#### Scenario 3 — HIGH USE
- **After each use:** Wipe-down of waterline. ~5 min.
- **Light scrub:** Every 2-3 days, scrub waterline and seat surfaces. ~10 min.
- **Deep scrub:** At each water change (every 1-2 weeks). ~20-30 min.

---

### 3. SALT RESIDUE MANAGEMENT

Salt water leaves mineral deposits on wood as water evaporates, especially at and above the waterline. Over time this can cause white crystalline buildup.

#### All Scenarios
- **After each soak:** Wipe the waterline and any splashed exterior surfaces with a damp cloth to remove salt residue before it dries. ~2-3 min.
- **At water change:** During the drain-and-scrub cycle, pay special attention to the waterline band (the 2-3 inches where water meets air). Use a soft brush with plain water to dissolve and remove salt deposits.
- **Exterior protection:** Salt splashes on exterior wood accelerate weathering. Wipe immediately. The exterior oil treatment (see section 5) helps protect against salt damage.
- **Metal hardware:** Salt is corrosive to non-marine-grade metals. All bands, bolts, and fittings MUST be 316 stainless steel or marine-grade. Inspect monthly for any corrosion. Rinse metal components with fresh water if salt splashes on them.

**Note:** Research indicates that dissolved sea salt can actually act as a mild natural impregnator/preservative for the interior wood, which is a benefit. The concern is with dried salt residue above the waterline.

---

### 4. CHECKING FOR MOLD, MILDEW, AND ALGAE

Wooden tubs are more susceptible to biological growth than acrylic/fiberglass. Salt water inhibits some growth but does not eliminate it, especially in warm, humid conditions.

#### Scenario 1 — LOW USE (highest risk — water sits longer between uses)
- **Before each use:** Visual inspection of interior surfaces for green/black/fuzzy spots. Check under any rim or lip where moisture lingers. ~3 min.
- **Weekly:** Even if not using the tub, lift the cover and inspect. Ensure adequate airflow. Stagnant covered water in a warm tub is ideal for algae.
- **Action if found:** Drain immediately. Scrub affected area with baking soda paste and soft brush. Rinse thoroughly. Allow to air dry for 2-4 hours in sunlight if possible (UV kills mold), then refill. Do NOT let the tub dry out completely (see section on wet vs. dry below).

#### Scenario 2 — MEDIUM USE (moderate risk)
- **Before each use:** Quick visual inspection. ~2 min.
- **Weekly:** Full interior inspection during weekly light scrub.
- **Action if found:** Same as above.

#### Scenario 3 — HIGH USE (lowest risk — frequent water changes and use)
- **Before each use:** Brief visual check. ~1 min. Daily use with frequent water changes keeps biological growth minimal.
- **Action if found:** Same as above, but occurrence should be rare with proper water changes.

---

### 5. WOOD CONDITIONING / TREATMENT SCHEDULE

**Critical distinction:**
- **Interior:** Do NOT apply oil, varnish, or sealant. The raw wood must absorb water to swell and seal. The tub's watertight integrity depends on this.
- **Exterior:** Apply tung oil, teak oil, or Seafin Teak Oil to protect from UV, weather, and salt splash.

#### Exterior Treatment Schedule

| Scenario | Indoor Tub | Outdoor Tub |
|----------|-----------|-------------|
| LOW | Annually | Every 6 months |
| MEDIUM | Annually | Every 6 months |
| HIGH | Annually | Every 4-6 months (more splash/exposure) |

**Application procedure:**
1. Drain tub and allow exterior to dry for 4-8 hours (do NOT let interior dry completely — keep a few inches of water inside).
2. Lightly sand exterior with 220-grit sandpaper if needed.
3. Apply tung oil or teak oil with a brush or cloth, following wood grain.
4. Allow 15-30 min penetration, wipe excess.
5. Apply second coat after 24 hours.
6. Allow 48 hours cure time before full use.
- **Time per application:** ~2-3 hours of active work (plus drying/curing time).
- **Cost per application:** Tung oil ~$20-35/quart (one quart sufficient for a 2-person tub exterior). Teak oil ~$15-25/pint.

#### Interior Wood Care

Instead of oil, maintain the interior by:
- Keeping the tub filled (wood stays swollen and sealed)
- Regular scrubbing to prevent buildup
- Ensuring the wood never fully dries out (see wet vs. dry section)

---

### 6. HEATING SYSTEM MAINTENANCE

Maintenance depends on heating type. Covering the two most likely options:

#### Electric Heater (inline or submersible)
- **Monthly:** Check connections, inspect heating element for scale/mineral buildup from salt water. Salt water accelerates scale formation. Descale with white vinegar soak if needed. ~15-20 min.
- **Quarterly:** Full inspection of wiring, thermostat calibration check. ~30 min.
- **Annually:** Professional inspection recommended. ~$75-150.
- **Element replacement:** Every 3-5 years depending on salt concentration. Cost: $50-200 for element.

#### Wood-Fired Stove (snorkel-style or external)
- **Every 20 uses:** Sweep chimney and clean firebox of soot/ash. ~20-30 min.
- **After each use:** Remove ash from firebox once cooled. ~5 min.
- **Monthly:** Inspect stove body, welds, and chimney for cracks or corrosion (salt air accelerates this). Lubricate damper. ~15 min.
- **Annually:** Full chimney sweep and stove inspection. Professional service: ~$100-200. Or DIY with chimney brush: ~$30-50 for brush kit.
- **Firebox/stove replacement:** Every 10-15 years. Cost: $500-2,000 depending on type.

---

### 7. PUMP / FILTER CLEANING

If the tub has a circulation pump and filter (not all traditional ofuro do — many are simple fill-and-soak):

#### Scenario 1 — LOW USE
- **Filter rinse:** Weekly with garden hose. ~5-10 min.
- **Deep filter clean:** Monthly with filter cleaning solution (non-chlorine). Soak 8-12 hours, rinse. ~10 min active time.
- **Filter replacement:** Every 12-18 months. Cost: $20-50 per cartridge.
- **Pump inspection:** Monthly, check for unusual noise, leaks, salt corrosion. ~5 min.
- **Pump impeller cleaning:** Every 3-6 months. ~20 min.

#### Scenario 2 — MEDIUM USE
- **Filter rinse:** Twice weekly. ~5-10 min each.
- **Deep filter clean:** Every 2-3 weeks. ~10 min active.
- **Filter replacement:** Every 6-12 months. Cost: $20-50.
- **Pump inspection:** Bi-weekly. ~5 min.
- **Pump impeller cleaning:** Every 2-3 months. ~20 min.

#### Scenario 3 — HIGH USE
- **Filter rinse:** Every other day. ~5-10 min.
- **Deep filter clean:** Weekly. ~10 min active.
- **Filter replacement:** Every 3-6 months. Cost: $20-50.
- **Pump inspection:** Weekly. ~5 min.
- **Pump impeller cleaning:** Monthly. ~20 min.

**Salt water note:** Salt water is harder on pump seals and metal components. Use only salt-water-rated pumps with marine-grade internals. Pump lifespan with salt water: ~5-8 years (vs. 8-12 years with fresh water). Replacement cost: $200-600.

---

### 8. SEASONAL MAINTENANCE

#### Spring (if tub was winterized)
- Inspect all wood for cracks, warping, mold that developed over winter. ~30-60 min.
- Re-tighten bands if wood shifted. ~15 min.
- Fill slowly to allow wood to re-swell (may take 24-48 hours to become fully watertight).
- Apply exterior oil treatment. ~2-3 hours.
- Run and test pump/heater. ~15 min.

#### Summer
- Increased algae risk in warm weather. Increase inspection frequency.
- For outdoor tubs: UV cover when not in use. Check exterior oil condition.
- Monitor water temperature — may need less heating energy.

#### Fall
- Apply exterior oil treatment if outdoor (pre-winter protection).
- Inspect and tighten bands before temperature swings begin.
- Check all seals, plumbing connections.
- Stock up on maintenance supplies.

#### Winter / Winterizing

**If continuing to use through winter:**
- Keep the tub filled and heated. A running hot tub is easier to maintain than a winterized one.
- Insulated cover is essential. Consider a floating thermal blanket under the cover.
- Monitor for ice formation around edges if outdoor.
- Energy costs increase 30-50% in cold months.

**If winterizing (shutting down for the season):**
1. Drain completely. Use wet/dry vacuum to blow out all plumbing lines (up to 6 gallons can remain in pipes and freeze/crack them).
2. Clean and scrub interior thoroughly.
3. Apply exterior sealant/oil.
4. Add pool-grade or RV-grade antifreeze to plumbing lines. NEVER use automotive antifreeze (toxic).
5. Cover with insulated, waterproof cover secured tightly.
6. **CRITICAL for wooden tubs:** A fully drained wooden tub WILL shrink and may crack. Options:
   - Leave a few inches of water in the bottom (risk of freezing in cold climates)
   - Accept that re-swelling will be needed in spring (fill slowly, may leak for 24-48 hours)
   - Best option: keep tub running at a lower temperature (85-90F) through winter if possible

**Winterizing time:** ~3-4 hours
**Winterizing cost:** Antifreeze ($15-25), cover ($100-300 if not already owned)

---

### 9. WOOD INSPECTION FOR CRACKS, WARPING, LEAKS

#### Scenario 1 — LOW USE
- **Weekly:** Visual check of interior staves for hairline cracks, especially near waterline where wet/dry cycles occur. Check for any dripping on exterior. ~5 min.
- **Monthly:** Thorough inspection at water change. Feel along stave joints for gaps. Check bottom for soft spots. ~15 min.
- **Quarterly:** Full structural inspection including bottom, all staves, joints, and exterior. ~30 min.

#### Scenario 2 — MEDIUM USE
- **Weekly:** Visual and tactile inspection during scrub. ~5-10 min.
- **Monthly:** Full inspection at water change. ~15 min.

#### Scenario 3 — HIGH USE
- **Weekly:** Visual inspection during regular cleaning. ~5 min.
- **Bi-weekly:** Inspect at water change. ~15 min.
- **Daily use actually reduces cracking risk** because the wood stays consistently saturated.

#### Repairs
- **Hairline cracks:** Fill with food-safe wood filler or beeswax. Cost: $5-15. Time: 30 min.
- **Small gaps between staves:** Often resolved by tightening bands and allowing wood to re-swell. Free (just time). ~15-30 min.
- **Warped stave:** May need professional replacement. Cost: $50-200 per stave plus labor ($50-100/hr). Time: 2-4 hours.
- **Leaking bottom:** Most serious issue. May require lifting tub, replacing bottom boards. Professional repair: $300-800.

---

### 10. RE-TIGHTENING METAL BANDS / HOOPS

Wooden tubs use metal bands (ideally 316 stainless steel for salt water) that compress the staves together. Wood expands and contracts with moisture and temperature changes, so bands need periodic adjustment.

#### All Scenarios
- **Weekly:** Visual check for band looseness. Tap bands — a tight band rings, a loose band thuds. ~2 min.
- **Monthly:** Check band tension with a wrench. Snug as needed — do NOT over-tighten (can crack staves). ~10-15 min.
- **Seasonally (spring and fall):** As temperatures shift, wood moves more. Check and adjust all bands. ~20-30 min.
- **Major tune-up every 6-7 years:** Full disassembly, reseat all staves, re-tighten all bands. This is the most significant periodic maintenance for a cooperage-style tub. Professional service: $200-500. DIY: 4-8 hours of labor.

**Salt water consideration:** Ensure all band hardware (nuts, bolts, threaded rods) is 316 stainless steel. Salt will destroy regular steel or even 304 stainless within 1-2 years. Lubricate threads annually with marine-grade lubricant to prevent seizing. Cost: $10-15 for lubricant.

---

### 11. WEEKLY TIME COMMITMENT

| Task | LOW (1-2x/wk) | MEDIUM (3-4x/wk) | HIGH (daily) |
|------|---------------|-------------------|--------------|
| Post-soak wipe-down | 10-15 min | 20-25 min | 35-40 min |
| Salt residue cleanup | 5-10 min | 10-15 min | 15-20 min |
| Water chemistry check (pH test strips) | 5 min | 10 min | 10 min |
| Filter rinse | 5-10 min | 10-15 min | 25-35 min |
| Mold/mildew inspection | 5 min | 5 min | 5 min |
| Interior scrub (light) | 0 min (not weekly) | 10 min | 20 min |
| Band/wood inspection | 5 min | 5 min | 5 min |
| Heating system check | 5 min | 5 min | 5 min |
| **Weekly total** | **40-55 min** | **~1.25-1.5 hrs** | **~2-2.25 hrs** |

**Add periodic tasks averaged weekly:**

| Periodic Task | LOW | MEDIUM | HIGH |
|--------------|-----|--------|------|
| Water change (amortized) | +20 min/wk | +30 min/wk | +45 min/wk |
| Deep filter clean (amortized) | +5 min/wk | +5 min/wk | +10 min/wk |
| Exterior oil treatment (amortized) | +5 min/wk | +5 min/wk | +8 min/wk |
| **Total weekly average** | **~1-1.5 hrs** | **~1.75-2.25 hrs** | **~2.75-3.25 hrs** |

---

### 12. MONTHLY MAINTENANCE COSTS

#### Scenario 1 — LOW USE (1-2x/week)

| Expense | Monthly Cost |
|---------|-------------|
| Water (1-1.5 changes/mo) | $2-5 |
| Salt (marine salt, ~2 lbs/change) | $3-5 |
| Electricity/gas for heating | $30-50 |
| Filter cartridges (amortized) | $2-4 |
| Cleaning supplies (baking soda, brushes) | $2-3 |
| Exterior oil treatment (amortized) | $2-3 |
| pH test strips | $2-3 |
| **Monthly total** | **$43-73** |

#### Scenario 2 — MEDIUM USE (3-4x/week)

| Expense | Monthly Cost |
|---------|-------------|
| Water (2-2.5 changes/mo) | $3-8 |
| Salt | $5-8 |
| Electricity/gas for heating | $50-80 |
| Filter cartridges (amortized) | $4-7 |
| Cleaning supplies | $3-5 |
| Exterior oil treatment (amortized) | $3-4 |
| pH test strips | $3-4 |
| **Monthly total** | **$71-116** |

#### Scenario 3 — HIGH USE (daily)

| Expense | Monthly Cost |
|---------|-------------|
| Water (2-4 changes/mo) | $4-12 |
| Salt | $8-12 |
| Electricity/gas for heating | $70-120 |
| Filter cartridges (amortized) | $7-12 |
| Cleaning supplies | $5-8 |
| Exterior oil treatment (amortized) | $4-6 |
| pH test strips | $4-5 |
| **Monthly total** | **$102-175** |

**Notes:**
- Energy costs assume an electric heater in a moderate climate. Wood-fired heating replaces electricity cost with firewood cost (~$5-15 per heating session, but zero electricity).
- Costs increase 30-50% in winter months for outdoor tubs due to heating demands.
- These costs do NOT include equipment replacement (pump, heater elements) which are amortized over years.

---

### KEEPING THE TUB WET VS. LETTING IT DRY

**This is the single most important maintenance concept for a wooden hot tub.**

When wood fibers absorb water, they swell. This swelling is what makes a cooperage-style wooden tub watertight — the staves press tightly against each other. If the wood dries out, it shrinks, gaps form between staves, and the tub leaks. Repeated wet/dry cycles cause cracking, warping, and premature failure.

**Rules:**
- **NEVER let the tub sit completely empty and dry for more than 24-48 hours** (less in hot/dry climates, where cracking can begin in as little as 12 hours).
- If you must drain for cleaning, refill the same day.
- Between uses, keep the tub filled with water (can be at a lower temperature to save energy — 85F "standby" vs. 104F "soak" temperature).
- Always use a cover when the tub is not in use to reduce evaporation.

**LOW use scenario risk:** With only 1-2 uses per week, you might be tempted to drain between uses. DO NOT. Keep the tub filled. The cost of maintaining water at a low standby temperature is far less than the cost of repairing cracked/leaking staves.

---

### HANDLING A 2-WEEK VACATION

#### Option A: Leave the Tub Running (RECOMMENDED)
- Fill with fresh salt water before departure.
- Set heater to standby/low temperature (85F) to save energy while keeping the wood wet.
- Ensure cover is secured.
- Turn off jets/circulation pump if desired, but leave heater on freeze-protection mode in cold weather.
- Have a neighbor or friend check on it once mid-trip (5 min check: water level, cover secure, no leaks).
- Upon return: drain, scrub, refill with fresh salt water before soaking (2 weeks of stagnant water will have bacterial growth). ~1.5 hours.
- **Cost of 2-week vacation mode:** ~$15-30 in electricity (standby heating).

#### Option B: Drain and Cover (RISKY for wood)
- Only consider this in humid climates where the wood will not dry out quickly.
- Drain, scrub interior, leave cover on tightly.
- Place damp towels inside the tub and cover to maintain some humidity (a trick used by some wooden tub owners).
- Upon return: fill slowly, allow 24-48 hours for wood to re-swell before expecting watertight seal. May leak initially. ~2-3 hours of active work.
- **Risk:** Cracks, stave shrinkage, leaking upon refill. NOT recommended for hot/dry climates.

#### Option C: Have Someone Maintain It
- Ask a neighbor to check water level, add water if evaporating, and confirm heater is running. Once per week, 10 min per visit.
- Best option if you can arrange it.

---

### EXPECTED LIFESPAN OF THE WOODEN TUB

| Factor | LOW Use | MEDIUM Use | HIGH Use |
|--------|---------|-----------|----------|
| **Expected tub lifespan** | **20-25+ years** | **15-20 years** | **10-15 years** |
| Wood saturation consistency | Good (kept filled) | Good | Very good (constantly in use) |
| Wear from use/scrubbing | Minimal | Moderate | Highest |
| Salt exposure (cumulative) | Lowest | Moderate | Highest |
| Wet/dry cycle risk | Highest (temptation to drain) | Moderate | Lowest (always wet) |
| Mold/algae risk | Highest (stagnant water) | Moderate | Lowest (frequent changes) |

**Key factors that shorten lifespan:**
- Allowing the tub to dry out repeatedly (biggest risk — can halve lifespan)
- Using chlorine or harsh chemicals (destroys wood fibers)
- Neglecting exterior oil treatment (UV and weather damage)
- Ignoring loose bands (leads to leaks and structural failure)
- High salt concentration (above 3.5% — keep at 1-2% for best wood preservation)

**Key factors that extend lifespan:**
- Consistent water fill (wood stays swollen)
- Regular exterior oil treatment
- Prompt repair of hairline cracks
- 316 stainless steel hardware (no corrosion)
- Proper wood species selection (hinoki, cedar, or teak)

---

### WHEN MAJOR MAINTENANCE / REPAIRS ARE NEEDED

| Repair | When Typically Needed | Cost (DIY) | Cost (Professional) | Time |
|--------|----------------------|------------|---------------------|------|
| Re-sealing stave joints | Year 5-8, then every 3-5 years | $20-50 (sealant) | $200-400 | 3-5 hrs |
| Replacing individual stave | Year 8-15 (if cracked/warped) | $50-200 (wood + materials) | $200-500 | 2-4 hrs |
| Full band retightening + stave reseating | Every 6-7 years | Free (just labor) | $200-500 | 4-8 hrs |
| Bottom board replacement | Year 10-20 (if soft/rotted) | $100-300 | $500-1,000 | 4-8 hrs |
| Pump replacement | Every 5-8 years (salt water) | $200-600 | $350-800 (with labor) | 1-2 hrs |
| Heater element replacement | Every 3-5 years (salt water) | $50-200 | $150-350 | 1-2 hrs |
| Full tub rebuild (all staves) | Year 15-25+ | $500-1,500 | $1,500-3,000+ | Multi-day |
| Exterior refinishing (full sand + oil) | Every 3-5 years | $30-60 | $200-400 | 4-6 hrs |

---

### MAINTENANCE QUICK-REFERENCE CALENDAR

#### Daily (if using the tub that day): ~10 min
- Wipe interior at waterline after soaking
- Wipe salt residue from exterior splashes
- Check water level (top off if low)
- Visual check for anything unusual

#### Weekly: ~15-30 min
- Test water pH (target 7.2-7.8)
- Rinse filter cartridge
- Inspect bands for looseness
- Check for mold/mildew under cover
- Skim debris from water surface

#### Monthly: ~1-2 hours
- Deep clean filter (overnight soak in cleaning solution)
- Inspect all metal hardware for corrosion
- Check pump operation and seals
- Inspect wood for cracks or soft spots
- Tighten bands if needed
- Clean heating system / descale

#### Quarterly: ~2-4 hours
- Full structural wood inspection
- Seasonal band adjustment
- Exterior oil treatment (outdoor tubs)
- Plumbing line flush
- Chimney sweep (if wood-fired, every 20 uses or quarterly)

#### Annually: ~4-8 hours
- Exterior oil treatment (indoor tubs) or second annual treatment (outdoor)
- Professional heater/pump inspection (optional but recommended)
- Full hardware lubrication
- Comprehensive structural assessment
- Replace filter cartridge(s)

#### Every 6-7 Years
- Full stave reseating and band retightening tune-up

---

### SOURCES

- [The Log Company — How to Care for Wood-Fired Hot Tubs](https://thelogcompany.com/news/how-to-care-wood-fired-hot-tubs-2025)
- [Roberts Hot Tubs — Wooden Hot Tub Maintenance Guide](https://rhtubs.com/worried-about-wooden-hot-tub-maintenance-the-no-stress-guide-to-caring-for-your-spa/)
- [Roberts Hot Tubs — Maintaining and Protecting Custom Wooden Tubs for Decades](https://rhtubs.com/resources/how-to-maintain-and-protect-your-custom-wooden-tub-for-decades/)
- [Roberts Hot Tubs — How Long Do Wooden Hot Tubs Last](https://rhtubs.com/how-long-do-wooden-hot-tubs-last-what-every-buyer-needs-to-know/)
- [Roberts Hot Tubs — Ofuro Soaking Tubs](https://rhtubs.com/resources/japanese-ofuro-soaking-tubs/)
- [Zen Bathworks — Discover Ofuros](https://www.zenbathworks.com/discover-ofuros/)
- [Sauneco — Wooden Hot Tub Guidance](https://sauneco.com/help/wooden-hot-tub-guidance/)
- [AlumiTubs — Water Use and Cleaning Tips](https://alumitubs.com/blogs/woodfiredhottubs/water-use-tips-how-often-to-change-clean-and-more)
- [Backcountry Recreation — Wood-Fired Cedar Hot Tub Maintenance](https://www.backcountryrecreation.com/pages/wood-fired-cedar-hot-tub-maintenance)
- [Snorkel Hot Tubs — Product Specifications and Maintenance](https://snorkel.com/product/6x4-wood-fired-hot-tub-package-w-snorkel/)
- [Kirami — Hot Tub Maintenance and Service Life](https://www.kirami.com/manuals/frequently-asked-questions/tub-maintenance-and-durability)
- [Cedar Tubs — Maintenance Checklist](https://www.cedartubs.com/hot-tub-maintenance-checklist.html)
- [Angi — How Much Does It Cost to Run a Hot Tub (2026)](https://www.angi.com/articles/cost-to-run-a-hot-tub.htm)
- [Backcountry Recreation — How to Winterize a Wood-Fired Hot Tub](https://www.backcountryrecreation.com/blogs/news/winterize-wood-fired-hot-tub)
- [GOODLAND — How to Winterize Your Hot Tub](https://hellogoodland.com/blogs/news/how-to-winterize-your-hot-tub)

---

*Agent 7 — Loop 1 Research Complete*

---

# ═══════════════════════════════════════════════════════════════
# LOOP 2 — CROSS-POLLINATION FINDINGS
# ═══════════════════════════════════════════════════════════════

## KEY REVISIONS FROM LOOP 2

### Major Design Changes
1. **Construction method changed: RECTANGULAR BOX** (not round stave/cooperage)
   - Reason: Federal HO #5 prohibits minors from power-driven woodworking machines
   - Round stave construction requires precision bevel cuts impossible without power saws
   - Rectangular uses stacked planks with lap joints — achievable with hand tools only
2. **2-person dimensions revised:** 54"L x 28"W x 24"D internal (~150 gal)
3. **4-person dimensions revised:** 60"L x 48"W x 28"D internal (~280 gal)
4. **"Sweet spot" compromise identified:** 44-45" round at 120-130 gal (but requires adult to pre-cut staves)

### Major Budget Alignment
- **2-person build cost:** $1,500 (low) / $2,185 (mid) / $2,845 (high)
- **4-person build cost:** $1,785 (low) / $2,625 (mid) / $3,390 (high)
- **Monthly operating (reconciled):** $50-115/month all-in (energy + water + chemicals)
- **Cost discrepancy resolved:** Agent 7's $43-175 and Agent 8's $30-75 were measuring different scopes; all-in is $50-115

### Major Technical Findings
- **5.5kW heater confirmed adequate** for both 150 gal and 280 gal (longer heat-up for larger)
- **H2O2 must be dosed DAILY** at 85°F standby (bacterial growth never pauses at this temp)
- **Salt drainage: 65-178 lbs/year** deposited — must drain to sanitary sewer, not lawn
- **Student hours revised:** 20-55 hours depending on how much adult pre-cuts

---

## Agent 1 — Design & Construction (Loop 2)

### Construction Method: Rectangular Box (Hand Tools Only)
- Stacked 2x6 WRC planks, like a log cabin
- Vertical battens (2x4) on exterior, through-bolted with 3/8" carriage bolts
- Corners use simple lap joint (alternating overlap at each course)
- Sealing: food-safe silicone caulk + closed-cell foam backer rod between courses

### 2-Person Cut List (2x6 WRC, actual 1.5" x 5.5")
| Component | Qty | Length |
|-----------|-----|--------|
| Floor boards | 6 | 54" |
| Long side boards | 10 | 57" (5 per side) |
| Short side boards | 10 | 28" (5 per end) |
| Floor joists | 3 | 28" (2x4) |
| External battens | 8 | 27" (2x4) |
| Bench/seat | 2 | 26" |
| **Total:** ~85 BF, est. $340-510 |

### 4-Person Cut List
| Component | Qty | Length |
|-----------|-----|--------|
| Floor boards | 9 | 60" |
| Long side boards | 12 | 63" (6 per side) |
| Short side boards | 12 | 48" (6 per end) |
| Floor joists | 4 | 48" (2x4) |
| External battens | 12 | 31" (2x4) |
| Bench/seat | 4 | 46" |
| **Total:** ~170 BF, est. $680-1,020 |

### Hand Tools Required
- Ryoba saw (Japanese pull saw)
- Chisel set (1/4", 1/2", 3/4", 1")
- Mallet, block plane
- Cordless drill + bits (NOT a "woodworking machine" per HO #5)
- Socket wrench set, bar clamps (4x 48")
- Combination square, tape measure

### Heater Integration
- 5.5kW heater: heats 150 gal from 85°F→104°F in ~50-75 min (adequate)
- 5.5kW heater: heats 280 gal from 85°F→104°F in ~75-90 min (adequate but slower)
- **Insulation is non-negotiable:** 2" XPS foam cover + 1" rigid foam on exterior walls
- Uninsulated tub loses ~2-3°F/hr; insulated loses ~0.5°F/hr

### Waterproofing Strategy (Layered)
1. Wood swelling (cedar naturally tightens when wet)
2. Silicone caulk at all joints during assembly
3. Backer rod between courses for compression seal
4. Optional interior tung oil finish
5. EPDM pond liner as fallback if leaks persist

---

## Agent 2 — Materials Sourcing (Loop 2)

### Hardware (All 316 Stainless Steel for Salt Water)
| Item | Qty | 316 SS Cost |
|------|-----|-------------|
| Carriage bolts 3/8"x6" | 24 | $34 |
| Carriage bolts 3/8"x3" | 12 | $13 |
| SS band clamps | 3 | $165 |
| Threaded rod + nuts 3/8" | 4 ft | $56 |
| Drain fitting 1.5" bulkhead | 1 | $28 |
| Misc washers/screws/brackets | lot | $40 |
| **Hardware total** | | **~$336** |

316 SS costs ~70-80% more than 304 SS — non-negotiable for salt water longevity (304 corrodes in 12-18 months).

### Pre-Cut Strategy
- **Local mill service:** $150-300 fee on top of lumber cost (mill rips, planes, bevels to spec)
- **Adult homeowner with shop:** $0 additional, 8-12 hours of cutting
- **Pre-cut stave kit:** $600-900 from specialty suppliers

---

## Agent 3 — Labor & Contracting (Loop 2)

### Reconciled Student Hours
| Scenario | Student Hours | @ $15/hr | @ $20/hr |
|----------|-------------|----------|----------|
| Pre-cut kit (fast) | 40-52 | $600-780 | $800-1,040 |
| Medium pace | 63-85 | $945-1,275 | $1,260-1,700 |
| First-timer (slow) | 86-109 | $1,290-1,635 | $1,720-2,180 |

### Tools Student CAN Legally Use
- All hand tools (saws, chisels, planes, mallets)
- Cordless drill (portable hand-held, not a "woodworking machine")
- Orbital sander (portable hand-held)
- Manual clamps, socket wrenches

### Tools Student CANNOT Use (Federal HO #5)
- Table saw, band saw, circular saw, miter saw
- Jointer, planer, router table
- Any power-driven woodworking machine

### Contract Requirements
- Written agreement with parent/guardian
- Safety clause specifying student scope (hand tools only)
- All power tool work performed by named adult
- Electrician provides own insurance for 240V work

---

## Agent 4 — Heating Systems (Loop 2)

### 5.5kW Heater: Confirmed Adequate for Both Sizes
| Metric | 150 gal (2-person) | 280 gal (4-person) |
|--------|-------------------|-------------------|
| 85°F→104°F heat-up | 50-75 min | 75-90 min |
| Cold start (55°F→104°F) | ~3.3 hours | ~6.8 hours |
| Standby energy (85°F, insulated) | $8-12/month | $12-18/month |
| Full temp energy (104°F) | $15-25/month | $22-35/month |

### 85°F Standby vs 104°F Continuous
- Standby saves 40-50% on electricity
- ~1 hour reheat penalty is acceptable trade-off
- Wood must stay wet regardless — standby at 85°F serves both purposes

### H2O2 Effect on Heater Elements
- At 30-100 ppm spa concentrations: minimal corrosion risk
- Standard Incoloy or titanium-sheathed elements tolerate these levels for years

---

## Agent 5 — Salt Water Chemistry (Loop 2)

### CRITICAL FINDING: 85°F Standby Creates Persistent Bacterial Incubation
- Pseudomonas doubles every ~30 min at 85°F
- Legionella grows at 77-113°F
- H2O2 residual is **non-negotiable** — cannot skip even one day

### H2O2 Half-Life by Condition
| Condition | Half-Life |
|-----------|-----------|
| 85°F standby, no bathers | 12-18 hours |
| 104°F soak, no bathers | 6-10 hours |
| 104°F soak, with bathers | 3-5 hours |

### Daily Protocol (2 Minutes)
1. Test H2O2 with strip
2. If below 30 ppm, dose to 50 ppm (~3-5 oz of 3% H2O2 per 100 gal)
3. Before each soak: test and boost to 50 ppm
4. After each soak: add half-dose to compensate for bather organics

### Water Change Trigger: Every 3-4 Weeks
- Wood tannins overwhelm H2O2 system over time
- Dissolved solids accumulate
- Fresh water is the reset

### Salt Drainage Impact on Lawns
| Grass Type | Max Drains/Year to Same Spot |
|------------|------------------------------|
| Kentucky Bluegrass | 3-4 |
| Tall Fescue | 6-8 |
| Bermuda | 8-12 |

**Recommendation:** Drain to sanitary sewer, rotate drain locations, or use gravel dry well.

---

## Agent 6 — Water Management (Loop 2)

### Fill Times
| Tub | Volume | Fill Time (6 GPM hose) |
|-----|--------|----------------------|
| 2-person | 150 gal | ~25 min |
| 4-person | 280 gal | ~47 min |

### Annual Water Cost
| Scenario | 2-Person | 4-Person |
|----------|----------|----------|
| Biweekly drains (26/yr) | $39-43 | $59 |
| Weekly drains (52/yr) | $78-86 | $117 |

### Salt Water Disposal (Ranked)
1. **Sanitary sewer cleanout** — best option, pipe drain directly
2. **Dispersed irrigation** over 1,000+ sq ft with post-flush — marginal
3. **Gravel dry well** — functional but salt migrates to soil over years
4. **Storm drain** — avoid, likely illegal

### Annual Salt Deposited
| Scenario | Salt/Year |
|----------|-----------|
| 2-person, biweekly | 65 lbs |
| 2-person, weekly | 130 lbs |
| 4-person, weekly | 178 lbs |

---

## Agent 7 — Maintenance (Loop 2)

### Cost Reconciliation (FINAL)
| Component | Monthly Cost |
|-----------|-------------|
| Electricity (heater + pump) | $8-35 |
| Water (2-4 changes/month) | $3-6 |
| H2O2 (35%, ~1.5 qt/month) | $15-25 |
| Salt (2-4 lbs/month) | $2-4 |
| Test strips/misc | $3-5 |
| **Total** | **$31-75** |

*Note: Range depends on climate, use frequency, and electricity rates. Agent 7's original $43-175 included worst-case heavy winter use; Agent 8's $30-75 only captured energy. The aligned range is $31-75 for typical use, up to $115 for heavy winter use.*

### Weekly Routine (15-20 min active)
| Task | Frequency | Time |
|------|-----------|------|
| Wipe interior at waterline | After each soak | 5 min |
| Add H2O2 maintenance dose | Every 2-3 days | 2 min |
| Test water (pH, clarity) | Weekly | 2 min |
| Wipe exterior | Weekly | 5 min |
| Full water change | Every 1-4 weeks | 30-40 min |

### What Kills a Wood Tub (Top 3)
1. **Drying out** — staves shrink, joints open, leaks on refill. Never empty >24-48 hrs.
2. **Mold/rot from stagnant untreated water** — daily H2O2 prevents this.
3. **Salt corrosion of non-316 hardware** — use 316 SS exclusively.

### Expected Lifespan
- Good maintenance: **15-25 years**
- Poor maintenance: **3-5 years**

---

## Agent 8 — Budget Analysis (Loop 2)

### FINAL ALIGNED BUDGET: 2-Person Tub

| Item | LOW | MID | HIGH |
|------|-----|-----|------|
| WRC Lumber (85 BF) | $340 | $425 | $510 |
| 316 SS Hardware | $250 | $336 | $420 |
| 5.5kW Heater + Pump | $300 | $400 | $500 |
| Plumbing/fittings | $30 | $50 | $75 |
| Student labor (40-85 hrs) | $600 | $900 | $1,200 |
| Electrician (240V) | $150 | $275 | $400 |
| Misc (sandpaper, sealant, tools) | $40 | $65 | $100 |
| **Construction Total** | **$1,710** | **$2,451** | **$3,205** |

### Monthly Operating
| Component | LOW | MID | HIGH |
|-----------|-----|-----|------|
| Electricity | $8 | $18 | $35 |
| Water | $3 | $4 | $6 |
| H2O2 | $15 | $20 | $25 |
| Salt | $2 | $3 | $4 |
| Misc supplies | $3 | $4 | $5 |
| **Monthly Total** | **$31** | **$49** | **$75** |
| **Annual Operating** | **$372** | **$588** | **$900** |

### 5-Year Cost of Ownership
| | 2-Person | 4-Person |
|--|----------|----------|
| Construction (mid) | $2,451 | $2,891 |
| Year 1 operating | $588 | $735 |
| Years 2-5 operating | $2,352 | $2,940 |
| Maintenance reserve | $300 | $400 |
| **5-Year Total** | **$5,691** | **$6,966** |

---

## Agent 9 — Timeline (Loop 2)

### Revised Timelines (Hand Tools, Rectangular Construction)

| Scenario | Calendar Weeks | Student Hours | Notes |
|----------|---------------|---------------|-------|
| Pre-cut kit (Super Fast) | 3-4 | 20-25 | 1-2 wks waiting, 1.5-2 wks assembly |
| Rough lumber + adult cuts (Fast) | 4-5 | 25-35 | Adult mills parallel to delivery |
| Educational / student prep (Medium) | 5-6 | 40-55 | Student does more shaping |

### Key Change from Loop 1
- Original timelines assumed power tool use (45-85 hrs)
- Hand-tool-only with adult pre-cutting **reduces** student hours to 20-55
- Calendar time stays similar because delivery wait is the bottleneck, not labor

---

## Agent 10 — Scaling Analysis (Loop 2)

### Revised 2-Person vs 4-Person (Rectangular)
| Attribute | 2-Person | Compact 4-Person |
|-----------|----------|-----------------|
| Dimensions | 54"x28"x24" | 60"x48"x28" |
| Volume | 150 gal | 280 gal |
| Build Cost (mid) | $2,451 | $2,891 |
| Delta | — | +$440 (+18%) |
| Monthly Operating | $49 | $65 |
| Heater | 5.5kW (ideal) | 5.5kW (adequate) |
| Foundation | Gravel pad OK | Concrete pad recommended |

### Sweet Spot Compromise: 44-45" / 120-130 gal
- Only ~$300-440 more than dedicated 2-person
- Keeps 5.5kW heater in optimal range
- Two people spacious, four people cozy but feasible
- Monthly cost only $3-5 more than 2-person

### Final Recommendation (Unchanged): Build the 2-Person First
- Simpler, cheaper, heatable with single 5.5kW
- Total materials ~$500-700 (lumber + hardware + sealant)
- Achievable in 8-12 build sessions
- Can always build a second/larger tub with experience gained

---

*Loop 2 — Cross-Pollination Complete. All 10 agents refined.*

---

# ═══════════════════════════════════════════════════════════════
# LOOP 3 — INTEGRATION (Conflict Resolution & Alignment)
# ═══════════════════════════════════════════════════════════════

## Conflicts Resolved

### 1. Construction Method — FINAL: Rectangular Box
- Round cooperage eliminated (requires power bevel cuts)
- Agent 2's cooperage approach and Agent 10's round compromise dropped
- Rectangular stacked-plank with through-bolted battens is the single approved method

### 2. Lumber Pricing Standardized
- Agent 1 implied $4-6/BF, Agent 2 implied $8-12/BF
- **Resolved: $6-8/BF** for quality clear/VG WRC in 8/4 stock
- 2-person: ~85-90 BF = **$540-720**
- 4-person: ~130-140 BF = **$780-1,120**

### 3. Hardware Cost Aligned
- Agent 1 said $80-150 (assumed zinc/304 SS)
- Agent 2 said $336 (proper 316 SS)
- **Resolved: ~$310** for 316 SS throughout (non-negotiable for salt water)

### 4. Student Hours — FINAL
- Agent 9 said 20-55 hrs, Agent 3 said 40-109 hrs
- Root cause: Agent 9 correctly removed power-tool milling from student scope
- **Resolved: Student hours = 20-55 (hand tools only). Adult adds 15-30 hrs for milling.**
- Total project hours: 35-85 depending on scenario

### 5. Monthly Operating Cost — FINAL
- Agent 7 original: $43-175/mo. Agent 8 original: $30-75/mo
- **Resolved: $31-75/month typical.** Up to $85-95 in cold-climate winter.
- Breakdown: Electricity $8-35, Water $3-6, H2O2 $15-25, Salt $2-4, Misc $3-5

### 6. H2O2 Dosing — FINAL
- Conflict between 3% and 35% concentrations resolved with dual protocol:
- **3% drugstore:** 6-8 fl oz per 150 gal (maintenance), 16 fl oz (shock). Cost: ~$19/mo
- **35% food-grade:** 0.5-0.7 fl oz per 150 gal (maintenance), 1.5 fl oz (shock). Cost: ~$9/mo
- Target residual: 30-50 ppm. Test with H2O2 strips before each soak.

### 7. Salt Concentration — FINAL
- Options were 0.2%, 0.3%, or 0.5%
- **Resolved: 0.2%** — provides silky feel with minimal corrosion risk
- **Exact amount: 2.5 lbs non-iodized pool salt per 150 gal fill**

---

## FINAL ALIGNED BUDGET (Loop 3)

### 2-Person Construction
| Category | LOW | MID | HIGH |
|----------|-----|-----|------|
| WRC Lumber (~85 BF) | $340 | $425 | $510 |
| 316 SS Hardware | $250 | $310 | $420 |
| 5.5kW Heater + Pump | $300 | $400 | $500 |
| Plumbing/fittings | $30 | $50 | $75 |
| Student labor (20-55 hrs @ $15/hr) | $300 | $525 | $825 |
| Electrician (240V circuit) | $150 | $275 | $400 |
| Misc (sandpaper, sealant, tools) | $40 | $65 | $100 |
| **TOTAL** | **$1,410** | **$2,050** | **$2,830** |

### 4-Person Construction
| Category | LOW | MID | HIGH |
|----------|-----|-----|------|
| WRC Lumber (~130 BF) | $520 | $650 | $780 |
| 316 SS Hardware | $350 | $470 | $590 |
| 5.5-11kW Heater + Pump | $380 | $500 | $650 |
| Plumbing/fittings | $40 | $65 | $100 |
| Student labor (+30%) | $390 | $680 | $1,070 |
| Electrician | $150 | $300 | $500 |
| Misc | $50 | $80 | $130 |
| Foundation | $100 | $175 | $300 |
| **TOTAL** | **$1,980** | **$2,920** | **$4,120** |

### Year 1 All-In
| | 2-Person MID | 4-Person MID |
|--|-------------|-------------|
| Construction | $2,050 | $2,920 |
| 12 mo operating ($49/mo) | $588 | $735 |
| **Year 1 Total** | **$2,638** | **$3,655** |

### 5-Year Cost of Ownership
| | 2-Person MID | 4-Person MID |
|--|-------------|-------------|
| Year 1 | $2,638 | $3,655 |
| Years 2-5 operating | $2,352 | $2,940 |
| Maintenance reserve | $300 | $400 |
| **5-Year Total** | **$5,290** | **$6,995** |

---

## FINAL TIMELINE (Loop 3)

| Scenario | Calendar Weeks | Student Hrs | Adult Hrs | Total Hrs |
|----------|---------------|-------------|-----------|-----------|
| Super Fast (pre-cut kit) | 3-4 | 20-25 | 15-20 | 35-45 |
| Fast (rough lumber + adult cuts) | 4-6 | 25-35 | 20-30 | 45-65 |
| Medium (educational pace) | 8-12 | 40-55 | 20-30 | 60-85 |

4-person adds ~30-40% to all hour counts and 1-2 weeks to calendar time.

---

## FINAL WATER MANAGEMENT PROTOCOL (Loop 3)

### Water Change Schedule
| Usage | Drains/Week | Interval | Annual Water Cost |
|-------|-------------|----------|-------------------|
| Light (1-3 soaks/wk) | — | Every 4 weeks | ~$8 |
| Moderate (4-7 soaks/wk) | — | Every 2-3 weeks | ~$16 |
| Heavy (daily) | — | Every 7-10 days | ~$31 |

### Day 1 Setup Checklist
1. Fill tub with clean water, note source TDS
2. Heat to 100-104°F
3. Dissolve 2.5 lbs pool salt in bucket, add to tub
4. Add shock dose H2O2 (16 oz of 3% OR 1.5 oz of 35%)
5. Wait 30 min, test H2O2 residual (target 30-50 ppm)
6. Test pH (target 7.0-7.4), record TDS baseline
7. Shower before entering (reduces organic load ~70%)
8. Post-soak: add maintenance H2O2 dose, replace cover

### Drainage
- H2O2-treated water is safe for lawn/garden (breaks down to water + oxygen)
- Salt water at 0.2%: drain to sanitary sewer or rotate across 3-4 lawn zones
- Never drain to storm drains (likely illegal, fines $1,000+)

---

*Loop 3 — Integration Complete. All conflicts resolved.*

