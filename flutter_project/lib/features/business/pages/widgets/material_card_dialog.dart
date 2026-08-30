// ═══════════════════════════════════════════════════════════════
// بطاقة مادة – إنشاء مادة تحت أي تصنيف (دفتر)
// الأرقام التسلسلية: دفاتر=1، مواد=1001
// الدفتر = تصنيف ينزلج منه مجموعة مواد تنتمي لنفس التصنيف والرمز
// ═══════════════════════════════════════════════════════════════

import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

class MaterialCardDialog extends StatefulWidget {
  final String uid;
  final String? parentNotebookCode; // كود الدفتر الأب (مثل 1001)

  const MaterialCardDialog({
    super.key,
    required this.uid,
    this.parentNotebookCode
  });

  @override
  State<MaterialCardDialog> createState() => _MaterialCardDialogState();
}

class _MaterialCardDialogState extends State<MaterialCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _unitController = TextEditingController(text: 'قطعة');
  final _notesController = TextEditingController();
  final _newNotebookNameController = TextEditingController();
  final _newNotebookIconController = TextEditingController();

  String? _selectedNotebookCode;
  bool _isSaving = false;
  bool _showNewNotebook = false;
  int _nextSerial = 0;

  // الدفاتر (التصنيفات)
  final List<Map<String, dynamic>> _notebooks = [];

  @override
  void initState() {
    super.initState();
    _selectedNotebookCode = widget.parentNotebookCode;
    _loadNotebooks();
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    _newNotebookNameController.dispose();
    _newNotebookIconController.dispose();
    super.dispose();
  }

  Future<void> _loadNotebooks() async {
    final res = await ApiService.get('/api/businesses/${widget.uid}/material-notebooks');

    final books = <Map<String, dynamic>>[];
    if (res.success && res.data != null) {
      final list = res.data!['notebooks'] ?? res.data!['data'] ?? [];
      if (list is List) {
        for (final item in list) {
          books.add(Map<String, dynamic>.from(item as Map));
        }
      }
    }

    // إضافة دفاتر افتراضية إذا لم تكن موجودة
    if (books.isEmpty) {
      books.addAll([
        {'code': 1001, 'nameAr': 'كهربائية', 'nameEn': 'Electrical', 'icon': 'bolt'},
        {'code': 1002, 'nameAr': 'سباكة', 'nameEn': 'Plumbing', 'icon': 'plumbing'},
        {'code': 1003, 'nameAr': 'دهانات', 'nameEn': 'Paint', 'icon': 'format_paint'},
        {'code': 1004, 'nameAr': 'معدات عامة', 'nameEn': 'General Equipment', 'icon': 'build'},
        {'code': 1005, 'nameAr': 'أدوات', 'nameEn': 'Tools', 'icon': 'handyman'},
      ]);
    }

    setState(() {
      _notebooks.clear();
      _notebooks.addAll(books);
    });

    await _calcNextSerial();
  }

  Future<void> _calcNextSerial() async {
    final parentCode = _selectedNotebookCode ?? '1001';
    final prefix = int.tryParse(parentCode) ?? 1001;

    final res = await ApiService.get('/api/products', queryParameters: {
      'businessId': widget.uid,
      'notebookCode': parentCode,
    });

    int maxSub = 0;
    if (res.success && res.data != null) {
      final list = res.data!['products'] ?? res.data!['data'] ?? [];
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

  String get _materialCode {
    final parent = _selectedNotebookCode ?? '1001';
    return '$parent-${_nextSerial.toString().padLeft(3, '0')}';
  }

  String get _selectedNotebookName {
    if (_selectedNotebookCode == null) return '';
    final nb = _notebooks.firstWhere(
      (n) => n['code'].toString() == _selectedNotebookCode,
      orElse: () => {'nameAr': '', 'nameEn': ''}
    );
    return nb['nameAr'] ?? nb['nameEn'] ?? '';
  }

  Future<void> _addNewNotebook() async {
    final name = _newNotebookNameController.text.trim();
    if (name.isEmpty) return;

    // حساب كود الدفتر الجديد
    int maxCode = 1000;
    for (final nb in _notebooks) {
      final code = nb['code'] is int ? nb['code'] as int : int.tryParse(nb['code'].toString()) ?? 0;
      if (code > maxCode) maxCode = code;
    }
    final newCode = maxCode + 1;

    try {
      await ApiService.post('/api/product-categories', body: {
        'businessId': widget.uid,
        'code': newCode,
        'nameAr': name,
        'nameEn': name,
        'icon': _newNotebookIconController.text.trim().isEmpty
            ? 'folder'
            : _newNotebookIconController.text.trim(),
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String()
      });

      setState(() {
        _notebooks.add({
          'code': newCode,
          'nameAr': name,
          'nameEn': name,
          'icon': 'folder'
        });
        _selectedNotebookCode = newCode.toString();
        _showNewNotebook = false;
        _newNotebookNameController.clear();
        _newNotebookIconController.clear();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNotebookCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الدفتر أولاً'), backgroundColor: AppTheme.danger)
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final productData = {
        'code': _materialCode,
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim().isEmpty
            ? _nameArController.text.trim()
            : _nameEnController.text.trim(),
        'notebookCode': _selectedNotebookCode,
        'notebookName': _selectedNotebookName,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'cost': double.tryParse(_costController.text) ?? 0.0,
        'stock': double.tryParse(_stockController.text) ?? 0.0,
        'minStock': double.tryParse(_minStockController.text) ?? 0.0,
        'unit': _unitController.text.trim().isEmpty ? 'قطعة' : _unitController.text.trim(),
        'notes': _notesController.text.trim(),
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String()
      };

      await ApiService.post('/api/products', body: {
        'businessId': widget.uid,
        ...productData,
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.danger)
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            AppTheme.divider(),
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
                      _buildNotebookSelector(),
                      const SizedBox(height: AppTheme.s8),
                      _buildNameFields(),
                      const SizedBox(height: AppTheme.s8),
                      _buildPriceFields(),
                      const SizedBox(height: AppTheme.s8),
                      _buildStockFields(),
                      const SizedBox(height: AppTheme.s8),
                      _buildNotesField(),
                    ],
                  ),
                ),
              ),
            ),
            AppTheme.divider(),
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
          const Icon(Icons.inventory_2_outlined, size: AppTheme.iconSize, color: AppTheme.textP),
          const SizedBox(width: AppTheme.s6),
          const Text('بطاقة مادة', style: AppTheme.sSubtitle),
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
          const Text('رمز المادة:', style: AppTheme.sCaption),
          const SizedBox(width: AppTheme.s6),
          Text(_materialCode, style: AppTheme.sBodyBold),
          const Spacer(),
          Text('الدفتر: $_selectedNotebookName', style: AppTheme.sCaption),
        ],
      )
    );
  }

  Widget _buildNotebookSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('الدفتر', style: AppTheme.sCaption),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _showNewNotebook = !_showNewNotebook),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: AppTheme.iconSizeSm, color: AppTheme.textP),
                  const SizedBox(width: 2),
                  Text('دفتر جديد', style: TextStyle(
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
        if (_showNewNotebook) ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newNotebookNameController,
                  style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
                  decoration: AppTheme.inputDecoration(hintText: 'اسم الدفتر'),
                ),
              ),
              const SizedBox(width: AppTheme.s4),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _newNotebookIconController,
                  style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
                  decoration: AppTheme.inputDecoration(hintText: 'أيقونة (اختياري)'),
                ),
              ),
              const SizedBox(width: AppTheme.s4),
              SizedBox(
                height: AppTheme.buttonHeight,
                child: ElevatedButton(
                  onPressed: _addNewNotebook,
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
            value: _selectedNotebookCode,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: const Text('اختر الدفتر', style: TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textM)),
            icon: const Icon(Icons.arrow_drop_down, size: AppTheme.iconSize),
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            items: _notebooks.map((nb) {
              return DropdownMenuItem<String>(
                value: nb['code'].toString(),
                child: Text('${nb['code']} - ${nb['nameAr']}')
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedNotebookCode = val);
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
            decoration: AppTheme.inputDecoration(hintText: 'اسم المادة بالعربي *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
          ),
        ),
        const SizedBox(width: AppTheme.s6),
        Expanded(
          child: TextFormField(
            controller: _nameEnController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'اسم المادة بالإنجليزي'),
          ),
        ),
      ]
    );
  }

  Widget _buildPriceFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _priceController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'سعر البيع', suffixText: 'د.ك'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: AppTheme.s6),
        Expanded(
          child: TextFormField(
            controller: _costController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'التكلفة', suffixText: 'د.ك'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ]
    );
  }

  Widget _buildStockFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _stockController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'الكمية'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: AppTheme.s6),
        Expanded(
          child: TextFormField(
            controller: _minStockController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'حد أدنى'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: AppTheme.s6),
        Expanded(
          child: TextFormField(
            controller: _unitController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'الوحدة'),
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
