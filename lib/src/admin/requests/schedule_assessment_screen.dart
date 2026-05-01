import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';

class ScheduleAssessmentScreen extends StatefulWidget {
  const ScheduleAssessmentScreen({
    super.key,
    required this.teamId,
    required this.requestId,
  });

  final String teamId;
  final String requestId;

  @override
  State<ScheduleAssessmentScreen> createState() =>
      _ScheduleAssessmentScreenState();
}

class _ScheduleAssessmentScreenState extends State<ScheduleAssessmentScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _instructionsController = TextEditingController();
  String? _selectedMemberUid;
  String? _selectedMemberEmail;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _fmtDate() {
    if (_selectedDate == null) return 'Select date';
    final d = _selectedDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _fmtTime() {
    if (_selectedTime == null) return 'Select time';
    final t = _selectedTime!;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (_selectedDate == null || _selectedTime == null) {
        throw Exception('Please select a date and time.');
      }
      if (_selectedMemberUid == null) {
        throw Exception('Please select a team member.');
      }

      final scheduledAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamRequest(widget.teamId, widget.requestId))
          .update({
        'assessment': {
          'status': 'scheduled',
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'instructions': _instructionsController.text.trim(),
          'assignedMemberUid': _selectedMemberUid,
          'assignedMemberEmail': _selectedMemberEmail ?? '',
        },
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment scheduled.')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final membersQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamMembers(widget.teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule assessment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Date & Time ────────────────────────────────────────────
            Text('Date & Time', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_fmtDate()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_fmtTime()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Instructions ───────────────────────────────────────────
            Text('Instructions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _instructionsController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Add any notes or instructions for the assessor...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Select team member ─────────────────────────────────────
            Text('Assign team member', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: membersQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text(
                    'No team members found.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  );
                }
                return Column(
                  children: [
                    for (final d in docs)
                      RadioListTile<String>(
                        value: d.id,
                        groupValue: _selectedMemberUid,
                        title: Text(
                          (d.data()['email'] as String?) ?? d.id,
                        ),
                        onChanged: (v) => setState(() {
                          _selectedMemberUid = v;
                          _selectedMemberEmail =
                              (d.data()['email'] as String?) ?? '';
                        }),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],

            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save assessment'),
            ),
          ],
        ),
      ),
    );
  }
}
