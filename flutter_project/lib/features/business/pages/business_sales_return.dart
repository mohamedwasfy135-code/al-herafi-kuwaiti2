import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/cross_platform_utils.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
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
      // تحميل العملاء والمنتجات والمرتجعات بدون orderBy لتجنب فهرس مركب
      final clientsRes = await ApiService.get('/api/clients', queryParameters: {'businessId': widget.uid});
      final productsRes = await ApiService.get('/api/products', queryParameters: {'businessId': widget.uid});
      final returnsRes = await ApiService.get('/api/invoices/sales-returns', queryParameters: {'businessId': widget.uid});

      final List<Map<String, dynamic>> clientsList = [];
      if (clientsRes.success && clientsRes.data != null) {
        final list = clientsRes.data!['clients'] ?? clientsRes.data!['data'];
        if (list is List) clientsList.addAll(list.cast<Map<String, dynamic>>());
      }

      final List<Map<String, dynamic>> productsList = [];
      if (productsRes.success && productsRes.data != null) {
        final list = productsRes.data!['products'] ?? productsRes.data!['data'];
        if (list is List) productsList.addAll(list.cast<Map<String, dynamic>>());
      }

      final List<Map<String, dynamic>> returnsList = [];
      if (returnsRes.success && returnsRes.data != null) {
        final list = returnsRes.data!['invoices'] ?? returnsRes.data!['data'];
        if (list is List) returnsList.addAll(list.cast<Map<String, dynamic>>());
      }

      returnsList.sort((a, b) {
        return _dateToMillis(b['createdAt']).compareTo(_dateToMillis(a['createdAt']));
      });

      if (mounted) {
        setState(() {
          _clients = clientsList;
          _products = productsList;
          _returns = returnsList;
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
        SnackBar(content: Text('أضف مادة واحدة على الأقل'), backgroundColor: _C.warning),
      );
      return;
    }
    if (_selectedClientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدد اسم العميل'), backgroundColor: _C.warning),
      );
      return;
    }

    // سؤال عن طريقة الدفع (إرجاع المبلغ)
    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final returnId = 'SR-${DateTime.now().millisecondsSinceEpoch}';

      final itemsData = filledItems.map((item) => {
        'productId': item.selectedProduct!['id'],
        'itemName': item.selectedProduct!['name'] ?? '',
        'quantity': item.quantity,
        'unitPrice': item.price,
        'total': item.total,
      }).toList();

      final String ledgerAccount = _getLedgerAccount(paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(paymentMethod);

      // حفظ المرتجع كفاتورة نوعها sales_return
      await ApiService.post('/api/invoices/sales-returns', body: {
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
        'createdAt': now,
      });

      // ✅ حركة مالية – خصم من الإيرادات (سالب)
      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': 'sales_return',
        'amount': _totalAmount,
        'category': 'مردود مبيعات',
        'description': 'مردود مبيعات - $_selectedClientName - $paymentMethodAr',
        'invoiceId': returnId,
        'clientId': _selectedClientId,
        'paymentMethod': paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now,
      });

      // ✅ تحديث دفتر الأستاذ (خصم من الحساب)
      await _updateLedgerAccount(ledgerAccount, -_totalAmount, now, returnId);

      // إرسال رابط دفع عبر واتساب لماي فاتوره
      if (paymentMethod == 'myinvoice' && _clientPhoneController.text.trim().isNotEmpty) {
        await _sendWhatsAppPaymentLink(_clientPhoneController.text.trim(), _totalAmount, returnId.substring(0, 8));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ مردود المبيعات بنجاح'), backgroundColor: _C.success),
        );
        _resetForm();
        _loadData();
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
      case 'myinvoice': return 'ماي فاتوره';
      default: return 'الصندوق';
    }
  }

  String _getPaymentMethodAr(String method) {
    switch (method) {
      case 'cash': return 'كاش';
      case 'knet': return 'كي نت';
      case 'bank': return 'تحويل بنكي';
      case 'myinvoice': return 'ماي فاتوره';
      default: return 'كاش';
    }
  }

  Future<void> _updateLedgerAccount(String accountName, double amount, String timestamp, String refId) async {
    await ApiService.post('/api/accounts', body: {
      'businessId': widget.uid,
      'accountName': accountName,
      'balance': amount,
      'lastUpdated': timestamp,
      'entry': {
        'amount': amount,
        'type': amount >= 0 ? 'debit' : 'credit',
        'refId': refId,
        'refType': 'مردود مبيعات',
        'description': _reasonController.text.trim(),
        'createdAt': timestamp,
      },
    });
  }

  // ─── نافذة طريقة الدفع ────────────────────────────────────
  Future<String?> _showPaymentMethodDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.undo, color: _C.accent, size: 22),
          SizedBox(width: 10),
          Text('طريقة إرجاع المبلغ', style: TextStyle(color: _C.textP, fontSize: 14)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('كيف سيتم إرجاع المبلغ للعميل؟', style: TextStyle(color: _C.textS, fontSize: 13)),
            SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pmButton(ctx, 'كاش', 'cash', Icons.payments, _C.success),
              _pmButton(ctx, 'كي نت', 'knet', Icons.credit_card, _C.accent),
              _pmButton(ctx, 'بنك', 'bank', Icons.account_balance, Color(0xFFAF52DE)),
              _pmButton(ctx, 'ماي فاتوره', 'myinvoice', Icons.receipt_long, _C.warning),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text('إلغاء', style: TextStyle(color: _C.textM))),
        ],
      ),
    );
  }

  Widget _pmButton(BuildContext ctx, String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(ctx, value),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.12),
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.3))),
          padding: EdgeInsets.symmetric(vertical: 6),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 28, color: color),
          SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Future<void> _sendWhatsAppPaymentLink(String phone, double amount, String invoiceNum) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '965${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('965')) {
      cleanPhone = '965$cleanPhone';
    }
    final message = 'مرحباً، يرجى سداد المبلغ ${amount.toStringAsFixed(3)} د.ك للفاتورة #$invoiceNum عبر رابط الدفع الآمن.\n\nشكراً لتعاملكم معنا.';
    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    await CrossPlatformUtils.openUrl(url);
  }

  // ═══════════════════════════════════════════════════════════════
  // البناء
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: _C.accent));
    }

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildFormColumn()),
              SizedBox(width: 12),
              Expanded(flex: 3, child: _buildReturnsListColumn()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.undo, color: _C.warning, size: 22),
          SizedBox(width: 8),
          Text('مردود مبيعات', style: TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.warning.withOpacity(0.3)),
            ),
            child: Text('الإجمالي: ${_totalAmount.toStringAsFixed(3)} د.ك', style: TextStyle(color: _C.warning, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormColumn() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.add_circle_outline, color: _C.accent, size: 14),
              SizedBox(width: 8),
              Text('مردود مبيعات جديد', style: TextStyle(color: _C.textP, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            SizedBox(height: 14),

            // اسم العميل
            TextField(
              controller: _clientNameController,
              style: TextStyle(
                color: _selectedClientId != null ? _C.accent : _C.textP,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                labelText: 'اسم العميل',
                labelStyle: TextStyle(color: _C.textS, fontSize: 13),
                prefixIcon: Icon(Icons.person, color: _C.textM, size: 14),
                suffixIcon: _selectedClientId != null
                    ? IconButton(icon: Icon(Icons.close, color: _C.danger, size: 16), onPressed: () => setState(() { _selectedClientId = null; _selectedClientName = ''; _clientNameController.clear(); }))
                    : null,
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                margin: EdgeInsets.only(top: 2),
                constraints: BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _clients.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(_clientNameController.text.toLowerCase())).take(5).length,
                  itemBuilder: (_, i) {
                    final filtered = _clients.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(_clientNameController.text.toLowerCase())).take(5).toList();
                    final c = filtered[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.person_outline, color: _C.accent, size: 16),
                      title: Text(c['name'] ?? '', style: TextStyle(color: _C.textP, fontSize: 13)),
                      onTap: () => setState(() {
                        _selectedClientId = c['id'];
                        _selectedClientName = c['name'] ?? '';
                        _clientNameController.text = c['name'] ?? '';
                        _clientPhoneController.text = c['phone'] ?? '';
                      }),
                    );
                  },
                ),
              ),

            SizedBox(height: 12),

            // المنتجات المرتجعة
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المنتجات المرتجعة', style: TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ...List.generate(_items.length, (i) => _buildReturnItemRow(i)),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: Icon(Icons.add_circle, color: _C.accent, size: 14),
                    label: Text('إضافة مادة', style: TextStyle(color: _C.accent, fontSize: 13)),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // السبب
            TextField(
              controller: _reasonController,
              style: TextStyle(color: _C.textP, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'سبب الإرجاع',
                labelStyle: TextStyle(color: _C.textS, fontSize: 13),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            SizedBox(height: 8),

            // ملاحظات
            TextField(
              controller: _notesController,
              style: TextStyle(color: _C.textP, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'ملاحظات (اختياري)...',
                hintStyle: TextStyle(color: _C.textM, fontSize: 13),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),

            SizedBox(height: 16),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.undo, size: 20),
                        SizedBox(width: 8),
                        Text('حفظ مردود المبيعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItemRow(int index) {
    final item = _items[index];
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
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
                  style: TextStyle(color: item.selectedProduct != null ? _C.accent : _C.textP, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'اسم المادة',
                    hintStyle: TextStyle(color: _C.textM, fontSize: 12),
                    filled: true,
                    fillColor: _C.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.accent)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                );
              },
              optionsViewBuilder: (_, onSelected, options) => Container(
                constraints: BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(color: _C.card, border: Border.all(color: _C.border), borderRadius: BorderRadius.circular(6)),
                child: ListView.builder(shrinkWrap: true, itemCount: options.length, itemBuilder: (_, i) {
                  final p = options.elementAt(i);
                  return ListTile(dense: true, title: Text(p['name'] ?? '', style: TextStyle(color: _C.textP, fontSize: 13)), onTap: () => onSelected(p));
                }),
              ),
            ),
          ),
          SizedBox(width: 4),
          // الكمية
          SizedBox(width: 60, child: TextField(
            controller: item.qtyController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: _C.textP, fontSize: 13),
            decoration: InputDecoration(hintText: 'الكمية', hintStyle: TextStyle(color: _C.textM, fontSize: 12), filled: true, fillColor: _C.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.accent)), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), isDense: true),
            onChanged: (_) => setState(() {}),
          )),
          SizedBox(width: 4),
          // السعر
          SizedBox(width: 80, child: TextField(
            controller: item.priceController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: _C.accent, fontSize: 13),
            decoration: InputDecoration(hintText: 'السعر', hintStyle: TextStyle(color: _C.textM, fontSize: 12), filled: true, fillColor: _C.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _C.accent)), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), isDense: true),
            onChanged: (_) => setState(() {}),
          )),
          SizedBox(width: 4),
          // الإجمالي
          SizedBox(width: 80, child: Text('${item.total.toStringAsFixed(3)}', style: TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          // حذف
          if (_items.length > 1)
            IconButton(onPressed: () => _removeItem(index), icon: Icon(Icons.close, color: _C.danger, size: 16), padding: EdgeInsets.zero, constraints: BoxConstraints(minWidth: 28, minHeight: 28)),
        ],
      ),
    );
  }

  // ─── Helper: parse date from API (String) or legacy Timestamp ───
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try { return DateTime.parse(value); } catch (_) { return null; }
    }
    return null;
  }

  int _dateToMillis(dynamic value) {
    final dt = _parseDate(value);
    return dt?.millisecondsSinceEpoch ?? 0;
  }

  // ─── سجل المرتجعات ────────────────────────────────────────
  Widget _buildReturnsListColumn() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            child: Row(children: [
              Icon(Icons.history, color: _C.accent, size: 14),
              SizedBox(width: 6),
              Text('سجل مردودات المبيعات', style: TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: _loadingReturns
                ? Center(child: CircularProgressIndicator(color: _C.accent))
                : _returns.isEmpty
                    ? Center(child: Text('لا توجد مرتجعات', style: TextStyle(color: _C.textM, fontSize: 18)))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _returns.length,
                        itemBuilder: (_, i) => _buildReturnCard(_returns[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(Map<String, dynamic> ret) {
    final amount = (ret['netTotal'] as num?)?.toDouble() ?? 0;
    final clientName = ret['clientName'] as String? ?? '';
    final reason = ret['reason'] as String? ?? '';
    final createdAt = ret['createdAt'];
    final dt = _parseDate(createdAt);
    final dateStr = dt != null ? '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}' : '';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 3),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: _C.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.undo, color: _C.warning, size: 16),
            SizedBox(width: 6),
            Text('مردود مبيعات', style: TextStyle(color: _C.warning, fontSize: 12, fontWeight: FontWeight.w600)),
            Spacer(),
            Text('${amount.toStringAsFixed(3)} د.ك', style: TextStyle(color: _C.accent, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 4),
          Row(children: [Icon(Icons.person_outline, color: _C.textM, size: 12), SizedBox(width: 4), Text(clientName, style: TextStyle(color: _C.textS, fontSize: 13))]),
          if (reason.isNotEmpty) Text(reason, style: TextStyle(color: _C.textM, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(dateStr, style: TextStyle(color: _C.textM, fontSize: 12)),
        ],
      ),
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
