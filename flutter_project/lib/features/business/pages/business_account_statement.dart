import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:sana3i_kuwait/core/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';

class _C {
  static const Color bg = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD2D2D7);
  static const Color accent = Color(0xFF0071E3);
  static const Color accentLight = Color(0xFFE8F0FE);
  static const Color textP = Color(0xFF1D1D1F);
  static const Color textS = Color(0xFF6E6E73);
  static const Color textM = Color(0xFF86868B);
  static const Color inputFill = Color(0xFFF5F5F7);
  static const Color danger = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
}

// ═══════════════════════════════════════════════════════════════
// كشف حساب – Account Statement
// ✅ كشف حساب عميل / مورد / بنك / كي نت / كاش / مصروف
// ✅ فلتر بالتاريخ + رصيد تراكمي
// ✅ بدون فهرس مركب
// ═══════════════════════════════════════════════════════════════

class BusinessAccountStatement extends StatefulWidget {
  final String uid;
  const BusinessAccountStatement({super.key, required this.uid});

  @override
  State<BusinessAccountStatement> createState() => _BusinessAccountStatementState();
}

class _BusinessAccountStatementState extends State<BusinessAccountStatement> {
  late final _uid = widget.uid;

  // نوع الكشف
  String _statementType = 'client'; // client | supplier | bank | knet | cash | expense
  String? _selectedEntityId;
  String _selectedEntityName = '';
  String? _selectedExpenseCategory;

  // فلتر التاريخ
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // البيانات
  List<Map<String, dynamic>> _entities = [];
  List<Map<String, dynamic>> _entries = [];
  bool _loadingEntities = true;
  bool _loadingEntries = false;

  // أنواع المصاريف المتوفرة
  List<String> _expenseCategories = [];

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  // ─── تحميل الكيانات حسب النوع ────────────────────────────────
  Future<void> _loadEntities() async {
    setState(() => _loadingEntities = true);
    try {
      List<Map<String, dynamic>> entities = [];
      List<String> categories = [];

      switch (_statementType) {
        case 'client':
          final res = await ApiService.get('/api/clients', queryParameters: {'businessId': _uid});
          if (res.success && res.data != null) {
            final list = res.data!['clients'] ?? res.data!['data'];
            if (list is List) entities = list.cast<Map<String, dynamic>>();
          }
          break;

        case 'supplier':
          final res = await ApiService.get('/api/suppliers', queryParameters: {'businessId': _uid});
          if (res.success && res.data != null) {
            final list = res.data!['suppliers'] ?? res.data!['data'];
            if (list is List) entities = list.cast<Map<String, dynamic>>();
          }
          break;

        case 'bank':
        case 'knet':
        case 'cash':
        case 'myinvoice':
          final accountName = _statementType == 'bank' ? 'البنك' : _statementType == 'knet' ? 'كي نت' : _statementType == 'myinvoice' ? 'ماي فاتوره' : 'الصندوق';
          final accounts = await FirestoreService.getAccounts(businessId: _uid);
          final account = accounts.where((a) => a['accountName'] == accountName).toList();
          if (account.isNotEmpty) {
            entities = [{'id': accountName, 'name': accountName, 'balance': account.first['balance'] ?? 0}];
          }
          break;

        case 'expense':
          final res = await ApiService.get('/api/dashboard', queryParameters: {'businessId': _uid});
          if (res.success && res.data != null) {
            final expenses = res.data!['expenseCategories'];
            if (expenses is List) {
              categories = expenses.map((e) => e.toString()).toList()..sort();
            }
          }
          break;
      }

      if (mounted) {
        setState(() {
          _entities = entities;
          _expenseCategories = categories;
          _selectedEntityId = null;
          _selectedEntityName = '';
          _selectedExpenseCategory = null;
          _entries = [];
          _loadingEntities = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingEntities = false);
    }
  }

  // ─── تحميل حركات الكشف ────────────────────────────────────────
  Future<void> _loadStatement() async {
    if (_statementType != 'expense' && _selectedEntityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اختر الكيان أولاً'), backgroundColor: _C.warning),
      );
      return;
    }
    if (_statementType == 'expense' && _selectedExpenseCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اختر فئة المصروف أولاً'), backgroundColor: _C.warning),
      );
      return;
    }

    setState(() => _loadingEntries = true);

    try {
      // استعلام المعاملات بدون orderBy
      final res = await ApiService.get('/api/bonds', queryParameters: {'businessId': _uid});
      List<Map<String, dynamic>> allEntries = [];
      if (res.success && res.data != null) {
        final list = res.data!['bonds'] ?? res.data!['data'];
        if (list is List) allEntries = list.cast<Map<String, dynamic>>();
      }

      // ترتيب يدوي حسب التاريخ (الأقدم أولاً للرصيد التراكمي)
      allEntries.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return aTime.compareTo(bTime);
      });

