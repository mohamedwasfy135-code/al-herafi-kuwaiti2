import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/cross_platform_utils.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة فاتورة المشتريات – Purchase Invoice (إصدار 2)
// ✅ نفس تصميم فاتورة المبيعات بالكامل
// ✅ بحث مواد بـ RawAutocomplete + تنقل تلقائي
// ✅ رقم فاتورة تلقائي + طباعة + دفع آجل
// ✅ Apple Design System
// ═══════════════════════════════════════════════════════════════

// ─── Apple Design System Colors ──────────────────────────────────────
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

class BusinessPurchaseInvoice extends StatefulWidget {
  final String uid;
  final String? initialInvoiceId;
  const BusinessPurchaseInvoice({super.key, required this.uid, this.initialInvoiceId});

  @override
  State<BusinessPurchaseInvoice> createState() => _BusinessPurchaseInvoiceState();
}

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
class _BusinessPurchaseInvoiceState extends State<BusinessPurchaseInvoice> {
  // ─── المتغيرات ──────────────────────────────────────────────
  Map<String, dynamic>? _businessData;
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  List<_PurchaseRow> _rows = [];

  // المورد
  final _supplierFieldController = TextEditingController();
  String? _selectedSupplierId;
  String _selectedSupplierName = '';
  String _selectedSupplierPhone = '';
  bool _showSupplierSuggestions = false;

  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  // رقم الفاتورة
  int _invoiceNumber = 0;
  String _currentInvoiceId = '';
  int? _currentInvoiceNumber;

  // طريقة الدفع
  String _paymentMethod = 'cash'; // cash | knet | bank | credit

  // حالة الدفع
  String _paymentStatus = 'paid'; // paid | partial | unpaid
  double _amountPaid = 0;

  // تنقل بين الفواتير
  List<String> _invoiceIds = [];
  int _currentInvoiceIndex = -1;

  // خصم عام
  double _discount = 0;
  double _discountPercent = 0;
  bool _isPercentDiscount = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _supplierFieldController.dispose();
    _notesController.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  // ─── تحميل البيانات ─────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final businessRes = await ApiService.get('/api/business/${widget.uid}');
      final suppliersRes = await ApiService.get('/api/suppliers', queryParameters: {'businessId': widget.uid});
      final invoicesRes = await ApiService.get('/api/invoices/purchase', queryParameters: {'businessId': widget.uid});

      if (mounted) {
        final List<Map<String, dynamic>> invoiceDocs = [];
        if (invoicesRes.success && invoicesRes.data != null) {
          final list = invoicesRes.data!['invoices'] ?? invoicesRes.data!['data'];
          if (list is List) invoiceDocs.addAll(list.cast<Map<String, dynamic>>());
        }
        invoiceDocs.sort((a, b) => _dateToMillis(b['createdAt']).compareTo(_dateToMillis(a['createdAt'])));

        final List<Map<String, dynamic>> suppliersList = [];
        if (suppliersRes.success && suppliersRes.data != null) {
          final list = suppliersRes.data!['suppliers'] ?? suppliersRes.data!['data'];
          if (list is List) suppliersList.addAll(list.cast<Map<String, dynamic>>());
        }

        setState(() {
          _businessData = businessRes.success ? (businessRes.data?['business'] as Map<String, dynamic>? ?? {}) : {};
          _suppliers = suppliersList;
          _invoiceIds = invoiceDocs.map((d) => d['id'] as String).toList();
          _rows = [_PurchaseRow()];
          _loading = false;
        });

        await _loadNextInvoiceNumber();

        if (widget.initialInvoiceId != null) {
          final idx = _invoiceIds.indexOf(widget.initialInvoiceId!);
          if (idx >= 0) _goToInvoiceByIndex(idx);
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── تحميل رقم الفاتورة التالي ──────────────────────────────
  Future<void> _loadNextInvoiceNumber() async {
    try {
      final counterRes = await ApiService.get('/api/subscriptions', queryParameters: {'businessId': widget.uid, 'counter': 'purchase'});
      if (counterRes.success && counterRes.data != null) {
        final savedNum = (counterRes.data!['purchaseInvoiceNumber'] as num?)?.toInt() ?? 0;
        if (savedNum > 0) {
          setState(() => _invoiceNumber = savedNum);
          return;
        }
      }

      final snapRes = await ApiService.get('/api/invoices/purchase', queryParameters: {'businessId': widget.uid});
      final List<Map<String, dynamic>> invoices = [];
      if (snapRes.success && snapRes.data != null) {
        final list = snapRes.data!['invoices'] ?? snapRes.data!['data'];
        if (list is List) invoices.addAll(list.cast<Map<String, dynamic>>());
      }

      int maxNum = 0;
      for (final doc in invoices) {
        final invoiceNum = (doc['invoiceNumber'] as num?)?.toInt() ?? 0;
        if (invoiceNum > maxNum) maxNum = invoiceNum;
      }

      setState(() => _invoiceNumber = maxNum > 0 ? maxNum : invoices.length);

      if (maxNum > 0) {
        await ApiService.put('/api/subscriptions/${widget.uid}', body: {'purchaseInvoiceNumber': maxNum});
      }
    } catch (e) {
      debugPrint('Error loading invoice number: $e');
    }
  }

  // ─── تحديث المنتجات من Stream ────────────────────────────
  Future<void> _loadProducts() async {
    final res = await ApiService.get('/api/products', queryParameters: {'businessId': widget.uid});
    if (res.success && res.data != null) {
      final list = res.data!['products'] ?? res.data!['data'];
      if (list is List) {
        setState(() => _products = list.cast<Map<String, dynamic>>());
      }
    }
  }

  // ─── حسابات ──────────────────────────────────────────────────
  double get _subtotal => _rows.fold(0.0, (sum, r) => sum + r.rowTotal);
  double get _discountAmount {
    if (_isPercentDiscount) return _subtotal * (_discountPercent / 100);
    return _discount;
  }
  double get _netTotal => _subtotal - _discountAmount;

  // ─── إضافة/حذف سطر ─────────────────────────────────────────
  void _addRow() => setState(() => _rows.add(_PurchaseRow()));

  void _addRowAndFocus() {
    setState(() => _rows.add(_PurchaseRow()));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _rows.isNotEmpty) _rows.last.searchFocusNode.requestFocus();
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() { _rows[index].dispose(); _rows.removeAt(index); });
  }

