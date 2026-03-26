import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/admin_remote_datasource.dart';
import '../../../../core/di/injection.dart';
import 'package:go_router/go_router.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final _ds = AdminRemoteDataSource(sl());
  Map<String, dynamic> _data = {};
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
      _data = await _ds.getReports(status: 'pending');
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // FIXED: Uses the correct resolveReport method
  Future<void> _handleAction(String id, {bool dismiss = false}) async {
    try {
      await _ds.resolveReport(id, dismiss: dismiss);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(dismiss ? 'Report Dismissed' : 'Action Taken & Resolved'),
          backgroundColor: dismiss ? Colors.grey : AppColors.success,
        ));
      }
      await _load();
    } catch (_) {}
  }

  // FIXED: Banning is now correctly mapped to user deactivation
  Future<void> _banUser(String userId) async {
    try {
      await _ds.toggleUserStatus(userId, false); // false = deactivate/ban
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User has been banned (deactivated)'),
          backgroundColor: Colors.black,
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data['summary'] as Map<String, dynamic>? ?? {};
    final reports = _data['reports'] as List? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // 🔥 FIX: Safely navigate back. If there is no history, force a return to the dashboard.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), // Remember to keep the correct title for each page!
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _SummaryChip('Total', '${summary['total'] ?? 0}', AppColors.primary),
                        const SizedBox(width: 8),
                        _SummaryChip('Pending', '${summary['pending'] ?? 0}', Colors.orange),
                        const SizedBox(width: 8),
                        _SummaryChip('Resolved', '${summary['resolved'] ?? 0}', AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (reports.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No pending reports', style: TextStyle(color: AppColors.textMuted))))
                    else
                      ...reports.map((r) {
                        final report = r as Map<String, dynamic>;
                        final reporter = report['reporter'] as Map<String, dynamic>? ?? {};
                        final reported = report['reported_user'] as Map<String, dynamic>? ?? {};
                        
                        // Failsafe IDs
                        final reportId = report['id'] ?? '';
                        final reportedUserId = reported['id'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text((report['type'] ?? '').toUpperCase(), style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const Spacer(),
                                  Text(_formatDate(report['created_at'] ?? ''), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('From: ${reporter['full_name'] ?? 'Unknown'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('Target: ${reported['full_name'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                                child: Text(report['body'] ?? 'No report details provided.', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _handleAction(reportId, dismiss: false),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                      child: const Text('Resolve', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _handleAction(reportId, dismiss: true),
                                      child: const Text('Dismiss'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (reportedUserId.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: () => _banUser(reportedUserId),
                                    icon: const Icon(Icons.gavel, color: Colors.black, size: 18),
                                    label: const Text('Ban Reported User', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                )
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
      ),
    );
  }
}