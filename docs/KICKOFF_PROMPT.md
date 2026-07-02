# KICKOFF PROMPT — paste this to the executor model first

You are picking up development of **UNTITLED RPG**, a Godot 4.3 GDScript mobile
side-scrolling action RPG. Two authoritative handoff documents exist in this repo. You must
read them before doing anything else.

## Step 1 — Read, in this exact order (do not skim)
1. `docs/CODEBASE_CONTEXT.md` — the architecture/conventions reference.
2. `docs/MASTER_PROMPT.md` — your task: an 8-phase plan with specs and acceptance criteria.

Also open and actually read the real source files referenced there before editing them —
especially `playercontroller.gd`, `player_animator.gd`, `weapon_data.gd`,
`weapons/animators/*.gd`, `slime.gd`, `player.tscn`, `global.gd`, and `project.godot`. Do
not assume behavior; verify it in the code.

## Step 2 — Confirm understanding before writing code
Reply with a short confirmation that includes:
- A 5–8 line summary of the architecture in your own words (puppet animator, WeaponData +
  WeaponAnimator plugin pattern, signal wiring, groups, collision layers).
- The four locked design decisions from MASTER_PROMPT (audit scope = fix everything; dodge
  roll REPLACES evade; boss runs in a new `boss_arena.tscn`; attacks are 8-directional via
  one angle-parameterized swing builder).
- The three critical gaps you must respect: player has NO `take_damage`/hurtbox/death yet;
  there is NO custom InputMap (only `ui_accept`); the attack charge is BINARY and must be
  made continuous for the mage laser.
- Any point in the docs you find ambiguous or risky — ask me, do not guess.

## Step 3 — Execute
- Follow the phases **in dependency order** (Phase 0 → 8). Do not jump ahead.
- **Non-negotiable rules** (from MASTER_PROMPT §0): match existing conventions
  (programmatic UI, code-driven puppet animation, data-driven weapons, signals, groups);
  Godot 4.3 APIs only; typed GDScript; scene-safe spawning with `is_instance_valid()`
  guards (no orphan-prone `get_tree().current_scene` / `get_parent().get_parent()`); no
  hardcoded viewport coordinates; keep touch and PC input behavior-identical through one
  input layer.
- **Leave the game runnable after every phase.** After each phase, run it on PC and verify
  that phase's Acceptance criteria; report what you tested and the result before moving on.
- Do not break the existing flow: the project must still boot from `titlescreen.tscn` and
  play normally, in addition to the new `boss_arena.tscn` quick-launch.
- Preserve public APIs/signals when refactoring (Phase 8) so existing scenes keep working.

## Guardrails
- If a change would regress a working system, stop and flag it instead of proceeding.
- Do not delete or overwrite anything you didn't create without first reading it and
  confirming it matches how the docs describe it.
- Keep commits/edits scoped per phase so changes are reviewable.
- When a spec is open to interpretation (e.g. the boss's "swords gain attack points at
  will"), follow the interpretation written in MASTER_PROMPT Phase 7 (visible, telegraphed
  per-sword randomized damage — unpredictable but fair). If you want to deviate, ask first.

Begin with Step 1 now. Do not write or modify any code until you have completed Steps 1–2
and I have answered any questions you raise.
