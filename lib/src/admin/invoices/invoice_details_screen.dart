import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/firestore_paths.dart';
import '../jobs/line_items_screen.dart';

// Professional Color Palette
class AppColors {
  static const primary = Color(0xFF1F2937);
  static const secondary = Color(0xFF6B7280);
  static const accent = Color(0xFF3B82F6);

  static const success = Color(0xFF059669);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  static const surface = Color(0xFFF9FAFB);
  static const background = Colors.white;
  static const border = Color(0xFFE5E7EB);
}

class InvoiceDetailsScreen extends StatelessWidget {
  const InvoiceDetailsScreen({
    super.key,
    required this.teamId,
    required this.invoiceId,
  });

  final String teamId;
  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .doc(FirestorePaths.teamInvoice(teamId, invoiceId));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!.data() ?? {};
        return _InvoiceDetailsBody(
          teamId: teamId,
          invoiceId: invoiceId,
          data: data,
          docRef: ref,
        );
      },
    );
  }
}

class _InvoiceDetailsBody extends StatefulWidget {
  const _InvoiceDetailsBody({
    required this.teamId,
    required this.invoiceId,
    required this.data,
    required this.docRef,
  });

  final String teamId;
  final String invoiceId;
  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> docRef;

  @override
  State<_InvoiceDetailsBody> createState() => _InvoiceDetailsBodyState();
}

