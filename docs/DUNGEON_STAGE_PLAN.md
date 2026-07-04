# DUNGEON STAGE 1 — Design & Build Plan (pilot: static, escape-themed)

> **Plan doc — written BEFORE build** (per request). An executor model builds
> from this. Grounds every system in the current codebase, specifies a modular
> layout that is **static now but procedural-ready**, and lays out a phased,
> headless-testable build order. `[PROPOSAL]` marks a default to steer.
> Companion: `ARCHITECTURE.md`. Current as of `f5f4b29`.

---

## 0. Goal

Stage 1 is a **flat side-scrolling dungeon the player must escape**: start
behind a broken cell door, fight out through corridors and chambers (slimes,
smashable pots, breakable doors, simple interactive gates), and reach the exit —
which the **FOURBLADE boss guards** in the final chamber. Beat it, the gate
opens, you escape.

- **Flat** (horizontal, single ground plane — no vertical platforming maze).
- **Modular**: assembled from reusable room/corridor **module scenes**.
- **Static for the pilot**, but built on an assembler that a procedural
  generator can drive later with zero changes to the modules.
- **Connected**: one continuous scene from cell → boss chamber → exit.
- Dungeon-feel detail: torchlight, stone, **light vegetation**, **breakable
  pots**, and **interactive elements** (levers, chest, exit gate).

---

## 1. Design pillars

1. **Modules + connectors, assembled from a layout list.** Every room is a
   self-contained scene with fixed-height floor and left/right **connection
   ports**. A `DungeonAssembler` places modules in a sequence, snapping each
   module's `PortLeft` to the previous module's `PortRight`. The pilot's
   sequence is a **hardcoded layout array**; the procedural version generates the
   same array. *This array IS the procedural seam.*
2. **Reuse the combat plumbing.** Breakables take hits through the SAME path
   enemies do (see §5) — no new damage system. Interactables use the existing
   `interact` action (`PlayerInput.interact_pressed`, currently unwired).
3. **Match conventions.** Collision = `StaticBody2D` + shapes on the Environment
   layer (like `DemoMap`/`boss_arena`); decor = code-drawn `Polygon2D`/`Line2D`
   and small prop scenes; VFX/shatter through the `Fx` autoload; typed GDScript.
4. **The boss is already built** — the boss chamber module reuses
   `boss_fourblade.tscn`; don't rebuild it.

---

## 2. Layout — the escape route (pilot, static)

Left → right, one ground plane. `‖` = breakable door gate, `⌐` = lever,
`▯` = pot cluster, `※` = vegetation, `S` = slime(s), `▣` = chest, `⚑` = exit gate.

```
[CELL] ‖→ [CORRIDOR ※▯] → [CHAMBER_S  S S ▯] → [CORRIDOR ▯▯] → [GUARDROOM ⌐‖ S ▣]
   →  [CORRIDOR ※] → [CHAMBER_L  S S S ▯※] → [ANTECHAMBER ‖(heavy) torches]
   →  [BOSS_CHAMBER  FOURBLADE ... ⚑exit(locked until boss dies)]
```

- **CELL** — start. A **breakable barred door** (`‖`) seals the cell; smashing it
  (or a lever) begins the escape. Sets the tone.
- **CORRIDORs** — straight halls (variants: plain / pots / vegetation). Connective
  tissue + light hazards.
- **CHAMBER_S / CHAMBER_L** — combat rooms with slimes, pots, vegetation.
- **GUARDROOM** — a **lever** (`⌐`) opens a **breakable door** you could also just
  smash; a **chest** (`▣`) rewards exploration.
- **ANTECHAMBER** — ominous torch-lit room; a **heavy breakable door** into the
  boss (only breakable, no lever — a deliberate "point of no return").
- **BOSS_CHAMBER** — reuses `boss_fourblade.tscn`; the **exit gate** (`⚑`) is
  locked until the boss dies, then opens → escape (title / victory).

**[PROPOSAL]** ~9 modules, ~4000–5000px wide total. Tunable via the layout array.

