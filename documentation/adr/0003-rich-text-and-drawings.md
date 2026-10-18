# ADR-0003: Rich text with flutter_quill, drawings as embeds

Status: accepted.

**Context:** notes need formatting and freehand drawings, stored once and synced through the existing protocol, without a custom editor engine.

**Decision:**
- Editor: `flutter_quill` (MIT, actively released, Delta document model). A custom editor engine (the author's own `Document_Platform`) was ruled out as over-engineered.
- Storage: `Note.content` holds the Quill Delta JSON as an opaque string; `Note.body` stays a plain-text mirror (embed placeholders and the trailing newline removed) used for search, card previews and clients without a rich editor. Drift schema v3 adds a nullable `content` column; the sync wire format gets an optional `content` field.
- Drawings: a versioned stroke format (`{"v":1,"ar":..,"s":[...]}`) stored as a plain `BlockEmbed('drawing', json)` inside `content`, so one field and one sync path cover text and drawings. A drawing-only note has empty `body` but non-empty `content`, and is valid.
- Format choices: points and widths are fractions of the canvas (identical on phone and desktop); colors are fixed ARGB values on a fixed white paper (a black pen stays visible in dark mode); points are rounded to 4 decimals and simplified with Douglas-Peucker; one drawing is capped at 200 KB.
- Own drawing code instead of `flutter_drawing_board`: that package's JSON would become the format stored and synced forever, and it has modest adoption (about 2.6k downloads when checked). The painter is small (a stroke list, cached committed layer, one active-stroke layer).
- Eraser removes whole strokes (simple, undoable); no pixel erasing.

**Consequences / limits:**
- The notes list query loads every column, including `content`; large drawings make list loads heavier. Select only list columns if this shows up in profiling.
- Rich paste is not supported on web (flutter_quill limitation); images/video embeds need `flutter_quill_extensions` and are not enabled.
- Drawings sync as part of the whole note (last-write-wins), so editing the text and the drawing on two devices at once keeps only the later note.
- No pressure sensitivity, shapes, text-in-drawing, zoom or pixel eraser yet.
