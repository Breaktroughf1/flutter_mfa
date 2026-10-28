# ADR-0006: UI widgets built on the widgets layer with their own theme

- Status: Accepted (28 October 2026)

## Context
Flutter 3.47 split Material and Cupertino into standalone packages and the November 2026 stable release (3.50) formally deprecates the in-SDK copies. A widget package hard-wired to `package:flutter/material.dart` will need migration and forces Material on Cupertino/custom-design apps.

## Decision
Widgets import only `package:flutter/widgets.dart` (+ `services`, `semantics`). Styling comes from `MfaTheme`/`MfaThemeData`. Two thin adapter files (`material_adapter.dart`, `cupertino_adapter.dart`) are the only files allowed to import design libraries; CI enforces this. Revisit adapter imports when 3.50 lands (they may switch to the new standalone packages).

## Consequences
+ Insulated from the Material split; works in any design system.
− Slightly more code for focus/ink behaviours we would otherwise inherit; goldens become the visual contract.
