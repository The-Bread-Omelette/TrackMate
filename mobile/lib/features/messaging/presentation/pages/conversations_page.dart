import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/messaging_remote_datasource.dart';
import '../../../social/data/social_remote_datasource.dart';
import '../../../trainer/data/trainer_remote_datasource.dart';
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

  void _showNewChatSheet(String currentUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewChatSheet(
        currentUserId: currentUserId,
        onChatStarted: () => _load(), 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticatedState).user;

    return MainLayout(
      user: user,
      title: 'Messages',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showNewChatSheet(user.id),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.chat, color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _conversations.isEmpty
                ? const Center(
                    child: Text('No messages yet. Tap the button to start chatting!',
                        style: TextStyle(color: AppColors.textMuted)))
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
                            ).then((_) => _load());
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final String currentUserId;
  final VoidCallback onChatStarted;
  
  const _NewChatSheet({
    required this.currentUserId, 
    required this.onChatStarted
  });

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _socialDs = SocialRemoteDataSource(sl());
  final _trainerDs = TrainerRemoteDataSource(sl());
  final _msgDs = sl<MessagingRemoteDataSource>();
  
  bool _loading = true;
  
  List<dynamic> _eligibleContacts = []; 
  List<dynamic> _searchResults = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final userState = context.read<AuthBloc>().state;
      final userRole = userState is AuthAuthenticatedState 
          ? userState.user.role.toString().toLowerCase() 
          : 'trainee';
      
      // 1. Fetch Friends & Force Label
      List<dynamic> friends = [];
      try {
        // Create a modifiable list
        friends = List.from(await _socialDs.getFriends());
        for (var f in friends) {
          if (f is Map) f['contact_label'] = 'Friend';
        }
      } catch (_) {}

      // 2. Fetch Trainer or Students & Force Label
      List<dynamic> professionalContacts = [];
      try {
        if (userRole.contains('trainer') || userRole.contains('admin')) {
          professionalContacts = List.from(await _trainerDs.getStudents());
          for (var p in professionalContacts) {
            if (p is Map) p['contact_label'] = 'Student';
          }
        } else {
          final trainer = await _trainerDs.getMyTrainer();
          if (trainer != null) {
            // 🔥 FORCE THE ROLE TO BE TRAINER! No more guessing from the backend.
            trainer['contact_label'] = 'Trainer';
            professionalContacts = [trainer];
          }
        }
      } catch (e) {
        debugPrint("Error fetching professional contacts: $e");
      }

      // 3. Merge them and extract the CORRECT User ID
      final Map<String, dynamic> uniqueContacts = {};
      for (var person in [...friends, ...professionalContacts]) {
        final targetUserId = person['user_id']?.toString() ?? person['id']?.toString();
        
        if (targetUserId != null) {
          person['chat_target_id'] = targetUserId; 
          
          // If the person is already in the list (e.g., they are a Friend AND your Trainer)
          // Make sure the "Trainer" label overrides the "Friend" label!
          if (uniqueContacts.containsKey(targetUserId)) {
            if (person['contact_label'] != 'Friend') {
              uniqueContacts[targetUserId]!['contact_label'] = person['contact_label'];
            }
          } else {
            uniqueContacts[targetUserId] = person;
          }
        }
      }

      final finalContacts = uniqueContacts.values
          .where((c) => c['chat_target_id'] != widget.currentUserId)
          .toList();

      if (mounted) {
        setState(() {
          _eligibleContacts = finalContacts;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Fatal error in contact load: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search(String q) {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    final query = q.toLowerCase().trim();
    
    final results = _eligibleContacts.where((u) {
      final name = (u['full_name'] ?? '').toLowerCase();
      // Search by the new injected label too!
      final label = (u['contact_label'] ?? '').toLowerCase();
      return name.contains(query) || label.contains(query);
    }).toList();
    
    setState(() => _searchResults = results);
  }

  void _startChat(Map<String, dynamic> otherUser) async {
     try {
        showDialog(
          context: context, 
          barrierDismissible: false, 
          builder: (_) => const Center(child: CircularProgressIndicator())
        );
        
        final targetId = otherUser['chat_target_id'];
        
        final conv = await _msgDs.startConversation(targetId);
        
        if (!mounted) return;
        Navigator.pop(context); 
        Navigator.pop(context); 
        
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
           conversationId: conv['conversation_id'],
           otherUserId: targetId,
           otherUserName: otherUser['full_name'] ?? 'User',
           ds: _msgDs,
           currentUserId: widget.currentUserId,
        )));
        
        widget.onChatStarted(); 
     } catch(e) {
        if (mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start conversation. Please try again.'))
          );
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _searchCtrl.text.trim().isNotEmpty ? _searchResults : _eligibleContacts;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('New Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search your connections...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading 
                  ? const Center(child: CircularProgressIndicator())
                  : displayList.isEmpty
                    ? const Center(child: Text('No connections found.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        controller: controller,
                        itemCount: displayList.length,
                        itemBuilder: (context, i) {
                          final user = displayList[i] as Map<String, dynamic>;
                          
                          // Look exactly at the label we injected
                          final label = user['contact_label'] as String? ?? 'Friend';
                          final isPro = label == 'Trainer';
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPro ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade200,
                              child: Text(
                                (user['full_name'] as String? ?? 'U')[0].toUpperCase(), 
                                style: TextStyle(color: isPro ? AppColors.primary : Colors.black87, fontWeight: FontWeight.bold)
                              ),
                            ),
                            title: Text(user['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            
                            // 🔥 THE NEW BEAUTIFUL BLUE BUBBLE DESIGN
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPro ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isPro ? AppColors.primary.withOpacity(0.3) : Colors.transparent),
                                    ),
                                    child: Text(
                                      label, 
                                      style: TextStyle(
                                        color: isPro ? AppColors.primary : Colors.black54, 
                                        fontSize: 10, 
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      )
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
                            onTap: () => _startChat(user),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}