      // تصفية حسب النوع والكيان والتاريخ
      final entries = <Map<String, dynamic>>[];
      for (final d in allEntries) {
        final type = d['type'] as String? ?? '';
        final paymentMethod = d['paymentMethod'] as String?;
        final ledgerAccount = d['ledgerAccount'] as String?;
        final category = d['category'] as String?;
        final clientId = d['clientId'] as String?;
        final supplierId = d['supplierId'] as String?;
        final createdAtStr = d['createdAt'] as String?;

        bool match = false;

        switch (_statementType) {
          case 'client':
            match = clientId == _selectedEntityId;
            break;
          case 'supplier':
            match = supplierId == _selectedEntityId;
            break;
          case 'bank':
            match = ledgerAccount == 'البنك' || paymentMethod == 'bank';
            break;
          case 'knet':
            match = ledgerAccount == 'كي نت' || paymentMethod == 'knet';
            break;
          case 'cash':
            match = ledgerAccount == 'الصندوق' || paymentMethod == 'cash';
            break;
          case 'myinvoice':
            match = ledgerAccount == 'ماي فاتوره' || paymentMethod == 'myinvoice';
            break;
          case 'expense':
            match = type == 'expense' && category == _selectedExpenseCategory;
            break;
        }

        if (!match) continue;

        // فلتر التاريخ
        if (createdAtStr != null) {
          final date = DateTime.tryParse(createdAtStr);
          if (date != null) {
            if (_dateFrom != null) {
              final fromStart = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
              if (date.isBefore(fromStart)) continue;
            }
            if (_dateTo != null) {
              final toEnd = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
              if (date.isAfter(toEnd)) continue;
            }
          }
        } else if (_dateFrom != null || _dateTo != null) {
          continue;
        }

        final entry = Map<String, dynamic>.from(d);
        entries.add(entry);
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _loadingEntries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEntries = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: _C.danger),
        );
      }
    }
  }

  // ─── أيقونات وألوان ──────────────────────────────────────────
  IconData _typeIcon(String type) {
    switch (type) {
      case 'client': return Icons.person;
      case 'supplier': return Icons.store;
      case 'bank': return Icons.account_balance;
      case 'knet': return Icons.credit_card;
      case 'cash': return Icons.payments;
      case 'myinvoice': return Icons.receipt_long;
      case 'expense': return Icons.receipt_long;
      default: return Icons.description;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'client': return _C.success;
      case 'supplier': return _C.accent;
      case 'bank': return Color(0xFFAF52DE);
      case 'knet': return _C.accent;
      case 'cash': return _C.success;
      case 'myinvoice': return _C.warning;
      case 'expense': return _C.danger;
      default: return _C.textM;
    }
  }

  String _typeAr(String type) {
    switch (type) {
      case 'client': return 'عميل';
      case 'supplier': return 'مورد';
      case 'bank': return 'البنك';
      case 'knet': return 'كي نت';
      case 'cash': return 'الصندوق';
      case 'myinvoice': return 'ماي فاتوره';
      case 'expense': return 'مصروف';
      default: return '';
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is String) {
      final d = DateTime.tryParse(timestamp);
      if (d != null) {
        return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _C.accent, surface: _C.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _C.accent, surface: _C.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateTo = picked);
  }

  String _formatDateShort(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════
  // البناء
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildTypeSelector(),
        _buildEntitySelector(),
        Expanded(child: _buildStatementTable()),
      ],
    );
  }

  // ─── شريط الأدوات ──────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment, color: _C.accent, size: 20),
          SizedBox(width: 8),
          Text('كشف حساب', style: TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
          Spacer(),
          // فلتر التاريخ
          GestureDetector(
            onTap: _pickDateFrom,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _dateFrom != null ? _C.accentLight : _C.inputFill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _dateFrom != null ? _C.accent.withOpacity(0.3) : _C.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 12, color: _dateFrom != null ? _C.accent : _C.textM),
                  SizedBox(width: 4),
                  Text(_dateFrom != null ? _formatDateShort(_dateFrom!) : 'من', style: TextStyle(color: _dateFrom != null ? _C.accent : _C.textM, fontSize: 12)),
                  if (_dateFrom != null) ...[
                    SizedBox(width: 3),
                    GestureDetector(onTap: () => setState(() => _dateFrom = null), child: Icon(Icons.close, size: 10, color: _C.danger)),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: 4),
          GestureDetector(
            onTap: _pickDateTo,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _dateTo != null ? _C.accentLight : _C.inputFill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _dateTo != null ? _C.accent.withOpacity(0.3) : _C.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 12, color: _dateTo != null ? _C.accent : _C.textM),
                  SizedBox(width: 4),
                  Text(_dateTo != null ? _formatDateShort(_dateTo!) : 'إلى', style: TextStyle(color: _dateTo != null ? _C.accent : _C.textM, fontSize: 12)),
                  if (_dateTo != null) ...[
                    SizedBox(width: 3),
                    GestureDetector(onTap: () => setState(() => _dateTo = null), child: Icon(Icons.close, size: 10, color: _C.danger)),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _loadingEntries ? null : _loadStatement,
            icon: Icon(Icons.search, size: 16),
            label: Text('عرض', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.accent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── اختيار نوع الكشف ──────────────────────────────────────────
  Widget _buildTypeSelector() {
    final types = [
      ('client', 'عميل', Icons.person, _C.success),
      ('supplier', 'مورد', Icons.store, _C.accent),
      ('bank', 'البنك', Icons.account_balance, Color(0xFFAF52DE)),
      ('knet', 'كي نت', Icons.credit_card, _C.accent),
      ('cash', 'الصندوق', Icons.payments, _C.success),
      ('myinvoice', 'ماي فاتوره', Icons.receipt_long, _C.warning),
      ('expense', 'مصروف', Icons.receipt_long, _C.danger),
    ];

    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        children: types.map((t) {
          final (key, label, icon, color) = t;
          final isSelected = _statementType == key;
          return GestureDetector(
            onTap: () {
              setState(() => _statementType = key);
              _loadEntities();
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.12) : _C.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color.withOpacity(0.3) : _C.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: isSelected ? color : _C.textM, size: 16),
                  SizedBox(width: 6),
                  Text(label, style: TextStyle(color: isSelected ? color : _C.textS, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── اختيار الكيان ──────────────────────────────────────────────
  Widget _buildEntitySelector() {
    if (_loadingEntities) {
      return Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.accent)),
      );
    }

    // كشف مصروف
    if (_statementType == 'expense') {
      if (_expenseCategories.isEmpty) {
        return Padding(
          padding: EdgeInsets.all(12),
          child: Text('لا توجد فئات مصاريف مسجلة', style: TextStyle(color: _C.textM, fontSize: 13)),
        );
      }
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فئة المصروف:', style: TextStyle(color: _C.textS, fontSize: 12)),
            SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _expenseCategories.map((cat) {
                final isSelected = _selectedExpenseCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedExpenseCategory = cat),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? _C.danger.withOpacity(0.1) : _C.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? _C.danger.withOpacity(0.3) : _C.border),
                    ),
                    child: Text(cat, style: TextStyle(color: isSelected ? _C.danger : _C.textS, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    // كشف بنك/كي نت/كاش - لا يحتاج اختيار كيان
    if (_statementType == 'bank' || _statementType == 'knet' || _statementType == 'cash' || _statementType == 'myinvoice') {
      if (_entities.isEmpty) {
        return Padding(
          padding: EdgeInsets.all(12),
          child: Text('لا يوجد حساب لهذا النوع بعد', style: TextStyle(color: _C.textM, fontSize: 13)),
        );
      }
      final entity = _entities.first;
      final balance = (entity['balance'] as num?)?.toDouble() ?? 0;
      final color = _typeColor(_statementType);

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(_typeIcon(_statementType), color: color, size: 20),
            SizedBox(width: 10),
            Text(entity['name'] ?? '', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Spacer(),
            Text('الرصيد الحالي: ', style: TextStyle(color: _C.textS, fontSize: 13)),
            Text('${balance.toStringAsFixed(3)} د.ك', style: TextStyle(color: balance >= 0 ? _C.success : _C.danger, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // كشف عميل/مورد - يحتاج اختيار
    if (_entities.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(12),
        child: Text(_statementType == 'client' ? 'لا يوجد عملاء مسجلون' : 'لا يوجد موردون مسجلون', style: TextStyle(color: _C.textM, fontSize: 13)),
      );
    }

    final color = _typeColor(_statementType);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statementType == 'client' ? 'اختر العميل:' : 'اختر المورد:',
            style: TextStyle(color: _C.textS, fontSize: 12),
          ),
          SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 120),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _entities.length,
              itemBuilder: (_, i) {
                final entity = _entities[i];
                final isSelected = _selectedEntityId == entity['id'];
                final balance = (entity['totalPurchases'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    _statementType == 'client' ? Icons.person : Icons.store,
                    color: isSelected ? color : _C.textM,
                    size: 14,
                  ),
                  title: Text(
                    entity['name'] ?? '',
                    style: TextStyle(color: isSelected ? color : _C.textS, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: entity['phone'] != null ? Text(entity['phone'], style: TextStyle(color: _C.textM, fontSize: 12)) : null,
                  trailing: Text('${balance.toStringAsFixed(3)} د.ك', style: TextStyle(color: _C.textM, fontSize: 12)),
                  selected: isSelected,
                  onTap: () => setState(() {
                    _selectedEntityId = entity['id'];
                    _selectedEntityName = entity['name'] ?? '';
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── جدول الكشف ──────────────────────────────────────────────────
  Widget _buildStatementTable() {
    if (_loadingEntries) {
      return Center(child: CircularProgressIndicator(color: _C.accent));
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: _C.textM.withOpacity(0.5)),
            SizedBox(height: 12),
            Text('اختر الكيان واضغط "عرض" لعرض كشف الحساب', style: TextStyle(color: _C.textS, fontSize: 18)),
          ],
        ),
      );
    }

    // حساب الرصيد التراكمي والمجاميع
    double runningBalance = 0;
    double totalDebit = 0;
    double totalCredit = 0;

    for (final d in _entries) {
      final type = d['type'] as String? ?? '';
      final amount = (d['amount'] as num?)?.toDouble() ?? 0;

      switch (type) {
        case 'income':
        case 'purchase_return':
          runningBalance += amount;
          totalDebit += amount;
          break;
        default:
          runningBalance -= amount;
          totalCredit += amount;
          break;
      }
    }

    return Column(
      children: [
        // ملخص الكشف
        Container(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.accentLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.accent.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'كشف حساب: $_selectedEntityName${_statementType == 'expense' ? _selectedExpenseCategory ?? '' : ''}',
                    style: TextStyle(color: _C.accent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  Text('${_entries.length} حركة', style: TextStyle(color: _C.textM, fontSize: 12)),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  _buildSummaryBox('مدين (داخل)', totalDebit, _C.success),
                  SizedBox(width: 8),
                  _buildSummaryBox('دائن (خارج)', totalCredit, _C.danger),
                  SizedBox(width: 8),
                  _buildSummaryBox('الرصيد', runningBalance, runningBalance >= 0 ? _C.success : _C.danger),
                ],
              ),
            ],
          ),
        ),

        // رأس الجدول
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _C.surface,
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(
            children: [
              _headerCell('التاريخ', 110),
              _headerCell('البيان', null, flex: 4),
              _headerCell('مدين', 90),
              _headerCell('دائن', 90),
              _headerCell('الرصيد', 100),
            ],
          ),
        ),

        // الصفوف
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemCount: _entries.length + 1, // +1 للإجمالي
            itemBuilder: (_, i) {
              if (i == _entries.length) {
                return _buildTotalRow(totalDebit, totalCredit, runningBalance);
              }
              return _buildEntryRow(_entries[i]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBox(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 14)),
            SizedBox(height: 2),
            Text('${amount.toStringAsFixed(3)}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, double? width, {int? flex}) {
    final child = Text(text, style: TextStyle(color: _C.textS, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    if (flex != null && width == null) return Expanded(flex: flex, child: child);
    return SizedBox(width: width, child: child);
  }

  Widget _buildEntryRow(Map<String, dynamic> d) {
    final type = d['type'] as String? ?? '';
    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
    final description = d['description'] as String? ?? '';
    final createdAt = d['createdAt'];
    final dateStr = createdAt != null ? _formatDate(createdAt) : '';

    double debit = 0;
    double credit = 0;
    Color rowColor;

    switch (type) {
      case 'income':
      case 'purchase_return':
        debit = amount;
        rowColor = _C.success;
        break;
      default:
        credit = amount;
        rowColor = _C.danger;
        break;
    }

    return Container(
      height: 38,
      padding: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(dateStr, style: TextStyle(color: _C.textM, fontSize: 12), textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 4,
            child: Text(
              description.isNotEmpty ? description : 'حركة مالية',
              style: TextStyle(color: _C.textS, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 90,
            child: debit > 0 ? Text('${debit.toStringAsFixed(3)}', style: TextStyle(color: _C.success, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center) : Text('-', style: TextStyle(color: _C.textM.withOpacity(0.3), fontSize: 12), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 90,
            child: credit > 0 ? Text('${credit.toStringAsFixed(3)}', style: TextStyle(color: _C.danger, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center) : Text('-', style: TextStyle(color: _C.textM.withOpacity(0.3), fontSize: 12), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '${(debit - credit).toStringAsFixed(3)}',
              style: TextStyle(color: rowColor, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(double totalDebit, double totalCredit, double balance) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _C.accentLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(width: 110),
          Expanded(
            flex: 4,
            child: Text('الإجمالي', style: TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 90,
            child: Text('${totalDebit.toStringAsFixed(3)}', style: TextStyle(color: _C.success, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 90,
            child: Text('${totalCredit.toStringAsFixed(3)}', style: TextStyle(color: _C.danger, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '${balance.toStringAsFixed(3)}',
              style: TextStyle(color: balance >= 0 ? _C.success : _C.danger, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
