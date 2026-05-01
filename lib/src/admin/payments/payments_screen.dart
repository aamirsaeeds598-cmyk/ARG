import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';
import '../jobs/job_details_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Payments Screen
// ─────────────────────────────────────────────────────────────────────────────

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final query = FirebaseFirestore.instance
        .collection(FirestorePaths.teamJobs(teamId))
        .orderBy('updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        // ── Loading ──────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // ── Error ────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: _ErrorCard(message: snapshot.error.toString()),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final withAmounts =
        docs.where((d) => d.data()['priceCents'] != null).toList();

        // Aggregate totals
        int totalCents  = 0;
        int paidCents   = 0;
        int unpaidCents = 0;

        for (final d in withAmounts) {
          final cents  = (d.data()['priceCents'] as int?) ?? 0;
          final status = (d.data()['paymentStatus'] as String?) ?? 'unpaid';
          totalCents += cents;
          if (status == 'paid') {
            paidCents += cents;
          } else {
            unpaidCents += cents;
          }
        }

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.payments_outlined,
                              color: colorScheme.onPrimaryContainer, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payments',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Track job payments & balances',
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

                // ── Summary cards ────────────────────────────────────────────
                if (withAmounts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              label: 'Total',
                              amount: totalCents,
                              color: colorScheme.primary,
                              bgColor: colorScheme.primaryContainer,
                              fgColor: colorScheme.onPrimaryContainer,
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryCard(
                              label: 'Paid',
                              amount: paidCents,
                              color: const Color(0xFF00897B),
                              bgColor: const Color(0xFFE0F2F1),
                              fgColor: const Color(0xFF004D40),
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryCard(
                              label: 'Pending',
                              amount: unpaidCents,
                              color: const Color(0xFFE65100),
                              bgColor: const Color(0xFFFFF3E0),
                              fgColor: const Color(0xFFBF360C),
                              icon: Icons.pending_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── List label ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      withAmounts.isEmpty
                          ? ''
                          : '${withAmounts.length} job${withAmounts.length == 1 ? '' : 's'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),

                // ── Empty ────────────────────────────────────────────────────
                if (withAmounts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _EmptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: withAmounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final d = withAmounts[i];
                        return _PaymentTile(
                          teamId: teamId,
                          jobId: d.id,
                          data: d.data(),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.fgColor,
    required this.icon,
  });

  final String label;
  final int amount;
  final Color color;
  final Color bgColor;
  final Color fgColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: fgColor),
          ),
          const SizedBox(height: 10),
          Text(
            '\$${(amount / 100).toStringAsFixed(0)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: fgColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Tile
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
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

    final title         = (data['title'] as String?) ?? 'Job';
    final priceCents    = (data['priceCents'] as int?) ?? 0;
    final paymentStatus = (data['paymentStatus'] as String?) ?? 'unpaid';
    final clientName    = data['clientName'] as String?;
    final amount        = (priceCents / 100).toStringAsFixed(2);
    final isPaid        = paymentStatus == 'paid';

    final accent = _accentColors[index % _accentColors.length];

    // Initials from title
    final initials = title.trim().isNotEmpty
        ? title.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'J';

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JobDetailsScreen(teamId: teamId, jobId: jobId),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
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
                    if (clientName != null && clientName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        clientName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right: amount + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$$amount',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isPaid
                          ? const Color(0xFF00897B)
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _PaymentBadge(status: paymentStatus),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Badge
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolve(status, Theme.of(context).colorScheme);
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
      case 'paid':
        return ('PAID', const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case 'partial':
        return ('PARTIAL', const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case 'overdue':
        return ('OVERDUE', const Color(0xFFFFEBEE), const Color(0xFFC62828));
      default:
        return ('UNPAID', cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
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
            child: Icon(Icons.payments_outlined,
                size: 28, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text('No payments yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Set a price in a job to track payments here.',
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