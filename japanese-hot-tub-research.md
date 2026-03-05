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
- **Status**: IN PROGRESS
- **Objective**: Each agent conducts independent research on their specialty
- **Results**: (pending)

### Loop 2 - Cross-Pollination
- **Status**: PENDING
- **Objective**: Agents review Loop 1 findings and refine with cross-agent context

### Loop 3 - Integration
- **Status**: PENDING
- **Objective**: Agents integrate findings, resolve conflicts, align numbers

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

