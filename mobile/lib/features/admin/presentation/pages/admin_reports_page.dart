import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/admin_remote_datasource.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _ds = AdminRemoteDataSource(sl());
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      _stats = await _ds.getStats();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stats API Failed 🚨'),
            content: Text(e.toString()),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely retrieve the user
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    // Responsive grid layout: 3 columns on wide screens for the 3 stat cards
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 800 ? 3 : 2;

    return MainLayout(
      user: user!,
      title: 'Admin Dashboard',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900), // Optimal width for readability
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const _WelcomeBanner(),
                const SizedBox(height: 32),

                // STATS GRID
                const Text(
                    "System Overview",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: screenWidth > 600 ? 1.6 : 1.4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StatCard(
                      icon: Icons.people_alt_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Users',
                      value: '${_stats['total_users'] ?? 0}',
                    ),
                    _StatCard(
                      icon: Icons.manage_accounts_outlined,
                      iconColor: Colors.purple,
                      title: 'Active Trainers',
                      value: '${_stats['active_trainers'] ?? 0}',
                    ),
                    _StatCard(
                      icon: Icons.assignment_ind_outlined,
                      iconColor: Colors.orange,
                      title: 'Trainer Apps',
                      value: '${_stats['pending_trainer_applications'] ?? 0}',
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // QUICK ACTIONS
                const Text(
                    "Quick Actions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _QuickActionCard(
                      icon: Icons.manage_accounts,
                      label: 'Review Trainer Apps',
                      color: Colors.orange,
                      onTap: () {
                        context.push(AppRouter.adminTrainers).then((_) => _load());
                      },
                    ),
                    const SizedBox(width: 16),
                    _QuickActionCard(
                      icon: Icons.group,
                      label: 'Manage All Users',
                      color: Colors.green,
                      onTap: () {
                        context.push(AppRouter.adminUsers).then((_) => _load());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A highly polished gradient welcome banner.
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Welcome, Admin',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)
                ),
                SizedBox(height: 8),
                Text(
                    'Manage users, trainers, and system settings efficiently.',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)
                ),
              ],
            ),
          ),
          Icon(Icons.dashboard_customize_rounded, color: Colors.white24, size: 64),
        ],
      ),
    );
  }
}

/// A modern stat card with subtle depth.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        title,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)
                    )
                )
              ]
          ),
          const SizedBox(height: 16),
          Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)
          ),
        ],
      ),
    );
  }
}

/// A clean, tap-friendly quick action button.
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          highlightColor: color.withOpacity(0.05),
          splashColor: color.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2))
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 12),
                Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}