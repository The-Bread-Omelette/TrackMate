import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/admin_remote_datasource.dart';
import '../../../../core/di/injection.dart';
import 'package:go_router/go_router.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _ds = AdminRemoteDataSource(sl());
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _users = [];
  bool _loading = true;
  
  // Infinite scrolling state
  bool _isFetchingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _load();
    
    // Listen to scroll events to trigger the next page load
    _scrollController.addListener(() {
      // If we scroll within 200 pixels of the bottom, fetch more
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _currentPage = 1;
      _hasMoreData = true;
    });
    
    try {
      final fetchedUsers = await _ds.getUsers(page: _currentPage);
      _users = fetchedUsers;
      
      // If the first page has fewer than 20 items, there is no more data
      if (fetchedUsers.length < 20) {
        _hasMoreData = false;
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('API Failed 🚨'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    // Stop if we are already fetching, have no more data, or widget is unmounted
    if (_isFetchingMore || !_hasMoreData || !mounted) return;
    
    setState(() => _isFetchingMore = true);
    
    try {
      _currentPage++;
      final moreUsers = await _ds.getUsers(page: _currentPage);
      
      if (moreUsers.isEmpty) {
        _hasMoreData = false;
      } else {
        setState(() {
          _users.addAll(moreUsers);
          // If the new batch is less than 20, we've hit the end of the database
          if (moreUsers.length < 20) _hasMoreData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more users: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _toggleStatus(String userId, bool activate) async {
    try {
      await _ds.toggleUserStatus(userId, activate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(activate ? 'User Activated' : 'User Deactivated'),
          backgroundColor: activate ? Colors.green : Colors.red,
        ));
        
        // Optimistically update the UI without reloading the whole list
        setState(() {
          final index = _users.indexWhere((u) => u['id'] == userId);
          if (index != -1) {
            _users[index]['is_active'] = activate;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Users', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _users.isEmpty
                  ? const Center(child: Text('No users found in system.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      // Add 1 to the item count to render the loading spinner at the bottom
                      itemCount: _users.length + (_hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        
                        // If we are rendering the extra index at the end, show the spinner
                        if (index == _users.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: SizedBox(
                                width: 24, 
                                height: 24, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              ),
                            ),
                          );
                        }

                        final user = _users[index] as Map<String, dynamic>;
                        final isActive = user['is_active'] == true;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text((user['full_name'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary)),
                            ),
                            title: Text(user['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${user['email']}\nRole: ${user['role']}', style: const TextStyle(fontSize: 12)),
                            isThreeLine: true,
                            trailing: Switch(
                              value: isActive,
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                              onChanged: (val) => _toggleStatus(user['id'], val),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}