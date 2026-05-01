import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Generic screen that streams a Firestore query and renders each doc
/// using a provided [itemBuilder].
///
/// Features:
/// - Real-time data streaming from Firestore
/// - Comprehensive error handling with user-friendly messages
/// - Empty state handling with customizable text
/// - Smooth loading and refresh animations
/// - Responsive design with proper spacing
/// - Accessibility considerations
class DashboardDetailScreen extends StatelessWidget {
  const DashboardDetailScreen({
    super.key,
    required this.title,
    required this.query,
    required this.emptyText,
    required this.itemBuilder,
    this.onRetry,
  });

  final String title;
  final Query<Map<String, dynamic>> query;
  final String emptyText;
  final Widget Function(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) itemBuilder;

  /// Optional callback for retrying failed queries
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) =>
            _buildBody(context, snapshot),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
    // Handle loading state
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingState();
    }

    // Handle error state
    if (snapshot.hasError) {
      return _buildErrorState(context, snapshot.error);
    }

    // Handle empty state
    final docs = snapshot.data?.docs ?? [];
    if (docs.isEmpty) {
      return _buildEmptyState(context);
    }

    // Handle success state
    return _buildListView(docs);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    final theme = Theme.of(context);
    final isNetworkError = error.toString().contains('Failed host lookup') ||
        error.toString().contains('Network is unreachable');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.cloud_off : Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError ? 'No Internet Connection' : 'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getErrorMessage(error),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemBuilder: (context, index) {
        return itemBuilder(context, docs[index]);
      },
    );
  }

  String _getErrorMessage(Object? error) {
    if (error == null) return 'An unknown error occurred';

    final errorString = error.toString();

    if (errorString.contains('permission-denied')) {
      return 'You do not have permission to access this data.';
    }
    if (errorString.contains('Failed host lookup') ||
        errorString.contains('Network is unreachable')) {
      return 'Please check your internet connection and try again.';
    }
    if (errorString.contains('deadline-exceeded')) {
      return 'The request took too long. Please try again.';
    }

    // Return a truncated version of the error for other cases
    return errorString.length > 100
        ? '${errorString.substring(0, 100)}...'
        : errorString;
  }
}