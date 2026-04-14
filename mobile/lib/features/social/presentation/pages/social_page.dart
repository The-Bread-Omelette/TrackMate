import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/social_remote_datasource.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _ds = SocialRemoteDataSource(sl());

  final Set<String> _sentRequests = {};
  List<dynamic> _feed = [];
  List<dynamic> _friends = [];
  List<dynamic> _requests = [];
  List<dynamic> _leaderboard = [];
  bool _loading = true;
  final _postCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _postCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _ds.getFeed(),
        _ds.getFriends(),
        _ds.getFriendRequests(),
        _ds.getLeaderboard(),
      ]);
      setState(() {
        _feed = results[0] as List<dynamic>;
        _friends = results[1] as List<dynamic>;
        _requests = results[2] as List<dynamic>;
        _leaderboard = results[3] as List<dynamic>;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await _ds.searchUsers(q);
      setState(() => _searchResults = results);
    } catch (_) {}
  }

  Future<void> _createPost() async {
    if (_postCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post can\'t be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      await _ds.createPost(_postCtrl.text.trim());
      _postCtrl.clear();
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user =
        (context.read<AuthBloc>().state as AuthAuthenticatedState).user;

    return MainLayout(
      user: user,
      title: 'Social',
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                const Tab(text: 'Feed'), // FIX: Added missing const
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Friends'),
                      if (_requests.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_requests.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Leaderboard'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _FeedTab(
                        feed: _feed,
                        postCtrl: _postCtrl,
                        onPost: _createPost,
                        onLike: (id) async {
                          await _ds.toggleLike(id);
                          await _load();
                        },
                        onDelete: (id) async {
                          await _ds.deletePost(id);
                          await _load();
                        },
                        currentUserId: user.id,
                        onRefresh: _load,
                      ),
                      _FriendsTab(
                        friends: _friends,
                        requests: _requests,
                        searchCtrl: _searchCtrl,
                        searchResults: _searchResults,
                        sentRequests: _sentRequests, // FIX: Passed _sentRequests variable
                        onSearch: _search,
                        onAccept: (id) async {
                          await _ds.respondToFriendRequest(id, true);
                          await _load();
                        },
                        onReject: (id) async {
                          await _ds.respondToFriendRequest(id, false);
                          await _load();
                        },
                        onRemove: (id) async {
                          await _ds.removeFriend(id);
                          await _load();
                        },
                        onSendRequest: (id) async {
                          await _ds.sendFriendRequest(id);
                          setState(() => _sentRequests.add(id));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Friend request sent')),
                            );
                          }
                        },
                        onRefresh: _load,
                      ),
                      _LeaderboardTab(leaderboard: _leaderboard),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  final List<dynamic> feed;
  final TextEditingController postCtrl;
  final VoidCallback onPost;
  final ValueChanged<String> onLike;
  final ValueChanged<String> onDelete;
  final String currentUserId;
  final Future<void> Function() onRefresh;

  const _FeedTab({
    required this.feed,
    required this.postCtrl,
    required this.onPost,
    required this.onLike,
    required this.onDelete,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                TextField(
                  controller: postCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?",
                    border: InputBorder.none,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: onPost,
                    child: const Text('Post'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (feed.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No posts yet. Add friends to see their posts!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...feed.map((p) {
              final post = p as Map<String, dynamic>;
              final author =
                  post['author'] as Map<String, dynamic>? ?? {};
              final isMe = author['id'] == currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withOpacity(0.1),
                          radius: 16,
                          child: Text(
                            (author['full_name'] as String? ?? 'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(author['full_name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (isMe)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.textMuted),
                            onPressed: () => onDelete(post['id']),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(post['content'] ?? ''),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => onLike(post['id']),
                          child: Row(
                            children: [
                              Icon(
                                post['liked_by_me'] == true
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                                color: post['liked_by_me'] == true
                                    ? AppColors.error
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text('${post['like_count'] ?? 0}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  final List<dynamic> friends;
  final List<dynamic> requests;
  final TextEditingController searchCtrl;
  final List<dynamic> searchResults;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onSendRequest;
  final Future<void> Function() onRefresh;

  // FIX: Made this required in the constructor instead of uninitialized
  final Set<String> sentRequests;

  const _FriendsTab({
    required this.friends,
    required this.requests,
    required this.searchCtrl,
    required this.searchResults,
    required this.onSearch,
    required this.onAccept,
    required this.onReject,
    required this.onRemove,
    required this.onSendRequest,
    required this.onRefresh,
    required this.sentRequests, // FIX: Added to constructor arguments
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Search users to add...',
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
            ),
          ),
          if (searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: searchResults.map((u) {
                  final user = u as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (user['full_name'] as String? ?? 'U')[0]
                            .toUpperCase(),
                        style:
                            const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    title: Text(user['full_name'] ?? ''),
                    subtitle: Text(user['role'] ?? ''),

                    trailing: sentRequests.contains(user['id'])
                        ? const Chip(
                            label: Text('Sent', style: TextStyle(fontSize: 11)),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                            padding: EdgeInsets.zero,
                          )
                        : friends.any((f) => (f as Map)['id'] == user['id'])
                            ? const Chip(
                                label: Text('Added', style: TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.primary,
                                labelStyle: TextStyle(color: Colors.white),
                                padding: EdgeInsets.zero,
                              )
                            : IconButton(
                                icon: const Icon(Icons.person_add, color: AppColors.primary),
                                onPressed: () => onSendRequest(user['id']),
                              ),
                    );
                }).toList(),
              ),
            ),
          ],
          if (requests.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Friend Requests',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...requests.map((r) {
              final req = r as Map<String, dynamic>;
              final sender =
                  req['sender'] as Map<String, dynamic>? ?? {};
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (sender['full_name'] as String? ?? 'U')[0]
                            .toUpperCase(),
                        style:
                            const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(sender['full_name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500))),
                    IconButton(
                      icon: const Icon(Icons.check, color: AppColors.success),
                      onPressed: () => onAccept(req['request_id']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: () => onReject(req['request_id']),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          Text('Friends (${friends.length})',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (friends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No friends yet. Search to add some!',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...friends.map((f) {
              final friend = f as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (friend['full_name'] as String? ?? 'F')[0]
                            .toUpperCase(),
                        style:
                            const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(friend['full_name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          Text(friend['email'] ?? '',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined,
                          color: AppColors.textMuted, size: 20),
                      onPressed: () => onRemove(friend['id']),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final List<dynamic> leaderboard;

  const _LeaderboardTab({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    if (leaderboard.isEmpty) {
      return const Center(
        child: Text(
          'Add friends to see the leaderboard!',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leaderboard.length,
      itemBuilder: (_, i) {
        final entry = leaderboard[i] as Map<String, dynamic>;
        final isMe = entry['is_me'] == true;
        final rank = entry['rank'] as int;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary.withOpacity(0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rank <= 3
                      ? ['🥇', '🥈', '🥉'][rank - 1]
                      : '#$rank',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${entry['full_name']}${isMe ? ' (you)' : ''}',
                  style: TextStyle(
                    fontWeight:
                        isMe ? FontWeight.bold : FontWeight.normal,
                    color: isMe ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${entry['total_steps']} steps',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}