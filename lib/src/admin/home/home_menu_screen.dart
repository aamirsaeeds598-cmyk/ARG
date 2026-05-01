import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../clients/clients_screen.dart';
import '../invoices/create_invoice_screen.dart';
import '../jobs/jobs_screen.dart';
import '../payments/payments_screen.dart';
import '../quotes/quotes_screen.dart';
import '../requests/requests_screen.dart';
import '../schedule/schedule_screen.dart';
import '../search/search_screen.dart';
import '../workers/workers_screen.dart';

// Professional Color Palette
class AppColors {
  static const primary = Color(0xFF1F2937);
  static const secondary = Color(0xFF6B7280);
  static const accent = Color(0xFF3B82F6);

  static const surface = Color(0xFFF9FAFB);
  static const background = Colors.white;
  static const border = Color(0xFFE5E7EB);

  // Module Colors
  static const jobsColor = Color(0xFF0EA5E9);
  static const requestsColor = Color(0xFFA855F7);
  static const quotesColor = Color(0xFFF59E0B);
  static const clientsColor = Color(0xFF10B981);
  static const workersColor = Color(0xFFEF4444);
  static const scheduleColor = Color(0xFF06B6D4);
  static const invoicesColor = Color(0xFF6366F1);
  static const paymentsColor = Color(0xFF8B5CF6);
  static const searchColor = Color(0xFF14B8A6);
}

class HomeMenuScreen extends StatefulWidget {
  const HomeMenuScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final modules = [
      _Module(
        label: 'Jobs',
        icon: Icons.work_outline,
        color: AppColors.jobsColor,
        builder: () => JobsScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Requests',
        icon: Icons.inbox_outlined,
        color: AppColors.requestsColor,
        builder: () => RequestsScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Quotes',
        icon: Icons.request_quote_outlined,
        color: AppColors.quotesColor,
        builder: () => QuotesScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Clients',
        icon: Icons.person_outline,
        color: AppColors.clientsColor,
        builder: () => ClientsScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Workers',
        icon: Icons.badge_outlined,
        color: AppColors.workersColor,
        builder: () => WorkersScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Schedule',
        icon: Icons.calendar_month_outlined,
        color: AppColors.scheduleColor,
        builder: () => ScheduleScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Invoices',
        icon: Icons.receipt_long_outlined,
        color: AppColors.invoicesColor,
        builder: () => CreateInvoiceScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Payments',
        icon: Icons.payments_outlined,
        color: AppColors.paymentsColor,
        builder: () => PaymentsScreen(teamId: widget.teamId),
      ),
      _Module(
        label: 'Search',
        icon: Icons.search,
        color: AppColors.searchColor,
        builder: () => SearchScreen(teamId: widget.teamId),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 32.h),
            children: [
              _buildHeader(),
              SizedBox(height: 32.h),
              _buildModulesGrid(context, modules),
              SizedBox(height: 24.h),
              _buildQuickStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 28.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Welcome to your workspace',
          style: TextStyle(
            color: AppColors.secondary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static const _needsScaffold = {
    'Requests', 'Clients', 'Schedule', 'Search', 'Payments',
  };

  void _openModule(BuildContext context, _Module module) {
    final screen = module.builder();
    final needsWrap = _needsScaffold.contains(module.label);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => needsWrap
            ? Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
              title: Text(module.label)),
          body: SafeArea(child: screen),
        )
            : screen,
      ),
    );
  }

  Widget _buildModulesGrid(BuildContext context, List<_Module> modules) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 0.95,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return _buildModuleCard(context, module, delay: index * 50);
      },
    );
  }

  Widget _buildModuleCard(
      BuildContext context,
      _Module module, {
        required int delay,
      }) {
    return GestureDetector(
      onTap: () => _openModule(context, module),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _openModule(context, module),
            borderRadius: BorderRadius.circular(14.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        module.color.withValues(alpha: 0.12),
                        module.color.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    module.icon,
                    color: module.color,
                    size: 28.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  module.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 18.sp,
                  color: AppColors.accent,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Tap any module above to manage your business operations. Use Search to quickly find anything.',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 12.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Module {
  const _Module({
    required this.label,
    required this.icon,
    required this.color,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
}