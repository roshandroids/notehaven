# Performance notes

What is already done, and how to check it. No benchmark numbers are claimed; measure on your own device.

## Done
- **Lazy lists everywhere:** notes use `MasonryGridView.builder`, color themes `SliverGrid.builder`, fonts `ListView.builder`; only visible items are built.
- **`RepaintBoundary`** around every note card and color tile so a change repaints one tile, not the grid.
- **Scoped rebuilds:** widgets watch `select`ed slices (`searchQueryProvider.select`, `settingsProvider.select`), and `ThemeData` is built once per settings change in a cached provider.
- **Debounced search** (250 ms) so typing does not re-run the SQLite query on every key.
- **Live SQLite queries** (Drift) instead of reloading lists after each write.
- **No first-frame theme flash:** settings load before `runApp` (`SharedPreferencesWithCache`, synchronous reads afterwards).
- **Entrance animations only for the first 12 cards** so scrolling never starts new animations.
- **Fonts:** only the curated rows preview in their own font; the 1,500+ family search shows names in the default font. A chosen font is downloaded once and cached by `google_fonts`.

## Check it
1. `flutter run --profile` on a real device, open DevTools → Performance, scroll a list with 1,000 notes.
2. Look for frames over the budget (16 ms at 60 Hz, 8 ms at 120 Hz) and for rebuild counts in the widget inspector.
3. Record before/after numbers in the pull request when you change a list or theme path.

## Rich content
- Drawings: finished strokes sit in their own `RepaintBoundary` and repaint only when the stroke list changes; only the active stroke repaints on pointer moves. Strokes are simplified (Douglas-Peucker) and capped at 200 KB per drawing.
- The notes list loads the full `content` column for every note; with many large drawings, select only list columns.

## Not done yet
- Pagination for very large note counts (the list loads all matches).
- Full-text search (`LIKE` scans the table; fine for thousands of notes, not millions).
- Bundling fonts for offline use.
