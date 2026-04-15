import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/messaging_remote_datasource.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final MessagingRemoteDataSource ds;
  final String currentUserId;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.ds,
    required this.currentUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  WebSocketChannel? _channel;
  final List<Map<String, dynamic>> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();
  
  bool _isOtherTyping = false;
  Timer? _typingTimer;
  bool _connected = false;

  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _pinnedMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scroll.dispose();
    _typingTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final msgs = await widget.ds.getMessages(widget.conversationId);
      setState(() {
        _messages.addAll(msgs.cast<Map<String, dynamic>>());
        final pinned = _messages.lastWhere((m) => m['is_pinned'] == true, orElse: () => {});
        if (pinned.isNotEmpty) {
          _pinnedMessage = pinned;
        }
      });
      await widget.ds.markRead(widget.conversationId);
    } catch (_) {}

    try {
      final ticket = await widget.ds.getWsTicket();
      final wsBase = ApiConstants.baseUrl.replaceFirst('http', 'ws');
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsBase${ApiConstants.apiVersion}/messaging/ws?ticket=$ticket'),
      );
      setState(() => _connected = true);

      _channel!.stream.listen(
        (raw) {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = data['type'] as String?;
// 🔥 NEW: Explicitly handle the acknowledgment of YOUR messages
          if (type == 'message_ack') {
            final clientId = data['client_id'];
            final savedMsg = Map<String, dynamic>.from(data['message'] as Map);
            
            setState(() {
              // Find our optimistic message by its client ID
              final idx = _messages.indexWhere((m) => m['id'] == clientId || m['client_id'] == clientId);
              
              if (idx != -1) {
                // Restore the reply box if the backend didn't echo it back perfectly
                if (savedMsg['reply_to'] == null && _messages[idx]['reply_to'] != null) {
                  savedMsg['reply_to'] = _messages[idx]['reply_to'];
                }
                
                // Swap the fake 'local_' ID with the real UUID from the database
                savedMsg['status'] = savedMsg['status'] == 'delivered' ? 'delivered' : 'sent';
                
                // Replace the temporary message entirely
                _messages[idx] = savedMsg; 
              }
            });
            _scrollToBottom();
            
          } else if (type == 'new_message') {
            final msg = Map<String, dynamic>.from(data['message'] as Map);
            
            if (msg['conversation_id'].toString() == widget.conversationId.toString()) {
              setState(() {
                if (msg['sender_id'].toString() != widget.currentUserId.toString()) {
                  final exists = _messages.any((m) => m['id'] == msg['id']);
                  if (!exists) _messages.add(msg);
                }
              });
              _scrollToBottom();
            }
          }else if (type == 'message_pinned') {
            setState(() {
              final idx = _messages.indexWhere((m) => m['id'] == data['message_id']);
              if (idx != -1) {
                _messages[idx]['is_pinned'] = data['is_pinned'];
              }
              if (data['is_pinned'] == true) {
                _pinnedMessage = data;
              } else if (_pinnedMessage?['message_id'] == data['message_id'] || _pinnedMessage?['id'] == data['message_id']) {
                _pinnedMessage = null;
              }
            });
          } else if (type == 'typing') {
            if (data['user_id'] != widget.currentUserId) {
              setState(() => _isOtherTyping = true);
              _typingTimer?.cancel();
              _typingTimer = Timer(const Duration(seconds: 5), () {
                if (mounted) setState(() => _isOtherTyping = false);
              });
            }
          } else if (type == 'messages_read') {
            setState(() {
              for (var m in _messages) {
                if (m['sender_id'] == widget.currentUserId) m['status'] = 'read';
              }
            });
          }
        },
        onDone: () { if (mounted) setState(() => _connected = false); },
        onError: (_) { if (mounted) setState(() => _connected = false); },
      );
    } catch (_) {}

    _scrollToBottom();
  }

 void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _channel == null) return;

    final currentReplyTo = _replyingTo;
    
    // 🔥 Generate a unique client-side ID
    final clientId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Create the optimistic temporary message
    final tempMessage = {
      'id': clientId, // Use it temporarily for the UI list
      'client_id': clientId, // Store it explicitly
      'sender_id': widget.currentUserId,
      'conversation_id': widget.conversationId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'sending', 
      'reply_to': currentReplyTo != null ? Map<String, dynamic>.from(currentReplyTo) : null,
      'is_pinned': false,
    };

    // 2. Instantly update UI and clear input
    setState(() {
      _messages.add(tempMessage);
      _replyingTo = null; // Clear the reply box immediately
    });
    _scrollToBottom();
    _inputCtrl.clear();

    // 3. Build payload safely
    final payload = <String, dynamic>{
      'type': 'send_message',
      'client_id': clientId, // 🔥 Send it to the backend
      'conversation_id': widget.conversationId,
      'content': text,
    };
    
    if (currentReplyTo != null && currentReplyTo['id'] != null) {
      payload['reply_to_id'] = currentReplyTo['id'];
    }

    _channel!.sink.add(jsonEncode(payload));
  }

  void _pin(String messageId) {
    _channel?.sink.add(jsonEncode({
      'type': 'pin_message',
      'message_id': messageId,
    }));
  }

  void _sendTyping() {
    _channel?.sink.add(jsonEncode({
      'type': 'typing',
      'conversation_id': widget.conversationId,
    }));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              radius: 16,
              child: Text(
                widget.otherUserName[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.otherUserName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  _connected ? 'Connected' : 'Connecting...',
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          _connected ? AppColors.success : AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_pinnedMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pinnedMessage!['content'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    onPressed: () => setState(() => _pinnedMessage = null),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isOtherTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isOtherTyping && i == _messages.length) {
                  return _TypingBubble(name: widget.otherUserName);
                }
                final m = _messages[i];
                final isMe = m['sender_id'] == widget.currentUserId;
                return _MessageBubble(
                  message: m,
                  isMe: isMe,
                  onReply: (msg) => setState(() => _replyingTo = msg),
                  onPin: (id) => _pin(id),
                );
              },
            ),
          ),

          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, 
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingTo!['sender_id'] == widget.currentUserId ? 'Replying to yourself' : 'Replying to ${widget.otherUserName}',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          _replyingTo!['content'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLength: 2000,
                    onChanged: (_) => _sendTyping(),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  color: AppColors.primary,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final Function(Map<String, dynamic>) onReply;
  final Function(String) onPin;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onReply,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final status = message['status'] as String? ?? 'sent';
    final time = message['created_at'] as String? ?? '';
    final replyTo = message['reply_to'];
    final isPinned = message['is_pinned'] == true;

    IconData getStatusIcon() {
      if (status == 'sending') return Icons.schedule;
      if (status == 'read') return Icons.done_all;
      if (status == 'delivered') return Icons.done_all;
      return Icons.done;
    }

    return GestureDetector(
      onLongPress: () {
        if (status != 'sending') _showMenu(context);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (replyTo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                      ),
                      child: Text(
                        replyTo['content'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ),

                  Text(
                    message['content'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPinned) ...[
                        Icon(Icons.push_pin, size: 10, color: isMe ? Colors.white70 : AppColors.primary),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _formatTime(time),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textMuted,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          getStatusIcon(),
                          size: 12,
                          color: status == 'read'
                              ? Colors.lightBlueAccent
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.primary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                onReply(message);
              },
            ),
            ListTile(
              leading: Icon(message['is_pinned'] == true ? Icons.push_pin_outlined : Icons.push_pin, color: AppColors.primary),
              title: Text(message['is_pinned'] == true ? 'Unpin Message' : 'Pin Message'),
              onTap: () {
                Navigator.pop(ctx);
                onPin(message['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.primary),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message['content']));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _TypingBubble extends StatelessWidget {
  final String name;
  const _TypingBubble({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('$name is typing...',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ),
      ),
    );
  }
}