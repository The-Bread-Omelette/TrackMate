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
  String _currentTab = 'pending'; // 'pending', 'approved', 'rejected'
  String _category = 'new'; // 'new' (Admissions) or 'updates' (Profile Updates)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    try {
      final Future<Map<String, dynamic>> Function({String? status}) fetchFunc = 
        _category == 'new' ? _ds.getNewAdmissions : _ds.getProfileUpdates;

      // Fetch the exact status we are viewing. The backend natively provides global
      // counts for all statuses inside the 'summary' object on every request.
      final response = await fetchFunc(status: _currentTab);

      _data = {
        'summary': response['summary'] ?? {},
        'applications': response['applications'] ?? [],
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
        content: Text(approve ? 'Request Approved' : 'Request Rejected'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _category == 'new' ? AppColors.primary : Colors.grey.shade200,
                      foregroundColor: _category == 'new' ? Colors.white : Colors.black87,
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (_category != 'new') {
                        setState(() => _category = 'new');
                        _load();
                      }
                    },
                    child: const Text('New Admissions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _category == 'updates' ? AppColors.primary : Colors.grey.shade200,
                      foregroundColor: _category == 'updates' ? Colors.white : Colors.black87,
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (_category != 'updates') {
                        setState(() => _category = 'updates');
                        _load();
                      }
                    },
                    child: const Text('Profile Updates'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                            child: Text('No $_currentTab requests found in this category.', style: const TextStyle(color: Colors.grey, fontSize: 14)),
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

  Widget _buildDiff(String label, dynamic oldVal, dynamic newVal) {
    final oStr = oldVal?.toString() ?? 'None';
    final nStr = newVal?.toString() ?? 'None';
    
    if (oStr == nStr) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text('$label: $nStr', style: const TextStyle(fontSize: 13, color: Colors.black87)),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(oStr, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red, fontSize: 13)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
              ),
              Text(nStr, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerCard(Map<String, dynamic> app) {
    final userId = app['user_id'] ?? app['id'] ?? '';
    final bool isUpdate = _category == 'updates';
    
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
              Text(_formatDate(app['created_at']?.toString() ?? app['submitted_at']?.toString()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Text(app['email'] ?? 'No email', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          
          if (!isUpdate) ...[
            Text(app['about'] ?? 'No bio provided.', style: const TextStyle(fontSize: 13)),
            if (app['specializations'] != null) ...[
              const SizedBox(height: 8),
              Text('Specializations: ${app['specializations']}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
            if (app['certifications'] != null) ...[
              const SizedBox(height: 4),
              Text('Certifications: ${app['certifications']}', style: const TextStyle(color: Colors.black87, fontSize: 12)),
            ],
            if (app['experience_years'] != null) ...[
              const SizedBox(height: 4),
              Text('Experience: ${app['experience_years']} years', style: const TextStyle(color: Colors.black87, fontSize: 12)),
            ]
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Requested Changes:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                  const SizedBox(height: 8),
                  _buildDiff('Experience (Years)', app['old_experience_years'], app['experience_years']),
                  _buildDiff('Specializations', app['old_specializations'], app['specializations']),
                  _buildDiff('Certifications', app['old_certifications'], app['certifications']),
                ],
              ),
            )
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
                label: const Text('Revoke / Reject', style: TextStyle(color: Colors.red)),
              ),
            )
          else if (_currentTab == 'rejected')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _respond(userId, true), 
                icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                label: const Text('Re-Approve', style: TextStyle(color: Colors.white)),
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