class _InvoiceDetailsBodyState extends State<_InvoiceDetailsBody>
    with SingleTickerProviderStateMixin {
  bool _collecting = false;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  int get _subtotalCents {
    final items = (widget.data['items'] as List? ?? []).cast<Map>();
    return items.fold<int>(0, (acc, i) => acc + ((i['priceCents'] as int?) ?? 0));
  }

  Future<void> _resendEmail() async {
    final email = _resolveEmail();
    final title = (widget.data['title'] as String?) ?? 'Invoice';
    final subject = Uri.encodeComponent(title);
    final body = Uri.encodeComponent(_buildTemplate());
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Could not open email app')),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Email opened successfully')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _resolveEmail() {
    final email = (widget.data['clientEmail'] as String?)?.trim() ?? '';
    return email.isNotEmpty ? email : 'aamirsaeed598@gmail.com';
  }

  String _buildTemplate() {
    final title = (widget.data['title'] as String?) ?? 'Invoice';
    final clientName = (widget.data['clientName'] as String?) ?? '';
    final salesPerson = (widget.data['salesPersonName'] as String?) ?? '';
    final items = (widget.data['items'] as List? ?? []).cast<Map>();
    final message = (widget.data['clientMessage'] as String?) ?? '';
    final issueTs = widget.data['issueDate'];
    final dateStr = issueTs is Timestamp
        ? () {
      final d = issueTs.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }()
        : '';

    final buf = StringBuffer();
    buf.writeln(title);
    if (dateStr.isNotEmpty) buf.writeln('Date: $dateStr');
    if (salesPerson.isNotEmpty) buf.writeln('Sales person: $salesPerson');
    buf.writeln('');
    buf.writeln('Bill To: $clientName');
    buf.writeln('');
    buf.writeln('Services / Items:');
    for (final item in items) {
      final price = (item['priceCents'] as int? ?? 0) == 0
          ? 'Free'
          : '\$${((item['priceCents'] as int) / 100).toStringAsFixed(2)}';
      buf.writeln('  - ${item['name']}: $price');
    }
    buf.writeln('');
    buf.writeln('Total: \$${(_subtotalCents / 100).toStringAsFixed(2)}');
    if (message.isNotEmpty) {
      buf.writeln('');
      buf.writeln(message);
    }
    return buf.toString();
  }

  Future<void> _collectPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Collect payment'),
        content: const Text(
          'Mark this invoice as paid? This action will update the associated job status as well.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm payment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _collecting = true);
    try {
      await widget.docRef.update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If linked to a job, mark it paid too
      final jobId = widget.data['jobId'] as String?;
      if (jobId != null && jobId.isNotEmpty) {
        await FirebaseFirestore.instance
            .doc(FirestorePaths.teamJob(widget.teamId, jobId))
            .update({
          'paymentStatus': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Payment collected successfully')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _collecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final title = (d['title'] as String?) ?? 'Invoice';
    final clientName = (d['clientName'] as String?) ?? '—';
    final clientEmail = (d['clientEmail'] as String?) ?? '';
    final salesPerson = (d['salesPersonName'] as String?) ?? '—';
    final clientMessage = (d['clientMessage'] as String?) ?? '';
    final status = (d['status'] as String?) ?? 'draft';
    final isPaid = status == 'paid';
    final items = (d['items'] as List? ?? []).cast<Map>();

    final issueTs = d['issueDate'];
    final issueDate = issueTs is Timestamp
        ? () {
      final dt = issueTs.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }()
        : '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPaid
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isPaid
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: isPaid ? AppColors.success : AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Invoice Header
              _buildInvoiceHeader(title, issueDate, isPaid),
              const SizedBox(height: 20),

              // Invoice Details Card
              _buildInvoiceDetailsCard(clientName, clientEmail, salesPerson),
              const SizedBox(height: 12),

              // Items Card
              _buildItemsCard(items, isPaid),
              const SizedBox(height: 12),

              // Client Message
              if (clientMessage.isNotEmpty) ...[
                _buildClientMessageCard(clientMessage),
                const SizedBox(height: 12),
              ],

              // Action Buttons
              _buildActionButtons(isPaid),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(String title, String date, bool isPaid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPaid
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: isPaid ? AppColors.success : AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Issued on $date',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceDetailsCard(
      String clientName,
      String clientEmail,
      String salesPerson,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Invoice details',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDetailRow('Client', clientName),
          if (clientEmail.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Email', clientEmail),
          ],
          const SizedBox(height: 8),
          _buildDetailRow('Sales person', salesPerson),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildItemsCard(List<Map<dynamic, dynamic>> items, bool isPaid) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isPaid
              ? null
              : () async {
            final current = items
                .map((m) => LineItem(
              name: (m['name'] ?? '').toString(),
              priceCents: (m['priceCents'] as int?) ?? 0,
              description: (m['description'] ?? '').toString(),
            ))
                .toList();
            final result = await Navigator.of(context)
                .push<List<LineItem>>(MaterialPageRoute(
              builder: (_) => LineItemsScreen(initial: current),
            ));
            if (result != null) {
              final updated = result
                  .map((i) => {
                'name': i.name,
                'priceCents': i.priceCents,
                'description': i.description,
              })
                  .toList();
              final total = result.fold<int>(
                  0, (acc, i) => acc + i.priceCents);
              await widget.docRef.update({
                'items': updated,
                'totalCents': total,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_outlined, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Products / Services',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isPaid)
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Text(
                    isPaid ? 'No items' : 'Tap to add services',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  )
                else ...[
                  for (int i = 0; i < items.length; i++) ...[
                    _buildItemRow(items[i]),
                    if (i < items.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  _buildTotalRow(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(Map<dynamic, dynamic> item) {
    final priceCents = (item['priceCents'] as int?) ?? 0;
    final price = priceCents == 0
        ? 'Free'
        : '\$${(priceCents / 100).toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['name'] ?? '').toString(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if ((item['description'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      (item['description'] ?? '').toString(),
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            price,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Row(
      children: [
        const Text(
          'Total',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '\$${(_subtotalCents / 100).toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildClientMessageCard(String message) {
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
          Row(
            children: [
              const Icon(
                Icons.message_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Client message',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isPaid) {
    if (!isPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
            ),
            onPressed: _resendEmail,
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Resend via email'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _collecting ? null : _collectPayment,
            icon: Icon(
              _collecting ? Icons.hourglass_empty : Icons.payments_outlined,
              size: 18,
            ),
            label: Text(
              _collecting ? 'Processing...' : 'Collect payment',
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment collected',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This invoice has been marked as paid',
                    style: TextStyle(
                      color: AppColors.success.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}