Adjusted `scripts/test_level.gd` so wall tiles no longer spawn collision bodies.

The map edge now remains responsible for blocking those positions, while interior collidable tiles like counters, tables, and plants still use full-tile diamond blockers. This keeps level planning simple without adding redundant collision on the outer wall row.
