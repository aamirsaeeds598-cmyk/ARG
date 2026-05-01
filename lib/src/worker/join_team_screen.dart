import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore_paths.dart';

// ─────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────
class _T {
  // Surfaces
  static const bg = Color(0xFF0F0F10);
  static const surface = Color(0xFF18181B);
  static const surfaceHover = Color(0xFF1E1E22);
  static const border = Color(0xFF2A2A2E);
  static const divider = Color(0xFF222226);

  // Text
  static const textPrimary = Color(0xFFF0F0F2);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF555555);

  // Accent – purple/violet
  static const accentStart = Color(0xFF5855D6);
  static const accentEnd = Color(0xFF7C3AED);

  // Status
  static const green = Color(0xFF4ADE80);
  static const greenBg = Color(0xFF1A2E1A);
  static const greenBorder = Color(0xFF166534);

  static const borderRadius = 16.0;
  static const cardRadius = 16.0;
}

// ─────────────────────────────────────────────
//  Gradient accent button
// ─────────────────────────────────────────────
class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            gradient: widget.onPressed == null
                ? null
                : const LinearGradient(
              colors: [_T.accentStart, _T.accentEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            color: widget.onPressed == null ? _T.border : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.loading
              ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Team icon widget
// ─────────────────────────────────────────────
class _TeamIcon extends StatelessWidget {
  const _TeamIcon({required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context) {
    // Cycle between two accent palettes based on teamId hash
    final isPurple = teamId.hashCode.isEven;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPurple
              ? const [Color(0xFF1E1B4B), Color(0xFF312E81)]
              : const [Color(0xFF0C2A1E), Color(0xFF064E3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPurple ? const Color(0xFF3730A3) : const Color(0xFF065F46),
          width: 1,
        ),
      ),
      child: Icon(
        isPurple ? Icons.group_rounded : Icons.trending_up_rounded,
        color: isPurple ? const Color(0xFF818CF8) : const Color(0xFF34D399),
        size: 20,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Role badge
// ─────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.isPurple});
  final String role;
  final bool isPurple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPurple ? const Color(0xFF1E1B4B) : const Color(0xFF052E16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPurple ? const Color(0xFF312E81) : const Color(0xFF065F46),
        ),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isPurple ? const Color(0xFF818CF8) : const Color(0xFF34D399),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Invite card
// ─────────────────────────────────────────────
class _InviteCard extends StatefulWidget {
  const _InviteCard({
    required this.invite,
    required this.isLoading,
    required this.onAccept,
  });

  final _InviteMatch invite;
  final bool isLoading;
  final VoidCallback onAccept;

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isPurple = widget.invite.teamId.hashCode.isEven;
    final role =
    (widget.invite.data['role'] as String? ?? 'worker').capitalize();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.cardRadius),
          border: Border.all(
            color: _hovered ? _T.accentStart : _T.border,
            width: _hovered ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                _TeamIcon(teamId: widget.invite.teamId),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.invite.teamId,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _T.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${widget.invite.inviteId}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _T.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RoleBadge(role: role, isPurple: isPurple),
              ],
            ),

            // Divider
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 1,
              color: _T.divider,
            ),

            // Footer row
            Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 13,
                  color: _T.textMuted,
                ),
                const SizedBox(width: 5),
                const Text(
                  'Pending invite',
                  style: TextStyle(fontSize: 11, color: _T.textMuted),
                ),
                const Spacer(),
                _GradientButton(
                  label: 'Accept →',
                  onPressed: widget.isLoading ? null : widget.onAccept,
                  loading: widget.isLoading,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Info footer strip
// ─────────────────────────────────────────────
class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: _T.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: _T.textMuted,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Invites matched to '),
                  TextSpan(
                    text: email,
                    style: const TextStyle(color: _T.textSecondary),
                  ),
                  const TextSpan(
                      text: '. Ask your admin if you\'re missing an invite.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Success toast
// ─────────────────────────────────────────────
class _SuccessToast extends StatelessWidget {
  const _SuccessToast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _T.greenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.greenBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: _T.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Main screen
// ─────────────────────────────────────────────
class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  String? _acceptingInviteId;

  String get _email =>
      (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();

  Future<List<_InviteMatch>> _findInvites() async {
    final email = _email;
    if (email.isEmpty) throw Exception('Your account has no email address.');

    final snap = await FirebaseFirestore.instance
        .collection('invites')
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .limit(25)
        .get();

    return snap.docs.map((d) {
      final teamId = (d.data()['teamId'] as String? ?? '').trim();
      return _InviteMatch(teamId: teamId, inviteId: d.id, data: d.data());
    }).where((m) => m.teamId.isNotEmpty).toList();
  }

  Future<void> _acceptInvite(_InviteMatch invite) async {
    setState(() {
      _isLoading = true;
      _acceptingInviteId = invite.inviteId;
      _error = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = _email;
      final db = FirebaseFirestore.instance;

      final inviteRef = db.collection('invites').doc(invite.inviteId);
      final memberRef =
      db.doc(FirestorePaths.teamMember(invite.teamId, user.uid));
      final userRef = db.doc(FirestorePaths.user(user.uid));

      await db.runTransaction((tx) async {
        tx.set(
          memberRef,
          {
            'uid': user.uid,
            'email': email,
            'role': 'worker',
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        tx.set(
          userRef,
          {
            'email': email,
            'role': 'worker',
            'currentTeamId': invite.teamId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        tx.update(inviteRef, {
          'status': 'accepted',
          'acceptedByUid': user.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        setState(() => _successMessage = 'You joined ${invite.teamId} successfully!');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _acceptingInviteId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;

    return Scaffold(
      backgroundColor:Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor:Color(0xFFF5F7FA),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            // Avatar circle
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_T.accentStart, Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Join a Team',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _T.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _T.textSecondary,
                side: const BorderSide(color: _T.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Sign out', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _T.border),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // ── Section header ──
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _T.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x554ADE80), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'PENDING INVITES',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // ── Error banner ──
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6B1A1A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 15, color: Color(0xFFFC8181)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFFC8181)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Success toast ──
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              _SuccessToast(message: _successMessage!),
            ],

            const SizedBox(height: 12),

            // ── Invite list ──
            Expanded(
              child: FutureBuilder<List<_InviteMatch>>(
                future: _findInvites(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _T.accentStart,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    log(snapshot.error.toString());
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: _T.textMuted, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error.toString(),
                            style:
                            const TextStyle(color: _T.textMuted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final invites = snapshot.data ?? const [];

                  if (invites.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color:Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: _T.border),
                            ),
                            child: const Icon(Icons.mail_outline_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No pending invites',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,

                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ask your admin to invite you,\nthen reopen this screen.',
                            style: TextStyle(
                                fontSize: 13,
                                color: _T.textMuted, height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Count headline
                      Text(
                        '${invites.length} waiting for you',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _T.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Cards
                      Expanded(
                        child: ListView.separated(
                          itemCount: invites.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final invite = invites[i];
                            final isThisLoading = _isLoading &&
                                _acceptingInviteId == invite.inviteId;
                            return _InviteCard(
                              invite: invite,
                              isLoading: isThisLoading,
                              onAccept: () => _acceptInvite(invite),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Info footer ──
            const SizedBox(height: 12),
            _InfoStrip(email: email.isEmpty ? '(no email)' : email),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────
class _InviteMatch {
  _InviteMatch({
    required this.teamId,
    required this.inviteId,
    required this.data,
  });

  final String teamId;
  final String inviteId;
  final Map<String, dynamic> data;
}

// ─────────────────────────────────────────────
//  String extension
// ─────────────────────────────────────────────
extension _StringX on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}