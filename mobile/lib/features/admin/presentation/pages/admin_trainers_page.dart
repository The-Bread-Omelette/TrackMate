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
  String _currentTab = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // 🔥 FRONTEND TRICK: Fetch all tabs to find the LATEST status for each user
      final pRes = await _ds.getTrainerApplications(status: 'pending');
      final aRes = await _ds.getTrainerApplications(status: 'approved');
      final rRes = await _ds.getTrainerApplications(status: 'rejected');

      // Inject the status into the objects so we can track them after combining
      final pApps = (pRes['applications'] as List? ?? []).map((e) => {...e as Map<String,dynamic>, 'status': 'pending'}).toList();
      final aApps = (aRes['applications'] as List? ?? []).map((e) => {...e as Map<String,dynamic>, 'status': 'approved'}).toList();
      final rApps = (rRes['applications'] as List? ?? []).map((e) => {...e as Map<String,dynamic>, 'status': 'rejected'}).toList();

      final allAppsList = [...pApps, ...aApps, ...rApps];

      // 🔥 FIX: Sort by date (newest first) using both possible date keys
      allAppsList.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? a['submitted_at']?.toString() ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? b['submitted_at']?.toString() ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA); 
      });

      // Deduplicate by user_id, keeping only the most recent application
      final Map<String, dynamic> latestAppsPerUser = {};
      for (final app in allAppsList) {
        final uid = app['user_id'] ?? app['id'];
        if (!latestAppsPerUser.containsKey(uid)) {
          latestAppsPerUser[uid] = app;
        }
      }

      final filteredApps = latestAppsPerUser.values.toList();
      
      // Recalculate summary dynamically based on the deduplicated list
      int countP = 0, countA = 0, countR = 0;
      final List<dynamic> currentTabApps = [];

      for (final app in filteredApps) {
        final status = app['status'];
        if (status == 'pending') countP++;
        else if (status == 'approved') countA++;
        else if (status == 'rejected') countR++;

        if (status == _currentTab) {
          currentTabApps.add(app);
        }
      }

      _data = {
        'summary': {'pending': countP, 'approved': countA, 'rejected': countR},
        'applications': currentTabApps,
      };

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
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        title: const Text('Trainer Applications', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
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

  Widget _buildTab(String label, String count, String tabValue, Color baseColor) {
    final isSelected = _currentTab == tabValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentTab != tabValue) {
            setState(() => _currentTab = tabValue);
            _load(); 
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
              // 🔥 FIX: Ensures the date renders correctly by checking both keys
              Text(_formatDate(app['created_at']?.toString() ?? app['submitted_at']?.toString()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                onPressed: () => _respond(userId, false),
                icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                label: const Text('Revoke Approval / Reject', style: TextStyle(color: Colors.red)),
              ),
            )
          else if (_currentTab == 'rejected')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _respond(userId, true), 
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