---

## 3. Module system

### 3.1 Module contract
Each module is a `.tscn` under `dungeon/modules/` with:
- Root `Node2D` (script `dungeon_module.gd`, `class_name DungeonModule`).
- Floor/walls: `StaticBody2D` + `CollisionShape2D` on the **Environment** layer
  (value 1), floor top at a shared `FLOOR_Y = 0` so modules line up flat.
- **Ports:** `Marker2D` children named `PortLeft` and/or `PortRight` at floor
  level. The assembler aligns `next.PortLeft` onto `prev.PortRight`.
- `@export var module_width: float` (or derive from ports) for placement.
- Content children: decor, `Slime` instances, breakables, interactables.
- Optional `@export var tags: Array[String]` (e.g. `["combat","corridor"]`) so
  the future generator can pick by role.

### 3.2 Assembler
`dungeon/dungeon_assembler.gd` on the stage scene root:
```
@export var layout: Array[String]   # ordered module scene paths (the pilot layout)
func _ready(): _assemble()
func _assemble():
    var cursor := Vector2.ZERO
    for path in layout:
        var m := load(path).instantiate(); add_child(m)
        # position so m.PortLeft lands on cursor; advance cursor to m.PortRight
```
- **Static pilot:** `layout` is filled in the `.tscn` inspector / a const array =
  the §2 sequence.
- **Procedural later:** a `DungeonGenerator` produces the `layout` array (picking
  modules by `tags`, guaranteeing a start, a boss room, and connectivity) and
  hands it to the same assembler. **No module or assembler change needed.**
- Player spawns at the CELL module's `PlayerSpawn` marker.

---

## 4. Environment & dungeon feel (no tilesets — code/prop-driven)

Keep the project's asset-light, code-drawn style.

- **Structure:** stone floor + walls as `StaticBody2D` collision with
  `Polygon2D` facing — flagstone floor strips and coursed wall blocks with slight
  per-block color jitter (dark cool greys/browns) so it reads as masonry, not a
  flat bar. A ceiling band + side pilasters frame corridors.
- **Atmosphere lighting [PROPOSAL]:** a `CanvasModulate` dims the stage to a cool
  dark tint; **torches** (`dungeon/props/torch.tscn`) place a flickering
  `PointLight2D` + a small code-drawn flame (`Polygon2D` + `Fx`-style ember
  particles) so pools of warm light punctuate the gloom. *Mobile renderer
  supports 2D lights; if perf/normal-maps are a concern we fall back to
  additive-blend glow sprites — verify early (open Q).*
- **Light vegetation:** hanging moss/vines (`Polygon2D` strands), floor grass
  tufts, mushrooms, small roots creeping over stone — decorative, non-colliding,
  gentle sway via a shared `_process` sway or a tiny tween. `props/vines.tscn`,
  `props/grass_tuft.tscn`, `props/mushroom.tscn`.
- **Dressing:** cracks, rubble piles, scattered bones, hanging chains, wall
  banners, floor puddles, cell bars. All non-colliding `Polygon2D`/`Line2D`.
- Parallax back layer (optional) — distant dark arches for depth.

---

## 5. Breakables (pots, doors, crates) — reuse the combat path

`class_name Breakable extends StaticBody2D` (`dungeon/breakable.gd`):
- `collision_layer` includes **EnemyHurtbox (value 4)** so the player's
  `AttackHitbox` (mask 4, `body_entered`) and the mage laser (mask 4 raycast)
  already detect it. In group **`"breakable"`** (NOT `"enemy"` — so slime aggro,
  bombug targeting, and prayer-lightning "nearest enemy" never target pots).
- `func take_damage(amount, knockback=Vector2.ZERO)` → deduct HP (pots ~1 hit),
  on 0 → `_shatter()` (spawn `Fx` shards/dust, optional loot drop, `queue_free`).
- **Player hookup (small edit):** extend `_on_attack_hit` and the laser hit loop
  to accept `is_in_group("enemy") OR is_in_group("breakable")`. One-line each;
  keeps everything else intact. *(This is the only player-combat edit.)*

