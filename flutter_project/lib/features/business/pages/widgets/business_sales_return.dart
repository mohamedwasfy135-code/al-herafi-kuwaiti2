import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة مردود المبيعات – Sales Return
// عند إرجاع عميل بضاعة → خصم من إيرادات + تحديث دفتر الأستاذ
// ═══════════════════════════════════════════════════════════════

class BusinessSalesReturn extends StatefulWidget {
  final String uid;
  const BusinessSalesReturn({super.key, required this.uid});

  @override
  State<BusinessSalesReturn> createState() => _BusinessSalesReturnState();
}

class _BusinessSalesReturnState extends State<BusinessSalesReturn> {
  final _amountController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  String? _selectedClientId;
  String _selectedClientName = '';
  bool _saving = false;
  bool _loading = true;

  // المنتجات المرتجعة
  List<_ReturnItem> _items = [_ReturnItem()];

  // سجل المرتجعات
  List<Map<String, dynamic>> _returns = [];
  bool _loadingReturns = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    for (final item in _items) { item.dispose(); }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.collection('business_clients').doc(widget.uid).collection('items').get(),
        ApiService.collection(kColProducts).where('businessId', isEqualTo: widget.uid).get(),
        ApiService.collection('business_invoices')
            .where('businessId', isEqualTo: widget.uid)
            .where('type', isEqualTo: 'sales_return')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .get(),
      ]);

      if (mounted) {
        setState(() {
          _clients = (results[0] as QuerySnapshot).docs.map((d) {
            final m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m;
          }).toList();
          _products = (results[1] as QuerySnapshot).docs.map((d) {
            final m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m;
          }).toList();
          _returns = (results[2] as QuerySnapshot).docs.map((d) {
            final m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m;
          }).toList();
          _loading = false;
          _loadingReturns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadingReturns = false; });
    }
  }

  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item.total);

  void _addItem() => setState(() => _items.add(_ReturnItem()));
  void _removeItem(int i) {
    if (_items.length <= 1) return;
    setState(() { _items[i].dispose(); _items.removeAt(i); });
  }

  // ─── حفظ مردود المبيعات ───────────────────────────────────
  Future<void> _saveReturn() async {
    final filledItems = _items.where((item) => item.selectedProduct != null && item.quantity > 0).toList();
    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مادة واحدة على الأقل'), backgroundColor: Colors.orange)
      );
      return;
    }
    if (_selectedClientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد اسم العميل'), backgroundColor: Colors.orange)
      );
      return;
    }

    // سؤال عن طريقة الدفع (إرجاع المبلغ)
    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final returnId = ApiService.collection('business_invoices').doc().id;

      final itemsData = filledItems.map((item) => {
        'productId': item.selectedProduct!['id'],
        'itemName': item.selectedProduct!['name'] ?? '',
        'quantity': item.quantity,
        'unitPrice': item.price,
        'total': item.total
      }).toList();

      final String ledgerAccount = _getLedgerAccount(paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(paymentMethod);

      // حفظ المرتجع كفاتورة نوعها sales_return
      await ApiService.collection('business_invoices').doc(returnId).set({
        'id': returnId,
        'businessId': widget.uid,
        'type': 'sales_return',
        'clientId': _selectedClientId,
        'clientName': _selectedClientName,
        'clientPhone': _clientPhoneController.text.trim(),
        'items': itemsData,
        'netTotal': _totalAmount,
        'paymentMethod': paymentMethod,
        'ledgerAccount': ledgerAccount,
        'reason': _reasonController.text.trim(),
        'notes': _notesController.text.trim(),
        'status': 'returned',
        'createdAt': now
      });

      // ✅ حركة مالية – خصم من الإيرادات (سالب)
      await ApiService.collection('business_transactions').add({
        'businessId': widget.uid,
        'type': 'sales_return',
        'amount': _totalAmount,
        'category': 'مردود مبيعات',
        'description': 'مردود مبيعات - $_selectedClientName - $paymentMethodAr',
        'invoiceId': returnId,
        'clientId': _selectedClientId,
        'paymentMethod': paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now
      });

      // ✅ تحديث دفتر الأستاذ (خصم من الحساب)
      await _updateLedgerAccount(ledgerAccount, -_totalAmount, now, returnId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ مردود المبيعات بنجاح'), backgroundColor: Colors.green)
        );
        _resetForm();
        _loadData();
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
    for (final item in _items) { item.dispose(); }
    setState(() {
      _items = [_ReturnItem()];
      _selectedClientId = null;
      _selectedClientName = '';
      _clientNameController.clear();
      _clientPhoneController.clear();
      _reasonController.clear();
      _notesController.clear();
    });
  }

  // ─── دوال دفتر الأستاذ ────────────────────────────────────
  String _getLedgerAccount(String method) {
    switch (method) {
      case 'cash': return 'الصندوق';
      case 'knet': return 'كي نت';
      case 'bank': return 'البنك';
      default: return 'الصندوق';
    }
  }

  String _getPaymentMethodAr(String method) {
    switch (method) {
      case 'cash': return 'كاش';
      case 'knet': return 'كي نت';
      case 'bank': return 'تحويل بنكي';
      default: return 'كاش';
    }
  }

  Future<void> _updateLedgerAccount(String accountName, double amount, FieldValue timestamp, String refId) async {
    final accountDoc = ApiService
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

    await accountDoc.collection('entries').add({
      'amount': amount,
      'type': amount >= 0 ? 'debit' : 'credit',
      'refId': refId,
      'refType': 'مردود مبيعات',
      'description': _reasonController.text.trim(),
      'createdAt': timestamp
    });
  }

  // ─── نافذة طريقة الدفع ────────────────────────────────────
  Future<String?> _showPaymentMethodDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.undo, color: Color(0xFF0071E3), size: 22),
          SizedBox(width: 10),
          Text('طريقة إرجاع المبلغ', style: TextStyle(color: Color(0xFF0071E3), fontSize: 12)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('كيف سيتم إرجاع المبلغ للعميل؟', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Row(children: [
              _pmButton(ctx, 'كاش', 'cash', Icons.payments, Colors.green),
              const SizedBox(width: 8),
              _pmButton(ctx, 'كي نت', 'knet', Icons.credit_card, Colors.blue),
              const SizedBox(width: 8),
              _pmButton(ctx, 'بنك', 'bank', Icons.account_balance, Colors.purple),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
        ],
      )
    );
  }

  Widget _pmButton(BuildContext ctx, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => Navigator.pop(ctx, value),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.5))),
          padding: const EdgeInsets.symmetric(vertical: 6),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      )
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // البناء
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildFormColumn()),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: _buildReturnsListColumn()),
            ],
          ),
        ),
      ]
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          const Icon(Icons.undo, color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          const Text('مردود مبيعات', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Text('الإجمالي: ${_totalAmount.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  Widget _buildFormColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.add_circle_outline, color: Color(0xFF0071E3), size: 14),
              SizedBox(width: 8),
              Text('مردود مبيعات جديد', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),

            // اسم العميل
            TextField(
              controller: _clientNameController,
              style: TextStyle(
                color: _selectedClientId != null ? const Color(0xFF0071E3) : Colors.white,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                labelText: 'اسم العميل',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.person, color: Colors.white38, size: 14),
                suffixIcon: _selectedClientId != null
                    ? IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 16), onPressed: () => setState(() { _selectedClientId = null; _selectedClientName = ''; _clientNameController.clear(); }))
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                setState(() {
                  _selectedClientName = v;
                  if (_selectedClientId != null && v != _selectedClientName) _selectedClientId = null;
                });
              },
            ),

            // اقتراحات العملاء
            if (_selectedClientId == null && _clientNameController.text.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D1F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _clients.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(_clientNameController.text.toLowerCase())).take(5).length,
                  itemBuilder: (_, i) {
                    final filtered = _clients.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(_clientNameController.text.toLowerCase())).take(5).toList();
                    final c = filtered[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline, color: Color(0xFF0071E3), size: 16),
                      title: Text(c['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      onTap: () => setState(() {
                        _selectedClientId = c['id'];
                        _selectedClientName = c['name'] ?? '';
                        _clientNameController.text = c['name'] ?? '';
                        _clientPhoneController.text = c['phone'] ?? '';
                      })
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // المنتجات المرتجعة
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المنتجات المرتجعة', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(_items.length, (i) => _buildReturnItemRow(i)),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF0071E3), size: 14),
                    label: const Text('إضافة مادة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // السبب
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'سبب الإرجاع',
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
                onPressed: _saving ? null : _saveReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.undo, size: 20),
                        SizedBox(width: 8),
                        Text('حفظ مردود المبيعات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ]),
              ),
            ),
          ],
        ),
      )
    );
  }

  Widget _buildReturnItemRow(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // اسم المادة
          Expanded(
            flex: 3,
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return <Map<String, dynamic>>[];
                return _products.where((p) => (p['name'] ?? '').toString().toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (p) => p['name'] ?? '',
              onSelected: (p) => setState(() {
                item.selectedProduct = p;
                item.priceController.text = (p['price'] ?? 0).toString();
              }),
              fieldViewBuilder: (_, controller, focusNode, onFieldSubmitted) {
                if (item.selectedProduct != null) controller.text = item.selectedProduct!['name'] ?? '';
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(color: item.selectedProduct != null ? const Color(0xFF0071E3) : Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'اسم المادة',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  )
                );
              },
              optionsViewBuilder: (_, onSelected, options) => Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(color: const Color(0xFF1D1D1F), border: Border.all(color: Colors.orange.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
                child: ListView.builder(shrinkWrap: true, itemCount: options.length, itemBuilder: (_, i) {
                  final p = options.elementAt(i);
                  return ListTile(dense: true, title: Text(p['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)), onTap: () => onSelected(p));
                }),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // الكمية
          SizedBox(width: 60, child: TextField(
            controller: item.qtyController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(hintText: 'الكمية', hintStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: Colors.white.withOpacity(0.06), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), isDense: true),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 4),
          // السعر
          SizedBox(width: 80, child: TextField(
            controller: item.priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12),
            decoration: InputDecoration(hintText: 'السعر', hintStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: Colors.white.withOpacity(0.06), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), isDense: true),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 4),
          // الإجمالي
          SizedBox(width: 80, child: Text('${item.total.toStringAsFixed(3)}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          // حذف
          if (_items.length > 1)
            IconButton(onPressed: () => _removeItem(index), icon: const Icon(Icons.close, color: Colors.redAccent, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ],
      )
    );
  }

  // ─── سجل المرتجعات ────────────────────────────────────────
  Widget _buildReturnsListColumn() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: const Row(children: [
              Icon(Icons.history, color: Color(0xFF0071E3), size: 14),
              SizedBox(width: 6),
              Text('سجل مردودات المبيعات', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: _loadingReturns
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                : _returns.isEmpty
                    ? Center(child: Text('لا توجد مرتجعات', style: TextStyle(color: Colors.white38, fontSize: 14)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _returns.length,
                        itemBuilder: (_, i) => _buildReturnCard(_returns[i]),
                      ),
          ),
        ],
      )
    );
  }

  Widget _buildReturnCard(Map<String, dynamic> ret) {
    final amount = (ret['netTotal'] as num?)?.toDouble() ?? 0;
    final clientName = ret['clientName'] as String? ?? '';
    final reason = ret['reason'] as String? ?? '';
    final createdAt = ret['createdAt'] as DateTime?;
    final dateStr = createdAt != null ? '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}' : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(right: const BorderSide(color: Colors.orange, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.undo, color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            const Text('مردود مبيعات', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${amount.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.person_outline, color: Colors.white38, size: 12), const SizedBox(width: 4), Text(clientName, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
          if (reason.isNotEmpty) Text(reason, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(dateStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      )
    );
  }
}

// ─── سطر المرتجع ──────────────────────────────────────────────
class _ReturnItem {
  Map<String, dynamic>? selectedProduct;
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();

  int get quantity => int.tryParse(qtyController.text) ?? 0;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get total => quantity * price;

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}
