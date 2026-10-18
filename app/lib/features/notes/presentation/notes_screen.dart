import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_controller.dart';

/// Lists notes and lets the user add one.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final failure = await ref
        .read(noteControllerProvider.notifier)
        .add(_title.text);
    if (!mounted) return;
    if (failure == null) {
      _title.clear();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(noteControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notehaven')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'New note'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          Expanded(
            child: notes.when(
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No notes yet'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          ListTile(title: Text(items[i].title)),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}