  // ─── حفظ فاتورة المشتريات ───────────────────────────────────
  Future<void> _saveInvoice() async {
    if (_selectedSupplierId == null && _selectedSupplierName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مورد أو اكتب اسم المورد'), backgroundColor: _C.warning),
      );
      return;
    }

    final filledRows = _rows.where((r) => r.selectedProduct != null && r.price > 0).toList();
    if (filledRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مادة واحدة على الأقل'), backgroundColor: _C.warning),
      );
      return;
    }

    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    setState(() {
      _saving = true;
      _paymentMethod = paymentMethod;
      if (paymentMethod == 'credit') {
        _paymentStatus = 'unpaid';
        _amountPaid = 0;
      } else {
        _paymentStatus = 'paid';
        _amountPaid = _netTotal;
      }
    });

    try {
      final now = DateTime.now().toIso8601String();
      final invoiceId = 'PI-${DateTime.now().millisecondsSinceEpoch}';
      final newInvoiceNumber = _invoiceNumber + 1;

      final itemsData = filledRows.map((r) => {
        'productId': r.selectedProduct!['id'],
        'itemName': r.selectedProduct!['name'] ?? '',
        'quantity': r.quantity,
        'unitPrice': r.price,
        'discount': r.discount,
        'discountAmount': r.discountAmount,
        'total': r.rowTotal,
      }).toList();

      final supplierName = _selectedSupplierName.isEmpty ? 'مورد غير محدد' : _selectedSupplierName;

      await ApiService.post('/api/invoices/purchase', body: {
        'id': invoiceId,
        'invoiceNumber': newInvoiceNumber,
        'businessId': widget.uid,
        'type': 'purchase',
        'supplierId': _selectedSupplierId,
        'supplierName': supplierName,
        'supplierPhone': _selectedSupplierPhone,
        'items': itemsData,
        'subtotal': _subtotal,
        'discountType': _isPercentDiscount ? 'percent' : 'fixed',
        'discountValue': _isPercentDiscount ? _discountPercent : _discount,
        'discountAmount': _discountAmount,
        'netTotal': _netTotal,
        'total': _netTotal,
        'paymentMethod': _paymentMethod,
        'notes': _notesController.text.trim(),
        'paymentStatus': _paymentStatus,
        'amountPaid': _amountPaid,
        'status': _paymentStatus,
        'createdAt': now,
      });

      // تحديث عداد رقم الفاتورة
      await ApiService.put('/api/subscriptions/${widget.uid}', body: {'purchaseInvoiceNumber': newInvoiceNumber});

      // تحديث المخزون - زيادة كمية المواد المشتراة
      for (final row in filledRows) {
        final productId = row.selectedProduct!['id'];
        await ApiService.put('/api/products/$productId', body: {
          'stockQuantityIncrement': row.quantity,
        });
      }

      // إنشاء حركة مالية
      final String ledgerAccount = _getLedgerAccount(_paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(_paymentMethod);

      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': 'purchase',
        'amount': _netTotal,
        'category': 'مشتريات',
        'description': 'فاتورة مشتريات #$newInvoiceNumber - $paymentMethodAr',
        'invoiceId': invoiceId,
        'supplierId': _selectedSupplierId,
        'paymentMethod': _paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now,
      });

      await _updateLedger(ledgerAccount, _netTotal, now, invoiceId);

      // تحديث بيانات المورد
      if (_selectedSupplierId != null) {
        await ApiService.put('/api/suppliers/$_selectedSupplierId', body: {
          'totalPurchasesIncrement': _netTotal,
          'lastPurchaseAt': now,
          'invoiceCountIncrement': 1,
        });
      } else if (supplierName != 'مورد غير محدد' && supplierName.isNotEmpty) {
        await ApiService.post('/api/suppliers', body: {
          'businessId': widget.uid,
          'name': supplierName,
          'phone': _selectedSupplierPhone,
          'totalPurchases': _netTotal,
          'lastPurchaseAt': now,
          'invoiceCount': 1,
          'createdAt': now,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ فاتورة المشتريات #$newInvoiceNumber بنجاح'), backgroundColor: _C.success),
        );
        _newInvoice();
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

  void _newInvoice() {
    for (final r in _rows) { r.dispose(); }
    setState(() {
      _rows = [_PurchaseRow()];
      _selectedSupplierId = null;
      _selectedSupplierName = '';
      _selectedSupplierPhone = '';
      _supplierFieldController.clear();
      _notesController.clear();
      _currentInvoiceIndex = -1;
      _currentInvoiceId = '';
      _showSupplierSuggestions = false;
      _paymentMethod = 'cash';
      _paymentStatus = 'paid';
      _amountPaid = 0;
      _discount = 0;
      _discountPercent = 0;
    });
    _loadNextInvoiceNumber();
    _reloadInvoiceIds();
  }

  // ─── دفع فاتورة آجلة ──────────────────────────────────────────
  Future<void> _payInvoice() async {
    if (_currentInvoiceId.isEmpty) return;

    final remaining = _netTotal - _amountPaid;
    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    final payAmount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(3));
        return AlertDialog(
          backgroundColor: _C.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _C.border)),
          title: const Text('دفع الفاتورة', style: TextStyle(color: _C.accent, fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المبلغ المتبقي: ${remaining.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.textS, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: _C.accent, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'المبلغ المراد دفعه',
                  labelStyle: const TextStyle(color: _C.textS),
                  suffixText: 'د.ك',
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, remaining),
              child: const Text('دفع الكل', style: TextStyle(color: _C.accent)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(amountCtrl.text.trim()) ?? 0),
              style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
              child: const Text('دفع'),
            ),
          ],
        );
      },
    );

    if (payAmount == null || payAmount <= 0) return;

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final newAmountPaid = _amountPaid + payAmount;
      final newStatus = newAmountPaid >= _netTotal ? 'paid' : 'partial';
      final String ledgerAccount = _getLedgerAccount(paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(paymentMethod);

      await ApiService.put('/api/invoices/purchase/$_currentInvoiceId', body: {
        'paymentStatus': newStatus,
        'amountPaid': newAmountPaid,
        'status': newStatus,
      });

      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': 'purchase',
        'amount': payAmount,
        'category': 'سداد فاتورة مشتريات آجلة',
        'description': 'سداد فاتورة مشتريات #${_currentInvoiceNumber ?? ""} - $paymentMethodAr',
        'invoiceId': _currentInvoiceId,
        'supplierId': _selectedSupplierId,
        'paymentMethod': paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now,
      });

      if (mounted) {
        setState(() {
          _paymentStatus = newStatus;
          _amountPaid = newAmountPaid;
          _paymentMethod = paymentMethod;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'paid'
                ? 'تم سداد الفاتورة بالكامل'
                : 'تم سداد ${payAmount.toStringAsFixed(3)} د.ك - المتبقي: ${(_netTotal - newAmountPaid).toStringAsFixed(3)} د.ك'),
            backgroundColor: _C.success,
          ),
        );
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

  // ─── إعادة تحميل قائمة الفواتير ────────────────────────────
  Future<void> _reloadInvoiceIds() async {
    try {
      final res = await ApiService.get('/api/invoices/purchase', queryParameters: {'businessId': widget.uid});
      final List<Map<String, dynamic>> docs = [];
      if (res.success && res.data != null) {
        final list = res.data!['invoices'] ?? res.data!['data'];
        if (list is List) docs.addAll(list.cast<Map<String, dynamic>>());
      }
      docs.sort((a, b) => _dateToMillis(b['createdAt']).compareTo(_dateToMillis(a['createdAt'])));

      if (mounted) {
        setState(() { _invoiceIds = docs.map((d) => d['id'] as String).toList(); });
      }
    } catch (e) {
      debugPrint('Error reloading invoice ids: $e');
    }
  }

  // ─── طباعة الفاتورة ────────────────────────────────────────
  Future<void> _printInvoice() async {
    final bName = _businessData?['businessName'] as String? ?? '';
    final bPhone = _businessData?['phone'] as String? ?? '';
    final bAddress = _businessData?['address'] as String? ?? '';
    final supplierName = _selectedSupplierName.isEmpty ? 'مورد غير محدد' : _selectedSupplierName;

    final itemsHtml = _rows.where((r) => r.selectedProduct != null).map((r) => '''
      <tr>
        <td style="padding:8px;border-bottom:1px solid #D2D2D7;text-align:center">${r.selectedProduct!['name'] ?? ''}</td>
        <td style="padding:8px;border-bottom:1px solid #D2D2D7;text-align:center">${r.quantity}</td>
        <td style="padding:8px;border-bottom:1px solid #D2D2D7;text-align:center">${r.price.toStringAsFixed(3)}</td>
        <td style="padding:8px;border-bottom:1px solid #D2D2D7;text-align:center">${r.discount}%</td>
        <td style="padding:8px;border-bottom:1px solid #D2D2D7;text-align:center">${r.rowTotal.toStringAsFixed(3)}</td>
      </tr>
    ''').join('');

    final invoiceNumStr = _currentInvoiceIndex == -1 ? '#${_invoiceNumber + 1}' : '#${_currentInvoiceNumber ?? ''}';

    final htmlContent = '''
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
      <meta charset="UTF-8">
      <title>فاتورة مشتريات $invoiceNumStr</title>
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap');
        * { font-family: 'Cairo', sans-serif; margin: 0; padding: 0; box-sizing: border-box; }
        body { padding: 20px; color: #1D1D1F; background: #fff; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #007AFF; padding-bottom: 16px; margin-bottom: 20px; }
        .business-name { font-size: 22px; font-weight: 700; color: #1D1D1F; }
        .business-info { font-size: 14px; color: #6E6E73; margin-top: 4px; }
        .invoice-title { text-align: left; }
        .invoice-title h2 { font-size: 22px; color: #007AFF; }
        .invoice-title p { font-size: 14px; color: #6E6E73; }
        .supplier-info { background: #F5F5F7; border: 1px solid #D2D2D7; border-radius: 8px; padding: 12px; margin-bottom: 16px; }
        .supplier-info span { font-weight: 600; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
        th { background: #007AFF; color: #fff; padding: 10px; font-size: 15px; text-align: center; }
        td { font-size: 15px; }
        .totals { text-align: left; direction: ltr; }
        .totals div { margin: 4px 0; font-size: 16px; }
        .net-total { font-size: 20px; font-weight: 700; color: #1D1D1F; background: #E3F2FD; padding: 10px 20px; border-radius: 8px; display: inline-block; margin-top: 8px; }
        .notes { margin-top: 16px; font-size: 14px; color: #6E6E73; }
        @media print { body { padding: 0; } }
      </style>
    </head>
    <body>
      <div class="header">
        <div>
          <div class="business-name">$bName</div>
          ${bPhone.isNotEmpty ? '<div class="business-info">$bPhone</div>' : ''}
          ${bAddress.isNotEmpty ? '<div class="business-info">$bAddress</div>' : ''}
        </div>
        <div class="invoice-title">
          <h2>فاتورة مشتريات</h2>
          <p>رقم: $invoiceNumStr</p>
          <p>التاريخ: ${_formatDate(DateTime.now())}</p>
        </div>
      </div>
      <div class="supplier-info">
        المورد: <span>$supplierName</span>
        ${_selectedSupplierPhone.isNotEmpty ? ' &nbsp;|&nbsp; هاتف: <span>$_selectedSupplierPhone</span>' : ''}
      </div>
      <table>
        <thead>
          <tr>
            <th>المادة</th>
            <th>الكمية</th>
            <th>السعر (د.ك)</th>
            <th>الخصم%</th>
            <th>الإجمالي (د.ك)</th>
          </tr>
        </thead>
        <tbody>$itemsHtml</tbody>
      </table>
      <div class="totals">
        <div>المجموع الفرعي: ${_subtotal.toStringAsFixed(3)} د.ك</div>
        ${_discountAmount > 0 ? '<div style="color:#FF3B30">الخصم: - ${_discountAmount.toStringAsFixed(3)} د.ك</div>' : ''}
        <div class="net-total">الصافي: ${_netTotal.toStringAsFixed(3)} د.ك</div>
      </div>
      ${_notesController.text.trim().isNotEmpty ? '<div class="notes">ملاحظات: ${_notesController.text.trim()}</div>' : ''}
    </body>
    </html>
    ''';

    final htmlWithPrint = htmlContent.replaceAll('</body>',
      '<script>setTimeout(function(){window.print();},600);</script></body>');

    await CrossPlatformUtils.openHtmlContent(htmlWithPrint, 'purchase_invoice.html');
  }

  // ─── التنقل بين الفواتير ────────────────────────────────────
  Future<void> _goToInvoice(int direction) async {
    if (_invoiceIds.isEmpty) return;
    int newIndex = _currentInvoiceIndex == -1 ? 0 : _currentInvoiceIndex + direction;
    if (newIndex < 0 || newIndex >= _invoiceIds.length) return;
    await _goToInvoiceByIndex(newIndex);
  }

  Future<void> _goToInvoiceByIndex(int newIndex) async {
    if (newIndex < 0 || newIndex >= _invoiceIds.length) return;
    try {
      final res = await ApiService.get('/api/invoices/purchase/${_invoiceIds[newIndex]}');
      if (!res.success || res.data == null) return;
      final data = res.data!['invoice'] as Map<String, dynamic>? ?? res.data!;

      for (final r in _rows) { r.dispose(); }

      setState(() {
        _currentInvoiceIndex = newIndex;
        _currentInvoiceId = _invoiceIds[newIndex];
        _currentInvoiceNumber = data['invoiceNumber'];
        _selectedSupplierId = data['supplierId'];
        _selectedSupplierName = data['supplierName'] ?? 'مورد غير محدد';
        _selectedSupplierPhone = data['supplierPhone'] ?? '';
        _supplierFieldController.text = _selectedSupplierName;
        _notesController.text = data['notes'] ?? '';
        _showSupplierSuggestions = false;
        _paymentMethod = data['paymentMethod'] ?? 'cash';
        _paymentStatus = data['paymentStatus'] ?? (data['paymentMethod'] == 'credit' ? 'unpaid' : 'paid');
        _amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? (data['paymentMethod'] == 'credit' ? 0 : (data['netTotal'] as num?)?.toDouble() ?? 0);

        // خصم
        final discountType = data['discountType'] as String? ?? 'percent';
        _isPercentDiscount = discountType == 'percent';
        if (_isPercentDiscount) {
          _discountPercent = (data['discountValue'] as num?)?.toDouble() ?? 0;
          _discount = 0;
        } else {
          _discount = (data['discountValue'] as num?)?.toDouble() ?? 0;
          _discountPercent = 0;
        }

        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        _rows = [];
        for (final item in items) {
          final row = _PurchaseRow();
          final matchedProduct = _products.firstWhere(
            (p) => p['id'] == item['productId'],
            orElse: () => <String, dynamic>{},
          );
          if (matchedProduct.isNotEmpty) {
            row.selectedProduct = matchedProduct;
            row.searchController.text = matchedProduct['name'] ?? '';
          } else {
            row.searchController.text = item['itemName'] ?? '';
          }
          row.qtyController.text = (item['quantity'] ?? 1).toString();
          row.priceController.text = (item['unitPrice'] ?? 0).toString();
          row.discountController.text = (item['discount'] ?? 0).toString();
          _rows.add(row);
        }
        if (_rows.isEmpty) _rows.add(_PurchaseRow());
      });
    } catch (e) {
      debugPrint('Error loading invoice: $e');
    }
  }

  // ─── إضافة مورد جديد ────────────────────────────────────────
  Future<void> _addNewSupplier() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _C.border)),
        title: const Text('إضافة مورد جديد', style: TextStyle(color: _C.accent, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: _C.textP),
              decoration: InputDecoration(
                hintText: 'اسم المورد',
                hintStyle: const TextStyle(color: _C.textM),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: _C.textP),
              decoration: InputDecoration(
                hintText: 'رقم الهاتف',
                hintStyle: const TextStyle(color: _C.textM),
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {'name': nameController.text.trim(), 'phone': phoneController.text.trim()});
            },
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final res = await ApiService.post('/api/suppliers', body: {
          'businessId': widget.uid,
          'name': result['name'],
          'phone': result['phone'] ?? '',
          'totalPurchases': 0,
          'invoiceCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
        });
        final newId = res.data?['id'] ?? res.data?['supplier']?['id'] ?? '';

        setState(() {
          _suppliers.add({'id': newId, 'name': result['name'], 'phone': result['phone'] ?? ''});
          _selectedSupplierId = newId;
          _selectedSupplierName = result['name']!;
          _selectedSupplierPhone = result['phone'] ?? '';
          _supplierFieldController.text = result['name']!;
          _showSupplierSuggestions = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: _C.danger),
          );
        }
      }
    }
  }

  // ─── إضافة مادة جديدة ────────────────────────────────────────
  Future<void> _addNewProduct(_PurchaseRow row) async {
    final nameController = TextEditingController(text: row.searchController.text.trim());
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final categoryController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _C.border)),
        title: const Text('إضافة مادة جديدة', style: TextStyle(color: _C.accent, fontSize: 20)),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  hintText: 'اسم المادة',
                  hintStyle: const TextStyle(color: _C.textM),
                  prefixIcon: const Icon(Icons.inventory_2, color: _C.accent, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  hintText: 'السعر (د.ك)',
                  hintStyle: const TextStyle(color: _C.textM),
                  prefixIcon: const Icon(Icons.attach_money, color: _C.accent, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  hintText: 'الكمية المتوفرة',
                  hintStyle: const TextStyle(color: _C.textM),
                  prefixIcon: const Icon(Icons.warehouse, color: _C.accent, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  hintText: 'الفئة (اختياري)',
                  hintStyle: const TextStyle(color: _C.textM),
                  prefixIcon: const Icon(Icons.category, color: _C.textM, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'price': priceController.text.trim(),
                'category': categoryController.text.trim(),
                'stock': stockController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final double price = double.tryParse(result['price'] ?? '') ?? 0;
        final int stock = int.tryParse(result['stock'] ?? '') ?? 0;
        final res = await ApiService.post('/api/products', body: {
          'businessId': widget.uid,
          'name': result['name'],
          'price': price,
          'category': result['category'] ?? '',
          'stockQuantity': stock,
          'isActive': true,
          'createdAt': DateTime.now().toIso8601String(),
        });
        final newId = res.data?['id'] ?? res.data?['product']?['id'] ?? '';

        final newProduct = {
          'id': newId,
          'name': result['name'],
          'price': price,
          'category': result['category'] ?? '',
          'stockQuantity': stock,
          'businessId': widget.uid,
        };

        setState(() {
          _products.add(newProduct);
          row.selectedProduct = newProduct;
          row.searchController.text = result['name']!;
          row.priceController.text = price.toStringAsFixed(3);
        });

        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) row.qtyFocusNode.requestFocus();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إضافة "${result['name']}" بنجاح'), backgroundColor: _C.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: _C.danger),
          );
        }
      }
    }
  }

  // ─── حوار طريقة الدفع ────────────────────────────────────────
  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _C.border)),
        title: const Text('طريقة الدفع', style: TextStyle(color: _C.accent, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _paymentOption(ctx, 'cash', 'نقدي', Icons.payments, _C.success),
            _paymentOption(ctx, 'knet', 'كي نت', Icons.credit_card, const Color(0xFF3B82F6)),
            _paymentOption(ctx, 'bank', 'بنك', Icons.account_balance, const Color(0xFF8B5CF6)),
            _paymentOption(ctx, 'credit', 'آجل', Icons.schedule, const Color(0xFFEF4444)),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption(BuildContext ctx, String value, String label, IconData icon, Color color) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: const TextStyle(color: _C.textP, fontSize: 18)),
      onTap: () => Navigator.pop(ctx, value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // ─── دفتر الأستاذ ────────────────────────────────────────────
  String _getLedgerAccount(String method) {
    switch (method) {
      case 'bank': return 'البنك';
      case 'knet': return 'كي نت';
      case 'myinvoice': return 'ماي فاتوره';
      case 'credit': return 'الصندوق';
      default: return 'الصندوق';
    }
  }

  String _getPaymentMethodAr(String method) {
    switch (method) {
      case 'cash': return 'نقدي';
      case 'knet': return 'كي نت';
      case 'bank': return 'بنك';
      case 'credit': return 'آجل';
      case 'myinvoice': return 'ماي فاتوره';
      default: return method;
    }
  }

  Future<void> _updateLedger(String account, double amount, String now, String invoiceId) async {
    try {
      await ApiService.post('/api/accounts', body: {
        'businessId': widget.uid,
        'accountName': account,
        'entry': {
          'amount': amount,
          'type': 'purchase',
          'description': 'فاتورة مشتريات #${_currentInvoiceNumber ?? _invoiceNumber + 1}',
          'invoiceId': invoiceId,
          'createdAt': now,
        },
      });
    } catch (e) {
      debugPrint('Error updating ledger: $e');
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════
  // البناء
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.accent));
    }

    _loadProducts();
    return Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.border),
                  ),
                  child: Column(
                    children: [
                      _buildInvoiceHeader(),
                      _buildSupplierSection(),
                      _buildInvoiceTable(),
                      _buildInvoiceFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
  }

  // ─── شريط الأدوات ──────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _C.bg,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: _C.accent, size: 14),
          const SizedBox(width: 6),
          const Text('فاتورة مشتريات', style: TextStyle(color: _C.textP, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          // أزرار التنقل
          IconButton(
            onPressed: _invoiceIds.isNotEmpty ? () => _goToInvoice(-1) : null,
            icon: const Icon(Icons.chevron_right, size: 16),
            color: _C.accent,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Text('${_currentInvoiceIndex + 1}/${_invoiceIds.length}',
            style: const TextStyle(color: _C.textS, fontSize: 12)),
          IconButton(
            onPressed: _invoiceIds.isNotEmpty ? () => _goToInvoice(1) : null,
            icon: const Icon(Icons.chevron_left, size: 16),
            color: _C.accent,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
          // طباعة
          IconButton(
            onPressed: _printInvoice,
            icon: const Icon(Icons.print, size: 16),
            color: _C.accent,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'طباعة',
          ),
          // جديد
          IconButton(
            onPressed: _newInvoice,
            icon: const Icon(Icons.add_circle_outline, size: 16),
            color: _C.success,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'فاتورة جديدة',
          ),
        ],
      ),
    );
  }

  // ─── رأس الفاتورة ──────────────────────────────────────────
  Widget _buildInvoiceHeader() {
    final invoiceNumStr = _currentInvoiceIndex == -1 ? '#${_invoiceNumber + 1}' : '#${_currentInvoiceNumber ?? ''}';

    // مؤشر حالة الدفع
    Color statusColor;
    String statusText;
    if (_paymentStatus == 'paid') { statusColor = _C.success; statusText = 'مدفوعة'; }
    else if (_paymentStatus == 'partial') { statusColor = _C.warning; statusText = 'مدفوعة جزئياً'; }
    else { statusColor = _C.danger; statusText = 'غير مدفوعة'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Text('فاتورة مشتريات $invoiceNumStr',
            style: const TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          // طريقة الدفع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _C.accentLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _C.accent.withOpacity(0.3)),
            ),
            child: Text(_getPaymentMethodAr(_paymentMethod),
              style: const TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          // حالة الدفع
          if (_currentInvoiceId.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(statusText,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          const Spacer(),
          // زر دفع للآجلة
          if (_currentInvoiceId.isNotEmpty && _paymentStatus != 'paid')
            ElevatedButton.icon(
              onPressed: _payInvoice,
              icon: const Icon(Icons.payment, size: 14),
              label: const Text('دفع', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
              ),
            ),
        ],
      ),
    );
  }

  // ─── قسم المورد ────────────────────────────────────────────
  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: _C.accent, size: 16),
              const SizedBox(width: 6),
              const Text('المورد', style: TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedSupplierId != null)
                TextButton(
                  onPressed: () => setState(() {
                    _selectedSupplierId = null;
                    _selectedSupplierName = '';
                    _selectedSupplierPhone = '';
                    _supplierFieldController.clear();
                  }),
                  child: const Text('إلغاء', style: TextStyle(color: _C.danger, fontSize: 12)),
                ),
              TextButton.icon(
                onPressed: _addNewSupplier,
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text('مورد جديد', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _C.accent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // حقل بحث المورد مع اقتراحات
          RawAutocomplete<Map<String, dynamic>>(
            textEditingController: _supplierFieldController,
            focusNode: FocusNode(),
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable.empty();
              final query = textEditingValue.text.toLowerCase();
              return _suppliers.where((s) =>
                (s['name'] as String? ?? '').toLowerCase().contains(query) ||
                (s['phone'] as String? ?? '').toLowerCase().contains(query)
              );
            },
            displayStringForOption: (option) => option['name'] ?? '',
            onSelected: (option) {
              setState(() {
                _selectedSupplierId = option['id'];
                _selectedSupplierName = option['name'] ?? '';
                _selectedSupplierPhone = option['phone'] ?? '';
                _supplierFieldController.text = option['name'] ?? '';
                _showSupplierSuggestions = false;
              });
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: _C.textP, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'اسم المورد أو رقم الهاتف',
                  hintStyle: const TextStyle(color: _C.textM, fontSize: 13),
                  prefixIcon: const Icon(Icons.person_outline, color: _C.textM, size: 16),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _C.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  isDense: true,
                ),
                onChanged: (v) {
                  if (_selectedSupplierId != null) {
                    setState(() => _selectedSupplierId = null);
                  }
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: _C.bg,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180, maxWidth: 340),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final option = options.elementAt(i);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: _C.border)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.store, color: _C.textM, size: 14),
                                const SizedBox(width: 8),
                                Text(option['name'] ?? '', style: const TextStyle(color: _C.textP, fontSize: 13)),
                                const Spacer(),
                                if (option['phone'] != null && option['phone'].toString().isNotEmpty)
                                  Text(option['phone'], style: const TextStyle(color: _C.textM, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          // هاتف المورد
          if (_selectedSupplierPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: _C.textM, size: 12),
                  const SizedBox(width: 4),
                  Text(_selectedSupplierPhone, style: const TextStyle(color: _C.textS, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── جدول الأصناف ──────────────────────────────────────────
  Widget _buildInvoiceTable() {
    return Column(
      children: [
        // رأس الجدول
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
            color: _C.accentLight,
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 30, child: Text('#', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(flex: 4, child: Text('المادة', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600))),
              SizedBox(width: 65, child: Text('الكمية', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              SizedBox(width: 80, child: Text('السعر', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              SizedBox(width: 55, child: Text('خصم%', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              SizedBox(width: 90, child: Text('الإجمالي', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              SizedBox(width: 28),
            ],
          ),
        ),
        // صفوف الأصناف
        ...List.generate(_rows.length, (i) => _buildRow(i)),
        // زر إضافة سطر
        InkWell(
          onTap: _addRowAndFocus,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 14, color: _C.accent.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text('إضافة سطر', style: TextStyle(color: _C.accent.withOpacity(0.7), fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int index) {
    final row = _rows[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // رقم
          SizedBox(
            width: 30,
            child: Text('${index + 1}', style: const TextStyle(color: _C.textM, fontSize: 12), textAlign: TextAlign.center),
          ),
          // مادة (بحث)
          Expanded(
            flex: 4,
            child: RawAutocomplete<Map<String, dynamic>>(
              textEditingController: row.searchController,
              focusNode: row.searchFocusNode,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable.empty();
                final query = textEditingValue.text.toLowerCase();
                return _products.where((p) =>
                  (p['name'] as String? ?? '').toLowerCase().contains(query)
                );
              },
              displayStringForOption: (option) => option['name'] ?? '',
              onSelected: (option) {
                setState(() {
                  row.selectedProduct = option;
                  row.searchController.text = option['name'] ?? '';
                  final price = (option['price'] as num?)?.toDouble() ?? 0;
                  row.priceController.text = price.toStringAsFixed(3);
                });
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) row.qtyFocusNode.requestFocus();
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: _C.textP, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث مادة...',
                    hintStyle: const TextStyle(color: _C.textM, fontSize: 12),
                    filled: true,
                    fillColor: _C.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _C.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    isDense: true,
                    suffixIcon: row.searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                row.selectedProduct = null;
                                row.searchController.clear();
                              });
                            },
                            icon: const Icon(Icons.clear, size: 12, color: _C.textM),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: Material(
                    color: _C.bg,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160, maxWidth: 300),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (_, i) {
                                final option = options.elementAt(i);
                                final stock = (option['stockQuantity'] as num?)?.toInt() ?? 0;
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _C.border))),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(option['name'] ?? '', style: const TextStyle(color: _C.textP, fontSize: 13))),
                                        Text('${(option['price'] as num?)?.toDouble().toStringAsFixed(3) ?? '0.000'}',
                                          style: const TextStyle(color: _C.accent, fontSize: 12)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: stock <= 5 ? _C.danger.withOpacity(0.1) : _C.success.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text('$stock',
                                            style: TextStyle(color: stock <= 5 ? _C.danger : _C.success, fontSize: 14)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // إضافة مادة جديدة
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _addNewProduct(row);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _C.accentLight,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add, size: 13, color: _C.accent),
                                  const SizedBox(width: 4),
                                  Text('إضافة مادة جديدة "${row.searchController.text}"',
                                    style: const TextStyle(color: _C.accent, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          // الكمية
          SizedBox(
            width: 65,
            child: TextField(
              controller: row.qtyController,
              focusNode: row.qtyFocusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: _C.textP, fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _C.border)),
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) row.priceFocusNode.requestFocus();
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          // السعر
          SizedBox(
            width: 80,
            child: TextField(
              controller: row.priceController,
              focusNode: row.priceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: _C.textP, fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _C.border)),
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) row.discountFocusNode.requestFocus();
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          // الخصم
          SizedBox(
            width: 55,
            child: TextField(
              controller: row.discountController,
              focusNode: row.discountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: _C.textP, fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: _C.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _C.border)),
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _addRowAndFocus(),
            ),
          ),
          const SizedBox(width: 4),
          // الإجمالي
          SizedBox(
            width: 90,
            child: Text(
              '${row.rowTotal.toStringAsFixed(3)} د.ك',
              style: const TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          // حذف
          SizedBox(
            width: 28,
            child: IconButton(
              onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
              icon: Icon(Icons.close, size: 14, color: _rows.length > 1 ? _C.danger : _C.textM.withOpacity(0.3)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ذيل الفاتورة ──────────────────────────────────────────
  Widget _buildInvoiceFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // خصم عام
          Row(
            children: [
              const Text('الخصم', style: TextStyle(color: _C.textS, fontSize: 13)),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: _C.inputFill,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _discountTypeButton('%', _isPercentDiscount),
                    _discountTypeButton('د.ك', !_isPercentDiscount),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 90,
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: _C.accent, fontSize: 13),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: _isPercentDiscount ? '%' : 'د.ك',
                    hintStyle: const TextStyle(color: _C.textM, fontSize: 12),
                    filled: true,
                    fillColor: _C.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _C.border)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final val = double.tryParse(v) ?? 0;
                    setState(() {
                      if (_isPercentDiscount) { _discountPercent = val.clamp(0, 100); _discount = 0; }
                      else { _discount = val; _discountPercent = 0; }
                    });
                  },
                ),
              ),
            ],
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('- ${_discountAmount.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.danger, fontSize: 12)),
              ],
            ),
          ],
          const Divider(color: _C.border, height: 20),
          // المجاميع
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع الفرعي', style: TextStyle(color: _C.textS, fontSize: 13)),
              Text('${_subtotal.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.textP, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          // الإجمالي
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.accentLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _C.accent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي', style: TextStyle(color: _C.textP, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${_netTotal.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.accent, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // مبلغ مدفوع و متبقي
          if (_currentInvoiceId.isNotEmpty && _paymentStatus != 'paid') ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المدفوع', style: TextStyle(color: _C.success, fontSize: 13)),
                Text('${_amountPaid.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.success, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المتبقي', style: TextStyle(color: _C.danger, fontSize: 13)),
                Text('${(_netTotal - _amountPaid).toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.danger, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // ملاحظات
          TextField(
            controller: _notesController,
            style: const TextStyle(color: _C.textP, fontSize: 13),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'ملاحظات...',
              hintStyle: const TextStyle(color: _C.textM, fontSize: 12),
              filled: true,
              fillColor: _C.inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _C.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            ),
          ),
          const SizedBox(height: 12),
          // أزرار الحفظ
          Row(
            children: [
              // زر الحفظ
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.save, size: 16),
                            SizedBox(width: 6),
                            Text('حفظ فاتورة المشتريات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ]),
                  ),
                ),
              ),
              // زر الدفع (للفاتورة المحفوظة غير المدفوعة)
              if (_currentInvoiceId.isNotEmpty && _paymentStatus != 'paid') ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _payInvoice,
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('دفع', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _discountTypeButton(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() {
        _isPercentDiscount = label == '%';
        _discount = 0;
        _discountPercent = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? _C.accentLight : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
          style: TextStyle(
            color: active ? _C.accent : _C.textM,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// موديل سطر المشتريات
// ═══════════════════════════════════════════════════════════════
class _PurchaseRow {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final qtyController = TextEditingController(text: '1');
  final qtyFocusNode = FocusNode();
  final priceController = TextEditingController();
  final priceFocusNode = FocusNode();
  final discountController = TextEditingController(text: '0');
  final discountFocusNode = FocusNode();

  Map<String, dynamic>? selectedProduct;

  int get quantity => int.tryParse(qtyController.text) ?? 1;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get discount => double.tryParse(discountController.text) ?? 0;
  double get discountAmount => price * quantity * (discount / 100);
  double get rowTotal => (price * quantity) - discountAmount;

  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    qtyController.dispose();
    qtyFocusNode.dispose();
    priceController.dispose();
    priceFocusNode.dispose();
    discountController.dispose();
    discountFocusNode.dispose();
  }
}
