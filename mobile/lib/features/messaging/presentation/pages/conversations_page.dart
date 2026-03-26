import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/messaging_remote_datasource.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _ds = sl<MessagingRemoteDataSource>();
  List<dynamic> _conversations = [];
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
      final convos = await _ds.getConversations();
      if (mounted) setState(() => _conversations = convos);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticatedState).user;

    return MainLayout(
      user: user,
      title: 'Messages',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Text('No messages yet.', style: TextStyle(color: AppColors.textMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = _conversations[i];
                      final otherUser = c['other_user'] ?? {};
                      final lastMsg = c['last_message'];
                      final unread = c['unread_count'] as int? ?? 0;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          radius: 24,
                          child: Text(
                            (otherUser['full_name']?[0] ?? 'U').toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          otherUser['full_name'] ?? 'Unknown User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: lastMsg != null
                            ? Text(
                                lastMsg['content'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread > 0 ? AppColors.textPrimary : AppColors.textMuted,
                                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              )
                            : const Text('No messages yet', style: TextStyle(fontStyle: FontStyle.italic)),
                        trailing: unread > 0
                            ? CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.primary,
                                child: Text(unread.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                conversationId: c['conversation_id'],
                                otherUserId: otherUser['id'],
                                otherUserName: otherUser['full_name'],
                                ds: _ds,
                                currentUserId: user.id,
                              ),
                            ),
                          ).then((_) => _load()); // Refresh unread counts when returning
                        },
                      );
                    },
                  ),
                ),
    );
  }
}