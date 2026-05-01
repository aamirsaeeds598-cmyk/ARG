import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';
import '../jobs/job_details_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Schedule Screen
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final query = FirebaseFirestore.instance
        .collection(FirestorePaths.teamJobs(widget.teamId))
        .orderBy('scheduledAt', descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        // Build a map: normalised date → list of docs
        final Map<DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        jobsByDay = {};

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final ts = doc.data()['scheduledAt'];
            if (ts is! Timestamp) continue;
            final d = ts.toDate();
            final key = DateTime(d.year, d.month, d.day);
            jobsByDay.putIfAbsent(key, () => []).add(doc);
          }
        }

        // Jobs shown in the list panel
        final listDocs = _selectedDay != null
            ? (jobsByDay[_selectedDay] ?? [])
            : jobsByDay.values.expand((e) => e).toList()
          ..sort((a, b) {
            final aTs = a.data()['scheduledAt'] as Timestamp?;
            final bTs = b.data()['scheduledAt'] as Timestamp?;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return aTs.compareTo(bTs);
          });

        return Scaffold(
          backgroundColor:        Color(0xFFF5F7FA),
        
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── Header ─────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Upcoming jobs & assignments',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            
                // ── Calendar ───────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _CalendarWidget(
                      focusedMonth: _focusedMonth,
                      selectedDay: _selectedDay,
                      jobsByDay: jobsByDay,
                      onMonthChanged: (m) => setState(() => _focusedMonth = m),
                      onDaySelected: (d) => setState(() {
                        _selectedDay = _selectedDay == d ? null : d;
                      }),
                    ),
                  ),
                ),
            
                // ── Section label ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDay != null
                                ? _formatSectionDate(_selectedDay!)
                                : 'All Scheduled Jobs',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (_selectedDay != null)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _selectedDay = null),
                            icon: const Icon(Icons.close_rounded, size: 14),
                            label: const Text('Clear'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            
                // ── Loading / Error / Empty ─────────────────────────────────────
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ErrorCard(message: snapshot.error.toString()),
                    ),
                  )
                else if (listDocs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _EmptyState(
                          hasFilter: _selectedDay != null,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverList.separated(
                        itemCount: listDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final doc = listDocs[i];
                          return _ScheduleTile(
                            teamId: widget.teamId,
                            jobId: doc.id,
                            data: doc.data(),
                            index: i,
                          );
                        },
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatSectionDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar Widget
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarWidget extends StatelessWidget {
  const _CalendarWidget({
    required this.focusedMonth,
    required this.selectedDay,
    required this.jobsByDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final Map<DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  jobsByDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    // Days in this month grid
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    // Offset so week starts on Monday (weekday 1)
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month navigation
          Row(
            children: [
              IconButton(
                onPressed: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month - 1),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor:
                  colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              Expanded(
                child: Text(
                  '${monthNames[focusedMonth.month - 1]} ${focusedMonth.year}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor:
                  colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day-of-week labels
          Row(
            children: dayLabels
                .map(
                  (l) => Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 6),

          // Day grid
          for (int row = 0; row < rows; row++) ...[
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - startOffset + 1;
                if (dayNum < 1 || dayNum > lastDay.day) {
                  return const Expanded(child: SizedBox(height: 36));
                }

                final dayDate =
                DateTime(focusedMonth.year, focusedMonth.month, dayNum);
                final isToday = dayDate == todayKey;
                final isSelected = selectedDay == dayDate;
                final hasJobs = jobsByDay.containsKey(dayDate);
                final jobCount = jobsByDay[dayDate]?.length ?? 0;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDaySelected(dayDate),
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 1, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : isToday
                            ? colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : isToday
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                          if (hasJobs)
                            Positioned(
                              bottom: 4,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  jobCount.clamp(1, 3),
                                      (_) => Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.onPrimary
                                          .withOpacity(0.8)
                                          : colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.teamId,
    required this.jobId,
    required this.data,
    required this.index,
  });

  final String teamId;
  final String jobId;
  final Map<String, dynamic> data;
  final int index;

  static const _accentColors = [
    Color(0xFF5B7FFF),
    Color(0xFF7C4DFF),
    Color(0xFF00BFA5),
    Color(0xFFFF6D3B),
    Color(0xFFFF4081),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = (data['title'] as String?) ?? 'Job';
    final assignedEmail = data['assignedWorkerEmail'] as String?;
    final status = (data['status'] as String?) ?? 'pending';

    final ts = data['scheduledAt'];
    final scheduledAt = ts is Timestamp ? ts.toDate() : null;

    final accent = _accentColors[index % _accentColors.length];

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                JobDetailsScreen(teamId: teamId, jobId: jobId),
          ),
        ),
        child: Container(

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.6),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Colour accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                // Date column
                if (scheduledAt != null)
                  Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.08),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          scheduledAt.day.toString(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accent,
                            height: 1,
                          ),
                        ),
                        Text(
                          _shortMonth(scheduledAt.month),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(scheduledAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (assignedEmail != null &&
                            assignedEmail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 13,
                                  color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  assignedEmail,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        _StatusChip(status: status),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortMonth(int m) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[m - 1];
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) =
    _resolve(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  (String, Color, Color) _resolve(String s, ColorScheme cs) {
    switch (s.toLowerCase()) {
      case 'in_progress':
      case 'in progress':
        return ('IN PROGRESS', const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      case 'done':
        return ('DONE', const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case 'cancelled':
        return ('CANCELLED', const Color(0xFFFFEBEE), const Color(0xFFC62828));
      default:
        return ('PENDING', cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded,
                size: 28, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No jobs on this day' : 'No scheduled jobs yet',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Try selecting another date or clear the filter.'
                : 'Add a schedule time in a job to see it here.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Card
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}