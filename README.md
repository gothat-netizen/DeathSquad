# Kill Team Digital -- Godot 4 Adaptation

Digital adaptation of Warhammer 40,000: Kill Team (3rd edition, rules
sourced from Wahapedia) -- a turn-based isometric tactical skirmish game.

This is the **Phase 1** scaffold: folder structure, architectural
boundaries, and stub scripts. Nothing here is gameplay-functional yet --
every stub has a `push_warning(...)` marking which phase implements it,
per the project's incremental-build discipline (no phase is skipped;
incomplete subsystems are labeled, not silently left as dead code).

## Architecture at a glance

```
core/           Pure rules engine. No dependency on presentation/, ui/, ai/.
  dice/         Centralized RNG service (Phase 4)
  rules/        Movement, combat, LoS, cover, effects, precedence (Phase 5-8)
  state/        GameState, OperativeState, MissionState, TurnState (Phase 3)
  events/       EventBus payloads and event name constants (Phase 3)
  resources/    Data schemas: OperativeData, WeaponData, FactionData, etc. (Phase 2)

data/           Content as Resources (.tres) -- designer/data-editable.
                Currently READMEs only; populated from Phase 12 onward.

ai/             AI controller + evaluators. Uses the SAME RulesEngine
                calls a human player's UI would use. (Phase 9)

presentation/   Visual layer: battlefield, operative views, LoS/movement
                visualizers. Reads GameState, never mutates it. (Phase 10-11, 16)

ui/             Main menu, game setup, HUD, inspectors, options, rules
                reference. Requests legality from RulesEngine; never
                calculates it locally. (Phase 11)

save/           Local-only save/load (StateSnapshot-based). (Phase 14)

debug/          Debug overlay/console, gated behind an explicit toggle.

autoload/       Godot singletons: EventBus, GameStateManager, DiceService,
                ContentDatabase.

tests/          unit/ (single-module, no scene tree) and integration/
                (full activation/turning-point/save-load sequences). (Phase 15)
```

## Rules source

Wahapedia Kill Team 3rd edition core rules, plus the Death Korps and
Kommandos faction pages -- see `/mnt/user-data/outputs/` chat history
for the full rules-to-architecture mapping documents produced before
this scaffold (kill-team-rules-mapping.md, death-korps-kommandos-mapping.md).

## Dependency rule

`core/` and `data/` never import from `presentation/`, `ui/`, or `ai/`.
Everything else depends on `core/` and `data/`, and communicates
laterally only through `EventBus`. If you find yourself importing
`presentation/` from inside `core/`, something has gone wrong.

## Status

**Tracked for later:** a real player/AI decision-prompt system is owed
in several places now -- Initiative (Phase 4/6), `PrecedenceResolver`'s
levels 5-6 (Phase 5), which action a ready operative performs (Phase
6), three combat choices (Phase 7): Obscured's "discard one success of
your choice", Shoot's defence-dice block allocation, and Fight's
strike-or-block choice per die, and exact marker-placement position
for Place Marker (Phase 8). All currently use a documented placeholder
policy instead of asking. Deferred by request until the relevant phase
(AI: Phase 9, UI: Phase 11) rather than built piecemeal now.

Phase 1 complete: project opens (Godot 4.3+), Main Menu scene runs,
folder structure and stub scripts are in place, autoloads are
registered.

