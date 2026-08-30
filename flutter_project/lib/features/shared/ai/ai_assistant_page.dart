import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../core/services/openrouter_service.dart';
import '../../../core/constants/services_data.dart';
import '../../../features/auth/pages/auth_page.dart'; // ✅ استيراد صفحة تسجيل الدخول

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});
  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool    _loading = false;
  String? _suggestedService;

  static const _systemPrompt =
      'أنت مساعد ذكي متخصص في خدمات الصيانة والمقاولات في الكويت، '
      'تعمل ضمن تطبيق "الحرفي الكويتي".\n'
      'مهامك:\n'
      '1. تشخيص المشكلة واقتراح الحرفي المناسب (سباك، كهربائي، نجار، '
      'فني تكييف، دهان، بناء ومقاولة، نقل أثاث، صيانة عامة)\n'
      '2. تقدير التكلفة بالدينار الكويتي\n'
      '3. نصائح وقائية لتجنب المشاكل مستقبلاً\n'
      'قواعد: تحدث بالعربية دائماً، كن ودوداً ومختصراً، '
      'وضح أن الأسعار تقديرية، إذا المشكلة خطيرة نبّه للجهات الرسمية.';

  static const _quickQuestions = [
    'عندي تسرب مياه 🚿',
    'الكهرباء مو شغالة 💡',
    'التكييف ما يبرد ❄️',
    'الباب ما يقفل 🚪',
    'أبي أدهن شقتي 🎨',
    'صيانة عامة 🔧',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMsg(
      text: 'مرحباً! 👋 أنا مساعدك الذكي في تطبيق الحرفي الكويتي.\n\n'
          'يمكنني مساعدتك في:\n'
          '🔍 تشخيص مشكلتك واقتراح الحرفي المناسب\n'
          '💰 تقدير التكلفة المتوقعة\n'
          '🛠️ نصائح الصيانة الوقائية\n\n'
          'صف لي مشكلتك وسأساعدك فوراً!',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? quickText]) async {
    // ✅ منع إرسال الرسائل إذا لم يكن المستخدم مسجلاً
    final user = AuthService.currentUser;
    if (user == null) {
      _showLoginRequiredMessage();
      return;
    }

    final text = quickText ?? _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMsg(text: text, isUser: true));
      _loading = true;
      _msgCtrl.clear();
    });
    _scrollToBottom();

    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
        for (int i = 1; i < _messages.length; i++)
          {
            'role': _messages[i].isUser ? 'user' : 'assistant',
            'content': _messages[i].text,
          },
      ];

      final reply = await OpenRouterService.chat(
        messages: messages,
        temperature: 0.7,
        maxTokens: 1024,
      );

      setState(() {
        _messages.add(_ChatMsg(
            text: reply.isNotEmpty ? reply : '⚠️ لم أفهم الرد',
            isUser: false));
        _detectService(reply);
      });
    } on Exception catch (e) {
      setState(() => _messages.add(_ChatMsg(
            text: '❌ تعذّر الاتصال بالمساعد الذكي، حاول مجدداً.\n($e)',
            isUser: false,
          )));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _showLoginRequiredMessage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنبيه'),
        content: const Text('يجب تسجيل الدخول أولاً لاستخدام المساعد الذكي.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
            child: const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  void _detectService(String reply) {
    _suggestedService = null;
    for (final svc in kServices) {
      if (reply.contains(svc.name)) {
        _suggestedService = svc.name;
        break;
      }
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

  @override
  Widget build(BuildContext context) {
    final isBottomSheet = ModalRoute.of(context) == null;
    final isDesktop = Responsive.isDesktop(context);
    final user = AuthService.currentUser;
    final double maxContentWidth = isDesktop ? 800 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: isBottomSheet
          ? null
          : AppBar(
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.auto_awesome, size: 14),
                ),
                const SizedBox(width: 10),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('المساعد الذكي',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('مدعوم بـ OpenRouter',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white70)),
                    ]),
              ]),
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'محادثة جديدة',
                  onPressed: () => setState(() {
                    _messages
                      ..clear()
                      ..add(const _ChatMsg(
                          text: 'مرحباً مجدداً! 👋 كيف يمكنني مساعدتك؟',
                          isUser: false));
                    _suggestedService = null;
                  }),
                ),
              ],
            ),
      body: user == null
          // ✅ واجهة الضيف: رسالة تسجيل الدخول
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 24),
                    const Text(
                      'يجب تسجيل الدخول أولاً',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لاستخدام المساعد الذكي، يرجى تسجيل الدخول أو إنشاء حساب جديد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                      ),
                      icon: const Icon(Icons.login),
                      label: const Text('تسجيل الدخول'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // ✅ واجهة المستخدم المسجل
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(children: [
                  if (isBottomSheet)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFF1A73E8),
                      child: Row(children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text('المساعد الذكي',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ]),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) return const _TypingIndicator();
                        return _MessageBubble(msg: _messages[i], isDesktop: isDesktop);
                      },
                    ),
                  ),
                  if (_suggestedService != null)
                    _ServiceSuggestion(
                      name: _suggestedService!,
                      onDismiss: () => setState(() => _suggestedService = null),
                      onTap: () => Navigator.pop(context, _suggestedService),
                    ),
                  if (_messages.length <= 1)
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _quickQuestions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ActionChip(
                          label: Text(_quickQuestions[i],
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () => _sendMessage(_quickQuestions[i]),
                          backgroundColor: const Color(0xFFE8F0FE),
                          side: const BorderSide(color: Color(0xFF1A73E8), width: 0.5),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _InputBar(
                      controller: _msgCtrl,
                      loading: _loading,
                      onSend: _sendMessage,
                      isDesktop: isDesktop),
                ]),
              ),
            ),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────
class _ChatMsg {
  final String text;
  final bool isUser;
  const _ChatMsg({required this.text, required this.isUser});
}

// ── Message Bubble ────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _ChatMsg msg;
  final bool isDesktop;
  const _MessageBubble({required this.msg, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxBubbleWidth = isDesktop
        ? 600 * 0.75
        : screenWidth * 0.75;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF1A73E8),
              child: Icon(Icons.auto_awesome, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1A73E8) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, size: 15, color: Colors.blue),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFF1A73E8),
          child: Icon(Icons.auto_awesome, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)
            ],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            _PulseDot(delay: 0),
            SizedBox(width: 5),
            _PulseDot(delay: 180),
            SizedBox(width: 5),
            _PulseDot(delay: 360),
          ]),
        ),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final int delay;
  const _PulseDot({required this.delay});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..repeat(reverse: true);
  late final Animation<double> _anim =
      Tween(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Color(0xFF1A73E8), shape: BoxShape.circle),
        ),
      );
}

// ── Service Suggestion ────────────────────────────────────────
class _ServiceSuggestion extends StatelessWidget {
  final String name;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  const _ServiceSuggestion(
      {required this.name, required this.onDismiss, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.tips_and_updates,
            color: Color(0xFF1A73E8), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text('هل تريد طلب $name الآن؟',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1A73E8)),
          child: const Text('استخدم التوصية'),
        ),
        IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  final bool isDesktop;
  const _InputBar(
      {required this.controller,
      required this.loading,
      required this.onSend,
      required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'صف مشكلتك هنا...',
                  filled: true,
                  fillColor: const Color(0xFFF1F3F4),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? const SizedBox(
                      width: 44,
                      height: 36,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF1A73E8))))
                  : FloatingActionButton.small(
                      key: const ValueKey('send'),
                      onPressed: onSend,
                      backgroundColor: const Color(0xFF1A73E8),
                      elevation: 0,
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
