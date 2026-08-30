import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/services_data.dart';

const _kGeminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'YOUR_GEMINI_API_KEY',
);
const _kGeminiModel = 'gemini-2.0-flash';
const _kGeminiUrl   =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_kGeminiModel:generateContent?key=$_kGeminiApiKey';

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
    final text = quickText ?? _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMsg(text: text, isUser: true));
      _loading = true;
      _msgCtrl.clear();
    });
    _scrollToBottom();

    try {
      final contents = <Map<String, dynamic>>[];

      for (int i = 1; i < _messages.length; i++) {
        contents.add({
          'role': _messages[i].isUser ? 'user' : 'model',
          'parts': [{'text': _messages[i].text}],
        });
      }

      final body = jsonEncode({
        'system_instruction': {
          'parts': [{'text': _systemPrompt}],
        },
        'contents': contents,
        'generationConfig': {
          'temperature':     0.7,
          'maxOutputTokens': 1024,
          'topP':            0.95,
        },
      });

      final response = await http.post(
        Uri.parse(_kGeminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final reply = data['candidates']?[0]?['content']?['parts']
                    ?[0]?['text'] as String?
            ?? '⚠️ لم أفهم الطلب، حاول مرة أخرى.';
        setState(() {
          _messages.add(_ChatMsg(text: reply, isUser: false));
          _detectService(reply);
        });
      } else {
        final err = jsonDecode(response.body);
        final msg = err['error']?['message'] ?? 'خطأ غير معروف';
        setState(() => _messages.add(_ChatMsg(
          text: '❌ خطأ (${response.statusCode}): $msg',
          isUser: false,
        )));
      }
    } on Exception catch (e) {
      setState(() => _messages.add(_ChatMsg(
        text: '❌ تعذّر الاتصال. تحقق من الإنترنت وحاول مجدداً.\n($e)',
        isUser: false,
      )));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
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
          Column(children: [
            // شريط علوي زجاجي
            if (!isBottomSheet)
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.white.withOpacity(0.1),
                    child: SafeArea(
                      bottom: false,
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0071E3).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0071E3)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('المساعد الذكي',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('مدعوم بـ Gemini 2.0 Flash',
                                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          tooltip: 'محادثة جديدة',
                          onPressed: () => setState(() {
                            _messages
                              ..clear()
                              ..add(const _ChatMsg(
                                text: 'مرحباً مجدداً! 👋 كيف يمكنني مساعدتك؟',
                                isUser: false,
                              ));
                            _suggestedService = null;
                          }),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),

            // رأس BottomSheet
            if (isBottomSheet)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.white.withOpacity(0.15),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF0071E3), size: 20),
                  const SizedBox(width: 8),
                  const Text('المساعد الذكي',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),

            // ✅ منطقة المحادثة أصبحت زجاجية بالكامل
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) return const _TypingIndicator();
                        return _MessageBubble(msg: _messages[i]);
                      },
                    ),
                  ),
                ),
              ),
            ),

            if (_suggestedService != null)
              _ServiceSuggestion(
                name: _suggestedService!,
                onDismiss: () => setState(() => _suggestedService = null),
                onTap: () {
                  Navigator.pop(context, _suggestedService);
                },
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
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1D1D1F))),
                    onPressed: () => _sendMessage(_quickQuestions[i]),
                    backgroundColor: const Color(0xFF0071E3).withOpacity(0.8),
                    side: const BorderSide(color: Color(0xFF0071E3)),
                  ),
                ),
              ),

            const SizedBox(height: 8),
            _InputBar(
                controller: _msgCtrl,
                loading: _loading,
                onSend: _sendMessage),
          ]),
        ],
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0071E3),
              child: Icon(Icons.auto_awesome, size: 15, color: Color(0xFF1D1D1F)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF0071E3).withOpacity(0.3)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? const Color(0xFF1D1D1F) : Colors.white,
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
              backgroundColor: const Color(0xFF0071E3).withOpacity(0.3),
              child: const Icon(Icons.person, size: 15, color: Color(0xFF1D1D1F)),
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
          backgroundColor: Color(0xFF0071E3),
          child: Icon(Icons.auto_awesome, size: 15, color: Color(0xFF1D1D1F)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
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
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
              color: Color(0xFF0071E3), shape: BoxShape.circle),
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
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.tips_and_updates, color: Color(0xFF0071E3), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text('هل تريد طلب $name الآن؟',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF0071E3)),
          child: const Text('استخدم التوصية'),
        ),
        IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 16, color: Colors.white70),
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
  const _InputBar(
      {required this.controller,
      required this.loading,
      required this.onSend});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
          ),
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'صف مشكلتك هنا...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? const SizedBox(
                      width: 44, height: 36,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0071E3)),
                      ))
                  : FloatingActionButton.small(
                      key: const ValueKey('send'),
                      onPressed: onSend,
                      backgroundColor: const Color(0xFF0071E3),
                      elevation: 0,
                      child: const Icon(Icons.send, color: Color(0xFF1D1D1F), size: 20),
                    ),
            ),
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