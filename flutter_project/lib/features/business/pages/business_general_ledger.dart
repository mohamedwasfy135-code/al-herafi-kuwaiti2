import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
// دفتر الأستاذ – General Ledger (إصدار 2)
// ✅ تجميع حسب الحساب (البنك → كي نت → الصندوق → أخرى)
// ✅ فلتر بالتاريخ (من / إلى) لاستدعاء أي يوم
// ✅ بدون فهرس مركب - ترتيب يدوي
// ═══════════════════════════════════════════════════════════════

class BusinessGeneralLedger extends StatefulWidget {
  final String uid;
  const BusinessGeneralLedger({super.key, required this.uid});

  @override
  State<BusinessGeneralLedger> createState() => _BusinessGeneralLedgerState();
}

class _BusinessGeneralLedgerState extends State<BusinessGeneralLedger>
    with AutomaticKeepAliveClientMixin {
  late final _uid = widget.uid;

  String? _filterType;
  String? _filterPaymentMethod;
  String? _filterLedgerAccount;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _loading = false;

  // Data loaded from API
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];

  // ترتيب الحسابات: البنك أولًا، ثم كي نت، ثم ماي فاتوره، ثم الصندوق، ثم الباقي
  static const _accountOrder = ['البنك', 'كي نت', 'ماي فاتوره', 'الصندوق'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // Load accounts
      final accountsRes = await ApiService.get('/api/accounts', queryParameters: {'businessId': _uid});
      if (accountsRes.success && accountsRes.data != null) {
        final list = accountsRes.data!['accounts'] ?? accountsRes.data!['data'];
        if (list is List) _accounts = list.cast<Map<String, dynamic>>();
      }

      // Load transactions
      final txnRes = await ApiService.get('/api/accounting/transactions', queryParameters: {
        'businessId': _uid,
        'limit': 1000,
      });
      if (txnRes.success && txnRes.data != null) {
        final list = txnRes.data!['transactions'] ?? txnRes.data!['data'];
        if (list is List) _transactions = list.cast<Map<String, dynamic>>();
      }

      // Sort transactions manually by date (newest first)
      _transactions.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      debugPrint('Error loading ledger data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ─── أيقونة ولون الحساب ─────────────────────────────────────
  IconData _accountIcon(String name) {
    if (name == 'الصندوق') return Icons.payments;
    if (name == 'كي نت') return Icons.credit_card;
    if (name == 'البنك') return Icons.account_balance;
    if (name == 'ماي فاتوره') return Icons.receipt_long;
    return Icons.folder;
  }

  Color _accountColor(String name) {
    if (name == 'الصندوق') return _C.success;
    if (name == 'كي نت') return _C.accent;
    if (name == 'البنك') return Colors.purple;
    if (name == 'ماي فاتوره') return _C.warning;
    return Colors.amber;
  }

  IconData _paymentIcon(String? method) {
    switch (method) {
      case 'cash': return Icons.payments;
      case 'knet': return Icons.credit_card;
      case 'bank': return Icons.account_balance;
      case 'myinvoice': return Icons.receipt_long;
      default: return Icons.receipt_long;
    }
  }

  Color _paymentColor(String? method) {
    switch (method) {
      case 'cash': return _C.success;
      case 'knet': return _C.accent;
      case 'bank': return Colors.purple;
      case 'myinvoice': return _C.warning;
      default: return _C.textS;
    }
  }

  String _paymentAr(String? method) {
    switch (method) {
      case 'cash': return 'كاش';
      case 'knet': return 'كي نت';
      case 'bank': return 'تحويل بنكي';
      case 'myinvoice': return 'ماي فاتوره';
      default: return '';
    }
  }

  // ─── فلتر التاريخ ────────────────────────────────────────────
  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _C.accent, surface: _C.card),
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
          colorScheme: const ColorScheme.light(primary: _C.accent, surface: _C.card),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateTo = picked);
  }

  String _formatDateShort(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  // ─── ترتيب الحسابات ──────────────────────────────────────────
  int _accountSortIndex(String name) {
    final idx = _accountOrder.indexOf(name);
    return idx >= 0 ? idx : _accountOrder.length;
  }

  // ─── تطبيق الفلاتر ──────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactions.where((d) {
      // فلتر النوع
      if (_filterType != null && d['type'] != _filterType) return false;

      // فلتر طريقة الدفع
      if (_filterPaymentMethod != null && d['paymentMethod'] != _filterPaymentMethod) return false;

      // فلتر حساب الأستاذ
      if (_filterLedgerAccount != null && d['ledgerAccount'] != _filterLedgerAccount) return false;

      // فلتر التاريخ
      final createdAtStr = d['createdAt'] as String?;
      if (createdAtStr != null) {
        final date = DateTime.tryParse(createdAtStr);
        if (date != null) {
          if (_dateFrom != null) {
            final fromStart = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
            if (date.isBefore(fromStart)) return false;
          }
          if (_dateTo != null) {
            final toEnd = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
            if (date.isAfter(toEnd)) return false;
          }
        }
      } else if (_dateFrom != null || _dateTo != null) {
        return false;
      }

      return true;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // البناء
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        _buildTopBar(),
        _buildAccountsBalanceBar(),
        Expanded(child: _buildGroupedTransactions()),
      ],
    );
  }

  // ─── شريط الأدوات العلوي ──────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.start,
        children: [
          // أيقونة العنوان
          const Icon(Icons.menu_book, color: _C.accent, size: 14),
          const Text('دفتر الأستاذ', style: TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),

          // فلتر من تاريخ
          GestureDetector(
            onTap: _pickDateFrom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (_dateFrom != null ? _C.accent : _C.textP).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_dateFrom != null ? _C.accent : _C.border).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 13, color: _dateFrom != null ? _C.accent : _C.textS),
                  const SizedBox(width: 4),
                  Text(
                    _dateFrom != null ? _formatDateShort(_dateFrom!) : 'من تاريخ',
                    style: TextStyle(color: _dateFrom != null ? _C.accent : _C.textS, fontSize: 12),
                  ),
                  if (_dateFrom != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _dateFrom = null),
                      child: const Icon(Icons.close, size: 14, color: _C.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // فلتر إلى تاريخ
          GestureDetector(
            onTap: _pickDateTo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (_dateTo != null ? _C.accent : _C.textP).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_dateTo != null ? _C.accent : _C.border).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 13, color: _dateTo != null ? _C.accent : _C.textS),
                  const SizedBox(width: 4),
                  Text(
                    _dateTo != null ? _formatDateShort(_dateTo!) : 'إلى تاريخ',
                    style: TextStyle(color: _dateTo != null ? _C.accent : _C.textS, fontSize: 12),
                  ),
                  if (_dateTo != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _dateTo = null),
                      child: const Icon(Icons.close, size: 14, color: _C.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // فلتر النوع
          _buildTypeFilterChip('الكل', null),
          _buildTypeFilterChip('إيرادات', 'income'),
          _buildTypeFilterChip('مصروفات', 'expense'),
          _buildTypeFilterChip('مشتريات', 'purchase'),
          _buildTypeFilterChip('مردود مبيعات', 'sales_return'),
          _buildTypeFilterChip('مردود مشتريات', 'purchase_return'),

          // فلتر طريقة الدفع
          const SizedBox(width: 8),
          _buildPaymentChip('كل الطرق', null),
          _buildPaymentChip('كاش', 'cash'),
          _buildPaymentChip('كي نت', 'knet'),
          _buildPaymentChip('بنك', 'bank'),
          _buildPaymentChip('ماي فاتوره', 'myinvoice'),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(String label, String? type) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _C.accent.withOpacity(0.15) : _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? _C.accent.withOpacity(0.4) : _C.border),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? _C.accent : _C.textS, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildPaymentChip(String label, String? method) {
    final isSelected = _filterPaymentMethod == method;
    Color chipColor = method == 'cash' ? _C.success : method == 'knet' ? _C.accent : method == 'bank' ? Colors.purple : _C.accent;
    return GestureDetector(
      onTap: () => setState(() => _filterPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? chipColor.withOpacity(0.4) : _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (method != null) ...[
              Icon(_paymentIcon(method), color: chipColor, size: 12),
              const SizedBox(width: 2),
            ],
            Text(label, style: TextStyle(color: isSelected ? chipColor : _C.textS, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── شريط أرصدة الحسابات ──────────────────────────────────────
  Widget _buildAccountsBalanceBar() {
    // Sort accounts by order
    final sortedAccounts = List<Map<String, dynamic>>.from(_accounts);
    sortedAccounts.sort((a, b) {
      final aName = a['accountName'] as String? ?? '';
      final bName = b['accountName'] as String? ?? '';
      return _accountSortIndex(aName).compareTo(_accountSortIndex(bName));
    });

    if (sortedAccounts.isEmpty) return const SizedBox.shrink();

    double totalBalance = 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أرصدة الحسابات', style: TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sortedAccounts.map((data) {
              final accountName = data['accountName'] as String? ?? data['id'] ?? '';
              final balance = (data['balance'] as num?)?.toDouble() ?? 0;
              totalBalance += balance;

              final accColor = _accountColor(accountName);
              final accIcon = _accountIcon(accountName);
              final isSelected = _filterLedgerAccount == accountName;

              return GestureDetector(
                onTap: () => setState(() {
                  _filterLedgerAccount = isSelected ? null : accountName;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? accColor.withOpacity(0.2) : accColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? accColor.withOpacity(0.6) : accColor.withOpacity(0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(accIcon, color: accColor, size: 16),
                      const SizedBox(width: 8),
                      Text(accountName, style: TextStyle(color: accColor, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Text('${balance.toStringAsFixed(3)}', style: TextStyle(color: accColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      Text('د.ك', style: TextStyle(color: accColor.withOpacity(0.6), fontSize: 14)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (sortedAccounts.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Text('إجمالي الأرصدة: ', style: TextStyle(color: _C.textS, fontSize: 12)),
                  Text('${totalBalance.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.accent, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── المعاملات المجمعة حسب الحساب ──────────────────────────────
  Widget _buildGroupedTransactions() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.accent));
    }

    final filteredDocs = _filteredTransactions;

    if (filteredDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: _C.textM.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('لا توجد حركات مالية', style: TextStyle(color: _C.textM)),
          ],
        ),
      );
    }

    // تجميع حسب حساب الأستاذ
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final d in filteredDocs) {
      final account = d['ledgerAccount'] as String? ?? 'أخرى';
      final entry = Map<String, dynamic>.from(d);
      grouped.putIfAbsent(account, () => []).add(entry);
    }

    // ترتيب المجموعات: البنك، كي نت، الصندوق، الباقي
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => _accountSortIndex(a).compareTo(_accountSortIndex(b)));

    // حساب الرصيد الإجمالي
    double totalBalance = 0;
    for (final d in filteredDocs) {
      final type = d['type'] as String? ?? '';
      final amount = (d['amount'] as num?)?.toDouble() ?? 0;
      switch (type) {
        case 'income':
        case 'purchase_return':
          totalBalance += amount;
          break;
        default:
          totalBalance -= amount;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: [
        // عرض المجموعات
        ...sortedKeys.map((accountName) => _buildAccountGroup(accountName, grouped[accountName]!)),

        // الرصيد النهائي
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.accentLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.accent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الرصيد النهائي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _C.accent)),
              Text('${totalBalance.toStringAsFixed(3)} د.ك',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _C.accent)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── مجموعة حساب واحد ──────────────────────────────────────────
  Widget _buildAccountGroup(String accountName, List<Map<String, dynamic>> entries) {
    final accColor = _accountColor(accountName);
    final accIcon = _accountIcon(accountName);

    // حساب رصيد المجموعة
    double groupBalance = 0;
    for (final d in entries) {
      final type = d['type'] as String? ?? '';
      final amount = (d['amount'] as num?)?.toDouble() ?? 0;
      switch (type) {
        case 'income':
        case 'purchase_return':
          groupBalance += amount;
          break;
        default:
          groupBalance -= amount;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس المجموعة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: accColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(accIcon, color: accColor, size: 16),
                ),
                const SizedBox(width: 12),
                Text(accountName, style: TextStyle(color: accColor, fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (groupBalance >= 0 ? _C.success : _C.danger).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (groupBalance >= 0 ? _C.success : _C.danger).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${groupBalance >= 0 ? '+' : ''}${groupBalance.toStringAsFixed(3)} د.ك',
                    style: TextStyle(
                      color: groupBalance >= 0 ? _C.success : _C.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entries.length} حركة', style: TextStyle(color: accColor.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),

          // المعاملات
          ...entries.map((d) => _buildTransactionRow(d, accColor)),

          // إجمالي الحساب
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accColor.withOpacity(0.04),
              border: Border(top: BorderSide(color: _C.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.summarize, color: accColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'إجمالي $accountName',
                      style: TextStyle(color: accColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (groupBalance >= 0 ? _C.success : _C.danger).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: (groupBalance >= 0 ? _C.success : _C.danger).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${groupBalance >= 0 ? '+' : ''}${groupBalance.toStringAsFixed(3)} د.ك',
                    style: TextStyle(
                      color: groupBalance >= 0 ? _C.success : _C.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── صف معاملة واحدة ──────────────────────────────────────────
  Widget _buildTransactionRow(Map<String, dynamic> d, Color groupColor) {
    final type = d['type'] as String? ?? 'expense';
    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
    final description = d['description'] as String? ?? '';
    final category = d['category'] as String? ?? '';
    final paymentMethod = d['paymentMethod'] as String?;
    final ledgerAccount = d['ledgerAccount'] as String?;
    final createdAtStr = d['createdAt'] as String?;
    DateTime? date;
    if (createdAtStr != null) {
      date = DateTime.tryParse(createdAtStr);
    }
    final dateStr = date != null ? DateFormat('yyyy/MM/dd HH:mm').format(date) : '';

    IconData icon;
    Color color;
    double balanceChange;

    switch (type) {
      case 'income':
        icon = Icons.arrow_downward;
        color = _C.success;
        balanceChange = amount;
        break;
      case 'expense':
        icon = Icons.arrow_upward;
        color = _C.danger;
        balanceChange = -amount;
        break;
      case 'purchase':
        icon = Icons.shopping_cart;
        color = _C.warning;
        balanceChange = -amount;
        break;
      case 'sales_return':
        icon = Icons.undo;
        color = Colors.deepOrange;
        balanceChange = -amount;
        break;
      case 'purchase_return':
        icon = Icons.redo;
        color = _C.accent;
        balanceChange = amount;
        break;
      case 'commission':
        icon = Icons.handshake;
        color = Colors.amber;
        balanceChange = -amount;
        break;
      default:
        icon = Icons.swap_horiz;
        color = _C.textM;
        balanceChange = 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // أيقونة النوع
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          // الوصف + الفئة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isNotEmpty ? description : 'حركة مالية',
                  style: const TextStyle(color: _C.textP, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(dateStr, style: TextStyle(color: _C.textM.withOpacity(0.7), fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(_translateCategory(category), style: TextStyle(color: _C.textM, fontSize: 14)),
                    if (paymentMethod != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _paymentColor(paymentMethod).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_paymentIcon(paymentMethod), color: _paymentColor(paymentMethod), size: 11),
                            const SizedBox(width: 2),
                            Text(_paymentAr(paymentMethod), style: TextStyle(color: _paymentColor(paymentMethod), fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // المبلغ
          Text(
            '${balanceChange >= 0 ? '+' : ''}${amount.toStringAsFixed(3)} د.ك',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _translateCategory(String cat) {
    const map = {
      'salary': 'رواتب', 'rent': 'إيجار', 'hospitality': 'ضيافة',
      'petty_cash': 'نثريات', 'delivery': 'توصيل', 'materials': 'مواد',
      'utilities': 'فواتير', 'sale': 'مبيعات', 'مبيعات': 'مبيعات',
      'مشتريات': 'مشتريات', 'مردود مبيعات': 'مردود مبيعات',
      'مردود مشتريات': 'مردود مشتريات', 'سند صرف': 'سند صرف',
      'سند قبض': 'سند قبض', 'other': 'أخرى',
    };
    return map[cat] ?? cat;
  }
}
