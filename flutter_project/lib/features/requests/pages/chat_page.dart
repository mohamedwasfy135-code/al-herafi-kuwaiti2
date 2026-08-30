import 'package:flutter/material.dart';

import '../../../core/services/chat_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/constants/app_constants.dart';

// ══════════════════════════════════════════════════════════════
// CHAT PAGE — محادثة مباشرة بين العميل والحرفي
// ══════════════════════════════════════════════════════════════
class ChatPage extends StatefulWidget {
  final String requestId;
  final String chatId;
  final String otherName;

  const ChatPage({
    super.key,
    required this.requestId,
    required this.chatId,
    required this.otherName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _uid        = AuthService.currentUser!.id;
  String _userName  = '';
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending     = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _markMessagesRead();
  }

  Future<void> _loadUserName() async {
    try {
      final data = await FirestoreService.getUser(_uid);
      if (data != null && mounted) {
        setState(() => _userName = data['name'] ?? 'مستخدم');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// تعيين الرسائل كمقروءة
  Future<void> _markMessagesRead() async {
    await ChatService.markChatRead(widget.chatId);
  }

  /// إرسال رسالة
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending || _userName.isEmpty) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        senderId: _uid,
        senderName: _userName,
        text: text,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في الإرسال: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// إنشاء chat document إذا لم يكن موجوداً
  static Future<String> getOrCreateChat({
    required String requestId,
    required String clientId,
    required String craftsmanId,
    required String clientName,
    required String craftsmanName,
  }) async {
    return await ChatService.createOrGetChat(
      otherUserId: craftsmanId,
      otherUserName: craftsmanName,
      requestId: requestId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.otherName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Text('محادثة مباشرة',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // ── قائمة الرسائل ──────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ChatService.messagesStream(widget.chatId),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!;

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('ابدأ المحادثة مع الحرفي',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              // تعيين كمقروء عند وصول رسائل جديدة
              _markMessagesRead();
              _scrollToBottom();

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) => _MessageBubble(
                  msg:   docs[i],
                  myUid: _uid,
                ),
              );
            },
          ),
        ),

        // ── حقل الإرسال ────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
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
            FloatingActionButton.small(
              onPressed: _sending ? null : _sendMessage,
              backgroundColor: Colors.blue,
              elevation: 0,
              child: _sending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final String myUid;

  const _MessageBubble({required this.msg, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isMe   = msg['senderId'] == myUid;
    final text   = msg['text'] as String? ?? msg['content'] as String? ?? '';
    final isRead = msg['read'] as bool? ?? false;
    final ts     = msg['createdAt'] as String? ?? msg['sentAt'] as String? ?? '';
    String time = '';
    if (ts.isNotEmpty) {
      try {
        final dt = DateTime.parse(ts);
        time = '${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, size: 16, color: Colors.blue),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(time,
                        style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white70
                                : Colors.grey.shade500)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 12,
                        color: isRead ? Colors.white : Colors.white60,
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
