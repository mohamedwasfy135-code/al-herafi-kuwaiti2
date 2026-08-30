import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/cross_platform_utils.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
// صفحة السندات – Bonds / Receipts / Journal Entries
// أنواع السندات: سند صرف / سند قبض / سند قيد (تحويل بين الحسابات)
// ✅ ماي فاتوره كطريقة دفع + إرسال رابط واتساب
// ✅ تفعيل حسابات المصروفات في السندات
// ✅ سند قيد لتحويل الكاش/كي نت/ماي فاتوره إلى البنك
// ═══════════════════════════════════════════════════════════════

class BusinessBonds extends StatefulWidget {
  final String uid;
  final String? initialType; // 'payment' | 'receipt' | 'journal'
  const BusinessBonds({super.key, required this.uid, this.initialType});

  @override
  State<BusinessBonds> createState() => _BusinessBondsState();
}

class _BusinessBondsState extends State<BusinessBonds> {
  // ─── المتغيرات ──────────────────────────────────────────────
  String _bondType = 'payment'; // payment | receipt | journal
  bool _typeLocked = false;
  String _paymentMethod = 'cash'; // cash | knet | bank | myinvoice
  final _amountController = TextEditingController();
  final _personNameController = TextEditingController();
  final _personPhoneController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _expenseAccounts = [];
  List<Map<String, dynamic>> _accounts = []; // ledger accounts for toolbar
  String? _selectedPersonId;
  String _selectedPersonType = ''; // client | supplier | expense
  bool _saving = false;
  bool _loadingPeople = true;

  // سجل السندات
  List<Map<String, dynamic>> _bonds = [];
  bool _loadingBonds = true;
  int _bondsPage = 0;
  bool _hasMoreBonds = true;
  bool _loadingMoreBonds = false;
  String _bondFilterType = 'all'; // all | payment | receipt | journal

  // ─── متغيرات سند القيد ────────────────────────────────────
  String _journalFromAccount = 'الصندوق'; // الحساب المحول منه
  String _journalToAccount = 'البنك';     // الحساب المحول إليه

