import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'chat_screen.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _uid = AuthService.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChatService.userChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 72, color: Colors.white.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text('لا توجد محادثات بعد',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          );
        }

        final chats = snapshot.data!;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final participants = List<String>.from(chat['participants'] ?? []);
                final otherUserId = participants.firstWhere(
                  (id) => id != _uid,
                  orElse: () => '',
                );
                final chatId = chat['id'] as String? ?? chat['chatId'] as String? ?? '';
                final unread = chat['unread_$_uid'] ?? 0;

                final participantNames =
                    chat['participantNames'] as Map<String, dynamic>?;
                final storedName = participantNames?[otherUserId] as String?;

                if (storedName != null && storedName.isNotEmpty) {
                  return _buildChatTile(
                    otherName: storedName,
                    lastMsg: chat['lastMessage'] ?? '',
                    lastTime: chat['lastMessageTime'] as String?,
                    unread: unread as int,
                    chatId: chatId,
                    otherUserId: otherUserId,
                    isDesktop: isDesktop,
                  );
                }

                return FutureBuilder<Map<String, dynamic>?>(
                  future: FirestoreService.getUser(otherUserId),
                  builder: (context, userSnap) {
                    final otherName =
                        userSnap.data?['name'] as String? ?? 'مستخدم';
                    final lastMsg = chat['lastMessage'] ?? '';
                    final lastTime = chat['lastMessageTime'] as String?;

                    return _buildChatTile(
                      otherName: otherName,
                      lastMsg: lastMsg,
                      lastTime: lastTime,
                      unread: unread as int,
                      chatId: chatId,
                      otherUserId: otherUserId,
                      isDesktop: isDesktop,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatTile({
    required String otherName,
    required String lastMsg,
    required String? lastTime,
    required int unread,
    required String chatId,
    required String otherUserId,
    required bool isDesktop,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 12, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0071E3).withOpacity(0.3),
                child: Text(
                  otherName.isNotEmpty ? otherName[0] : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                otherName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  lastMsg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (lastTime != null && lastTime.isNotEmpty)
                    Text(
                      _formatTime(lastTime),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFF0071E3),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Color(0xFF1D1D1F),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: chatId,
                      otherUserName: otherName,
                      otherUserId: otherUserId,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      if (now.difference(dt).inMinutes < 1) return 'الآن';
      if (now.difference(dt).inHours < 1)
        return '${now.difference(dt).inMinutes} د';
      if (now.difference(dt).inDays < 1)
        return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}
