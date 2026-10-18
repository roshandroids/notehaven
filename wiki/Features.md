# Features

- **Notes:** rich text (`flutter_quill`), freehand drawings inside notes (pen, highlighter, stroke eraser, colors, undo/redo), delete with undo, copy, live search, masonry grid, swipe actions, word count.
- **Appearance:** 50+ FlexColorScheme themes, light/dark/system, any Google Font with live preview (fonts download at runtime).
- **Feedback:** haptics on phones/tablets, optional UI sounds (off by default, synthesized in code), undo snackbars, long-press/right-click note menu, motion settings. All toggles live in Appearance ([ADR-0004](https://github.com/roshandroids/notehaven/blob/main/documentation/adr/0004-feedback-haptics-sounds-motion.md)).
- **Shortcuts:** Ctrl/Cmd+N new note, Ctrl/Cmd+S save, Ctrl/Cmd+, appearance.
- **Responsive:** one pane on phones, list + editor side by side from 900 px.
- **Accessibility:** screen-reader labels/actions, tap-target tests, reduce-motion ([details](https://github.com/roshandroids/notehaven/blob/main/documentation/accessibility.md)).
- **Sync:** backend-agnostic, off until a backend is configured (see [Data and Sync](Data-and-Sync)).

Where to look: notes UI in `app/lib/features/notes/presentation/`, settings in `features/settings/`, feedback services in `app/lib/shared/feedback/`.