  // الحسابات المتاحة للتحويل
  static const _ledgerAccounts = ['البنك', 'كي نت', 'الصندوق', 'ماي فاتوره'];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _bondType = widget.initialType!;
      _typeLocked = true;
      _bondFilterType = widget.initialType == 'journal' ? 'all' : widget.initialType!;
    }
    _loadPeople();
    _loadBonds();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _personNameController.dispose();
    _personPhoneController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── تحميل العملاء والموردين والحسابات ─────────────────────
  Future<void> _loadPeople() async {
    try {
      final clientsRes = await ApiService.get('/api/clients', queryParameters: {'businessId': widget.uid});
      final suppliersRes = await ApiService.get('/api/suppliers', queryParameters: {'businessId': widget.uid});
      final expenseRes = await ApiService.get('/api/accounts', queryParameters: {'businessId': widget.uid, 'type': 'expense'});

      if (mounted) {
        setState(() {
          if (clientsRes.success && clientsRes.data != null) {
            final list = clientsRes.data!['clients'] ?? clientsRes.data!['data'];
            if (list is List) _clients = list.cast<Map<String, dynamic>>();
          }
          if (suppliersRes.success && suppliersRes.data != null) {
            final list = suppliersRes.data!['suppliers'] ?? suppliersRes.data!['data'];
            if (list is List) _suppliers = list.cast<Map<String, dynamic>>();
          }
          if (expenseRes.success && expenseRes.data != null) {
            final list = expenseRes.data!['accounts'] ?? expenseRes.data!['data'];
            if (list is List) _expenseAccounts = list.cast<Map<String, dynamic>>();
          }
          _loadingPeople = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  // ─── تحميل حسابات دفتر الأستاذ (لشريط الأدوات) ──────────────
  Future<void> _loadAccounts() async {
    try {
      final res = await ApiService.get('/api/accounts', queryParameters: {'businessId': widget.uid});
      if (res.success && res.data != null) {
        final list = res.data!['accounts'] ?? res.data!['data'];
        if (list is List && mounted) {
          setState(() => _accounts = list.cast<Map<String, dynamic>>());
        }
      }
    } catch (_) {}
  }

  // ─── تحميل السندات ──────────────────────────────────────────
  Future<void> _loadBonds() async {
    try {
      final res = await ApiService.get('/api/bonds', queryParameters: {'businessId': widget.uid, 'limit': 50});

      List<Map<String, dynamic>> bondsList = [];
      if (res.success && res.data != null) {
        final list = res.data!['bonds'] ?? res.data!['data'];
        if (list is List) bondsList = list.cast<Map<String, dynamic>>();
      }

      // Sort by date (newest first)
      bondsList.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });

      _bonds = bondsList;
      _bondsPage = 1;
      _hasMoreBonds = bondsList.length >= 50;
    } catch (e) {
      debugPrint('Error loading bonds: $e');
    } finally {
      if (mounted) setState(() => _loadingBonds = false);
    }
  }

  Future<void> _loadMoreBonds() async {
    if (!_hasMoreBonds || _loadingMoreBonds) return;
    setState(() => _loadingMoreBonds = true);
    try {
      final res = await ApiService.get('/api/bonds', queryParameters: {
        'businessId': widget.uid,
        'limit': 50,
        'page': _bondsPage + 1,
      });

      List<Map<String, dynamic>> moreBonds = [];
      if (res.success && res.data != null) {
        final list = res.data!['bonds'] ?? res.data!['data'];
        if (list is List) moreBonds = list.cast<Map<String, dynamic>>();
      }

      moreBonds.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });

      final existingIds = _bonds.map((b) => b['id']).toSet();
      final newBonds = moreBonds.where((b) => !existingIds.contains(b['id'])).toList();

      if (mounted) {
        setState(() {
          _bonds.addAll(newBonds);
          _bondsPage++;
          _hasMoreBonds = moreBonds.length >= 50;
          _loadingMoreBonds = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more bonds: $e');
      if (mounted) setState(() => _loadingMoreBonds = false);
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> get _filteredBonds {
    var list = _bonds;

    if (_bondFilterType != 'all') {
      list = list.where((b) => b['type'] == _bondFilterType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((b) {
        final person = (b['personName'] as String? ?? '').toLowerCase();
        final reason = (b['reason'] as String? ?? '').toLowerCase();
        return person.contains(_searchQuery) || reason.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  // ═══════════════════════════════════════════════════════════════
  // حفظ السند
  // ═══════════════════════════════════════════════════════════════
  Future<void> _saveBond() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final personName = _personNameController.text.trim();
    final reason = _reasonController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغ صحيح'), backgroundColor: _C.warning),
      );
      return;
    }

    // ─── سند قيد: تحويل بين حسابات ────────────────────────────
    if (_bondType == 'journal') {
      if (_journalFromAccount == _journalToAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن التحويل من وإلى نفس الحساب'), backgroundColor: _C.warning),
        );
        return;
      }
      await _saveJournalEntry(amount, reason);
      return;
    }

    if (personName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الشخص/الجهة'), backgroundColor: _C.warning),
      );
      return;
    }

    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    setState(() {
      _saving = true;
      _paymentMethod = paymentMethod;
    });

    try {
      final now = DateTime.now().toIso8601String();

      final String ledgerAccount = _getLedgerAccount(_paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(_paymentMethod);

      final bondRes = await ApiService.post('/api/bonds', body: {
        'businessId': widget.uid,
        'type': _bondType,
        'amount': amount,
        'personId': _selectedPersonId,
        'personType': _selectedPersonType,
        'personName': personName,
        'personPhone': _personPhoneController.text.trim(),
        'reason': reason,
        'notes': _notesController.text.trim(),
        'paymentMethod': _paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now,
      });

      final bondId = bondRes.data?['id'] ?? '';

      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': _bondType == 'payment' ? 'expense' : 'income',
        'amount': amount,
        'category': _bondType == 'payment' ? 'سند صرف' : 'سند قبض',
        'description': _bondType == 'payment'
            ? 'سند صرف - $personName - $paymentMethodAr'
            : 'سند قبض - $personName - $paymentMethodAr',
        'bondId': bondId,
        'paymentMethod': _paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now,
      });

      await _updateLedgerAccount(ledgerAccount, _bondType == 'receipt' ? amount : -amount, now, bondId);

      // تحديث رصيد العميل/المورد
      if (_selectedPersonId != null) {
        final field = _bondType == 'payment' ? 'totalPayments' : 'totalReceipts';
        if (_selectedPersonType == 'client') {
          await ApiService.put('/api/clients/$_selectedPersonId', body: {
            field: amount,
            'lastTransactionAt': now,
          });
        } else if (_selectedPersonType == 'supplier') {
          await ApiService.put('/api/suppliers/$_selectedPersonId', body: {
            field: amount,
            'lastTransactionAt': now,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_bondType == 'payment' ? 'تم حفظ سند الصرف بنجاح' : 'تم حفظ سند القبض بنجاح'),
            backgroundColor: _C.success,
          ),
        );
        _resetForm();
        _loadBonds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: _C.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── حفظ سند القيد (تحويل بين حسابات) ─────────────────────
  Future<void> _saveJournalEntry(double amount, String reason) async {
    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();

      final description = reason.isNotEmpty
          ? reason
          : 'تحويل من $_journalFromAccount إلى $_journalToAccount';

      // حفظ سند القيد
      final bondRes = await ApiService.post('/api/bonds', body: {
        'businessId': widget.uid,
        'type': 'journal',
        'amount': amount,
        'personName': 'سند قيد',
        'reason': description,
        'notes': _notesController.text.trim(),
        'fromAccount': _journalFromAccount,
        'toAccount': _journalToAccount,
        'createdAt': now,
      });

      final bondId = bondRes.data?['id'] ?? '';

      // خصم من الحساب المحول منه
      await _updateLedgerAccount(_journalFromAccount, -amount, now, bondId, refType: 'سند قيد - خصم');

      // إضافة إلى الحساب المحول إليه
      await _updateLedgerAccount(_journalToAccount, amount, now, bondId, refType: 'سند قيد - إضافة');

      // إنشاء حركتين ماليتين للتوثيق
      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': 'expense',
        'amount': amount,
        'category': 'سند قيد',
        'description': 'سند قيد - تحويل من $_journalFromAccount - $description',
        'bondId': bondId,
        'paymentMethod': 'journal',
        'ledgerAccount': _journalFromAccount,
        'createdAt': now,
      });

      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': 'income',
        'amount': amount,
        'category': 'سند قيد',
        'description': 'سند قيد - إيداع في $_journalToAccount - $description',
        'bondId': bondId,
        'paymentMethod': 'journal',
        'ledgerAccount': _journalToAccount,
        'createdAt': now,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحويل ${amount.toStringAsFixed(3)} د.ك من $_journalFromAccount إلى $_journalToAccount'),
            backgroundColor: _C.success,
          ),
        );
        _resetForm();
        _loadBonds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: _C.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── إرسال رابط دفع ماي فاتوره عبر واتساب ──────────────────
  Future<void> _sendWhatsAppPaymentLink(String phone, double amount, String invoiceNum) async {
    // تنظيف رقم الهاتف
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '965${cleanPhone.substring(1)}'; // رمز الكويت
    } else if (!cleanPhone.startsWith('+') && !cleanPhone.startsWith('965')) {
      cleanPhone = '965$cleanPhone';
    }
    if (cleanPhone.startsWith('+')) cleanPhone = cleanPhone.substring(1);

    final message = 'مرحباً، يرجى سداد المبلغ ${amount.toStringAsFixed(3)} د.ك للفاتورة #$invoiceNum عبر رابط الدفع الآمن.\n\n'
        'شكراً لتعاملكم معنا.';

    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    await CrossPlatformUtils.openUrl(url);
  }

  void _resetForm() {
    setState(() {
      _amountController.clear();
      _personNameController.clear();
      _personPhoneController.clear();
      _reasonController.clear();
      _notesController.clear();
      _selectedPersonId = null;
      _selectedPersonType = '';
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // البناء
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isJournal = _bondType == 'journal';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: isJournal
                  ? _buildJournalForm()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildFormColumn()),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _buildBondsListColumn()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── شريط الأدوات ──────────────────────────────────────────
  Widget _buildToolbar() {
    String title;
    IconData titleIcon;
    switch (_bondType) {
      case 'journal':
        title = 'سند قيد - تحويل بين الحسابات';
        titleIcon = Icons.swap_horiz;
        break;
      case 'receipt':
        title = 'سند قبض';
        titleIcon = Icons.arrow_downward;
        break;
      default:
        title = 'سند صرف';
        titleIcon = Icons.arrow_upward;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Icon(titleIcon, color: _bondTypeColor, size: 16),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: _C.textP, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          // أرصدة الحسابات السريعة
          if (_accounts.isNotEmpty)
            Row(
              children: _accounts.map((data) {
                final name = data['accountName'] as String? ?? data['id'] ?? '';
                final balance = (data['balance'] as num?)?.toDouble() ?? 0;
                final color = _getAccountColor(name);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getAccountIcon(name), color: color, size: 11),
                        const SizedBox(width: 4),
                        Text('${balance.toStringAsFixed(3)}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color get _bondTypeColor {
    switch (_bondType) {
      case 'payment': return _C.danger;
      case 'receipt': return _C.success;
      case 'journal': return _C.accent;
      default: return _C.accent;
    }
  }

  IconData _getAccountIcon(String name) {
    if (name == 'الصندوق') return Icons.payments;
    if (name == 'كي نت') return Icons.credit_card;
    if (name == 'البنك') return Icons.account_balance;
    if (name == 'ماي فاتوره') return Icons.receipt_long;
    return Icons.folder;
  }

  Color _getAccountColor(String name) {
    if (name == 'الصندوق') return _C.success;
    if (name == 'كي نت') return _C.accent;
    if (name == 'البنك') return Colors.purple;
    if (name == 'ماي فاتوره') return _C.warning;
    return Colors.amber;
  }

  // ─── نموذج سند القيد (تحويل بين حسابات) ────────────────────
  Widget _buildJournalForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _C.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz, color: _C.accent, size: 14),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سند قيد', style: TextStyle(color: _C.accent, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('تحويل مبالغ بين الحسابات لضمان عملية محاسبية تامة', style: TextStyle(color: _C.textS, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // الحساب المحول منه
            const Text('من حساب:', style: TextStyle(color: _C.textS, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildAccountDropdown(
              value: _journalFromAccount,
              onChanged: (v) => setState(() => _journalFromAccount = v!),
              excludeAccount: _journalToAccount,
            ),
            const SizedBox(height: 16),

            // أيقونة التحويل
            Center(
              child: Container(
                width: 44, height: 36,
                decoration: BoxDecoration(
                  color: _C.accentLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.accent.withOpacity(0.3)),
                ),
                child: const Icon(Icons.south, color: _C.accent, size: 14),
              ),
            ),
            const SizedBox(height: 16),

            // الحساب المحول إليه
            const Text('إلى حساب:', style: TextStyle(color: _C.textS, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildAccountDropdown(
              value: _journalToAccount,
              onChanged: (v) => setState(() => _journalToAccount = v!),
              excludeAccount: _journalFromAccount,
            ),
            const SizedBox(height: 16),

            // المبلغ
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: _C.accent, fontSize: 26, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'المبلغ المحول',
                labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                suffixText: 'د.ك',
                suffixStyle: const TextStyle(color: _C.textM, fontSize: 13),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
            ),
            const SizedBox(height: 12),

            // السبب
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: _C.textP, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'السبب (اختياري)',
                labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                hintText: 'مثال: إيداع مبيعات الكاش في البنك',
                hintStyle: const TextStyle(color: _C.textM, fontSize: 12),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),

            // ملاحظات
            TextField(
              controller: _notesController,
              style: const TextStyle(color: _C.textP, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'ملاحظات (اختياري)...',
                hintStyle: const TextStyle(color: _C.textM, fontSize: 13),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 20),

            // ملخص التحويل
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.accentLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.accent.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAccountBadge(_journalFromAccount),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, color: _C.accent, size: 16),
                      const SizedBox(width: 12),
                      _buildAccountBadge(_journalToAccount),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'تحويل ${_amountController.text.isEmpty ? '0.000' : double.tryParse(_amountController.text)?.toStringAsFixed(3) ?? '0.000'} د.ك',
                    style: const TextStyle(color: _C.accent, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveBond,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.swap_horiz, size: 16),
                        SizedBox(width: 8),
                        Text('تنفيذ التحويل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
              ),
            ),

            const SizedBox(height: 20),

            // سجل التحويلات الأخيرة
            _buildRecentJournalEntries(),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
    String? excludeAccount,
  }) {
    final accounts = _ledgerAccounts.where((a) => a != excludeAccount).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _C.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: DropdownButton<String>(
        value: accounts.contains(value) ? value : accounts.first,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.arrow_drop_down, color: _C.textS, size: 14),
        style: const TextStyle(color: _C.textP, fontSize: 13),
        dropdownColor: _C.card,
        items: accounts.map((account) {
          final color = _getAccountColor(account);
          return DropdownMenuItem<String>(
            value: account,
            child: Row(
              children: [
                Icon(_getAccountIcon(account), color: color, size: 15),
                const SizedBox(width: 8),
                Text(account, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccountBadge(String accountName) {
    final color = _getAccountColor(accountName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getAccountIcon(accountName), color: color, size: 13),
          const SizedBox(width: 6),
          Text(accountName, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── سجل التحويلات الأخيرة ────────────────────────────────
  Widget _buildRecentJournalEntries() {
    final journalBonds = _bonds.where((b) => b['type'] == 'journal').toList();

    if (journalBonds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('لا توجد تحويلات سابقة', style: TextStyle(color: _C.textM, fontSize: 12)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('آخر التحويلات:', style: TextStyle(color: _C.textS, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ...journalBonds.take(5).map((bond) {
          final amount = (bond['amount'] as num?)?.toDouble() ?? 0;
          final from = bond['fromAccount'] as String? ?? '';
          final to = bond['toAccount'] as String? ?? '';
          final createdAtStr = bond['createdAt'] as String?;
          final dateStr = createdAtStr != null ? _formatDateString(createdAtStr) : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _C.border.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, color: _C.accent.withOpacity(0.6), size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$from ← $to: ${amount.toStringAsFixed(3)} د.ك',
                    style: const TextStyle(color: _C.textS, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(dateStr, style: const TextStyle(color: _C.textM, fontSize: 14)),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── نموذج إنشاء السند (صرف/قبض) ───────────────────────────
  Widget _buildFormColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: _bondTypeColor, size: 15),
                const SizedBox(width: 8),
                Text('سند جديد', style: TextStyle(color: _bondTypeColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),

            // نوع السند
            if (!_typeLocked)
              Wrap(
                spacing: 6,
                children: [
                  _bondTypeChip('سند صرف', 'payment', Icons.arrow_upward, _C.danger),
                  _bondTypeChip('سند قبض', 'receipt', Icons.arrow_downward, _C.success),
                  _bondTypeChip('سند قيد', 'journal', Icons.swap_horiz, _C.accent),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _bondTypeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _bondTypeColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _bondType == 'payment' ? Icons.arrow_upward : _bondType == 'receipt' ? Icons.arrow_downward : Icons.swap_horiz,
                      color: _bondTypeColor, size: 15,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _bondType == 'payment' ? 'سند صرف' : _bondType == 'receipt' ? 'سند قبض' : 'سند قيد',
                      style: TextStyle(color: _bondTypeColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // المبلغ
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: _C.accent, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'المبلغ',
                labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                suffixText: 'د.ك',
                suffixStyle: const TextStyle(color: _C.textM, fontSize: 13),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // اسم الشخص / الجهة
            TextField(
              controller: _personNameController,
              style: const TextStyle(color: _C.textP, fontSize: 13),
              decoration: InputDecoration(
                labelText: _bondType == 'payment' ? 'المدفوع له' : 'الدافع',
                labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                prefixIcon: Icon(
                  _bondType == 'payment' ? Icons.person_outline : Icons.person,
                  color: _C.textS, size: 15,
                ),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                if (_selectedPersonId != null) {
                  setState(() { _selectedPersonId = null; _selectedPersonType = ''; });
                }
              },
            ),
            const SizedBox(height: 8),

            // رقم الهاتف
            TextField(
              controller: _personPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: _C.textP, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                prefixIcon: const Icon(Icons.phone, color: _C.textS, size: 15),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),

            // اختيار من العملاء/الموردين/حسابات المصروفات
            if (_loadingPeople)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _C.accent))
            else if (_clients.isNotEmpty || _suppliers.isNotEmpty || _expenseAccounts.isNotEmpty)
              _buildPersonPicker(),

            const SizedBox(height: 12),

            // السبب
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: _C.textP, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'السبب / الوصف',
                labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),

            // ملاحظات
            TextField(
              controller: _notesController,
              style: const TextStyle(color: _C.textP, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'ملاحظات (اختياري)...',
                hintStyle: const TextStyle(color: _C.textM, fontSize: 13),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),

            const SizedBox(height: 16),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveBond,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bondTypeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_bondType == 'payment' ? Icons.arrow_upward : _bondType == 'receipt' ? Icons.arrow_downward : Icons.swap_horiz, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          _bondType == 'payment' ? 'حفظ سند الصرف' : _bondType == 'receipt' ? 'حفظ سند القبض' : 'تنفيذ التحويل',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bondTypeChip(String label, String type, IconData icon, Color color) {
    final active = _bondType == type;
    return GestureDetector(
      onTap: () => setState(() => _bondType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : _C.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color.withOpacity(0.5) : _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? color : _C.textM, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: active ? color : _C.textM, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── اختيار شخص من العملاء/الموردين/حسابات المصروفات ──────
  Widget _buildPersonPicker() {
    // جمع جميع الأشخاص والحسابات
    final allPeople = <Map<String, dynamic>>[];

    // العملاء
    for (final c in _clients) {
      allPeople.add({...c, '_type': 'client'});
    }
    // الموردين
    for (final s in _suppliers) {
      allPeople.add({...s, '_type': 'supplier'});
    }
    // حسابات المصروفات (مفعّلة)
    for (final e in _expenseAccounts) {
      allPeople.add({...e, '_type': 'expense', 'name': e['name'] ?? 'حساب مصروفات', 'phone': ''});
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('اختر من العملاء / الموردين / الحسابات:', style: TextStyle(color: _C.textS, fontSize: 12)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allPeople.length,
              itemBuilder: (_, i) {
                final person = allPeople[i];
                final personType = person['_type'] as String;
                final isSelected = _selectedPersonId == person['id'] && _selectedPersonType == personType;
                final Color typeColor;
                final IconData typeIcon;

                switch (personType) {
                  case 'client':
                    typeColor = _C.accent;
                    typeIcon = Icons.person;
                    break;
                  case 'supplier':
                    typeColor = Colors.teal;
                    typeIcon = Icons.store;
                    break;
                  case 'expense':
                    typeColor = _C.warning;
                    typeIcon = Icons.folder;
                    break;
                  default:
                    typeColor = _C.textM;
                    typeIcon = Icons.person;
                }

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(typeIcon, color: isSelected ? _C.accent : typeColor, size: 16),
                  title: Row(
                    children: [
                      Text(person['name'] ?? '', style: TextStyle(color: isSelected ? _C.accent : _C.textS, fontSize: 12)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          personType == 'client' ? 'عميل' : personType == 'supplier' ? 'مورد' : 'مصروف',
                          style: TextStyle(color: typeColor, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onTap: () => setState(() {
                    _selectedPersonId = person['id'];
                    _selectedPersonType = personType;
                    _personNameController.text = person['name'] ?? '';
                    _personPhoneController.text = person['phone'] ?? '';
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── سجل السندات ───────────────────────────────────────────
  Widget _buildBondsListColumn() {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          // شريط البحث والفلتر
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(Icons.history, color: _C.accent, size: 14),
                const SizedBox(width: 6),
                const Text('سجل السندات', style: TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                _filterChip('الكل', 'all'),
                const SizedBox(width: 3),
                _filterChip('صرف', 'payment'),
                const SizedBox(width: 3),
                _filterChip('قبض', 'receipt'),
                const SizedBox(width: 3),
                _filterChip('قيد', 'journal'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: _C.textP, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'بحث في السندات...',
                hintStyle: const TextStyle(color: _C.textM, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: _C.textM, size: 16),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loadingBonds
                ? const Center(child: CircularProgressIndicator(color: _C.accent))
                : _filteredBonds.isEmpty
                    ? Center(child: Text('لا توجد سندات', style: TextStyle(color: _C.textM, fontSize: 18)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _filteredBonds.length + 1,
                        itemBuilder: (_, i) {
                          if (i == _filteredBonds.length) {
                            return _loadingMoreBonds
                                ? const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: _C.accent)))
                                : _hasMoreBonds
                                    ? TextButton(onPressed: _loadMoreBonds, child: const Text('تحميل المزيد', style: TextStyle(color: _C.accent, fontSize: 13)))
                                    : const SizedBox.shrink();
                          }
                          return _buildBondCard(_filteredBonds[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _bondFilterType == value;
    Color color;
    if (value == 'payment') color = _C.danger;
    else if (value == 'receipt') color = _C.success;
    else if (value == 'journal') color = _C.accent;
    else color = _C.accent;

    return GestureDetector(
      onTap: () => setState(() => _bondFilterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : _C.inputFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color.withOpacity(0.4) : _C.border),
        ),
        child: Text(label, style: TextStyle(color: active ? color : _C.textM, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBondCard(Map<String, dynamic> bond) {
    final amount = (bond['amount'] as num?)?.toDouble() ?? 0;
    final personName = bond['personName'] as String? ?? '';
    final reason = bond['reason'] as String? ?? '';
    final bondType = bond['type'] as String? ?? 'payment';
    final createdAtStr = bond['createdAt'] as String?;
    final dateStr = createdAtStr != null ? _formatDateString(createdAtStr) : '';
    final isJournal = bondType == 'journal';
    final isPayment = bondType == 'payment';
    final Color typeColor = isJournal ? _C.accent : (isPayment ? _C.danger : _C.success);
    final IconData typeIcon = isJournal ? Icons.swap_horiz : (isPayment ? Icons.arrow_upward : Icons.arrow_downward);
    final String typeLabel = isJournal ? 'سند قيد' : (isPayment ? 'سند صرف' : 'سند قبض');

    // تفاصيل سند القيد
    final fromAccount = bond['fromAccount'] as String? ?? '';
    final toAccount = bond['toAccount'] as String? ?? '';
    final paymentMethod = bond['paymentMethod'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: isPayment
              ? BorderSide(color: typeColor, width: 3)
              : BorderSide.none,
          left: !isPayment
              ? BorderSide(color: typeColor, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, color: typeColor, size: 16),
              const SizedBox(width: 6),
              Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600)),
              if (paymentMethod.isNotEmpty && !isJournal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getPaymentColor(paymentMethod).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    _getPaymentMethodAr(paymentMethod),
                    style: TextStyle(color: _getPaymentColor(paymentMethod), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${amount.toStringAsFixed(3)} د.ك',
                style: TextStyle(color: typeColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (isJournal && fromAccount.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.swap_horiz, color: _C.accent.withOpacity(0.5), size: 13),
                const SizedBox(width: 4),
                Text('$fromAccount ← $toAccount', style: const TextStyle(color: _C.textS, fontSize: 12)),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, color: _C.textM, size: 13),
                const SizedBox(width: 4),
                Text(personName, style: const TextStyle(color: _C.textS, fontSize: 12)),
              ],
            ),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(reason, style: const TextStyle(color: _C.textM, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 2),
          Text(dateStr, style: const TextStyle(color: _C.textM, fontSize: 14)),
        ],
      ),
    );
  }

  Color _getPaymentColor(String method) {
    switch (method) {
      case 'cash': return _C.success;
      case 'knet': return _C.accent;
      case 'bank': return Colors.purple;
      case 'myinvoice': return _C.warning;
      default: return _C.textM;
    }
  }

  String _formatDateString(String timestamp) {
    final d = DateTime.tryParse(timestamp);
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ─── دالة تحديد حساب دفتر الأستاذ ────────────────────────────
  String _getLedgerAccount(String paymentMethod) {
    switch (paymentMethod) {
      case 'cash':      return 'الصندوق';
      case 'knet':      return 'كي نت';
      case 'bank':      return 'البنك';
      case 'myinvoice': return 'ماي فاتوره';
      default:          return 'الصندوق';
    }
  }

  String _getPaymentMethodAr(String method) {
    switch (method) {
      case 'cash':      return 'كاش';
      case 'knet':      return 'كي نت';
      case 'bank':      return 'تحويل بنكي';
      case 'myinvoice': return 'ماي فاتوره';
      case 'journal':   return 'سند قيد';
      default:          return 'كاش';
    }
  }

  // ─── تحديث رصيد حساب دفتر الأستاذ ────────────────────────────
  Future<void> _updateLedgerAccount(String accountName, double amount, String timestamp, String refId, {String? refType}) async {
    await ApiService.post('/api/accounts', body: {
      'businessId': widget.uid,
      'accountName': accountName,
      'amount': amount,
      'type': amount >= 0 ? 'debit' : 'credit',
      'refId': refId,
      'refType': refType ?? (_bondType == 'payment' ? 'سند صرف' : 'سند قبض'),
      'description': _reasonController.text.trim(),
      'createdAt': timestamp,
    });
  }

  // ─── نافذة اختيار طريقة الدفع ─────────────────────────────────
  Future<String?> _showPaymentMethodDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.payment, color: _C.accent, size: 22),
            const SizedBox(width: 10),
            Text(
              _bondType == 'payment' ? 'طريقة الدفع - سند صرف' : 'طريقة القبض - سند قبض',
              style: const TextStyle(color: _C.accent, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر طريقة الدفع:', style: TextStyle(color: _C.textS, fontSize: 13)),
            const SizedBox(height: 14),
            // صف أول: كاش + كي نت
            Row(
              children: [
                _paymentMethodButton(ctx, 'كاش', 'cash', Icons.payments, _C.success),
                const SizedBox(width: 6),
                _paymentMethodButton(ctx, 'كي نت', 'knet', Icons.credit_card, _C.accent),
              ],
            ),
            const SizedBox(height: 8),
            // صف ثاني: بنك + ماي فاتوره
            Row(
              children: [
                _paymentMethodButton(ctx, 'بنك', 'bank', Icons.account_balance, Colors.purple),
                const SizedBox(width: 6),
                _paymentMethodButton(ctx, 'ماي فاتوره', 'myinvoice', Icons.receipt_long, _C.warning),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('إلغاء', style: TextStyle(color: _C.textS)),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodButton(BuildContext ctx, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => Navigator.pop(ctx, value),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
