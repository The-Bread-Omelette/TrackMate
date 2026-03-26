import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/admin_remote_datasource.dart';
import '../../../../core/di/injection.dart';
import 'package:go_router/go_router.dart';

class AdminTrainersPage extends StatefulWidget {
  const AdminTrainersPage({super.key});
  @override
  State<AdminTrainersPage> createState() => _AdminTrainersPageState();
}

class _AdminTrainersPageState extends State<AdminTrainersPage> {
  final _ds = AdminRemoteDataSource(sl());
  
  Map<String, dynamic> _data = {}; 
  bool _loading = true;
  String _currentTab = 'pending'; // 🔥 NEW: Tracks which list we are viewing

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // 🔥 Fetches data strictly based on the selected tab
      _data = await _ds.getTrainerApplications(status: _currentTab);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(String userId, bool approve) async {
    try {
      await _ds.approveTrainer(userId, approve);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Trainer Approved' : 'Application Rejected'),
        backgroundColor: approve ? Colors.green : Colors.red,
      ));
      
      // Refresh the current tab to remove the card we just acted on
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: Colors.black87,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data['summary'] as Map<String, dynamic>? ?? {};
    final apps = _data['applications'] as List? ?? [];

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
        title: const Text('Trainer Applications', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), // Remember to keep the correct title for each page!
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          // TAB SELECTORS
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Row(
              children: [
                _buildTab('Pending', '${summary['pending'] ?? 0}', 'pending', Colors.orange),
                const SizedBox(width: 8),
                _buildTab('Approved', '${summary['approved'] ?? 0}', 'approved', Colors.green),
                const SizedBox(width: 8),
                _buildTab('Rejected', '${summary['rejected'] ?? 0}', 'rejected', Colors.red),
              ],
            ),
          ),
          
          // LIST VIEW
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: apps.isEmpty
                        ? Center(
                            child: Text('No $_currentTab applications found.', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: apps.length,
                            itemBuilder: (context, index) => _buildTrainerCard(apps[index] as Map<String, dynamic>),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // 🔥 NEW: Interactive Tab Builder
  Widget _buildTab(String label, String count, String tabValue, Color baseColor) {
    final isSelected = _currentTab == tabValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentTab != tabValue) {
            setState(() => _currentTab = tabValue);
            _load(); // Reload data for the new tab
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? baseColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? baseColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? baseColor : Colors.black87)),
              Text(label, style: TextStyle(fontSize: 12, color: isSelected ? baseColor : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerCard(Map<String, dynamic> app) {
    final userId = app['user_id'] ?? app['id'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(app['full_name'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_formatDate(app['submitted_at']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Text(app['email'] ?? 'No email', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Text(app['about'] ?? 'No bio provided.', style: const TextStyle(fontSize: 13)),
          if (app['specializations'] != null) ...[
            const SizedBox(height: 8),
            Text('Specializations: ${app['specializations']}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          
          // 🔥 NEW: Dynamic buttons based on the current tab
          if (_currentTab == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respond(userId, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respond(userId, false),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            )
          else if (_currentTab == 'approved')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _respond(userId, false), // Rejecting an approved user revokes them
                icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                label: const Text('Revoke Approval / Reject', style: TextStyle(color: Colors.red)),
              ),
            )
          else if (_currentTab == 'rejected')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _respond(userId, true), // Approving a rejected user
                icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                label: const Text('Re-Approve Trainer', style: TextStyle(color: Colors.white)),
              ),
            )
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}