Variants:
- **Pot / crate** — layer 4 only (doesn't block movement); 1 hit; shards + puff;
  `[PROPOSAL]` small chance to drop a heal/mana pickup or nothing.
- **Breakable door** — layer `1 | 4` (**Environment + EnemyHurtbox**): blocks the
  player body (a real gate) *and* is smashable. More HP (several hits). On break:
  clear collision, splinter VFX, open passage. Some doors also open via a lever
  (§6) so a player can choose stealth-ish vs. brute force.

`Fx` additions: `shatter(pos, color)` (pottery shards + dust), `splinters(pos)`
(wood). Scene-safe, guarded like the rest.

---

## 6. Interactive elements

Wire the **existing but unused** interact path:
- `PlayerInput.interact_pressed` → connect in `playercontroller._ready` to a new
  `_on_interact()` that calls `interact(self)` on the **nearest Interactable in
  range**.
- Player tracks nearby interactables via an `Area2D` "InteractProbe" (or a
  group+distance scan over `"interactable"`); shows a small prompt (a floating
  "E" via `Fx`/a Label) on the closest.

`class_name Interactable extends Area2D` (`dungeon/interactable.gd`):
- `signal interacted(by)`, `func interact(by): ...`, `prompt_text := "USE"`.

Elements:
- **Lever / switch** (`props/lever.tscn`) — on interact, toggles a target
  breakable door open (via an exported `NodePath`/group id), clanks, animates.
- **Chest** (`props/chest.tscn`) — opens once, drops loot (a weapon `ItemInstance`
  into inventory via `ItemDB`, or a pickup), lid animates.
- **Exit gate** (`props/exit_gate.tscn`) — starts **locked**; listens for the
  boss's `died` signal; on boss death it unlocks + interact → escape
  (`change_scene_to_file` to title / a victory screen). This is the win condition.
- (Optional) **wall torch** is decor, not interactable.

---

## 7. Enemies

- **Slimes** placed in chamber/corridor modules as `slime.tscn` instances (they
  already patrol/aggro/lunge on `EnemyBase`). `[PROPOSAL]` a couple per combat
  room, sized by the slime's own random scale.
- **Optional spawn-on-enter:** a module can hold its slimes inactive until the
  player crosses an entry `Area2D`, to control pacing — nice-to-have, not v1.
- Boss chamber = `boss_fourblade.tscn` (already complete).

---

## 8. Collision layers / groups (additions)

- Reuse: Environment=1, PlayerHitbox=2, EnemyHurtbox=4, PlayerHurtbox=8,
  EnemyHitbox=16, Projectile=32 (unchanged).
- **Breakable** rides **EnemyHurtbox (4)** (+ Environment(1) for doors), group
  `"breakable"`.
- **Interactable** = `Area2D`, its own light mask so the player's InteractProbe
  finds it; group `"interactable"`. `[PROPOSAL]` reuse a spare bit or just use
  group+distance (no new physics layer needed).

---

## 9. Camera / flow

- Player `Camera2D` already follows (zoom 2). For the pilot, free-follow is fine;
  `[PROPOSAL]` add optional camera limits from the assembled bounds so it doesn't
  show past the end walls. Per-room "lock" cameras are a later polish.
- **Entry:** `[PROPOSAL]` reroute `class_selection → dungeon_stage_1.tscn`
  (Stage 1 becomes the real first level). Keep `DemoMap` as a sandbox and
  `boss_arena` as the test harness. *Confirm before rerouting (open Q).*
- **Escape objective:** a lightweight objective line on the HUD ("ESCAPE THE
  DUNGEON" → "THE WAY IS GUARDED" → "THE GATE IS OPEN"). Optional for v1.

---

## 10. Procedural-ready seam (how the pilot becomes generated)

- Modules never hardcode neighbors — they only expose ports + tags.
- The assembler consumes a **layout array**; the pilot fills it statically.
- Later `dungeon/dungeon_generator.gd` builds that array (seeded RNG; rules:
  start=CELL, end=BOSS_CHAMBER, N combat/corridor modules between, no dead ends
  since it's linear-flat) and feeds the identical assembler. Swapping static→
  procedural is changing who fills `layout`, nothing else.

---

## 11. New files (indicative)

```
dungeon/dungeon_stage_1.tscn/.gd      # the assembled pilot stage (root + assembler)
dungeon/dungeon_assembler.gd          # layout → placed modules
dungeon/dungeon_module.gd             # class_name DungeonModule (ports/tags)
dungeon/breakable.gd                  # class_name Breakable
dungeon/interactable.gd               # class_name Interactable
dungeon/modules/mod_cell.tscn
dungeon/modules/mod_corridor(_a/_b).tscn
dungeon/modules/mod_chamber_small.tscn
dungeon/modules/mod_chamber_large.tscn
dungeon/modules/mod_guardroom.tscn
dungeon/modules/mod_antechamber.tscn
dungeon/modules/mod_boss_chamber.tscn
dungeon/props/{torch,pot,crate,door,vines,grass_tuft,mushroom,lever,chest,exit_gate}.tscn
autoload/fx.gd                        # + shatter/splinters (small additions)
playercontroller.gd                   # + interact wiring; breakable in attack/laser hit checks
tests/test_dungeon.gd, tests/test_breakable_interact.gd
```

## 12. Build order (phased — each ships green, headless-testable)

1. **Breakable system** — `breakable.gd` + `pot`/`crate`/`door` props; player
   attack/laser hit checks accept `"breakable"`; `Fx.shatter/splinters`.
   `test_breakable_interact.gd`: a pot dies to one swing; a door blocks the
   player then opens when smashed; a slime never targets a pot.
2. **Interactable system** — `interactable.gd` + interact wiring + probe/prompt;
   `lever` opens a door; `chest` grants an item. Extend the test.
3. **Module + assembler** — `dungeon_module.gd`, `dungeon_assembler.gd`, and 2–3
   modules; verify ports snap flat and the player can traverse. `test_dungeon.gd`.
4. **Full pilot layout** — author all modules + the §2 sequence into
   `dungeon_stage_1.tscn`; place slimes; connect the boss chamber + exit gate
   (opens on boss `died`).
5. **Dungeon-feel pass** — stone facing, `CanvasModulate` + torches, vegetation,
   dressing.
6. **Flow hookup** — reroute `class_selection → dungeon_stage_1` (pending open Q);
   optional camera limits + objective HUD line.

## 13. Test plan (headless, like existing suites)
- Breakable: 1-hit pot shatters + frees; door blocks body then opens on break;
  pot is NOT in "enemy" (slime/prayer ignore it).
- Interact: `interact_pressed` triggers the nearest interactable; lever opens its
  door; chest grants once.
- Assembler: N modules place with aligned ports (no gaps/overlaps); player spawn
  at the cell; a walk from spawn reaches the boss chamber x-range.
- Exit gate: locked while boss alive → unlocks on boss `died`.
- Regression: full existing suite stays green.

## 14. Open questions (steer before build)
1. **Reroute the main flow now** (class_selection → dungeon_stage_1), or keep it
   opt-in behind a title button until it's fleshed out? (Default: build the
   scene, add a title "STAGE 1" button, reroute only when you say.)
2. **Boss inside the dungeon scene** (one connected environment, my default) vs.
   a door that transitions to the existing `boss_arena.tscn`?
3. **2D lighting** (CanvasModulate + PointLight2D torches) on the Mobile
   renderer — go for real lights (atmosphere) or additive-glow fake-out
   (safer/cheaper)? I'll prototype one torch first to confirm.
4. **Loot from pots/chests** — drop pickups (heal/mana/weapons) now, or leave
   breakables purely cosmetic/juicy for the pilot?
5. **Escape framing** — end on boss death + gate (return to title), or is there a
   short "you escaped" beat/victory screen you want?
