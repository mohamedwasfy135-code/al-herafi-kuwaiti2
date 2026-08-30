import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// ══════════════════════════════════════════════════════════════
// AI IMAGE ANALYZER — Gemini Vision (مجاني)
// العميل يصوّر المشكلة → Gemini يحللها ويقترح الحل
// ══════════════════════════════════════════════════════════════

// نفس المفتاح المستخدم في ai_assistant_page.dart
const _kGeminiApiKey  = 'YOUR_GEMINI_API_KEY';
const _kGeminiModel   = 'gemini-2.0-flash';
const _kGeminiUrl     =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_kGeminiModel:generateContent?key=$_kGeminiApiKey';

class AiImageAnalyzerPage extends StatefulWidget {
  const AiImageAnalyzerPage({super.key});
  @override
  State<AiImageAnalyzerPage> createState() =>
      _AiImageAnalyzerPageState();
}

class _AiImageAnalyzerPageState extends State<AiImageAnalyzerPage> {
  File?   _image;
  String  _result  = '';
  bool    _loading = false;

  static const _prompt =
      'أنت خبير صيانة في الكويت. حلّل هذه الصورة وأجب بالعربية:\n\n'
      '🔍 **نوع المشكلة:** [حدد بدقة]\n'
      '⚠️ **مستوى الخطورة:** منخفض / متوسط / عالي / طارئ\n'
      '👷 **الحرفي المطلوب:** [سباك/كهربائي/نجار/فني تكييف/دهان/بناء]\n'
      '💰 **التكلفة التقديرية:** [نطاق بالدينار الكويتي]\n'
      '✅ **3 خطوات عاجلة:** [ماذا يفعل صاحب البيت الآن]\n\n'
      'كن مختصراً وواضحاً.';

  Future<void> _pickImage(ImageSource src) async {
    final picked = await ImagePicker().pickImage(
        source: src, imageQuality: 75, maxWidth: 1024);
    if (picked == null) return;
    setState(() { _image = File(picked.path); _result = ''; });
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;
    setState(() => _loading = true);

    try {
      final bytes   = await _image!.readAsBytes();
      final base64  = base64Encode(bytes);
      final ext     = _image!.path.split('.').last.toLowerCase();
      final mime    = ext == 'png' ? 'image/png' : 'image/jpeg';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': mime,
                  'data':      base64,
                },
              },
              {'text': _prompt},
            ],
          }
        ],
        'generationConfig': {
          'temperature':     0.4,
          'maxOutputTokens': 800,
        },
      });

      final response = await http.post(
        Uri.parse(_kGeminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final reply = data['candidates']?[0]?['content']?['parts']
                    ?[0]?['text'] as String?
            ?? '⚠️ لم أتمكن من تحليل الصورة.';
        setState(() => _result = reply);
      } else {
        final err = jsonDecode(response.body);
        setState(() => _result =
            '❌ خطأ (${response.statusCode}): '
            '${err['error']?['message'] ?? 'تحقق من API Key'}');
      }
    } on Exception catch (e) {
      setState(() => _result = '❌ خطأ في الاتصال: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تشخيص الصورة بالذكاء الاصطناعي',
                style: TextStyle(fontSize: 12)),
            Text('Gemini Vision — مجاني',
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── بانر الميزة ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF42A5F5)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(children: [
              Icon(Icons.camera_enhance, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('صوّر المشكلة',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Gemini يحللها ويقترح الحل والتكلفة فوراً',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // ── منطقة الصورة ────────────────────────────────
          GestureDetector(
            onTap: _showPicker,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: _image == null
                    ? Colors.grey.shade100
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _image == null
                      ? Colors.grey.shade300
                      : const Color(0xFF1A73E8),
                  width: 2,
                ),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('اضغط لالتقاط أو اختيار صورة',
                            style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text('صورة واضحة تعطي نتيجة أدق',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ])
                  : Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_image!,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        bottom: 8, right: 8,
                        child: GestureDetector(
                          onTap: _showPicker,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── زر التحليل ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: (_image == null || _loading) ? null : _analyzeImage,
              icon: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'جاري التحليل...' : 'حلّل الصورة',
                  style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // ── نتيجة التحليل ───────────────────────────────
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome,
                        color: Color(0xFF1A73E8), size: 20),
                    SizedBox(width: 8),
                    Text('نتيجة التحليل',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                  const Divider(height: 20),
                  Text(_result,
                      style: const TextStyle(fontSize: 14, height: 1.7)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.handyman, size: 14),
                        label: const Text('اطلب الحرفي'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() { _image = null; _result = ''; }),
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('صورة جديدة'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FE),
                child: Icon(Icons.camera_alt,
                    color: Color(0xFF1A73E8)),
              ),
              title: const Text('التقط صورة',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('افتح الكاميرا الآن'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FE),
                child: Icon(Icons.photo_library,
                    color: Color(0xFF1A73E8)),
              ),
              title: const Text('اختر من المعرض',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('من صور جهازك'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ]),
        ),
      ),
    );
  }
}
