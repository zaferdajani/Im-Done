import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/categories.dart';
import '../models/task.dart';
import '../services/voice_parser.dart';
import '../state/providers.dart';
import 'format.dart';
import 'sign_in_sheet.dart';

/// Opens the editor. Returns the saved task, or null if cancelled.
Future<Task?> showTaskEditor(BuildContext context, {required Task draft, required bool isNew}) =>
    showModalBottomSheet<Task?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskEditorSheet(draft: draft, isNew: isNew),
    );

/// Builds a draft from a spoken sentence.
Task draftFromSpeech(Task base, String spoken) {
  final p = parseSpeech(spoken);
  final today = DateTime.now();
  DateTime? start = p.periodStart;
  DateTime? end;
  if (p.periodDays != null) {
    start ??= DateTime(today.year, today.month, today.day);
    end = start.add(Duration(days: p.periodDays! - 1));
  }
  return base.copyWith(
    title: p.title,
    frequency: p.frequency ?? base.frequency,
    weekdays: p.weekdays.isNotEmpty ? p.weekdays : base.weekdays,
    everyNDays: p.everyNDays ?? base.everyNDays,
    hour: p.hour ?? base.hour,
    minute: p.minute ?? base.minute,
    periodStart: start ?? base.periodStart,
    periodEnd: end ?? base.periodEnd,
  );
}

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, required this.draft, required this.isNew});
  final Task draft;
  final bool isNew;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late Task _t = widget.draft;
  late final TextEditingController _title = TextEditingController(text: widget.draft.title);
  late final TextEditingController _note = TextEditingController(text: widget.draft.note ?? '');
  late final TextEditingController _group = TextEditingController(text: widget.draft.group ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _group.dispose();
    super.dispose();
  }

  void _set(Task t) => setState(() => _t = t);

  Future<void> _pickTime() async {
    final r = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _t.hour, minute: _t.minute));
    if (r != null) _set(_t.copyWith(hour: r.hour, minute: r.minute));
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? _t.periodStart : _t.periodEnd) ?? _t.periodStart ?? now;
    final r = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (r == null) return;
    if (start) {
      _set(_t.copyWith(periodStart: r, periodEnd: (_t.periodEnd != null && _t.periodEnd!.isBefore(r)) ? r : _t.periodEnd));
    } else {
      _set(_t.copyWith(periodEnd: r));
    }
  }

  Future<void> _chooseKind(TaskKind k) async {
    if (k == TaskKind.personal) {
      _set(_t.copyWith(kind: k));
      return;
    }
    final l = ref.read(l10nProvider);
    if (!ref.read(bootstrapProvider).cloudAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cloudUnavailable)));
      return;
    }
    if (needsSignIn(ref.read(authUserProvider).value)) {
      final user = await showSignInSheet(context);
      if (user == null) return;
    }
    _set(_t.copyWith(kind: k));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final l = ref.read(l10nProvider);
    try {
      final group = _group.text.trim();
      var t = _t.copyWith(title: title, note: _note.text.trim(), group: group.isEmpty ? null : group, clearGroup: group.isEmpty);
      if (t.frequency == Frequency.once && t.periodStart == null) {
        final n = DateTime.now();
        t = t.copyWith(periodStart: DateTime(n.year, n.month, n.day));
      }
      final saved = await ref.read(taskActionsProvider).save(t);
      // Ask for notification permission IN CONTEXT: the person just created
      // something that needs reminding (store guideline: never at cold start).
      final sched = ref.read(bootstrapProvider).scheduler;
      if (!await sched.permissionGranted() && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.notifications_active_rounded, size: 36),
            title: Text(l.notifPermissionTitle),
            content: Text(l.notifPermissionBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.enable)),
            ],
          ),
        );
        if (go == true) await sched.requestPermission();
        ref.invalidate(notificationsEnabledProvider);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.error}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final lang = ref.watch(languageCodeProvider);
    final scheme = Theme.of(context).colorScheme;
    final canChangeKind = widget.isNew || !_t.isShared;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.isNew ? l.newTask : l.editTask, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: widget.isNew && _title.text.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(hintText: l.titleHint),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 18),
            _Label(l.kindLabel),
            SegmentedButton<TaskKind>(
              segments: [
                ButtonSegment(value: TaskKind.personal, label: Text(l.kindPersonal), icon: const Icon(Icons.person_rounded)),
                ButtonSegment(value: TaskKind.shared, label: Text(l.kindShared), icon: const Icon(Icons.group_rounded)),
              ],
              selected: {_t.kind},
              onSelectionChanged: canChangeKind ? (s) => _chooseKind(s.first) : null,
            ),
            if (_t.isShared)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.kindSharedHint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ),
            const SizedBox(height: 18),
            _Label(l.importanceLabel),
            SegmentedButton<Importance>(
              segments: [
                ButtonSegment(value: Importance.high, label: Text(l.importanceHigh), icon: Icon(importanceIcon(Importance.high))),
                ButtonSegment(value: Importance.medium, label: Text(l.importanceMedium)),
                ButtonSegment(value: Importance.low, label: Text(l.importanceLow), icon: Icon(importanceIcon(Importance.low))),
              ],
              selected: {_t.importance},
              onSelectionChanged: (s) => _set(_t.copyWith(importance: s.first)),
            ),
            const SizedBox(height: 18),
            _Label(l.frequencyLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in Frequency.values)
                  ChoiceChip(
                    label: Text(_freqName(l, f)),
                    selected: _t.frequency == f,
                    onSelected: (_) => _set(_t.copyWith(frequency: f)),
                  ),
              ],
            ),
            if (_t.frequency == Frequency.weekly) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(l.weekdayShort[d - 1]),
                      selected: _t.weekdays.contains(d),
                      onSelected: (on) {
                        final s = {..._t.weekdays};
                        on ? s.add(d) : s.remove(d);
                        _set(_t.copyWith(weekdays: s));
                      },
                    ),
                ],
              ),
            ],
            if (_t.frequency == Frequency.everyNDays) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(l.everyNDaysLabel),
                  const SizedBox(width: 12),
                  _Stepper(
                    value: _t.everyNDays,
                    min: 2,
                    max: 60,
                    onChanged: (v) => _set(_t.copyWith(everyNDays: v)),
                  ),
                  const SizedBox(width: 8),
                  Text(l.freqSummaryEveryN.fill({'n': _t.everyNDays})),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Tile(
                    label: l.timeLabel,
                    value: formatTime(context, _t.hour, _t.minute),
                    icon: Icons.schedule_rounded,
                    onTap: _pickTime,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    label: _t.frequency == Frequency.once ? l.dateLabel : l.periodStart,
                    value: _t.periodStart == null ? l.today : formatDateShort(lang, _t.periodStart!),
                    icon: Icons.today_rounded,
                    onTap: () => _pickDate(start: true),
                  ),
                ),
              ],
            ),
            if (_t.frequency != Frequency.once) ...[
              const SizedBox(height: 10),
              _Tile(
                label: l.periodEnd,
                value: _t.periodEnd == null ? l.periodNone : formatDateShort(lang, _t.periodEnd!),
                icon: Icons.event_busy_rounded,
                onTap: () => _pickDate(start: false),
                onClear: _t.periodEnd == null ? null : () => _set(_t.copyWith(clearPeriodEnd: true)),
              ),
            ],
            const SizedBox(height: 18),
            _Label(l.nagLabel),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(_t.nagEveryMinutes == 0 ? l.nagOff : l.nagHint),
              value: _t.nagEveryMinutes > 0,
              onChanged: (on) => _set(_t.copyWith(nagEveryMinutes: on ? 10 : 0)),
            ),
            if (_t.nagEveryMinutes > 0)
              Row(
                children: [
                  Text(l.nagEvery),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _t.nagEveryMinutes,
                    items: [5, 10, 15, 30, 60].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                    onChanged: (v) => v == null ? null : _set(_t.copyWith(nagEveryMinutes: v)),
                  ),
                  const SizedBox(width: 16),
                  _Stepper(value: _t.nagRepeats, min: 1, max: 30, onChanged: (v) => _set(_t.copyWith(nagRepeats: v))),
                  const SizedBox(width: 8),
                  Text(l.nagTimes),
                ],
              ),
            const SizedBox(height: 14),
            _Label(l.categoryLabel),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in taskCategories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      avatar: Icon(c.icon, size: 18, color: _t.category == c.key ? Colors.white : c.color),
                      label: Text(categoryName(l, c.key)),
                      selected: _t.category == c.key,
                      selectedColor: c.color,
                      labelStyle: TextStyle(color: _t.category == c.key ? Colors.white : null),
                      showCheckmark: false,
                      onSelected: (on) => _set(on ? _t.copyWith(category: c.key) : _t.copyWith(clearCategory: true)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            _Label(l.groupLabel),
            TextField(
              controller: _group,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: l.groupHint, prefixIcon: const Icon(Icons.folder_outlined)),
              onChanged: (_) => setState(() {}),
            ),
            if (_group.text.trim().isNotEmpty && ref.read(taskActionsProvider).peopleOfGroup(_group.text.trim()).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.groupSharedHint.fill({'n': ref.read(taskActionsProvider).peopleOfGroup(_group.text.trim()).length}),
                  style: TextStyle(color: scheme.primary, fontSize: 13),
                ),
              ),
            if (ref.watch(groupNamesProvider).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final g in ref.watch(groupNamesProvider))
                      ChoiceChip(
                        label: Text(g),
                        selected: _group.text.trim() == g,
                        showCheckmark: false,
                        onSelected: (on) => setState(() => _group.text = on ? g : ''),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              decoration: InputDecoration(hintText: l.noteLabel),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving || _title.text.trim().isEmpty ? null : _save,
              child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.save),
            ),
            TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
          ],
        ),
      ),
    );
  }

  String _freqName(L10n l, Frequency f) => switch (f) {
        Frequency.once => l.freqOnce,
        Frequency.daily => l.freqDaily,
        Frequency.weekdays => l.freqWeekdays,
        Frequency.weekly => l.freqWeekly,
        Frequency.everyNDays => l.freqEveryNDays,
      };
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.icon, required this.onTap, this.onClear});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ],
                ),
              ),
              if (onClear != null) IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_rounded)),
          SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          IconButton.filledTonal(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_rounded)),
        ],
      );
}
