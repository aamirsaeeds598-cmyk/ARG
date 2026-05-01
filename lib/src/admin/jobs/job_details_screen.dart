import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/firestore_paths.dart';
import 'invoice_screen.dart';
import 'job_status.dart';
import 'visit_details_screen.dart';

// Professional Color Palette
class AppColors {
  static const primary = Color(0xFF1F2937);
  static const secondary = Color(0xFF6B7280);
  static const accent = Color(0xFF3B82F6);

  static const success = Color(0xFF059669);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  static const surface = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFF3F4F6);
}

class JobDetailsScreen extends StatefulWidget {
  const JobDetailsScreen({
    super.key,
    required this.teamId,
    required this.jobId,
  });

  final String teamId;
  final String jobId;

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;
  String? _error;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    if (!mounted) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId))
          .update({
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessSnackBar('Job updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _parseError(e));
        _showErrorSnackBar(_error!);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteJob(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete job'),
        content: const Text(
          'This will permanently delete the job. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId))
          .delete();

      if (mounted) {
        _showSuccessSnackBar('Job deleted');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _parseError(e));
        _showErrorSnackBar(_error!);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendConfirmation({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String adminEmail,
    required String adminName,
  }) async {
    try {
      final clientId = data['clientId'] as String?;
      String clientEmail = '';

      if (clientId != null && clientId.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .doc(FirestorePaths.teamClient(widget.teamId, clientId))
              .get();
          clientEmail = (snap.data()?['email'] as String?)?.trim() ?? '';
        } catch (e) {
          debugPrint('Error fetching client email: $e');
        }
      }

      clientEmail = clientEmail.isEmpty ? 'aamirsaeed598@gmail.com' : clientEmail;

      final title = (data['title'] as String?) ?? 'Job';
      final scheduledAt = data['scheduledAt'];
      final scheduledText = _formatTimestamp(scheduledAt);

      final subject = Uri.encodeComponent('Job Confirmation: $title');
      final body = Uri.encodeComponent(
        'Dear Client,\n\n'
            'This is a confirmation for your upcoming job.\n\n'
            'Job: $title\n'
            'Scheduled: $scheduledText\n'
            'Sales person: $adminName\n\n'
            'Please reply if you have any questions.\n\n'
            'Regards,\n$adminName',
      );

      final uri = Uri.parse('mailto:$clientEmail?subject=$subject&body=$body');

      if (!await launchUrl(uri)) {
        if (context.mounted) {
          _showErrorSnackBar('Could not open email app');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to send confirmation');
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Not scheduled';

    final d = timestamp.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String _parseError(Object? error) {
    if (error == null) return 'An unknown error occurred';

    final errorString = error.toString();

    if (errorString.contains('permission-denied')) {
      return 'Permission denied. You do not have access to modify this job.';
    }
    if (errorString.contains('not-found')) {
      return 'Job not found. It may have been deleted.';
    }
    if (errorString.contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again.';
    }

    return errorString.length > 100
        ? '${errorString.substring(0, 100)}...'
        : errorString;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobRef = FirebaseFirestore.instance
        .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId));
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor:  Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete job',
            onPressed: _isSaving ? null : () => _deleteJob(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: jobRef.snapshots(),
        builder: (context, snapshot) => _buildContent(
          context,
          snapshot,
          currentUser,
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      User? currentUser,
      ) {
    if (!snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading job',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _parseError(snapshot.error),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final data = snapshot.data!.data() ?? {};
    final title = (data['title'] as String?) ?? 'Job';

    return FadeTransition(
      opacity: _fadeController,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SliverToBoxAdapter(
            child: _buildBody(context, data, currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      Map<String, dynamic> data,
      User? currentUser,
      ) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: currentUser != null
          ? FirebaseFirestore.instance
          .doc(FirestorePaths.user(currentUser.uid))
          .get()
          : null,
      builder: (context, userSnap) {
        final adminName = _getAdminName(userSnap.data?.data(), currentUser);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Status Overview
              _buildStatusOverview(context, data),
              const SizedBox(height: 16),

              // Job Info Card
              _buildJobInfoCard(context, data),
              const SizedBox(height: 12),

              // Visit Schedule Card
              _buildVisitScheduleCard(context, data),
              const SizedBox(height: 12),

              // Assigned Worker Card
              _buildAssignedWorkerCard(context, data),
              const SizedBox(height: 12),

              // Pricing Card
              _buildPricingCard(context, data),
              const SizedBox(height: 12),

              // Signature Card
              // _buildSignatureCard(context, data),
              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(context, data, adminName, currentUser?.email ?? ''),

              // Error Message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOverview(BuildContext context, Map<String, dynamic> data) {
    final status = JobStatus.fromValue(data['status'] as String?);
    final isClosed = status == JobStatus.done;
    final isPaid = (data['paymentStatus'] as String?) == 'paid';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isClosed
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isClosed
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isClosed ? Icons.check_circle : Icons.schedule,
                      size: 16,
                      color: isClosed ? AppColors.success : AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isClosed ? 'Completed' : status.value,
                      style: TextStyle(
                        color: isClosed ? AppColors.success : AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isPaid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.paid,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Paid',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard(BuildContext context, Map<String, dynamic> data) {
    final description = (data['description'] as String?) ?? '';
    final fromQuote = data['sourceQuoteId'] != null;

    return _Card(
      icon: Icons.info_outline,
      title: 'Job Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            'Title',
            (data['title'] as String?) ?? 'Job',
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow('Description', description),
          ],
          if (fromQuote) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Created from quote',
                style: TextStyle(
                  color: AppColors.info,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisitScheduleCard(BuildContext context, Map<String, dynamic> data) {
    return _VisitScheduleCard(
      teamId: widget.teamId,
      jobId: widget.jobId,
      jobData: data,
      isClosed: JobStatus.fromValue(data['status'] as String?) == JobStatus.done,
      isSaving: _isSaving,
      onSetSchedule: () async {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          initialDate: DateTime.now(),
        );

        if (date == null || !mounted) return;

        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (time == null) return;

        await _update({
          'scheduledAt': Timestamp.fromDate(
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
          ),
        });
      },
    );
  }

  Widget _buildAssignedWorkerCard(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    final assignedEmail = data['assignedWorkerEmail'] as String?;

    if (assignedEmail != null && assignedEmail.isNotEmpty) {
      return _AssignedWorkerDisplayCard(
        assignedEmail: assignedEmail,
      );
    } else {
      return _AssignWorkerSelectionCard(
        teamId: widget.teamId,
        onWorkerSelected: (email) async {
          await _update({
            'assignedWorkerEmail': email,
            'status': JobStatus.assigned.value,
          });
          // Auto-assign worker to this team
          if (email.isNotEmpty) {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) {
              final d = snap.docs.first;
              final current = d.data()['currentTeamId'] as String?;
              if (current == null || current.isEmpty) {
                await d.reference.update({'currentTeamId': widget.teamId});
              }
            }
          }
        },
        isSaving: _isSaving,
      );
    }
  }

  Widget _buildPricingCard(BuildContext context, Map<String, dynamic> data) {
    final priceCents = data['priceCents'] as int?;

    return _Card(
      icon: Icons.payments_outlined,
      title: 'Pricing',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Subtotal',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 14,
            ),
          ),
          Text(
            priceCents == null
                ? '—'
                : '\$${(priceCents / 100).toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard(BuildContext context, Map<String, dynamic> data) {
    final signature = data['signature'] as String?;

    return _Card(
      icon: Icons.draw_outlined,
      title: 'Signature',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (signature != null && signature.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    const Text('Signature collected',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  // Show as image if base64, else plain text
                  _isBase64Sig(signature)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            base64Decode(signature),
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Text(signature,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _isSaving
                  ? null
                  : () => _showSignatureDialog(context, signature),
              icon: const Icon(Icons.edit, size: 18),
              label: Text(
                signature != null && signature.isNotEmpty
                    ? 'Update signature'
                    : 'Collect signature',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context,
      Map<String, dynamic> data,
      String adminName,
      String adminEmail,
      ) {
    final status = JobStatus.fromValue(data['status'] as String?);
    final isClosed = status == JobStatus.done;
    final isPaid = (data['paymentStatus'] as String?) == 'paid';

    if (!isClosed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isSaving
                ? null
                : () => _sendConfirmation(
              context: context,
              data: data,
              adminEmail: adminEmail,
              adminName: adminName,
            ),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Send confirmation'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.success, width: 1.5),
              foregroundColor: AppColors.success,
            ),
            onPressed: _isSaving
                ? null
                : () => _update({'status': JobStatus.done.value}),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Close job'),
          ),
        ],
      );
    } else {
      return _ClosedJobActionsCard(
        teamId: widget.teamId,
        jobId: widget.jobId,
        data: data,
        isPaid: isPaid,
        isSaving: _isSaving,
        onReopenJob: () => _update({'status': JobStatus.open.value}),
      );
    }
  }

  String _getAdminName(Map<String, dynamic>? userData, User? currentUser) {
    if (userData != null) {
      final name = (userData['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return currentUser?.email ?? 'Admin';
  }

  void _showSignatureDialog(BuildContext context, String? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => _SignatureDialog(
        existing: existing,
        onSave: (sig) => _update({'signature': sig}),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Card Component
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signature Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog({
    required this.existing,
    required this.onSave,
  });

  final String? existing;
  final Future<void> Function(String) onSave;

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  late final SignatureController _ctrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_ctrl.isEmpty) {
      setState(() => _error = 'Please draw your signature.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      // Export as PNG bytes then base64
      final image = await _ctrl.toImage();
      final bytes = await image!.toByteData(format: ui.ImageByteFormat.png);
      final b64 = base64Encode(bytes!.buffer.asUint8List());
      await widget.onSave(b64);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Collect signature'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Draw your signature below.',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Signature(
                controller: _ctrl,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _ctrl.clear()),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
          if (_error != null)
            Text(_error!,
                style: TextStyle(
                    color: theme.colorScheme.error, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save signature'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visit Schedule Card
// ── Base64 signature helper ───────────────────────────────────────────────────

bool _isBase64Sig(String s) {
  if (s.length < 100) return false;
  try { base64Decode(s); return true; } catch (_) { return false; }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VisitScheduleCard extends StatelessWidget {
  const _VisitScheduleCard({
    required this.teamId,
    required this.jobId,
    required this.jobData,
    required this.isClosed,
    required this.isSaving,
    required this.onSetSchedule,
  });

  final String teamId;
  final String jobId;
  final Map<String, dynamic> jobData;
  final bool isClosed;
  final bool isSaving;
  final VoidCallback onSetSchedule;

  String get _formattedSchedule {
    final scheduledTs = jobData['scheduledAt'];
    if (scheduledTs is! Timestamp) return 'Not scheduled';

    final d = scheduledTs.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  bool get _isScheduled => jobData['scheduledAt'] is Timestamp;

  Future<void> _openOrCreateVisit(BuildContext context) async {
    if (!_isScheduled) {
      onSetSchedule();
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.jobVisits(teamId, jobId))
        .orderBy('createdAt', descending: false)
        .limit(1)
        .get();

    String visitId;

    if (snap.docs.isNotEmpty) {
      visitId = snap.docs.first.id;
    } else {
      visitId = await _createVisit();
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitDetailsScreen(
          teamId: teamId,
          jobId: jobId,
          visitId: visitId,
        ),
      ),
    );
  }

  Future<String> _createVisit() async {
    final lineItemsRaw = jobData['lineItems'];
    final lineItems = lineItemsRaw is List ? lineItemsRaw : [];
    final workerEmail = (jobData['assignedWorkerEmail'] as String?) ?? '';

    String workerName = workerEmail;
    if (workerEmail.isNotEmpty) {
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: workerEmail)
            .limit(1)
            .get();

        final name = (userSnap.docs.firstOrNull?.data()['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          workerName = name;
        }
      } catch (e) {
        debugPrint('Error fetching worker name: $e');
      }
    }

    final ref = await FirebaseFirestore.instance
        .collection(FirestorePaths.jobVisits(teamId, jobId))
        .add({
      'scheduledAt': jobData['scheduledAt'],
      'status': 'scheduled',
      'workerEmail': workerEmail,
      'workerName': workerName.isNotEmpty ? workerName : 'Test Name',
      'instructions': (jobData['description'] as String?) ?? '',
      'lineItems': lineItems,
      'timerRunning': false,
      'timerStartedAt': null,
      'totalSeconds': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color:       Color(0xFFF5F7FA),

    child: InkWell(
        onTap: isClosed ? null : () => _openOrCreateVisit(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isScheduled
                ? AppColors.accent.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isScheduled
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month,
                size: 18,
                color: _isScheduled ? AppColors.accent : AppColors.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visit date & time',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedSchedule,
                      style: TextStyle(
                        color: _isScheduled
                            ? AppColors.accent
                            : AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isClosed)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assigned Worker Cards
// ─────────────────────────────────────────────────────────────────────────────

class _AssignedWorkerDisplayCard extends StatelessWidget {
  const _AssignedWorkerDisplayCard({required this.assignedEmail});

  final String assignedEmail;

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: Icons.person_2_outlined,
      title: 'Assigned worker',
      child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: assignedEmail)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final workerData = snapshot.data?.docs.firstOrNull?.data();
          final workerName = (workerData?['name'] as String?)?.trim().isNotEmpty == true
              ? workerData!['name'] as String
              : 'Worker';

          return Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workerName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      assignedEmail,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AssignWorkerSelectionCard extends StatelessWidget {
  const _AssignWorkerSelectionCard({
    required this.teamId,
    required this.onWorkerSelected,
    required this.isSaving,
  });

  final String teamId;
  final Function(String) onWorkerSelected;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: Icons.person_add_outlined,
      title: 'Assign worker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No worker assigned',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'worker')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final workers = docs.map((d) => (
                email: (d.data()['email'] as String?) ?? '',
                name: (d.data()['name'] as String?)?.trim() ?? '',
              )).where((w) => w.email.isNotEmpty).toList();

              if (workers.isEmpty) {
                return const Text(
                  'No workers on this team yet.',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                );
              }

              return DropdownButtonFormField<String>(
                initialValue: null,
                items: [
                  for (final w in workers)
                    DropdownMenuItem(
                      value: w.email,
                      child: Text(w.name.isNotEmpty ? w.name : w.email),
                    ),
                ],
                onChanged: isSaving ? null : (email) => onWorkerSelected(email ?? ''),
                decoration: InputDecoration(
                  labelText: 'Select worker',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Closed Job Actions Card
// ─────────────────────────────────────────────────────────────────────────────

class _ClosedJobActionsCard extends StatelessWidget {
  const _ClosedJobActionsCard({
    required this.teamId,
    required this.jobId,
    required this.data,
    required this.isPaid,
    required this.isSaving,
    required this.onReopenJob,
  });

  final String teamId;
  final String jobId;
  final Map<String, dynamic> data;
  final bool isPaid;
  final bool isSaving;
  final VoidCallback onReopenJob;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Job completed',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection(FirestorePaths.jobVisits(teamId, jobId))
                          .where('status', isEqualTo: 'completed')
                          .orderBy('createdAt', descending: true)
                          .limit(1)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text(
                            'Visit completed',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11,
                            ),
                          );
                        }

                        final visitData = snapshot.data!.docs.first.data();
                        final completedTs = visitData['scheduledAt'];

                        if (completedTs is! Timestamp) {
                          return const Text(
                            'Visit completed',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11,
                            ),
                          );
                        }

                        final d = completedTs.toDate();
                        final formatted = 'Done on '
                            '${d.year}-${d.month.toString().padLeft(2, '0')}-'
                            '${d.day.toString().padLeft(2, '0')} at '
                            '${d.hour.toString().padLeft(2, '0')}:'
                            '${d.minute.toString().padLeft(2, '0')}';

                        return Text(
                          formatted,
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isPaid)
          _InvoiceViewCard(teamId: teamId, jobId: jobId)
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InvoiceScreen(
                  teamId: teamId,
                  jobId: jobId,
                  jobData: data,
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Create invoice'),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: AppColors.accent, width: 1.5),
            foregroundColor: AppColors.accent,
          ),
          onPressed: isSaving ? null : onReopenJob,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reopen job'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice View Card
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceViewCard extends StatelessWidget {
  const _InvoiceViewCard({
    required this.teamId,
    required this.jobId,
  });

  final String teamId;
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection(FirestorePaths.teamInvoices(teamId))
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: null,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Loading...'),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          return OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No invoice found')),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('No invoice found'),
          );
        }

        final invoiceData = snapshot.data!.docs.first.data();

        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => _showInvoiceDialog(context, invoiceData),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('View invoice'),
        );
      },
    );
  }

  void _showInvoiceDialog(
      BuildContext context,
      Map<String, dynamic> invoiceData,
      ) {
    final title = (invoiceData['title'] as String?)?.isNotEmpty == true
        ? invoiceData['title'] as String
        : 'Invoice';

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow('Client', (invoiceData['clientName'] as String?) ?? '—'),
              _InfoRow('Sales person', (invoiceData['salesPersonName'] as String?) ?? '—'),
              _InfoRow(
                'Total',
                '\$${(((invoiceData['totalCents'] as int?) ?? 0) / 100).toStringAsFixed(2)}',
              ),
              _InfoRow('Status', (invoiceData['status'] as String?) ?? '—'),
              const SizedBox(height: 12),
              const Text(
                'Items',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              for (final item
              in (invoiceData['items'] as List? ?? []).cast<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text((item['name'] ?? '').toString())),
                      Text(
                        (item['priceCents'] as int? ?? 0) == 0
                            ? 'Free'
                            : '\$${((item['priceCents'] as int) / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row & Info Item Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}