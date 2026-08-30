import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة السندات – Bonds / Receipts
// أنواع السندات: سند صرف (صرف نقدي) / سند قبض (استلام نقدي)
// ═══════════════════════════════════════════════════════════════

class BusinessBonds extends StatefulWidget {
  final String uid;
  final String? initialType; // 'payment' أو 'receipt'
  const BusinessBonds({super.key, required this.uid, this.initialType});

  @override
  State<BusinessBonds> createState() => _BusinessBondsState();
}

class _BusinessBondsState extends State<BusinessBonds> {
  // ─── المتغيرات ──────────────────────────────────────────────
  String _bondType = 'payment'; // payment = سند صرف | receipt = سند قبض
  bool _typeLocked = false; // إذا تم تحديد النوع من الخارج لا يمكن تغييره
  String _paymentMethod = 'cash'; // cash | knet | bank
  final _amountController = TextEditingController();
  final _personNameController = TextEditingController();
  final _personPhoneController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _suppliers = [];
  String? _selectedPersonId;
  String _selectedPersonType = ''; // client | supplier
  bool _saving = false;
  bool _loadingPeople = true;

  // سجل السندات
  List<Map<String, dynamic>> _bonds = [];
  bool _loadingBonds = true;
  String? _lastBondId;
  bool _loadingMoreBonds = false;
  String _bondFilterType = 'all'; // all | payment | receipt

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _bondType = widget.initialType!;
      _typeLocked = true;
      _bondFilterType = widget.initialType!;
    }
    _loadPeople();
    _loadBonds();
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

  // ─── تحميل العملاء والموردين ────────────────────────────────
  Future<void> _loadPeople() async {
    try {
      final results = await Future.wait([
        ApiService.get('/api/clients', queryParameters: {'businessId': widget.uid}),
        ApiService.get('/api/suppliers', queryParameters: {'businessId': widget.uid}),
      ]);

      if (mounted) {
        List<Map<String, dynamic>> clients = [];
        List<Map<String, dynamic>> suppliers = [];
        
        if (results[0].success && results[0].data != null) {
          final list = results[0].data!['clients'] ?? results[0].data!['data'] ?? [];
          if (list is List) clients = list.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            if (m['id'] == null) m['id'] = '';
            return m;
          }).toList();
        }
        
        if (results[1].success && results[1].data != null) {
          final list = results[1].data!['suppliers'] ?? results[1].data!['data'] ?? [];
          if (list is List) suppliers = list.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            if (m['id'] == null) m['id'] = '';
            return m;
          }).toList();
        }

        setState(() {
          _clients = clients;
          _suppliers = suppliers;
          _loadingPeople = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  // ─── تحميل السندات ──────────────────────────────────────────
  Future<void> _loadBonds() async {
    try {
      final res = await ApiService.get('/api/bonds', queryParameters: {
        'businessId': widget.uid,
        'limit': '20',
      });
      if (res.success && res.data != null) {
        final list = res.data!['bonds'] ?? res.data!['data'] ?? [];
        if (list is List) {
          _bonds = list.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            if (m['id'] == null) m['id'] = '';
            return m;
          }).toList();
          _lastBondId = _bonds.isNotEmpty ? _bonds.last['id']?.toString() : null;
        }
      }
    } catch (e) {
      debugPrint('Error loading bonds: $e');
    } finally {
      if (mounted) setState(() => _loadingBonds = false);
    }
  }

  Future<void> _loadMoreBonds() async {
    if (_lastBondId == null || _loadingMoreBonds) return;
    setState(() => _loadingMoreBonds = true);
    try {
      final res = await ApiService.get('/api/bonds', queryParameters: {
        'businessId': widget.uid,
        'afterId': _lastBondId ?? '',
        'limit': '20',
      });
      if (res.success && res.data != null) {
        final list = res.data!['bonds'] ?? res.data!['data'] ?? [];
        if (list is List) {
          final more = list.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            if (m['id'] == null) m['id'] = '';
            return m;
          }).toList();
          _bonds.addAll(more);
          _lastBondId = more.isNotEmpty ? more.last['id']?.toString() : null;
        }
      }
    } catch (e) {
      debugPrint('Error loading more bonds: $e');
    } finally {
      if (mounted) setState(() => _loadingMoreBonds = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBonds {
    var list = _bonds;

    // فلتر النوع
    if (_bondFilterType != 'all') {
      list = list.where((b) => b['type'] == _bondFilterType).toList();
    }

    // فلتر البحث
    if (_searchQuery.isNotEmpty) {
      list = list.where((b) {
        final person = (b['personName'] as String? ?? '').toLowerCase();
        final reason = (b['reason'] as String? ?? '').toLowerCase();
        return person.contains(_searchQuery) || reason.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  // ─── حفظ السند ──────────────────────────────────────────────
  Future<void> _saveBond() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final personName = _personNameController.text.trim();
    final reason = _reasonController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغ صحيح'), backgroundColor: Colors.orange)
      );
      return;
    }
    if (personName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الشخص/الجهة'), backgroundColor: Colors.orange)
      );
      return;
    }

    // سؤال عن طريقة الدفع
    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    setState(() {
      _saving = true;
      _paymentMethod = paymentMethod;
    });

    try {
      final now = DateTime.now().toIso8601String();
      final bondId = widget.db.collection('business_bonds').doc().id;

      // حساب دفتر الأستاذ حسب طريقة الدفع
      final String ledgerAccount = _getLedgerAccount(_paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(_paymentMethod);

      // حفظ السند
      await widget.db.collection('business_bonds').doc(bondId).set({
        'id': bondId,
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
        'createdAt': now
      });

      // إنشاء حركة مالية مرتبطة بدفتر الأستاذ
      await widget.db.collection('business_transactions').add({
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
        'createdAt': now
      });

      // ✅ تحديث دفتر الأستاذ (رصيد الحساب)
      await _updateLedgerAccount(ledgerAccount, _bondType == 'receipt' ? amount : -amount, now, bondId);

      // تحديث رصيد العميل/المورد
      if (_selectedPersonId != null) {
        if (_selectedPersonType == 'client') {
          await widget.db
              .collection('business_clients')
              .doc(widget.uid)
              .collection('items')
              .doc(_selectedPersonId)
              .update({
            _bondType == 'payment' ? 'totalPayments' : 'totalReceipts': FieldValue.increment(amount),
            'lastTransactionAt': now
          });
        } else if (_selectedPersonType == 'supplier') {
          await widget.db
              .collection('business_suppliers')
              .doc(widget.uid)
              .collection('items')
              .doc(_selectedPersonId)
              .update({
            _bondType == 'payment' ? 'totalPayments' : 'totalReceipts': FieldValue.increment(amount),
            'lastTransactionAt': now
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_bondType == 'payment' ? 'تم حفظ سند الصرف بنجاح' : 'تم حفظ سند القبض بنجاح'),
            backgroundColor: Colors.green,
          )
        );
        _resetForm();
        _loadBonds(); // تحديث السجل
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العمود الأيسر: إنشاء سند
              Expanded(flex: 2, child: _buildFormColumn()),
              const SizedBox(width: 12),
              // العمود الأيمن: سجل السندات
              Expanded(flex: 3, child: _buildBondsListColumn()),
            ],
          ),
        ),
      ]
    );
  }

  // ─── شريط الأدوات ──────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Color(0xFF0071E3), size: 22),
          const SizedBox(width: 8),
          const Text('السندات', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          // إحصائيات سريعة
          FutureBuilder<Map<String, dynamic>?>(
            future: _loadSummary(),
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final data = snap.data;
              if (data == null) return const SizedBox.shrink();
              final totalIncome = (data['totalIncome'] as num?)?.toDouble() ?? 0;
              final totalExpense = (data['totalExpense'] as num?)?.toDouble() ?? 0;
              return Row(
                children: [
                  _quickStat('قبض', totalIncome, Colors.green),
                  const SizedBox(width: 12),
                  _quickStat('صرف', totalExpense, Colors.redAccent),
                ]
              );
            },
          ),
        ],
      )
    );
  }

  Widget _quickStat(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${amount.toStringAsFixed(3)}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      )
    );
  }

  // ─── نموذج إنشاء السند ──────────────────────────────────────
  Widget _buildFormColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان
            const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF0071E3), size: 14),
                SizedBox(width: 8),
                Text('سند جديد', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),

            // نوع السند (مخفي إذا كان النوع مقفولاً)
            if (!_typeLocked)
              Row(
                children: [
                  _bondTypeChip('سند صرف', 'payment', Icons.arrow_upward, Colors.redAccent),
                  const SizedBox(width: 8),
                  _bondTypeChip('سند قبض', 'receipt', Icons.arrow_downward, Colors.green),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (_bondType == 'payment' ? Colors.redAccent : Colors.green).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (_bondType == 'payment' ? Colors.redAccent : Colors.green).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _bondType == 'payment' ? Icons.arrow_upward : Icons.arrow_downward,
                      color: _bondType == 'payment' ? Colors.redAccent : Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _bondType == 'payment' ? 'سند صرف' : 'سند قبض',
                      style: TextStyle(
                        color: _bondType == 'payment' ? Colors.redAccent : Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // المبلغ
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF0071E3), fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'المبلغ',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                suffixText: 'د.ك',
                suffixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // اسم الشخص / الجهة
            TextField(
              controller: _personNameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: _bondType == 'payment' ? 'المدفوع له' : 'الدافع',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: Icon(
                  _bondType == 'payment' ? Icons.person_outline : Icons.person,
                  color: Colors.white38, size: 14,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.phone, color: Colors.white38, size: 14),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),

            // اختيار من العملاء/الموردين
            if (_loadingPeople)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0071E3)))
            else if (_clients.isNotEmpty || _suppliers.isNotEmpty)
              _buildPersonPicker(),

            const SizedBox(height: 12),

            // السبب
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'السبب / الوصف',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),

            // ملاحظات
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'ملاحظات (اختياري)...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  backgroundColor: _bondType == 'payment' ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_bondType == 'payment' ? Icons.arrow_upward : Icons.arrow_downward, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _bondType == 'payment' ? 'حفظ سند الصرف' : 'حفظ سند القبض',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ]),
              ),
            ),
          ],
        ),
      )
    );
  }

  Widget _bondTypeChip(String label, String type, IconData icon, Color color) {
    final active = _bondType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bondType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? color : Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: active ? color : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      )
    );
  }

  // ─── اختيار شخص من العملاء/الموردين ────────────────────────
  Widget _buildPersonPicker() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bondType == 'payment' ? 'اختر من العملاء:' : 'اختر من الموردين:',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _bondType == 'payment' ? _clients.length : _suppliers.length,
              itemBuilder: (_, i) {
                final person = _bondType == 'payment' ? _clients[i] : _suppliers[i];
                final isSelected = _selectedPersonId == person['id'];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    _bondType == 'payment' ? Icons.person_outline : Icons.store,
                    color: isSelected ? const Color(0xFF0071E3) : Colors.white38,
                    size: 16,
                  ),
                  title: Text(person['name'] ?? '', style: TextStyle(color: isSelected ? const Color(0xFF0071E3) : Colors.white60, fontSize: 12)),
                  selected: isSelected,
                  onTap: () => setState(() {
                    _selectedPersonId = person['id'];
                    _selectedPersonType = _bondType == 'payment' ? 'client' : 'supplier';
                    _personNameController.text = person['name'] ?? '';
                    _personPhoneController.text = person['phone'] ?? '';
                  })
                );
              },
            ),
          ),
        ],
      )
    );
  }

  // ─── سجل السندات ───────────────────────────────────────────
  Widget _buildBondsListColumn() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // شريط البحث والفلتر
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF0071E3), size: 14),
                const SizedBox(width: 6),
                const Text('سجل السندات', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                // فلاتر
                _filterChip('الكل', 'all'),
                const SizedBox(width: 4),
                _filterChip('صرف', 'payment'),
                const SizedBox(width: 4),
                _filterChip('قبض', 'receipt'),
              ],
            ),
          ),
          // بحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'بحث في السندات...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 16),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // القائمة
          Expanded(
            child: _loadingBonds
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                : _filteredBonds.isEmpty
                    ? Center(child: Text('لا توجد سندات', style: TextStyle(color: Colors.white38, fontSize: 14)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _filteredBonds.length + 1,
                        itemBuilder: (_, i) {
                          if (i == _filteredBonds.length) {
                            return _loadingMoreBonds
                                ? const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: Color(0xFF0071E3))))
                                : _lastBondId != null
                                    ? TextButton(onPressed: _loadMoreBonds, child: const Text('تحميل المزيد', style: TextStyle(color: Color(0xFF0071E3), fontSize: 12)))
                                    : const SizedBox.shrink();
                          }
                          return _buildBondCard(_filteredBonds[i]);
                        },
                      ),
          ),
        ],
      )
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _bondFilterType == value;
    Color color;
    if (value == 'payment') color = Colors.redAccent;
    else if (value == 'receipt') color = Colors.green;
    else color = const Color(0xFF0071E3);

    return GestureDetector(
      onTap: () => setState(() => _bondFilterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color.withOpacity(0.4) : Colors.white.withOpacity(0.08)),
        ),
        child: Text(label, style: TextStyle(color: active ? color : Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
      )
    );
  }

  Widget _buildBondCard(Map<String, dynamic> bond) {
    final amount = (bond['amount'] as num?)?.toDouble() ?? 0;
    final personName = bond['personName'] as String? ?? '';
    final reason = bond['reason'] as String? ?? '';
    final bondType = bond['type'] as String? ?? 'payment';
    final createdAt = bond['createdAt'] as DateTime?;
    final dateStr = createdAt != null ? _formatDate(createdAt) : '';
    final isPayment = bondType == 'payment';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: isPayment
              ? const BorderSide(color: Colors.redAccent, width: 3)
              : BorderSide.none,
          left: !isPayment
              ? const BorderSide(color: Colors.green, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPayment ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPayment ? Colors.redAccent : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isPayment ? 'سند صرف' : 'سند قبض',
                style: TextStyle(color: isPayment ? Colors.redAccent : Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${amount.toStringAsFixed(3)} د.ك',
                style: TextStyle(
                  color: isPayment ? Colors.redAccent : Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.white38, size: 12),
              const SizedBox(width: 4),
              Text(personName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(reason, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 2),
          Text(dateStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      )
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ─── دالة تحديد حساب دفتر الأستاذ ────────────────────────────
  String _getLedgerAccount(String paymentMethod) {
    switch (paymentMethod) {
      case 'cash':   return 'الصندوق';
      case 'knet':   return 'كي نت';
      case 'bank':   return 'البنك';
      default:       return 'الصندوق';
    }
  }

  String _getPaymentMethodAr(String method) {
    switch (method) {
      case 'cash':   return 'كاش';
      case 'knet':   return 'كي نت';
      case 'bank':   return 'تحويل بنكي';
      default:       return 'كاش';
    }
  }

  // ─── تحديث رصيد حساب دفتر الأستاذ ────────────────────────────
  Future<void> _updateLedgerAccount(String accountName, double amount, FieldValue timestamp, String refId) async {
    final accountDoc = widget.db
        .collection('business_ledger')
        .doc(widget.uid)
        .collection('accounts')
        .doc(accountName);

    final doc = await accountDoc.get();
    if (doc.exists) {
      await accountDoc.update({
        'balance': FieldValue.increment(amount),
        'lastUpdated': timestamp
      });
    } else {
      await accountDoc.set({
        'accountName': accountName,
        'balance': amount,
        'createdAt': timestamp,
        'lastUpdated': timestamp
      });
    }

    // إضافة حركة مفصلة في سجل الحساب
    await accountDoc.collection('entries').add({
      'amount': amount,
      'type': amount >= 0 ? 'debit' : 'credit',
      'refId': refId,
      'refType': _bondType == 'payment' ? 'سند صرف' : 'سند قبض',
      'description': _reasonController.text.trim(),
      'createdAt': timestamp
    });
  }

  Future<Map<String, dynamic>?> _loadSummary() async {
    final res = await ApiService.get('/api/businesses/${widget.uid}/summary');
    if (res.success && res.data != null) {
      return res.data!['summary'] as Map<String, dynamic>? ?? res.data;
    }
    return null;
  }

  // ─── نافذة اختيار طريقة الدفع ─────────────────────────────────
  Future<String?> _showPaymentMethodDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.payment, color: Color(0xFF0071E3), size: 22),
            const SizedBox(width: 10),
            Text(
              _bondType == 'payment' ? 'طريقة الدفع - سند صرف' : 'طريقة القبض - سند قبض',
              style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر طريقة الدفع:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              children: [
                _paymentMethodButton(ctx, 'كاش', 'cash', Icons.payments, Colors.green),
                const SizedBox(width: 8),
                _paymentMethodButton(ctx, 'كي نت', 'knet', Icons.credit_card, Colors.blue),
                const SizedBox(width: 8),
                _paymentMethodButton(ctx, 'بنك', 'bank', Icons.account_balance, Colors.purple),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
        ],
      )
    );
  }

  Widget _paymentMethodButton(BuildContext ctx, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => Navigator.pop(ctx, value),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      )
    );
  }
}
