import '../features/notes/domain/note.dart';
import '../features/notes/presentation/note_actions.dart';
import '../features/settings/domain/notes_maintenance.dart';
import '../features/settings/presentation/settings_providers.dart';

/// Binds Settings' "Delete all notes" action to the notes feature, so neither
/// feature has to import the other.
final notesMaintenanceOverride = notesMaintenanceProvider.overrideWith(
  (ref) => _NoteActionsMaintenance(ref.watch(noteActionsProvider)),
);

class _NoteActionsMaintenance implements NotesMaintenance {
  _NoteActionsMaintenance(this._actions);

  final NoteActions _actions;
  List<Note> _lastDeleted = const [];

  @override
  Future<int> deleteAll() async {
    _lastDeleted = await _actions.deleteAll();
    return _lastDeleted.length;
  }

  @override
  Future<void> undoDeleteAll() async {
    for (final n in _lastDeleted) {
      await _actions.restore(n);
    }
    _lastDeleted = const [];
  }
}