Phase 2 complete: core Resource schemas (`core/resources/`) are fully
fielded and typed, including the previously-missing `UniqueActionData`.
Proof-of-concept content exists for two operatives pulled directly from
Wahapedia -- Death Korps Trooper and Kommando Boy, each with their real
weapons (Lasgun/Bayonet, Slugga/Choppa) and their procedural ability
stub (Group Activation, Taktical Wot-notz) -- wired into
`ContentDatabase` so faction/operative/weapon lookup by id works.
`tests/unit/test_phase2_data_load.gd` is a headless smoke test proving
the schema round-trips (run with
`godot --headless --script res://tests/unit/test_phase2_data_load.gd`
once you have the Godot editor -- not runnable in the sandbox this was
built in, so give it a run and let me know if anything doesn't load).

Weapon rules that need a `RuleEffect` subclass (e.g. Slugga's Range 8")
are intentionally left off these two proof-of-concept weapons for now --
that system lands in Phase 5, populated with content in Phase 12.

Phase 3 complete: `GameStateManager` (autoload) now actually runs a
game -- `start_new_game()` spawns both rosters into a live `GameState`,
then drives the Strategy phase (Initiative, Ready-step CP math
including the turn-1 catch-up rule, readying all operatives) and the
Firefight phase (activation bookkeeping, forced-activation queue for
things like Group Activation, counteract eligibility, turning-point-
end detection). Every transition emits a real event over `EventBus`
using the `GameEvents` constants. `tests/unit/test_phase3_game_state.gd`
drives two full turning points and asserts on both state and event order.

Phase 4 complete: `DiceRoller` (`core/dice/`) is fully implemented --
deterministic given a seed, shared classification logic for attack AND
defence dice (unmodified 1 always fails, unmodified 6 always crits,
threshold decides the rest), `roll_d3()`, single-die rolls, a reroll
primitive, and a generic `roll_off()` with tied-contestant re-rolling.
Every roll is logged (`DiceRoller.roll_log` / `DiceService.get_roll_log()`).
`RollResult` gained success-counting helpers. `tests/unit/test_phase4_dice.gd`
checks determinism, classification correctness (500-roll sample), D3
bounds, and roll-off winner selection.

Phase 6 complete: real movement and spatial rules.

- **`movement_rules.gd`** implements all four movement actions
  (Reposition, Dash, Fall Back, Charge) as one parameterized function,
  matching the core rules' own framing of them as variations on
  Reposition. Confirmed against the actual rules text: distance is
  measured in straight-line increments **rounded up individually before
  summing** (not the total distance rounded once -- verified against
  the core rules' own worked example, 0.5"+2.75" -> 1"+3" = 4"), same-
  activation mutual exclusivity is asymmetric exactly as written (e.g.
  Dash only excludes Charge, not Reposition), Reposition/Dash can't
  pass through *or* finish within an unassisted enemy's control range
  (checked per path segment, not just the endpoint), Fall Back requires
  already being engaged and lifts the passing-through restriction,
  and Charge requires ending engaged and is blocked by a Conceal order.
- **`line_of_sight_rules.gd`** implements Control Range (mutual,
  within 1" AND visible) and a real distance-to-segment/line-vs-rect
  geometry layer for it. Honest scope note: there's no terrain/map data
  yet (Phase 10/13), so `is_visible()` takes an explicit obstacle list
  rather than querying a battlefield that doesn't exist -- open ground
  (no obstacles) means everything is visible, which is correct but
  incomplete until real terrain lands.
- **`RulesEngine.validate_move()`/`execute_move()`** are wired for
  real now, gathering enemies/friendlies from `GameState` and (on
  success) mutating the operative's actual position and emitting
  `OPERATIVE_MOVED`.
- **Initiative got a correctness fix** while I had the exact rules
  text open: the roll-off winner *decides* who gets initiative (not
  automatically takes it), and the tie-break is the previous non-
  initiative player deciding -- both are real player/AI decisions with
  no prompt system yet, so this joins the Initiative-tie-break/
  Precedence-tie seam already tracked for Phase 9/11. Turning point 1's
  initiative (mission-pack-dependent, per the actual rule) is a
  placeholder until Phase 13.
- **Surfaced and documented a real gap**: `GameStateManager.start_new_game()`
  spawns every operative at `Vector2.ZERO` -- there's no deployment-zone
  system yet, so both rosters currently stack at the origin. Harmless
  until something checks distance/control-range at game start, which
  Phase 6's own movement validation does -- flagged directly in the
  code rather than quietly worked around.

`tests/unit/test_phase6_movement.gd` covers the increment-rounding
example, all four actions' distance and control-range legality
(including the pass-through-with-an-assisting-friendly case), Conceal
blocking Charge, the asymmetric mutual-exclusivity rules, and the
RulesEngine wiring (real mutation + event emission).

Phase 7 complete: real Shoot and Fight, verified against the actual
core rules text (re-fetched to get the exact sequence right rather
than work from the earlier summary doc).

- **`combat_rules.gd`** implements Shoot's full six-step sequence
  (select weapon -> valid target -> roll attack dice -> roll defence
  dice -> resolve defence dice -> resolve attack dice) and Fight's
  genuinely different pipeline (simultaneous rolls with per-assist Hit
  improvement, then ALTERNATING one-success-at-a-time resolution,
  attacker first, no separate defence roll at all). Kept as two
  functions on purpose -- confirmed again that merging them would mean
  branching exactly where the spec says not to.
- **Valid Target got a correction while implementing it**: the rules
  don't just say "visible (+not in cover if Conceal)" -- a target is
  also invalid if any of the *shooter's own* friendly operatives are
  within its control range (no shooting into your own melee). Missed
  in the earlier rules-mapping doc; caught and fixed here.
- **Obscured** correctly downgrades all crits to normal *and* makes
  the attacker discard one success, as two independent rules (not one
  combined effect) -- `resolve_shoot()` applies both.
- **`cover_rules.gd`** implements Cover (intervening terrain within
  the target's control range, never within 2" of the attacker) and
  Obscured (intervening Heavy terrain, ignoring parts within 1" of
  either operative) as genuinely independent checks. One documented
  simplification: "cannot be in cover from and obscured by the same
  terrain feature -- defender chooses" isn't implemented (a real
  defender decision, same seam category as Initiative/Precedence).
- **Three more placeholder policies**, all documented in the code
  rather than silently guessed: Obscured's "discard one success of
  your choice" defaults to discarding a normal success; Shoot's
  defence-dice block allocation is a greedy heuristic, not necessarily
  optimal; Fight's strike-or-block choice always strikes, never
  blocks. All are real per-die player decisions with no prompt system
  yet -- joining the same tracked list as Initiative/Precedence/
  action-selection rather than becoming one-off guesses.
- **`RulesEngine`** wires `get_valid_targets()`, `validate_attack()`
  (Conceal order and control-range preconditions, same-activation
  Shoot repeat check), `resolve_shoot()`, and `resolve_fight()`
  (computing real assist counts from `GameState`), emitting
  `ATTACK_RESOLVED`, `DAMAGE_APPLIED`, and `OPERATIVE_INCAPACITATED`.

`tests/unit/test_phase7_combat.gd` covers Conceal+cover invalidating a
target, the friendly-near-target block, Obscured's crit-downgrade,
damage math actually matching wounds lost, a full Fight exchange, and
the RulesEngine preconditions (Conceal blocks Shoot; repeating Shoot
in one activation is rejected) against a live `GameState`.

Phase 8 complete: real objective/marker mechanics, confirmed against
the core rules' Markers section.

- **`MarkerState`** (new) is the runtime marker instance -- position,
  who's carrying it (if anyone), and a cached controlling player used
  to detect changes.
- **`objective_rules.gd`** implements Control (contest within 1" +
  visible, friendly total APL vs enemy total APL -- a tie means
  uncontrolled, not a coin flip) and the carrying-operative-is-the-
  only-contester rule, plus Pick Up Marker / Place Marker as real
  actions with their legality checks (requires control to pick up,
  can't Place in the same activation as Pick Up unless incapacitated,
  the incapacitated-carrier exception is free and exempt from the
  repeat-action rule).
- **`RulesEngine`** wires marker control queries and both actions, and
  `refresh_all_marker_control()` recomputes every marker after each
  activation (positions/wounds shift control even without a marker
  action) and fires `OBJECTIVE_CONTROLLED` only on an actual change --
  wired into `GameStateManager.activate_operative()`.
- Two things deliberately left as documented gaps rather than guessed:
  exact marker-placement position is a real player decision (defaults
  to the operative's own position -- joins the tracked decision-prompt
  list), and "control cannot change mid-action" isn't enforced as a
  snapshot since there's no action-sequencing orchestration layer that
  would need it yet.
- **VP scoring stays out of scope on purpose**: the core rules define
  HOW markers are controlled, not WHEN that scores points -- that's
  mission-pack content (Phase 13, no mission data exists yet).
  `MissionState.victory_points` is a plain accumulator with nothing
  wired to it automatically. Re-labeled `MissionData.counts_operative_for_scoring()`
  from Phase 8 to Phase 13 accordingly -- it was mis-attributed
  earlier.

`tests/unit/test_phase8_objectives.gd` covers uncontested/contested/
tied control, the carrying-only-contests rule (even against a higher-
APL bystander), both marker actions' legality (including the outnumbered-
so-denied-pickup case and the incapacitated-carrier exception), and
the live control-change event through a real `GameStateManager` activation.

Deliberately NOT implemented yet: Climb/Drop/Jump and real terrain
(Phase 10/13), `RuleEffect`-driven weapon/ability content (Phase 12),
and mission-pack VP scoring (Phase 13).

Phase 5 complete: the rules-engine foundation now actually resolves
things.

- **`EffectResolver`** dispatches `RuleEffect`s by timing (PRE_ROLL /
  POST_ROLL / POST_ACTION) and enforces the APL +/-1 and Move >=4"
  hard clamps.
- **`TimedStatusEffect`** (new) is the generic bounded-duration
  stat-modifier component flagged back in the Death Korps/Kommandos
  mapping doc -- it backs both the universal Stun weapon keyword
  ("APL -1 until end of its next activation") and Death Korps'
  Guardsmen Orders (turning-point-scoped, mutually exclusive --
  applying a new order in the same `exclusivity_group` replaces the
  old one instead of stacking). `OperativeState.get_effective_apl()`/
  `get_effective_move()` are now the real source of truth for those
  stats, folding in Injured's -2" Move penalty too.
- **`StatModifierEffect`** (new, `core/resources/effects/`) is the
  first concrete `RuleEffect` subclass -- generic enough to count as
  foundation infrastructure rather than Phase 12 content, since Stun
  is a universal keyword, not faction-specific.
- **`PrecedenceResolver`** implements the real 6-level precedence
  system. The first four levels (specific rule / designer's
  commentary / non-core-book rule / "cannot" beats "can") resolve
  automatically from `RuleEffect` metadata. Levels 5-6 ("active
  player decides", falling back to "initiative player decides")
  **need a real decision prompt that doesn't exist yet** -- this is
  the same seam as the Initiative tie-break from Phase 4, and
  `resolve()` is honest about it: it returns `requires_decision_by`
  instead of guessing. Both of these are parked for the same future
  decision-prompt system (Phase 9 AI / Phase 11 UI) rather than
  being built as two separate one-offs.
- `GameStateManager.activate_operative()` now actually expires
  Stun-style effects when an operative's activation ends.

`tests/unit/test_phase5_effects.gd` covers the Stun round-trip through
`EffectResolver`, both hard clamps (including a deliberately absurd
-10" Move penalty to prove the floor holds), exclusivity-group
overwrite, real end-of-activation expiry via `GameStateManager`, and
all four precedence levels plus the honest tie case.
