import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

class BusinessAddExpense extends StatefulWidget {
  final String uid;
  const BusinessAddExpense({super.key, required this.uid});

  @override
  State<BusinessAddExpense> createState() => _BusinessAddExpenseState();
}

class _BusinessAddExpenseState extends State<BusinessAddExpense> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedCategory;
  bool _saving = false;

  static const List<Map<String, String>> _categories = [
    {'value': 'salary', 'label': 'رواتب موظفين', 'icon': '👥'},
    {'value': 'rent', 'label': 'إيجارات', 'icon': '🏢'},
    {'value': 'hospitality', 'label': 'مصاريف ضيافة', 'icon': '☕'},
    {'value': 'petty_cash', 'label': 'نثريات', 'icon': '💵'},
    {'value': 'delivery', 'label': 'مصاريف توصيل', 'icon': '🚚'},
    {'value': 'materials', 'label': 'مواد خام', 'icon': '📦'},
    {'value': 'utilities', 'label': 'فواتير', 'icon': '🧾'},
    {'value': 'other', 'label': 'مصاريف أخرى', 'icon': '📋'},
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _snack('❌ الرجاء إدخال مبلغ صحيح');
      return;
    }
    if (_selectedCategory == null) {
      _snack('❌ الرجاء اختيار نوع المصروف');
      return;
    }

    setState(() => _saving = true);

    final res = await ApiService.post('/api/accounting/transactions', body: {
      'businessId': widget.uid,
      'type': 'expense',
      'amount': amount,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : _getCategoryLabel(_selectedCategory!),
      'category': _selectedCategory,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': widget.uid,
    });
    if (!res.success) {
      if (mounted) _snack('خطأ: ${res.errorMessage}');
      return;
    }

    if (mounted) {
      _snack('✅ تم تسجيل المصروف بنجاح');
      Navigator.pop(context, true);
    }
  }

  String _getCategoryLabel(String value) {
    return _categories.firstWhere((c) => c['value'] == value)['label'] ?? value;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: const Color(0xFF0071E3), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1D1F),
      appBar: AppBar(
        title: const Text('إضافة مصروف'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // المبلغ
            const Text('المبلغ (دينار كويتي)', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0.000',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0071E3))),
                prefixIcon: const Icon(Icons.monetization_on, color: Color(0xFF0071E3)),
              ),
            ),

            const SizedBox(height: 24),

            // نوع المصروف
            const Text('نوع المصروف', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['value']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0071E3).withOpacity(0.3) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? const Color(0xFF0071E3) : Colors.white.withOpacity(0.3)),
                    ),
                    child: Text('${cat['icon']} ${cat['label']}',
                        style: TextStyle(color: isSelected ? const Color(0xFF0071E3) : Colors.white70, fontSize: 13)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // وصف
            const Text('وصف (اختياري)', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'تفاصيل المصروف...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0071E3))),
              ),
            ),

            const SizedBox(height: 32),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(Icons.save),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ المصروف', style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}