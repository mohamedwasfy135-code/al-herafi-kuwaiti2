import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/services/api_key_service.dart';

class AdminApiKeyTab extends StatefulWidget {
  const AdminApiKeyTab({super.key});
  @override
  State<AdminApiKeyTab> createState() => _AdminApiKeyTabState();
}

class _AdminApiKeyTabState extends State<AdminApiKeyTab> {
  final _apiKeyCtrl = TextEditingController();
  bool _loadingKey = false;

  Future<void> _loadApiKey() async {
    final key = await ApiKeyService.getOpenRouterKey();
    if (key != null && mounted) setState(() => _apiKeyCtrl.text = key);
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) { _snack('⚠️ ${'enter_valid_key'.tr()}'); return; }
    setState(() => _loadingKey = true);
    await ApiKeyService.saveOpenRouterKey(key);
    if (mounted) { setState(() => _loadingKey = false); _snack('✅ ${'saved_successfully'.tr()}'); }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void initState() { super.initState(); _loadApiKey(); }
  @override
  void dispose() { _apiKeyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان والأيقونة
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0071E3).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF0071E3), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔑 ${'openrouter_api_key'.tr()}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'openrouter_description'.tr(),
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // حقل المفتاح زجاجي
                TextField(
                  controller: _apiKeyCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'key_label'.tr(),
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'sk-or-v1-...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0071E3)),
                    ),
                    prefixIcon: const Icon(Icons.key_rounded, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 20),

                // الأزرار
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadingKey ? null : _saveApiKey,
                        icon: _loadingKey
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D1D1F)))
                            : const Icon(Icons.save_rounded, size: 14, color: Color(0xFF1D1D1F)),
                        label: Text('save'.tr(), style: const TextStyle(color: Color(0xFF1D1D1F))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _apiKeyCtrl.clear(),
                        icon: const Icon(Icons.clear_rounded, size: 14, color: Colors.white70),
                        label: Text('clear'.tr(), style: const TextStyle(color: Colors.white70)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // تحذير الصلاحيات زجاجي
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade300),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '⚠️ ${'admin_privilege_required'.tr()}',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade300, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}