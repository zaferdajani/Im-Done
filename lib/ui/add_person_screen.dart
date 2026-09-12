import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/task.dart';
import '../state/providers.dart';
import 'sign_in_sheet.dart';
import 'task_detail_screen.dart';

/// Landing for a scanned or opened personal code: shows who it is and asks
/// which of your shared tasks to add them to.
class AddPersonScreen extends ConsumerStatefulWidget {
  const AddPersonScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends ConsumerState<AddPersonScreen> {
  TaskMember? _person;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = ref.read(bootstrapProvider);
    if (!b.cloudAvailable) {
      setState(() => _loading = false);
      return;
    }
    if (ref.read(authUserProvider).value == null) {
      final user = await showSignInSheet(context);
      if (user == null) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
    }
    try {
      final p = await b.cloudTasks.lookupPersonalCode(widget.code);
      if (mounted) setState(() => _person = p);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(Task t) async {
    setState(() => _busy = true);
    final l = ref.read(l10nProvider);
    try {
      await ref.read(taskActionsProvider).addMemberByCode(t, widget.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.personAdded)));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(myUidProvider);
    final mine = ref.watch(allTasksProvider).where((t) => t.isShared && t.ownerUid == uid).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.addByCode)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (!ref.read(bootstrapProvider).cloudAvailable)
                  Text(l.cloudUnavailable, style: TextStyle(color: scheme.error))
                else if (_person == null)
                  Text(l.codeNotFound, style: TextStyle(color: scheme.error, fontSize: 16))
                else ...[
                  ListTile(
                    leading: CircleAvatar(child: Text(_person!.name.isEmpty ? '?' : _person!.name.characters.first.toUpperCase())),
                    title: Text(_person!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    subtitle: Text('${l.inviteCodeLabel}: ${widget.code}'),
                  ),
                  const SizedBox(height: 12),
                  Text(l.addToWhichTask, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  if (mine.isEmpty)
                    Text(l.noSharedTasksYet, style: TextStyle(color: scheme.onSurfaceVariant))
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final t in mine)
                            ListTile(
                              leading: const Icon(Icons.group_rounded),
                              title: Text(t.title),
                              trailing: t.members.any((m) => m.uid == _person!.uid)
                                  ? const Icon(Icons.check_rounded)
                                  : const Icon(Icons.add_rounded),
                              enabled: !_busy && !t.members.any((m) => m.uid == _person!.uid),
                              onTap: () => _add(t),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
