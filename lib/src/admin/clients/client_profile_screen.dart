import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';
import '../jobs/create_job_screen.dart';
import '../jobs/job_details_screen.dart';
import '../quotes/create_quote_screen.dart';
import '../quotes/quote_details_screen.dart';
import '../requests/request_details_screen.dart';
import '../requests/requests_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

class _C {
  static const ink        = Color(0xFF0F1117);
  static const surface    = Color(0xFFF7F8FA);
  static const card       = Color(0xFFFFFFFF);
  static const accent     = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFEFF4FF);
  static const muted      = Color(0xFF6B7280);
  static const border     = Color(0xFFE5E7EB);
  static const error      = Color(0xFFDC2626);
  static const errorSoft  = Color(0xFFFEF2F2);
}

const _kAvatarColors = [
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFFDB2777),
];

// ─────────────────────────────────────────────────────────────────────────────

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({
    super.key,
    required this.teamId,
    required this.clientId,
  });

  final String teamId;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .doc(FirestorePaths.teamClient(teamId, clientId));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: _C.surface,
            body: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _C.accent),
            ),
          );
        }
        final data = snapshot.data!.data() ?? {};
        return _Body(
            teamId: teamId, clientId: clientId, data: data, docRef: ref);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.teamId,
    required this.clientId,
    required this.data,
    required this.docRef,
  });

  final String teamId;
  final String clientId;
  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> docRef;

  String _since(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    if (ts is! Timestamp) return '';
    final dt = ts.toDate();
    return 'Client since ${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final name  = (data['name']  as String?) ?? 'Client';
    final email = (data['email'] as String?) ?? '';
    final phone = (data['phone'] as String?) ?? '';
    final since = _since(data);

    // Pick a consistent avatar color from the clientId hash
    final avatarColor =
    _kAvatarColors[clientId.hashCode.abs() % _kAvatarColors.length];

    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: _C.surface,
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar with hero avatar ─────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned:         true,
            backgroundColor: _C.card,
            surfaceTintColor: Colors.transparent,
            elevation:      0,
            scrolledUnderElevation: 1,
            shadowColor:    _C.border,
            leading: IconButton(
              icon:  const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _C.ink),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: () =>
                      _editContact(context, name, email, phone),
                  style: TextButton.styleFrom(
                    backgroundColor: _C.accentSoft,
                    foregroundColor: _C.accent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: _C.card,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Avatar
                    Container(
                      width:  80,
                      height: 80,
                      decoration: BoxDecoration(
                        color:  avatarColor,
                        shape:  BoxShape.circle,
                        border: Border.all(color: _C.card, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color:      avatarColor.withOpacity(0.40),
                            blurRadius: 16,
                            offset:     const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color:       Colors.white,
                            fontSize:    26,
                            fontWeight:  FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        color:       _C.ink,
                        fontSize:    20,
                        fontWeight:  FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (since.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(since,
                          style: const TextStyle(
                              color: _C.muted, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Body content ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Contact info card ──────────────────────────────────────
                _sectionLabel('Contact Info'),
                const SizedBox(height: 8),
                _infoCard(context, email, phone, name),
                const SizedBox(height: 20),

                // ── Quick actions ──────────────────────────────────────────
                _sectionLabel('Quick Actions'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        icon:  Icons.inbox_rounded,
                        label: 'Request',
                        color: const Color(0xFF7C3AED),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                  title: const Text('New request')),
                              body: SafeArea(
                                child: RequestsScreen(
                                  teamId:              teamId,
                                  preselectedClientId: clientId,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBtn(
                        icon:  Icons.receipt_long_rounded,
                        label: 'Quote',
                        color: const Color(0xFF059669),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateQuoteScreen(
                              teamId:              teamId,
                              preselectedClientId: clientId,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBtn(
                        icon:  Icons.work_rounded,
                        label: 'Job',
                        color: _C.accent,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateJobScreen(
                              teamId:              teamId,
                              preselectedClientId: clientId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Requests ───────────────────────────────────────────────
                _Section(
                  title:          'Requests',
                  icon:           Icons.inbox_rounded,
                  accentColor:    const Color(0xFF7C3AED),
                  collection:     FirestorePaths.teamRequests(teamId),
                  whereField:     'clientId',
                  whereValue:     clientId,
                  sortKey:        'createdAt',
                  sortDescending: true,
                  limit:          20,
                  emptyText:      'No requests yet.',
                  itemBuilder:    (doc) {
                    final d = doc.data();
                    return _ActivityTile(
                      icon:      Icons.inbox_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: (d['serviceDescription'] as String?) ??
                          'Request',
                      subtitle: (d['status'] as String?) ?? 'new',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RequestDetailsScreen(
                              teamId: teamId, requestId: doc.id),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── Quotes ─────────────────────────────────────────────────
                _Section(
                  title:          'Quotes',
                  icon:           Icons.receipt_long_rounded,
                  accentColor:    const Color(0xFF059669),
                  collection:     FirestorePaths.teamQuotes(teamId),
                  whereField:     'clientId',
                  whereValue:     clientId,
                  sortKey:        'createdAt',
                  sortDescending: true,
                  limit:          20,
                  emptyText:      'No quotes yet.',
                  itemBuilder:    (doc) {
                    final d = doc.data();
                    return _ActivityTile(
                      icon:      Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF059669),
                      title:    (d['title']  as String?) ?? 'Quote',
                      subtitle: (d['status'] as String?) ?? 'draft',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuoteDetailsScreen(
                              teamId: teamId, quoteId: doc.id),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── Jobs ───────────────────────────────────────────────────
                _Section(
                  title:          'Jobs',
                  icon:           Icons.work_rounded,
                  accentColor:    _C.accent,
                  collection:     FirestorePaths.teamJobs(teamId),
                  whereField:     'clientId',
                  whereValue:     clientId,
                  sortKey:        'updatedAt',
                  sortDescending: true,
                  limit:          20,
                  emptyText:      'No jobs yet.',
                  itemBuilder:    (doc) {
                    final d = doc.data();
                    return _ActivityTile(
                      icon:      Icons.work_rounded,
                      iconColor: _C.accent,
                      title:    (d['title']  as String?) ?? 'Job',
                      subtitle: (d['status'] as String?) ?? '-',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JobDetailsScreen(
                              teamId: teamId, jobId: doc.id),
                        ),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Contact info card ─────────────────────────────────────────────────────

  Widget _infoCard(
      BuildContext context, String email, String phone, String name) {
    return Container(
      decoration: BoxDecoration(
        color:        _C.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _contactRow(
            icon:  Icons.email_rounded,
            value: email.isEmpty ? 'No email' : email,
            empty: email.isEmpty,
          ),
          Container(height: 1, color: _C.border, margin:
          const EdgeInsets.symmetric(horizontal: 16)),
          _contactRow(
            icon:  Icons.phone_rounded,
            value: phone.isEmpty ? 'No phone' : phone,
            empty: phone.isEmpty,
          ),
        ],
      ),
    );
  }

  Widget _contactRow(
      {required IconData icon,
        required String value,
        required bool empty}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width:  34,
            height: 34,
            decoration: BoxDecoration(
              color:        _C.accentSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _C.accent),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color:      empty ? _C.muted : _C.ink,
              fontSize:   14,
              fontWeight: empty ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color:       _C.ink,
        fontSize:    13,
        fontWeight:  FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
  }

  void _editContact(
      BuildContext context, String name, String email, String phone) {
    showModalBottomSheet<void>(
      context:          context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditContactSheet(
        docRef:       docRef,
        initialName:  name,
        initialEmail: email,
        initialPhone: phone,
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        _C.card,
          borderRadius: BorderRadius.circular(13),
          border:       Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width:  38,
              height: 38,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color:      _C.ink,
                fontSize:   12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity tile ─────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData     icon;
  final Color        iconColor;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:           onTap,
      borderRadius:    BorderRadius.circular(10),
      splashColor:     _C.accentSoft,
      highlightColor:  _C.accentSoft.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color:        iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color:      _C.ink,
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _C.muted, fontSize: 11)),
                ],
              ),
            ),
            Container(
              width:  26,
              height: 26,
              decoration: BoxDecoration(
                color:        _C.accentSoft,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: _C.accent, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.collection,
    required this.whereField,
    required this.whereValue,
    required this.sortKey,
    required this.sortDescending,
    required this.limit,
    required this.emptyText,
    required this.itemBuilder,
  });

  final String   title;
  final IconData icon;
  final Color    accentColor;
  final String   collection;
  final String   whereField;
  final String   whereValue;
  final String   sortKey;
  final bool     sortDescending;
  final int      limit;
  final String   emptyText;
  final Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  itemBuilder;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    docs.sort((a, b) {
      final aVal = a.data()[sortKey];
      final bVal = b.data()[sortKey];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return 1;
      if (bVal == null) return -1;
      int cmp = 0;
      if (aVal is Timestamp && bVal is Timestamp) {
        cmp = aVal.compareTo(bVal);
      } else if (aVal is Comparable && bVal is Comparable) {
        cmp = (aVal as Comparable).compareTo(bVal);
      } else {
        cmp = aVal.toString().compareTo(bVal.toString());
      }
      return sortDescending ? -cmp : cmp;
    });
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        _C.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width:  30,
                  height: 30,
                  decoration: BoxDecoration(
                    color:        accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color:      accentColor,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(collection)
                  .where(whereField, isEqualTo: whereValue)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _C.accent),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(snapshot.error.toString(),
                        style: const TextStyle(
                            color: _C.error, fontSize: 12)),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                docs = _sortDocs(docs);
                if (docs.length > limit) docs = docs.sublist(0, limit);

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: _C.muted),
                        const SizedBox(width: 8),
                        Text(emptyText,
                            style: const TextStyle(
                                color: _C.muted, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    for (var i = 0; i < docs.length; i++) ...[
                      itemBuilder(docs[i]),
                      if (i < docs.length - 1)
                        Container(
                            height: 1,
                            color:  _C.border,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 2)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit contact sheet ────────────────────────────────────────────────────────

class _EditContactSheet extends StatefulWidget {
  const _EditContactSheet({
    required this.docRef,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
  });

  final DocumentReference<Map<String, dynamic>> docRef;
  final String initialName;
  final String initialEmail;
  final String initialPhone;

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool    _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name  = TextEditingController(text: widget.initialName);
    _email = TextEditingController(text: widget.initialEmail);
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      if (_name.text.trim().isEmpty) throw Exception('Name is required.');
      await widget.docRef.update({
        'name':  _name.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'phone': _phone.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        _C.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 20, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width:  40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color:        _C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        _C.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded,
                    size: 18, color: _C.accent),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Contact',
                style: TextStyle(
                  color:       _C.ink,
                  fontSize:    17,
                  fontWeight:  FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sheetField(controller: _name,  label: 'Full name',
              icon: Icons.person_rounded),
          const SizedBox(height: 12),
          _sheetField(controller: _email, label: 'Email',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _sheetField(controller: _phone, label: 'Phone',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        _C.errorSoft,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                    color: _C.error.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: _C.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: _C.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: _saving
                    ? null
                    : const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                color: _saving ? _C.border : null,
                boxShadow: _saving
                    ? null
                    : [
                  BoxShadow(
                    color:      _C.accent.withOpacity(0.30),
                    blurRadius: 10,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor:     Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                icon: _saving
                    ? const SizedBox(
                    width:  16,
                    height: 16,
                    child:  CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  _saving ? 'Saving…' : 'Save Changes',
                  style: const TextStyle(
                    color:       Colors.white,
                    fontSize:    14,
                    fontWeight:  FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String                label,
    required IconData              icon,
    TextInputType?                 keyboardType,
  }) {
    return TextField(
      controller:   controller,
      keyboardType: keyboardType,
      style: const TextStyle(
          color: _C.ink, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: _C.muted, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: _C.muted),
        filled:     true,
        fillColor:  _C.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }
}