# Tests

Unit tests (`tests/unit/`) exercise a single core/ module in isolation,
no scene tree required (dice distributions & determinism, movement
legality, LoS, cover, single-weapon resolution).

Integration tests (`tests/integration/`) exercise full activation
sequences, full turning points, seeded mission generation, and
save/load round trips.

A headless GDScript test runner (e.g. GUT -- Gut Unit Test, a free
Godot addon) is recommended so these run without booting the full
scene tree. Not yet added to `addons/` -- planned for Phase 15
(Automated testing), though nothing stops individual test files being
added earlier alongside the modules they cover, per the master spec's
"whenever a new rule is implemented, create a test for it."
