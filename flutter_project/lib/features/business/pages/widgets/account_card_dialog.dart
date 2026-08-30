// ═══════════════════════════════════════════════════════════════
// بطاقة حساب – إنشاء حساب تحت أي تصنيف
// الأرقام التسلسلية: دفاتر=1، حسابات=101
// ═══════════════════════════════════════════════════════════════

import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

class AccountCardDialog extends StatefulWidget {
  final String uid;
  final String? parentCategoryCode; // كود التصنيف الأب (مثل 101)
  final String? parentCategoryName; // اسم التصنيف الأب (مثل "عملاء")

  const AccountCardDialog({
    super.key,
    required this.uid,
    this.parentCategoryCode,
    this.parentCategoryName
  });

  @override
  State<AccountCardDialog> createState() => _AccountCardDialogState();
}

class _AccountCardDialogState extends State<AccountCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();

  String _selectedType = 'client';
  String? _selectedParentCode;
  bool _isSaving = false;
  bool _showNewCategory = false;
  int _nextSerial = 0;

  // تصنيفات الحسابات
  final List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _selectedParentCode = widget.parentCategoryCode;
    _loadCategories();
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final res = await ApiService.get('/api/businesses/${widget.uid}/account-categories');

    final cats = <Map<String, dynamic>>[];
    if (res.success && res.data != null) {
      final list = res.data!['categories'] ?? res.data!['data'] ?? [];
      if (list is List) {
        for (final item in list) {
          cats.add(Map<String, dynamic>.from(item as Map));
        }
      }
    }

    // إضافة التصنيفات الافتراضية إذا لم تكن موجودة
    if (cats.isEmpty) {
      for (final cat in AppTheme.defaultAccountCategories) {
        cats.add(cat);
      }
    }

    setState(() {
      _categories.clear();
      _categories.addAll(cats);
    });

    // حساب الرقم التسلسلي
    await _calcNextSerial();
  }

  Future<void> _calcNextSerial() async {
    final parentCode = _selectedParentCode ?? '101';
    final prefix = int.tryParse(parentCode) ?? 101;

    final res = await ApiService.get('/api/businesses/${widget.uid}/accounts', queryParameters: {
      'parentCode': parentCode,
    });

    int maxSub = 0;
    if (res.success && res.data != null) {
      final list = res.data!['accounts'] ?? res.data!['data'] ?? [];
      if (list is List) {
        for (final item in list) {
          final data = item as Map<String, dynamic>;
          final code = data['code'] as String? ?? '';
          final parts = code.split('-');
          if (parts.length >= 2) {
            final sub = int.tryParse(parts.last) ?? 0;
            if (sub > maxSub) maxSub = sub;
          }
        }
      }
    }

    setState(() {
      _nextSerial = maxSub + 1;
    });
  }

  String get _accountCode {
    final parent = _selectedParentCode ?? '101';
    return '$parent-${_nextSerial.toString().padLeft(3, '0')}';
  }

  String get _selectedCategoryName {
    if (_selectedParentCode == null) return '';
    final cat = _categories.firstWhere(
      (c) => c['code'].toString() == _selectedParentCode,
      orElse: () => {'nameAr': '', 'nameEn': ''}
    );
    return cat['nameAr'] ?? cat['nameEn'] ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final accountData = {
        'code': _accountCode,
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim().isEmpty
            ? _nameArController.text.trim()
            : _nameEnController.text.trim(),
        'type': _selectedType,
        'parentCode': _selectedParentCode ?? '101',
        'parentName': _selectedCategoryName,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'notes': _notesController.text.trim(),
        'balance': 0.0,
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true
      };

      await ApiService.post('/api/businesses/${widget.uid}/accounts', body: accountData);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.danger,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addNewCategory() async {
    final name = _customCategoryController.text.trim();
    if (name.isEmpty) return;

    // حساب كود التصنيف الجديد
    int maxCode = 0;
    for (final cat in _categories) {
      final code = cat['code'] is int ? cat['code'] as int : int.tryParse(cat['code'].toString()) ?? 0;
      if (code > maxCode) maxCode = code;
    }
    final newCode = maxCode + 1;

    try {
      await ApiService.post('/api/product-categories', body: {
        'businessId': widget.uid,
        'code': newCode,
        'nameAr': name,
        'nameEn': name,
        'type': _selectedType
      });

      setState(() {
        _categories.add({
          'code': newCode,
          'nameAr': name,
          'nameEn': name,
          'type': _selectedType
        });
        _selectedParentCode = newCode.toString();
        _showNewCategory = false;
        _customCategoryController.clear();
      });

      await _calcNextSerial();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.danger)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.rLarge),
        side: const BorderSide(color: AppTheme.border, width: 0.5),
      ),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── الرأس ────────────────────────────────────────
            _buildHeader(),
            AppTheme.divider(),
            // ─── المحتوى ──────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.s12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCodeRow(),
                      const SizedBox(height: AppTheme.s8),
                      _buildTypeSelector(),
                      const SizedBox(height: AppTheme.s8),
                      _buildParentCategory(),
                      const SizedBox(height: AppTheme.s8),
                      _buildNameFields(),
                      const SizedBox(height: AppTheme.s8),
                      _buildContactFields(),
                      const SizedBox(height: AppTheme.s8),
                      _buildNotesField(),
                    ],
                  ),
                ),
              ),
            ),
            AppTheme.divider(),
            // ─── الأزرار ──────────────────────────────────────
            _buildActions(),
          ],
        ),
      )
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s10),
      child: Row(
        children: [
          const Icon(Icons.person_add_outlined, size: AppTheme.iconSize, color: AppTheme.textP),
          const SizedBox(width: AppTheme.s6),
          const Text('بطاقة حساب', style: AppTheme.sSubtitle),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, size: AppTheme.iconSize, color: AppTheme.textM),
          ),
        ],
      )
    );
  }

  Widget _buildCodeRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rSmall),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Text('رقم الحساب:', style: AppTheme.sCaption),
          const SizedBox(width: AppTheme.s6),
          Text(_accountCode, style: AppTheme.sBodyBold),
          const Spacer(),
          Text('التصنيف: $_selectedCategoryName', style: AppTheme.sCaption),
        ],
      )
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      {'value': 'client', 'label': 'عميل', 'icon': Icons.person_outlined},
      {'value': 'supplier', 'label': 'مورد', 'icon': Icons.business_outlined},
      {'value': 'expense', 'label': 'مصروف', 'icon': Icons.trending_down_outlined},
      {'value': 'revenue', 'label': 'إيراد', 'icon': Icons.trending_up_outlined},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('نوع الحساب', style: AppTheme.sCaption),
        const SizedBox(height: AppTheme.s4),
        Row(
          children: types.map((t) {
            final isSelected = _selectedType == t['value'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => setState(() => _selectedType = t['value'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.s4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.textP : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.rSmall),
                      border: Border.all(
                        color: isSelected ? AppTheme.textP : AppTheme.border,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t['icon'] as IconData,
                            size: AppTheme.iconSizeSm,
                            color: isSelected ? Colors.white : AppTheme.textS),
                        const SizedBox(width: AppTheme.s4),
                        Text(t['label'] as String,
                            style: TextStyle(
                              fontSize: AppTheme.fSmall,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.white : AppTheme.textS,
                            )),
                      ],
                    ),
                  ),
                ),
              )
            );
          }).toList(),
        ),
      ]
    );
  }

  Widget _buildParentCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('التصنيف', style: AppTheme.sCaption),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _showNewCategory = !_showNewCategory),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: AppTheme.iconSizeSm, color: AppTheme.textP),
                  const SizedBox(width: 2),
                  Text('تصنيف جديد', style: TextStyle(
                    fontSize: AppTheme.fSmall,
                    color: AppTheme.textP,
                    fontWeight: FontWeight.w500,
                  )),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.s4),
        if (_showNewCategory) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCategoryController,
                  style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
                  decoration: AppTheme.inputDecoration(hintText: 'اسم التصنيف الجديد'),
                ),
              ),
              const SizedBox(width: AppTheme.s4),
              SizedBox(
                height: AppTheme.buttonHeight,
                child: ElevatedButton(
                  onPressed: _addNewCategory,
                  style: AppTheme.primaryButtonSm,
                  child: const Text('إضافة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8),
          decoration: BoxDecoration(
            color: AppTheme.inputFill,
            borderRadius: BorderRadius.circular(AppTheme.rSmall),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: DropdownButton<String>(
            value: _selectedParentCode,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.arrow_drop_down, size: AppTheme.iconSize),
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            items: _categories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat['code'].toString(),
                child: Text('${cat['code']} - ${cat['nameAr']}')
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedParentCode = val);
              _calcNextSerial();
            },
          ),
        ),
      ]
    );
  }

  Widget _buildNameFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _nameArController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'الاسم بالعربي *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
          ),
        ),
        const SizedBox(width: AppTheme.s6),
        Expanded(
          child: TextFormField(
            controller: _nameEnController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'الاسم بالإنجليزي'),
          ),
        ),
      ]
    );
  }

  Widget _buildContactFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _phoneController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'هاتف', prefixIcon: Icons.phone_outlined),
            keyboardType: TextInputType.phone,
          ),
        ),
        const SizedBox(width: AppTheme.s6),
        Expanded(
          child: TextFormField(
            controller: _emailController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'بريد', prefixIcon: Icons.email_outlined),
            keyboardType: TextInputType.emailAddress,
          ),
        ),
      ]
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
      decoration: AppTheme.inputDecoration(hintText: 'ملاحظات'),
      maxLines: 2
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: AppTheme.buttonHeight,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ),
          const SizedBox(width: AppTheme.s6),
          SizedBox(
            height: AppTheme.buttonHeight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ),
        ],
      )
    );
  }
}
