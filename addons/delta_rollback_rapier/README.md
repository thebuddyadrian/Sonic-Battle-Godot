Delta Rollback: Godot Rapier integration
========================================

Optional companion to the `delta_rollback` addon, for games whose physics runs
on [Godot Rapier](https://godot.rapier.rs), which is deterministic across
platforms and can save and load a whole physics space:

- `PhysicsWorld.gd`: puts a Rapier physics space (2D or 3D) under rollback, as
  a single network node that steps the space each tick and saves and loads it
  whole.
- `DetMath.gd`: deterministic versions of the engine's vector and transform
  methods that use trigonometry (`from_angle()`, `rotated()`, `angle()`...),
  on top of Rapier's deterministic math (`RapierMath2D` / `RapierMath3D`).

Requires the `delta_rollback` addon, Godot Rapier 2D and/or 3D, and the
version of Godot they need (4.7 or later for Rapier 0.36).

See "Physics with Godot Rapier" and "Deterministic math in scripts" in
[the project page](https://gitlab.com/bimdav/delta_rollback/), and the demos in
`demo/physics/` and `demo/physics3d/`.
