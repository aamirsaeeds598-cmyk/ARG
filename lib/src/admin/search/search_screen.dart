import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';
import '../clients/client_profile_screen.dart';
import '../invoices/invoice_details_screen.dart';
import '../jobs/job_details_screen.dart';
import '../quotes/quote_details_screen.dart';
import '../requests/request_details_screen.dart';
import '../workers/worker_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Search Screen
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  bool _matches(Map<String, dynamic> data, List<String> fields) {
    if (_query.isEmpty) return true;
    for (final f in fields) {
      final v = (data[f] ?? '').toString().toLowerCase();
      if (v.contains(_query)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final db = FirebaseFirestore.instance;

    final clientsQ =
    db.collection(FirestorePaths.teamClients(widget.teamId)).limit(50);
    final activeJobsQ = db
        .collection(FirestorePaths.teamJobs(widget.teamId))
        .where('status', whereNotIn: ['done']).limit(50);
    final doneJobsQ = db
        .collection(FirestorePaths.teamJobs(widget.teamId))
        .where('status', isEqualTo: 'done')
        .limit(100);
    final requestsQ =
    db.collection(FirestorePaths.teamRequests(widget.teamId)).limit(50);
    final quotesQ =
    db.collection(FirestorePaths.teamQuotes(widget.teamId)).limit(50);
    final invoicesQ =
    db.collection(FirestorePaths.teamInvoices(widget.teamId)).limit(50);
    final workersQ = db
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .limit(50);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.manage_search_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Search',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Text(
                        'Clients, workers, jobs, quotes & more',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
        
                    // ── Search bar ────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onChanged,

                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(

                          fillColor: Colors.white,
                          hintText:
                          'Search clients, workers, jobs, quotes…',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant),
                            onPressed: _clearSearch,
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onTap: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        
            // ── Results ──────────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Section(
                    title: 'Clients',
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF5B7FFF),
                    stream: clientsQ.snapshots(),
                    sortKey: 'createdAt',
                    sortDescending: true,
                    emptyText: 'No matching clients.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      if (!_matches(data, const ['name', 'email', 'phone']))
                        return null;
                      final name = (data['name'] as String?) ?? 'Client';
                      final meta = [
                        (data['email'] as String?)?.trim(),
                        (data['phone'] as String?)?.trim(),
                      ]
                          .where((v) => v != null && v.isNotEmpty)
                          .join(' • ');
                      return _ResultTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: const Color(0xFF5B7FFF),
                        title: name,
                        subtitle: meta.isEmpty ? doc.id : meta,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ClientProfileScreen(
                              teamId: widget.teamId, clientId: doc.id),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Workers / Team Members',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF7C4DFF),
                    stream: workersQ.snapshots(),
                    sortKey: null,
                    sortDescending: false,
                    emptyText: 'No matching workers.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      if (!_matches(data, const ['email'])) return null;
                      final email = (data['email'] as String?) ?? doc.id;
                      final team =
                          (data['currentTeamId'] as String?) ?? 'Not assigned';
                      return _ResultTile(
                        icon: Icons.badge_outlined,
                        iconColor: const Color(0xFF7C4DFF),
                        title: email,
                        subtitle: 'Team: $team',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WorkerProfileScreen(
                            teamId: widget.teamId,
                            workerUid: doc.id,
                            workerEmail: data['email'] as String?,
                          ),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Jobs — Active',
                    icon: Icons.work_outline_rounded,
                    iconColor: const Color(0xFFFF6D3B),
                    stream: activeJobsQ.snapshots(),
                    sortKey: 'updatedAt',
                    sortDescending: true,
                    emptyText: 'No active jobs.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      if (!_matches(data, const [
                        'title',
                        'description',
                        'location',
                        'assignedWorkerEmail'
                      ])) return null;
                      final title = (data['title'] as String?) ?? 'Job';
                      final status = (data['status'] as String?) ?? '-';
                      return _ResultTile(
                        icon: Icons.work_outline_rounded,
                        iconColor: const Color(0xFFFF6D3B),
                        title: title,
                        subtitle: 'Status: $status',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => JobDetailsScreen(
                              teamId: widget.teamId, jobId: doc.id),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Jobs — Completed',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF00BFA5),
                    stream: doneJobsQ.snapshots(),
                    sortKey: 'updatedAt',
                    sortDescending: true,
                    emptyText: 'No completed jobs.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      final paymentStatus =
                          (data['paymentStatus'] as String?) ?? '';
                      if (paymentStatus == 'paid') return null;
                      if (!_matches(data, const [
                        'title',
                        'description',
                        'location',
                        'assignedWorkerEmail'
                      ])) return null;
                      final title = (data['title'] as String?) ?? 'Job';
                      return _ResultTile(
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF00BFA5),
                        title: title,
                        subtitle: 'Completed',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => JobDetailsScreen(
                              teamId: widget.teamId, jobId: doc.id),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Jobs — Closed',
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF607D8B),
                    stream: doneJobsQ.snapshots(),
                    sortKey: 'updatedAt',
                    sortDescending: true,
                    emptyText: 'No closed jobs.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      final paymentStatus =
                          (data['paymentStatus'] as String?) ?? '';
                      if (paymentStatus != 'paid') return null;
                      if (!_matches(data, const [
                        'title',
                        'description',
                        'location',
                        'assignedWorkerEmail'
                      ])) return null;
                      final title = (data['title'] as String?) ?? 'Job';
                      return _ResultTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF607D8B),
                        title: title,
                        subtitle: 'Closed & paid',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => JobDetailsScreen(
                              teamId: widget.teamId, jobId: doc.id),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Requests',
                    icon: Icons.inbox_outlined,
                    iconColor: const Color(0xFFFF4081),
                    stream: requestsQ.snapshots(),
                    sortKey: 'createdAt',
                    sortDescending: true,
                    emptyText: 'No matching requests.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      if (!_matches(data, const [
                        'clientName',
                        'serviceDescription',
                        'location',
                        'priority'
                      ])) return null;
                      final clientName =
                          (data['clientName'] as String?) ?? 'Client';
                      final service =
                          (data['serviceDescription'] as String?) ?? '';
                      final priority = (data['priority'] as String?) ?? 'normal';
                      return _ResultTile(
                        icon: Icons.inbox_outlined,
                        iconColor: const Color(0xFFFF4081),
                        title: clientName,
                        subtitle: '$service • $priority',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RequestDetailsScreen(
                              teamId: widget.teamId, requestId: doc.id),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Quotes — Pending',
                    icon: Icons.request_quote_outlined,
                    iconColor: const Color(0xFFFFAB40),
                    stream: quotesQ.snapshots(),
                    sortKey: 'createdAt',
                    sortDescending: true,
                    emptyText: 'No pending quotes.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      if (data['status'] == 'approved') return null;
                      if (!_matches(
                          data, const ['title', 'clientName', 'status']))
                        return null;
                      final clientName =
                          (data['clientName'] as String?) ?? 'Client';
                      final totalCents = (data['totalCents'] as int?) ?? 0;
                      final status = (data['status'] as String?) ?? 'draft';
                      return _ResultTile(
                        icon: Icons.request_quote_outlined,
                        iconColor: const Color(0xFFFFAB40),
                        title: clientName,
                        subtitle: '\$${(totalCents / 100).toStringAsFixed(2)} • $status',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => QuoteDetailsScreen(
                              teamId: widget.teamId, quoteId: doc.id),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Quotes — Approved',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF00BFA5),
                    stream: quotesQ.snapshots(),
                    sortKey: 'createdAt',
                    sortDescending: true,
                    emptyText: 'No approved quotes.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      if (data['status'] != 'approved') return null;
                      if (!_matches(
                          data, const ['title', 'clientName', 'status']))
                        return null;
                      final clientName =
                          (data['clientName'] as String?) ?? 'Client';
                      final totalCents = (data['totalCents'] as int?) ?? 0;
                      return _ResultTile(
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF00BFA5),
                        title: clientName,
                        subtitle:
                        '\$${(totalCents / 100).toStringAsFixed(2)} • approved',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => QuoteDetailsScreen(
                              teamId: widget.teamId, quoteId: doc.id),
                        )),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
        
                  _Section(
                    title: 'Invoices',
                    icon: Icons.receipt_long_outlined,
                    iconColor: const Color(0xFF5B7FFF),
                    stream: invoicesQ.snapshots(),
                    sortKey: 'createdAt',
                    sortDescending: true,
                    emptyText: 'No invoices yet.',
                    itemBuilder: (context, doc) {
                      final data = doc.data();
                      if (!_matches(data,
                          const ['title', 'clientName', 'salesPersonName']))
                        return null;
                      final clientName =
                          (data['clientName'] as String?) ?? 'Client';
                      final title = (data['title'] as String?) ?? 'Invoice';
                      final totalCents = (data['totalCents'] as int?) ?? 0;
                      final status = (data['status'] as String?) ?? 'draft';
                      final isPaid = status == 'paid';
                      return _ResultTile(
                        icon: Icons.receipt_long_outlined,
                        iconColor: isPaid
                            ? const Color(0xFF00BFA5)
                            : const Color(0xFF5B7FFF),
                        title: clientName,
                        subtitle:
                        '$title  •  \$${(totalCents / 100).toStringAsFixed(2)}  •  $status',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => InvoiceDetailsScreen(
                              teamId: widget.teamId, invoiceId: doc.id),
                        )),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
// Section Card
// ─────────────────────────────────────────────────────────────────────────────

typedef _Builder = Widget? Function(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    );

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.stream,
    required this.sortKey,
    required this.sortDescending,
    required this.emptyText,
    required this.itemBuilder,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String? sortKey;
  final bool sortDescending;
  final String emptyText;
  final _Builder itemBuilder;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (sortKey == null || sortKey!.isEmpty) return docs;
    docs.sort((a, b) {
      final aVal = a.data()[sortKey];
      final bVal = b.data()[sortKey];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return 1;
      if (bVal == null) return -1;
      int comparison = 0;
      if (aVal is Timestamp && bVal is Timestamp) {
        comparison = aVal.compareTo(bVal);
      } else if (aVal is Comparable && bVal is Comparable) {
        comparison = (aVal as Comparable).compareTo(bVal);
      } else {
        comparison = aVal.toString().compareTo(bVal.toString());
      }
      return sortDescending ? -comparison : comparison;
    });
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.6),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withOpacity(0.4),
          ),

          // Stream content
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          snapshot.error.toString(),
                          style: TextStyle(
                              color: colorScheme.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }

              var docs = snapshot.data?.docs ?? const [];
              docs = _sortDocs(docs);

              final tiles = <Widget>[];
              for (final d in docs) {
                final w = itemBuilder(context, d);
                if (w != null) tiles.add(w);
              }

              if (tiles.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Text(
                    emptyText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (int i = 0; i < tiles.length; i++) ...[
                      tiles[i],
                      if (i < tiles.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 52,
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}