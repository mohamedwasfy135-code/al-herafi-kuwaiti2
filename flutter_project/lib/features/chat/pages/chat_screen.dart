import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _uid = AuthService.currentUser!.id;
  String _userName = '';
  String? _otherUserPhone;
  String? _otherUserAvatar;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadOtherUserInfo();
    ChatService.markChatRead(widget.chatId);
  }

  Future<void> _loadUserName() async {
    try {
      final data = await FirestoreService.getUser(_uid);
      if (data != null && mounted) {
        setState(() => _userName = data['name'] ?? 'مستخدم');
      }
    } catch (_) {}
  }

  Future<void> _loadOtherUserInfo() async {
    try {
      final data = await FirestoreService.getUser(widget.otherUserId);
      if (data != null && mounted) {
        setState(() {
          _otherUserPhone = data['phone'] as String?;
          _otherUserAvatar = data['avatarUrl'] as String? ?? data['photoURL'] as String?;
        });
        debugPrint('📱 Info loaded for ${widget.otherUserId}');
      }
    } catch (e) {
      debugPrint('❌ Error loading user info: $e');
    }
  }

  Future<String?> _getOtherUserPhone() async {
    if (_otherUserPhone != null && _otherUserPhone!.isNotEmpty) {
      return _otherUserPhone;
    }
    for (int i = 0; i < 3; i++) {
      await _loadOtherUserInfo();
      if (_otherUserPhone != null && _otherUserPhone!.isNotEmpty) {
        return _otherUserPhone;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  String _formatPhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  Future<void> _callOtherUser() async {
    final phone = await _getOtherUserPhone();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم الهاتف غير متوفر حالياً، حاول مجدداً')),
        );
      }
      return;
    }
    final formatted = _formatPhoneNumber(phone);
    final uri = Uri.parse('tel:$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp() async {
    final phone = await _getOtherUserPhone();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم الهاتف غير متوفر حالياً، حاول مجدداً')),
        );
      }
      return;
    }
    final formatted = _formatPhoneNumber(phone);
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب')),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _userName.isEmpty) return;
    ChatService.sendMessage(
      chatId: widget.chatId,
      senderId: _uid,
      senderName: _userName,
      text: text,
    );
    _msgCtrl.clear();
  }

  Future<void> _pickAndSendMedia(bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.uploadFile(
        '/api/upload',
        filePath: file.path,
        fieldName: 'file',
        fields: {
          'chatId': widget.chatId,
          'type': isVideo ? 'video' : 'image',
        },
      );

      if (res.success && res.data != null) {
        final downloadUrl = res.data!['url'] as String? ?? '';
        if (downloadUrl.isNotEmpty) {
          await FirestoreService.sendMessage(
            chatId: widget.chatId,
            content: downloadUrl,
            messageType: isVideo ? 'video' : 'image',
          );
        }
      }
    } catch (_) {} finally {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo, color: Color(0xFF0071E3)),
                    title: const Text('صورة', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendMedia(false);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam, color: Color(0xFF0071E3)),
                    title: const Text('فيديو', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendMedia(true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    return Scaffold(
      body: Stack(
        children: [
          // صورة الخلفية
          Positioned.fill(
            child: Image.asset(
              'assets/images/ocean_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)],
                  ),
                ),
              ),
            ),
          ),
          // طبقة داكنة شفافة
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          // تأثير زجاجي خفيف
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
          // المحتوى
          Column(
            children: [
              // شريط علوي زجاجي
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.white.withOpacity(0.1),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            backgroundImage: _otherUserAvatar != null
                                ? NetworkImage(_otherUserAvatar!)
                                : null,
                            child: _otherUserAvatar == null
                                ? Text(
                                    widget.otherUserName.isNotEmpty
                                        ? widget.otherUserName[0]
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.otherUserName,
                              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.white70),
                            tooltip: 'واتساب',
                            onPressed: _openWhatsApp,
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.white70),
                            tooltip: 'اتصال هاتفي',
                            onPressed: _callOtherUser,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // قائمة الرسائل
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ChatService.messagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('لا توجد رسائل بعد', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    final messages = snapshot.data!;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollCtrl.hasClients) {
                        _scrollCtrl.animateTo(
                          _scrollCtrl.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isMe = msg['senderId'] == _uid;
                            final type = msg['type'] as String? ?? msg['messageType'] as String? ?? 'text';
                            final content = msg['text'] as String? ?? msg['content'] as String? ?? '';

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF0071E3).withOpacity(0.3) : Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(18).copyWith(
                                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                                  ),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: (isDesktop ? 900 : screenWidth) * 0.7,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          msg['senderName'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF0071E3),
                                          ),
                                        ),
                                      ),
                                    if (type == 'image')
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(content),
                                      )
                                    else if (type == 'video')
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.videocam, size: 14, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Text('🎥 فيديو', style: TextStyle(color: isMe ? Colors.white70 : Colors.white, fontSize: 13)),
                                        ],
                                      )
                                    else
                                      Text(
                                        content,
                                        style: TextStyle(color: isMe ? const Color(0xFF1D1D1F) : Colors.white, fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              // شريط الكتابة الزجاجي
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
                          child: Row(children: [
                            IconButton(
                              icon: const Icon(Icons.attach_file, color: Color(0xFF0071E3)),
                              onPressed: _showAttachmentOptions,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'اكتب رسالة...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.15),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: const Color(0xFF0071E3),
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Color(0xFF1D1D1F)),
                                onPressed: _sendMessage,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
