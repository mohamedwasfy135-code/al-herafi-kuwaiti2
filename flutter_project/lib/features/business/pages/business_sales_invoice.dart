import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/cross_platform_utils.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import 'widgets/payment_card.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة فاتورة المبيعات – Sales Invoice (إصدار 7)
// ✅ بحث مواد بـ RawAutocomplete (تنقل بالأسهم + نقر + Enter)
// ✅ تنقل تلقائي: مادة → كمية → سعر → خصم → سطر جديد
// ✅ رقم فاتورة تلقائي + زر طباعة + عرض الكمية المتوفرة
// ✅ إشعار قرب انتهاء المخزون
// ✅ طريقة الدفع INLINE + PaymentCard للفاتورة المحفوظة
// ═══════════════════════════════════════════════════════════════

class BusinessSalesInvoice extends StatefulWidget {
  final String uid;
  final String? initialInvoiceId;
  const BusinessSalesInvoice({super.key, required this.uid, this.initialInvoiceId});

  @override
  State<BusinessSalesInvoice> createState() => _BusinessSalesInvoiceState();
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
class _BusinessSalesInvoiceState extends State<BusinessSalesInvoice> {
  // ─── متغيرات الفاتورة ───────────────────────────────────────
  Map<String, dynamic>? _businessData;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  List<_InvoiceRow> _rows = [];

  // العميل
  final _clientFieldController = TextEditingController();
  String? _selectedClientId;
  String _selectedClientName = '';
  String _selectedClientPhone = '';
  bool _showClientSuggestions = false;

  final _notesController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  // رقم الفاتورة
  int _invoiceNumber = 0;
  String _currentInvoiceId = '';

  // طريقة الدفع
  String _paymentMethod = 'cash'; // cash | knet | bank | my_invoice | credit

  // حالة الدفع
  String _paymentStatus = 'paid'; // paid | partial | unpaid
  double _amountPaid = 0;

  // تنقل بين الفواتير
  List<String> _invoiceIds = [];
  int _currentInvoiceIndex = -1;

  // عتبة تنبيه المخزون
  static const int _lowStockThreshold = 5;

  // طرق الدفع (inline chips)
  static const _paymentMethods = [
    {'code': 'cash', 'ar': 'كاش', 'icon': Icons.money_outlined},
    {'code': 'knet', 'ar': 'كي نت', 'icon': Icons.credit_card_outlined},
    {'code': 'bank', 'ar': 'بنك', 'icon': Icons.account_balance_outlined},
    {'code': 'my_invoice', 'ar': 'ماي فاتورة', 'icon': Icons.link_outlined},
    {'code': 'credit', 'ar': 'آجل', 'icon': Icons.schedule_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _clientFieldController.dispose();
    _notesController.dispose();
    _paymentAmountController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  // ─── تحميل البيانات ─────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final businessRes = await ApiService.get('/api/business/${widget.uid}');
      final clientsRes = await ApiService.get('/api/clients', queryParameters: {'businessId': widget.uid});
      final invoicesRes = await ApiService.get('/api/invoices/sales', queryParameters: {'businessId': widget.uid});

      if (mounted) {
        final List<Map<String, dynamic>> invoiceDocs = [];
        if (invoicesRes.success && invoicesRes.data != null) {
          final list = invoicesRes.data!['invoices'] ?? invoicesRes.data!['data'];
          if (list is List) invoiceDocs.addAll(list.cast<Map<String, dynamic>>());
        }
        invoiceDocs.sort((a, b) => _dateToMillis(b['createdAt']).compareTo(_dateToMillis(a['createdAt'])));

        final List<Map<String, dynamic>> clientsList = [];
        if (clientsRes.success && clientsRes.data != null) {
          final list = clientsRes.data!['clients'] ?? clientsRes.data!['data'];
          if (list is List) clientsList.addAll(list.cast<Map<String, dynamic>>());
        }

        setState(() {
          _businessData = businessRes.success ? (businessRes.data?['business'] as Map<String, dynamic>? ?? {}) : {};
          _clients = clientsList;
          _invoiceIds = invoiceDocs.map((d) => d['id'] as String).toList();
          _rows = [_InvoiceRow()];
          _loading = false;
        });

        // تحميل رقم الفاتورة التالي
        await _loadNextInvoiceNumber();

        // إذا تم تحديد فاتورة معينة للفتح
        if (widget.initialInvoiceId != null) {
          final idx = _invoiceIds.indexOf(widget.initialInvoiceId!);
          if (idx >= 0) {
            _goToInvoiceByIndex(idx);
          }
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
      // أولاً: محاولة قراءة العداد
      final counterRes = await ApiService.get('/api/subscriptions', queryParameters: {'businessId': widget.uid, 'counter': 'sales'});
      if (counterRes.success && counterRes.data != null) {
        final savedNum = (counterRes.data!['salesInvoiceNumber'] as num?)?.toInt() ?? 0;
        if (savedNum > 0) {
          setState(() => _invoiceNumber = savedNum);
          return;
        }
      }

      final snapRes = await ApiService.get('/api/invoices/sales', queryParameters: {'businessId': widget.uid});
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
        await ApiService.put('/api/subscriptions/${widget.uid}', body: {'salesInvoiceNumber': maxNum});
      }
    } catch (e) {
      debugPrint('Error loading invoice number: $e');
    }
  }

  // ─── تحديث قائمة المنتجات من الـ Stream ─────────────────
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
  double get _totalDiscount => _rows.fold(0.0, (sum, r) => sum + r.discountAmount);
  double get _netTotal => _subtotal;

  // ─── إضافة سطر جديد ─────────────────────────────────────────
  void _addRow() {
    setState(() => _rows.add(_InvoiceRow()));
  }

  void _addRowAndFocus() {
    setState(() => _rows.add(_InvoiceRow()));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _rows.isNotEmpty) {
        _rows.last.searchFocusNode.requestFocus();
      }
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  // ─── حفظ الفاتورة ───────────────────────────────────────────
  Future<void> _saveInvoice() async {
    if (_selectedClientId == null && _selectedClientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر عميل أو اختر عميل نقدي'), backgroundColor: Colors.orange),
      );
      return;
    }

    final filledRows = _rows.where((r) => r.selectedProduct != null && r.price > 0).toList();
    if (filledRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مادة واحدة على الأقل'), backgroundColor: Colors.orange),
      );
      return;
    }

    // التحقق من توفر الكمية في المخزون
    for (final row in filledRows) {
      final stockQty = _getProductStock(row.selectedProduct!);
      if (stockQty >= 0 && row.quantity > stockQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الكمية المطلوبة من "${row.selectedProduct!['name']}" (${row.quantity}) أكبر من المتوفر ($stockQty)'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // استخدام طريقة الدفع المحددة inline
    setState(() {
      _saving = true;
      // _paymentMethod already set by the inline chip selector
      if (_paymentMethod == 'credit') {
        _paymentStatus = 'unpaid';
        _amountPaid = 0;
      } else {
        final enteredAmount = double.tryParse(_paymentAmountController.text) ?? _netTotal;
        _amountPaid = enteredAmount > _netTotal ? _netTotal : enteredAmount;
        _paymentStatus = _amountPaid >= _netTotal - 0.001 ? 'paid' : 'partial';
      }
    });

    try {
      final now = DateTime.now().toIso8601String();
      final invoiceId = 'SI-${DateTime.now().millisecondsSinceEpoch}';

      // زيادة رقم الفاتورة
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

      final clientName = _selectedClientName.isEmpty ? 'عميل نقدي' : _selectedClientName;

      await ApiService.post('/api/invoices/sales', body: {
        'id': invoiceId,
        'invoiceNumber': newInvoiceNumber,
        'businessId': widget.uid,
        'type': 'sales',
        'clientId': _selectedClientId,
        'clientName': clientName,
        'clientPhone': _selectedClientPhone,
        'items': itemsData,
        'subtotal': _subtotal,
        'totalDiscount': _totalDiscount,
        'netTotal': _netTotal,
        'paymentMethod': _paymentMethod,
        'notes': _notesController.text.trim(),
        'paymentStatus': _paymentStatus,
        'amountPaid': _amountPaid,
        'status': _paymentStatus,
        'createdAt': now,
      });

      // تحديث عداد رقم الفاتورة
      await ApiService.put('/api/subscriptions/${widget.uid}', body: {
        'salesInvoiceNumber': newInvoiceNumber,
      });

      // تحديث المخزون - تقليل كمية المواد المباعة
      for (final row in filledRows) {
        final productId = row.selectedProduct!['id'];
        await ApiService.put('/api/products/$productId', body: {
          'stockQuantityIncrement': -row.quantity,
        });
      }

      final String ledgerAccount = _getLedgerAccount(_paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(_paymentMethod);

      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': 'income',
        'amount': _amountPaid,
        'category': 'مبيعات',
        'description': 'فاتورة مبيعات #$newInvoiceNumber - $paymentMethodAr',
        'invoiceId': invoiceId,
        'clientId': _selectedClientId,
        'paymentMethod': _paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now,
      });

      if (_selectedClientId != null) {
        await ApiService.put('/api/clients/$_selectedClientId', body: {
          'totalPurchasesIncrement': _netTotal,
          'lastPurchaseAt': now,
          'invoiceCountIncrement': 1,
        });
      } else if (clientName != 'عميل نقدي' && clientName.isNotEmpty) {
        await ApiService.post('/api/clients', body: {
          'businessId': widget.uid,
          'name': clientName,
          'phone': _selectedClientPhone,
          'totalPurchases': _netTotal,
          'lastPurchaseAt': now,
          'invoiceCount': 1,
          'createdAt': now,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الفاتورة #$newInvoiceNumber بنجاح'), backgroundColor: Colors.green),
        );
        _newInvoice();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _newInvoice() {
    for (final r in _rows) { r.dispose(); }
    setState(() {
      _rows = [_InvoiceRow()];
      _selectedClientId = null;
      _selectedClientName = '';
      _selectedClientPhone = '';
      _clientFieldController.clear();
      _notesController.clear();
      _paymentAmountController.clear();
      _currentInvoiceIndex = -1;
      _currentInvoiceId = '';
      _showClientSuggestions = false;
      _paymentMethod = 'cash';
      _paymentStatus = 'paid';
      _amountPaid = 0;
    });
    // إعادة تحميل رقم الفاتورة من العداد لضمان الدقة
    _loadNextInvoiceNumber();
    // إعادة تحميل قائمة الفواتير
    _reloadInvoiceIds();
  }

  // ─── إعادة تحميل قائمة معرفات الفواتير ──────────────────────
  Future<void> _reloadInvoiceIds() async {
    try {
      final res = await ApiService.get('/api/invoices/sales', queryParameters: {'businessId': widget.uid});
      final List<Map<String, dynamic>> docs = [];
      if (res.success && res.data != null) {
        final list = res.data!['invoices'] ?? res.data!['data'];
        if (list is List) docs.addAll(list.cast<Map<String, dynamic>>());
      }
      docs.sort((a, b) => _dateToMillis(b['createdAt']).compareTo(_dateToMillis(a['createdAt'])));

      if (mounted) {
        setState(() {
          _invoiceIds = docs.map((d) => d['id'] as String).toList();
        });
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
    final clientName = _selectedClientName.isEmpty ? 'عميل نقدي' : _selectedClientName;

    final itemsHtml = _rows.where((r) => r.selectedProduct != null).map((r) => '''
      <tr>
        <td style="padding:8px;border-bottom:1px solid #ddd;text-align:center">${r.selectedProduct!['name'] ?? ''}</td>
        <td style="padding:8px;border-bottom:1px solid #ddd;text-align:center">${r.quantity}</td>
        <td style="padding:8px;border-bottom:1px solid #ddd;text-align:center">${r.price.toStringAsFixed(3)}</td>
        <td style="padding:8px;border-bottom:1px solid #ddd;text-align:center">${r.discount}%</td>
        <td style="padding:8px;border-bottom:1px solid #ddd;text-align:center">${r.rowTotal.toStringAsFixed(3)}</td>
      </tr>
    ''').join('');

    final invoiceNumStr = _currentInvoiceIndex == -1 ? '#${_invoiceNumber + 1}' : '#${_currentInvoiceNumber ?? ''}';

    final htmlContent = '''
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
      <meta charset="UTF-8">
      <title>فاتورة مبيعات $invoiceNumStr</title>
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap');
        * { font-family: 'Cairo', sans-serif; margin: 0; padding: 0; box-sizing: border-box; }
        body { padding: 20px; color: #1D1D1F; background: #fff; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #1D1D1F; padding-bottom: 16px; margin-bottom: 20px; }
        .business-name { font-size: 22px; font-weight: 700; color: #1D1D1F; }
        .business-info { font-size: 14px; color: #666; margin-top: 4px; }
        .invoice-title { text-align: left; }
        .invoice-title h2 { font-size: 22px; color: #1D1D1F; }
        .invoice-title p { font-size: 14px; color: #666; }
        .client-info { background: #f8f9fa; border-radius: 8px; padding: 12px; margin-bottom: 16px; }
        .client-info span { font-weight: 600; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
        th { background: #1D1D1F; color: #007AFF; padding: 10px; font-size: 15px; text-align: center; }
        td { font-size: 15px; }
        .totals { text-align: left; direction: ltr; }
        .totals div { margin: 4px 0; font-size: 16px; }
        .net-total { font-size: 24px; font-weight: 700; color: #1D1D1F; background: #E3F2FD; padding: 10px 20px; border-radius: 8px; display: inline-block; margin-top: 8px; }
        .notes { margin-top: 16px; font-size: 14px; color: #666; }
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
          <h2>فاتورة مبيعات</h2>
          <p>رقم: $invoiceNumStr</p>
          <p>التاريخ: ${_formatDate(DateTime.now())}</p>
        </div>
      </div>
      <div class="client-info">
        العميل: <span>$clientName</span>
        ${_selectedClientPhone.isNotEmpty ? ' &nbsp;|&nbsp; هاتف: <span>$_selectedClientPhone</span>' : ''}
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
        ${_totalDiscount > 0 ? '<div style="color:red">إجمالي الخصم: - ${_totalDiscount.toStringAsFixed(3)} د.ك</div>' : ''}
        <div class="net-total">الصافي: ${_netTotal.toStringAsFixed(3)} د.ك</div>
      </div>
      ${_notesController.text.trim().isNotEmpty ? '<div class="notes">ملاحظات: ${_notesController.text.trim()}</div>' : ''}
      <div style="margin-top:24px;font-size:13px;color:#999;text-align:center">شكراً لتعاملكم معنا</div>
    </body>
    </html>
    ''';

    // إضافة سكريبت الطباعة التلقائية داخل HTML نفسه
    final htmlWithPrint = htmlContent.replaceAll(
      '</body>',
      '<script>setTimeout(function(){window.print();},600);</script></body>',
    );

    // إنشاء Blob وفتحه في تبويب جديد
    await CrossPlatformUtils.openHtmlContent(htmlWithPrint, 'sales_invoice.html');
  }

  // ─── الحصول على كمية المخزون ────────────────────────────────
  int _getProductStock(Map<String, dynamic> product) {
    // إذا لم يكن الحقل موجوداً نعتبره 0 وليس -1
    // لعرض الكمية سواء كانت موجبة أو سالبة أو صفر
    if (!product.containsKey('stockQuantity')) return 0;
    final val = product['stockQuantity'];
    if (val == null) return 0;
    return (val as num).toInt();
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
      final res = await ApiService.get('/api/invoices/sales/${_invoiceIds[newIndex]}');
      if (!res.success || res.data == null) return;
      final data = res.data!['invoice'] as Map<String, dynamic>? ?? res.data!;

      for (final r in _rows) { r.dispose(); }

      setState(() {
        _currentInvoiceIndex = newIndex;
        _currentInvoiceId = _invoiceIds[newIndex];
        _currentInvoiceNumber = data['invoiceNumber'];
        _selectedClientId = data['clientId'];
        _selectedClientName = data['clientName'] ?? 'عميل نقدي';
        _selectedClientPhone = data['clientPhone'] ?? '';
        _clientFieldController.text = _selectedClientName;
        _notesController.text = data['notes'] ?? '';
        _showClientSuggestions = false;
        _paymentMethod = data['paymentMethod'] ?? 'cash';
        _paymentStatus = data['paymentStatus'] ?? (data['paymentMethod'] == 'credit' ? 'unpaid' : 'paid');
        _amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? (data['paymentMethod'] == 'credit' ? 0 : (data['netTotal'] as num?)?.toDouble() ?? 0);
        _paymentAmountController.text = _netTotal.toStringAsFixed(3);

        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        _rows = [];
        for (final item in items) {
          final row = _InvoiceRow();
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
        if (_rows.isEmpty) _rows.add(_InvoiceRow());
      });
    } catch (e) {
      debugPrint('Error loading invoice: $e');
    }
  }

  int? _currentInvoiceNumber;

  // ─── إضافة عميل جديد ────────────────────────────────────────
  Future<void> _addNewClient() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rLarge)),
        title: const Text('إضافة عميل جديد', style: AppTheme.sSection),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppTheme.textP),
              decoration: AppTheme.inputDecoration(hintText: 'اسم العميل'),
            ),
            const SizedBox(height: AppTheme.s8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textP),
              decoration: AppTheme.inputDecoration(hintText: 'رقم الهاتف'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AppTheme.textS))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {'name': nameController.text.trim(), 'phone': phoneController.text.trim()});
            },
            style: AppTheme.primaryButton,
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final res = await ApiService.post('/api/clients', body: {
          'businessId': widget.uid,
          'name': result['name'],
          'phone': result['phone'] ?? '',
          'totalPurchases': 0,
          'invoiceCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
        });
        final newId = res.data?['id'] ?? res.data?['client']?['id'] ?? '';

        setState(() {
          _clients.add({'id': newId, 'name': result['name'], 'phone': result['phone'] ?? ''});
          _selectedClientId = newId;
          _selectedClientName = result['name']!;
          _selectedClientPhone = result['phone'] ?? '';
          _clientFieldController.text = result['name']!;
          _showClientSuggestions = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ─── إضافة مادة جديدة سريعاً ───────────────────────────────
  Future<void> _addNewProduct(_InvoiceRow row) async {
    final nameController = TextEditingController(text: row.searchController.text.trim());
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    final stockController = TextEditingController(text: '0');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rLarge)),
        title: const Text('إضافة مادة جديدة', style: AppTheme.sSection),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textP),
                decoration: AppTheme.inputDecoration(
                  hintText: 'اسم المادة',
                  prefixIcon: Icons.inventory_2,
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textP),
                decoration: AppTheme.inputDecoration(
                  hintText: 'السعر (د.ك)',
                  prefixIcon: Icons.attach_money,
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textP),
                decoration: AppTheme.inputDecoration(
                  hintText: 'الكمية المتوفرة',
                  prefixIcon: Icons.warehouse,
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: AppTheme.textP),
                decoration: AppTheme.inputDecoration(
                  hintText: 'الفئة (اختياري)',
                  prefixIcon: Icons.category,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textS)),
          ),
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
            style: AppTheme.primaryButton,
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

        // نقل التركيز إلى حقل الكمية بعد إضافة المادة
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) row.qtyFocusNode.requestFocus();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إضافة "${result['name']}" بنجاح'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // البناء
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.textP));
    }

    _loadProducts();
    return Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.s12),
                child: Container(
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    children: [
                      _buildInvoiceHeader(),
                      _buildClientSection(),
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
    final invoiceLabel = _currentInvoiceIndex == -1
        ? 'فاتورة مبيعات جديدة #${_invoiceNumber + 1}'
        : 'فاتورة #${_currentInvoiceNumber ?? _invoiceIds[_currentInvoiceIndex].substring(0, 8)}';

    return AppTheme.buildTopBar(
      title: invoiceLabel,
      icon: Icons.receipt_long,
      actions: [
        IconButton(
          onPressed: _printInvoice,
          icon: const Icon(Icons.print, size: AppTheme.iconSize),
          color: AppTheme.accent,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'طباعة',
        ),
        IconButton(
          onPressed: _invoiceIds.isNotEmpty && _currentInvoiceIndex < _invoiceIds.length - 1 ? () => _goToInvoice(1) : null,
          icon: const Icon(Icons.chevron_left, size: AppTheme.iconSize),
          color: AppTheme.accent,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Text('${_currentInvoiceIndex + 1}/${_invoiceIds.length}', style: const TextStyle(color: AppTheme.textS, fontSize: AppTheme.fCaption)),
        IconButton(
          onPressed: _currentInvoiceIndex > 0 ? () => _goToInvoice(-1) : null,
          icon: const Icon(Icons.chevron_right, size: AppTheme.iconSize),
          color: AppTheme.accent,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        const SizedBox(width: AppTheme.s4),
        IconButton(
          onPressed: _newInvoice,
          icon: const Icon(Icons.add_circle_outline, size: AppTheme.iconSize),
          color: AppTheme.success,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'فاتورة جديدة',
        ),
      ],
    );
  }

  // ─── رأس الفاتورة ──────────────────────────────────────────
  Widget _buildInvoiceHeader() {
    final bName = _businessData?['businessName'] as String? ?? 'المنشأة';
    final bPhone = _businessData?['phone'] as String? ?? '';
    final bAddress = _businessData?['address'] as String? ?? '';
    final bLogo = _businessData?['logoUrl'] as String? ?? '';

    final invoiceNumStr = _currentInvoiceIndex == -1
        ? '#${_invoiceNumber + 1}'
        : '#${_currentInvoiceNumber ?? ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentLight,
              border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5),
            ),
            child: bLogo.isNotEmpty
                ? ClipOval(child: Image.network(bLogo, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 20, color: AppTheme.accent)))
                : const Icon(Icons.store, size: 20, color: AppTheme.accent),
          ),
          const SizedBox(width: AppTheme.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bName, style: const TextStyle(color: AppTheme.textP, fontSize: AppTheme.fPageTitle, fontWeight: FontWeight.bold)),
                if (bPhone.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Row(children: [const Icon(Icons.phone, color: AppTheme.textM, size: AppTheme.iconSizeSm), const SizedBox(width: 3), Text(bPhone, style: const TextStyle(color: AppTheme.textS, fontSize: AppTheme.fCaption))]),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('فاتورة مبيعات $invoiceNumStr', style: const TextStyle(color: AppTheme.textP, fontSize: AppTheme.fSection, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── قسم العميل ──────────────────────────────────────────────
  Widget _buildClientSection() {
    final filteredClients = _showClientSuggestions && _clientFieldController.text.isNotEmpty
        ? _clients.where((c) {
            final query = _clientFieldController.text.toLowerCase();
            final name = (c['name'] as String? ?? '').toLowerCase();
            final phone = (c['phone'] as String? ?? '').toLowerCase();
            return name.contains(query) || phone.contains(query);
          }).toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.inputFill)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppTheme.accent, size: AppTheme.iconSize),
              const SizedBox(width: AppTheme.s6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _clientFieldController,
                      style: TextStyle(
                        color: _selectedClientId != null ? AppTheme.accent : AppTheme.textP,
                        fontSize: AppTheme.fSection,
                        fontWeight: _selectedClientId != null ? FontWeight.bold : FontWeight.normal,
                      ),
                      decoration: InputDecoration(
                        hintText: 'اسم العميل أو رقم الهاتف...',
                        hintStyle: const TextStyle(color: AppTheme.textM, fontSize: AppTheme.fCaption),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.textM, size: AppTheme.iconSizeSm),
                        suffixIcon: _selectedClientId != null
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: AppTheme.iconSizeSm),
                                onPressed: () => setState(() {
                                  _selectedClientId = null;
                                  _selectedClientName = '';
                                  _selectedClientPhone = '';
                                  _clientFieldController.clear();
                                  _showClientSuggestions = false;
                                }),
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.inputFill,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.rSmall),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.rSmall),
                          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {
                        _showClientSuggestions = v.isNotEmpty;
                        if (_selectedClientId != null && v != _selectedClientName) {
                          _selectedClientId = null;
                          _selectedClientName = '';
                          _selectedClientPhone = '';
                        }
                      }),
                      onSubmitted: (v) {
                        if (filteredClients.length == 1) {
                          final c = filteredClients[0];
                          setState(() {
                            _selectedClientId = c['id'];
                            _selectedClientName = c['name'] ?? '';
                            _selectedClientPhone = c['phone'] ?? '';
                            _clientFieldController.text = c['name'] ?? '';
                            _showClientSuggestions = false;
                          });
                          if (_rows.isNotEmpty) {
                            _rows.first.searchFocusNode.requestFocus();
                          }
                        }
                      },
                    ),
                    if (_showClientSuggestions && filteredClients.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        constraints: const BoxConstraints(maxHeight: 140),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(AppTheme.rSmall),
                          border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filteredClients.length,
                          itemBuilder: (_, i) {
                            final c = filteredClients[i];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.s12),
                              leading: const Icon(Icons.person_outline, color: AppTheme.accent, size: AppTheme.iconSize),
                              title: Text(c['name'] ?? '', style: const TextStyle(color: AppTheme.textP, fontSize: AppTheme.fCaption)),
                              subtitle: c['phone'] != null && c['phone'].toString().isNotEmpty
                                  ? Text(c['phone'], style: const TextStyle(color: AppTheme.textM, fontSize: AppTheme.fSmall))
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedClientId = c['id'];
                                  _selectedClientName = c['name'] ?? '';
                                  _selectedClientPhone = c['phone'] ?? '';
                                  _clientFieldController.text = c['name'] ?? '';
                                  _showClientSuggestions = false;
                                });
                                if (_rows.isNotEmpty) {
                                  _rows.first.searchFocusNode.requestFocus();
                                }
                              },
                            );
                          },
                        ),
                      ),
                    if (_showClientSuggestions && filteredClients.isEmpty && _clientFieldController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(AppTheme.s8),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(AppTheme.rSmall),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Text('لا يوجد عميل بهذا الاسم', style: TextStyle(color: AppTheme.textM, fontSize: AppTheme.fCaption)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _showClientSuggestions = false);
                                _addNewClient();
                              },
                              icon: const Icon(Icons.person_add, size: AppTheme.iconSizeSm),
                              label: const Text('إضافة', style: TextStyle(fontSize: AppTheme.fSmall)),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.s6),
              IconButton(
                onPressed: _addNewClient,
                icon: const Icon(Icons.person_add, color: AppTheme.accent, size: AppTheme.iconSize),
                tooltip: 'إضافة عميل جديد',
              ),
              const SizedBox(width: AppTheme.s4),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedClientId = null;
                  _selectedClientName = 'عميل نقدي';
                  _selectedClientPhone = '';
                  _clientFieldController.text = 'عميل نقدي';
                  _showClientSuggestions = false;
                }),
                icon: const Icon(Icons.payments, size: AppTheme.iconSize),
                label: const Text('نقدي', style: TextStyle(fontSize: AppTheme.fCaption)),
                style: TextButton.styleFrom(
                  foregroundColor: _selectedClientName == 'عميل نقدي' ? AppTheme.accent : AppTheme.textS,
                ),
              ),
            ],
          ),
          if (_selectedClientId != null || _selectedClientName == 'عميل نقدي')
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.s4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: AppTheme.iconSizeSm),
                  const SizedBox(width: AppTheme.s4),
                  Text('العميل: $_selectedClientName', style: const TextStyle(color: AppTheme.textS, fontSize: AppTheme.fCaption)),
                  if (_selectedClientPhone.isNotEmpty) ...[
                    const SizedBox(width: AppTheme.s8),
                    Text(_selectedClientPhone, style: const TextStyle(color: AppTheme.textM, fontSize: AppTheme.fSmall)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── جدول الفاتورة ─────────────────────────────────────────
  Widget _buildInvoiceTable() {
    return Column(
      children: [
        // رأس الجدول
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: AppTheme.s8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            border: Border(bottom: BorderSide(color: AppTheme.accent.withOpacity(0.3), width: 1.5)),
          ),
          child: Row(
            children: [
              _tableHeaderCell('#', 44),
              _tableHeaderCell('المادة', null, flex: 5),
              _tableHeaderCell('الكمية', 80),
              _tableHeaderCell('السعر', 100),
              _tableHeaderCell('الخصم%', 80),
              _tableHeaderCell('الإجمالي', 110),
              _tableHeaderCell('', 40),
            ],
          ),
        ),
        // أسطر الفاتورة
        ...List.generate(_rows.length, (i) => _buildRow(i)),
        // زر إضافة سطر
        Padding(
          padding: const EdgeInsets.all(AppTheme.s8),
          child: TextButton.icon(
            onPressed: _addRowAndFocus,
            icon: const Icon(Icons.add_circle, color: AppTheme.accent, size: AppTheme.iconSize),
            label: const Text('إضافة سطر', style: TextStyle(color: AppTheme.accent, fontSize: AppTheme.fCaption)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(String text, double? width, {int? flex}) {
    final child = Text(text, style: const TextStyle(color: AppTheme.accent, fontSize: AppTheme.fCaption, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    if (flex != null && width == null) {
      return Expanded(flex: flex, child: child);
    }
    return SizedBox(width: width, child: child);
  }

  // ─── سطر الفاتورة ───────────────────────────────────────────
  Widget _buildRow(int index) {
    final row = _rows[index];
    final hasProduct = row.selectedProduct != null;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: hasProduct
            ? AppTheme.accent.withOpacity(0.05)
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: AppTheme.inputFill)),
      ),
      child: Row(
        children: [
          // رقم السطر
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasProduct ? AppTheme.accent.withOpacity(0.2) : AppTheme.inputFill,
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: TextStyle(color: hasProduct ? AppTheme.accent : AppTheme.textM, fontSize: AppTheme.fCaption, fontWeight: FontWeight.w600)),
            ),
          ),
          // حقل البحث عن مادة - باستخدام RawAutocomplete
          Expanded(
            flex: 5,
            child: _buildProductAutocomplete(row, index),
          ),
          const SizedBox(width: 2),
          // الكمية
          SizedBox(
            width: 80,
            child: _rowTextField(
              controller: row.qtyController,
              focusNode: row.qtyFocusNode,
              hint: '1',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) {
                row.priceFocusNode.requestFocus();
              },
              enabled: hasProduct,
            ),
          ),
          const SizedBox(width: 2),
          // السعر
          SizedBox(
            width: 100,
            child: _rowTextField(
              controller: row.priceController,
              focusNode: row.priceFocusNode,
              hint: '0.000',
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) {
                row.discountFocusNode.requestFocus();
              },
              enabled: hasProduct,
            ),
          ),
          const SizedBox(width: 2),
          // الخصم %
          SizedBox(
            width: 80,
            child: _rowTextField(
              controller: row.discountController,
              focusNode: row.discountFocusNode,
              hint: '0%',
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) {
                _addRowAndFocus();
              },
              enabled: hasProduct,
            ),
          ),
          const SizedBox(width: 2),
          // الإجمالي
          SizedBox(
            width: 110,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasProduct && row.rowTotal > 0
                    ? AppTheme.accent.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
              ),
              child: Text(
                row.rowTotal > 0 ? '${row.rowTotal.toStringAsFixed(3)}' : '-',
                style: TextStyle(
                  color: row.rowTotal > 0 ? AppTheme.accent : AppTheme.textM,
                  fontSize: AppTheme.fCaption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // زر حذف
          SizedBox(
            width: 40,
            child: _rows.length > 1
                ? IconButton(
                    onPressed: () => _removeRow(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: AppTheme.iconSize),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // بحث المادة باستخدام RawAutocomplete
  // ✅ تنقل بالأسهم (↑↓) + اختيار بـ Enter + نقر بالماوس
  // ✅ عرض الكمية المتوفرة + تنبيه المخزون المنخفض
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProductAutocomplete(_InvoiceRow row, int rowIndex) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: row.searchController,
      focusNode: row.searchFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return <Map<String, dynamic>>[];
        if (row.selectedProduct != null && textEditingValue.text == row.selectedProduct!['name']) {
          return <Map<String, dynamic>>[];
        }
        return _products.where((p) {
          final name = (p['name'] as String? ?? '').toLowerCase();
          return name.contains(query);
        });
      },
      displayStringForOption: (option) => option['name'] ?? '',
      onSelected: (selection) {
        _selectProduct(row, selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        final stock = row.selectedProduct != null ? _getProductStock(row.selectedProduct!) : 0;
        final isLowStock = stock > 0 && stock <= _lowStockThreshold;
        final isOutOfStock = stock == 0;
        final isNegativeStock = stock < 0;

        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          style: TextStyle(
            color: row.selectedProduct != null ? AppTheme.accent : AppTheme.textP,
            fontSize: AppTheme.fCaption,
            fontWeight: row.selectedProduct != null ? FontWeight.w600 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث عن مادة...',
            hintStyle: const TextStyle(color: AppTheme.textM, fontSize: AppTheme.fSmall),
            prefixIcon: Icon(
              row.selectedProduct != null ? Icons.check_circle : Icons.search,
              color: row.selectedProduct != null
                  ? (isNegativeStock || isOutOfStock ? Colors.redAccent : (isLowStock ? Colors.orange : Colors.green))
                  : AppTheme.textM,
              size: AppTheme.iconSize,
            ),
            suffixIcon: row.selectedProduct != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // عرض الكمية المتوفرة (دائماً - سواء موجبة أو سالبة أو صفر)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s4, vertical: 2),
                        margin: const EdgeInsets.only(left: 4, right: 4),
                        decoration: BoxDecoration(
                          color: isNegativeStock
                              ? Colors.red.withOpacity(0.2)
                              : (isOutOfStock
                                  ? Colors.red.withOpacity(0.2)
                                  : (isLowStock ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15))),
                          borderRadius: BorderRadius.circular(AppTheme.rSmall),
                          border: Border.all(
                            color: isNegativeStock
                                ? Colors.red.withOpacity(0.4)
                                : (isOutOfStock
                                    ? Colors.red.withOpacity(0.4)
                                    : (isLowStock ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3))),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isOutOfStock ? 'نفد' : '$stock',
                          style: TextStyle(
                            color: isNegativeStock
                                ? Colors.redAccent
                                : (isOutOfStock ? Colors.redAccent : (isLowStock ? Colors.orange : Colors.greenAccent)),
                            fontSize: AppTheme.fSmall,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: AppTheme.iconSizeSm),
                        onPressed: () {
                          setState(() {
                            row.selectedProduct = null;
                            row.searchController.clear();
                            row.priceController.clear();
                            row.discountController.clear();
                            row.qtyController.text = '1';
                          });
                          row.searchFocusNode.requestFocus();
                        },
                      ),
                    ],
                  )
                : null,
            filled: true,
            fillColor: AppTheme.inputFill,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.rSmall),
              borderSide: BorderSide(color: row.selectedProduct != null ? AppTheme.accent.withOpacity(0.3) : AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.rSmall),
              borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            isDense: true,
          ),
          onChanged: (v) {
            setState(() {
              if (row.selectedProduct != null && v != row.selectedProduct!['name']) {
                row.selectedProduct = null;
                row.priceController.clear();
                row.discountController.clear();
                row.qtyController.text = '1';
              }
            });
          },
          onSubmitted: (v) {
            onFieldSubmitted();
            if (row.selectedProduct != null) {
              row.qtyFocusNode.requestFocus();
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(AppTheme.rSmall),
            color: AppTheme.bg,
            child: Container(
              width: 380,
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
                border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, spreadRadius: 1)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // عنوان القائمة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rSmall)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2, color: AppTheme.accent, size: AppTheme.iconSize),
                        const SizedBox(width: AppTheme.s6),
                        Text('نتائج البحث (${options.length})', style: const TextStyle(color: AppTheme.accent, fontSize: AppTheme.fSmall, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('↑↓ للتنقل  Enter للاختيار', style: TextStyle(color: AppTheme.textM, fontSize: AppTheme.fTiny)),
                      ],
                    ),
                  ),
                  // قائمة النتائج
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: options.length > 10 ? 10 : options.length,
                      itemBuilder: (_, i) {
                        final p = options.elementAt(i);
                        final pPrice = ((p['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(3);
                        final pCategory = p['category'] as String? ?? '';
                        final pStock = _getProductStock(p);
                        final isLow = pStock > 0 && pStock <= _lowStockThreshold;
                        final isOutOfStock = pStock == 0;
                        final isNegative = pStock < 0;

                        return InkWell(
                          onTap: () => onSelected(p),
                          hoverColor: AppTheme.accent.withOpacity(0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s8),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppTheme.inputFill)),
                              color: isOutOfStock ? Colors.red.withOpacity(0.05) : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOutOfStock || isNegative ? Icons.warning_amber : Icons.inventory_2_outlined,
                                  color: isNegative ? Colors.redAccent : (isOutOfStock ? Colors.redAccent : (isLow ? Colors.orange : AppTheme.accent)),
                                  size: AppTheme.iconSize,
                                ),
                                const SizedBox(width: AppTheme.s8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name'] ?? '', style: TextStyle(color: isOutOfStock || isNegative ? Colors.redAccent : AppTheme.textP, fontSize: AppTheme.fCaption, fontWeight: FontWeight.w500)),
                                      if (pCategory.isNotEmpty)
                                        Text(pCategory, style: const TextStyle(color: AppTheme.textM, fontSize: AppTheme.fTiny)),
                                    ],
                                  ),
                                ),
                                // الكمية المتوفرة (دائماً - سواء موجبة أو سالبة أو صفر)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isNegative
                                        ? Colors.red.withOpacity(0.2)
                                        : (isOutOfStock
                                            ? Colors.red.withOpacity(0.2)
                                            : (isLow ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.1))),
                                    borderRadius: BorderRadius.circular(AppTheme.rSmall),
                                    border: Border.all(
                                      color: isNegative
                                          ? Colors.red.withOpacity(0.4)
                                          : (isOutOfStock
                                              ? Colors.red.withOpacity(0.4)
                                              : (isLow ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.2))),
                                    ),
                                  ),
                                  child: Text(
                                    isOutOfStock ? 'نفد' : '$pStock',
                                    style: TextStyle(
                                      color: isNegative ? Colors.redAccent : (isOutOfStock ? Colors.redAccent : (isLow ? Colors.orange : Colors.greenAccent)),
                                      fontSize: AppTheme.fSmall,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.s6),
                                Text('$pPrice د.ك', style: const TextStyle(color: AppTheme.accent, fontSize: AppTheme.fSmall, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── اختيار مادة من القائمة ─────────────────────────────────
  void _selectProduct(_InvoiceRow row, Map<String, dynamic> product) {
    setState(() {
      row.selectedProduct = product;
      row.searchController.text = product['name'] ?? '';
      final price = (product['price'] as num?)?.toDouble() ?? 0;
      if (row.priceController.text.isEmpty || row.price == 0) {
        row.priceController.text = price.toStringAsFixed(3);
      }
    });

    // تنبيه إذا كانت الكمية منخفضة أو سالبة
    final stock = _getProductStock(product);
    if (stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تحذير: "${product['name']}" المخزون بالسالب ($stock)!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (stock == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تحذير: "${product['name']}" نفد من المخزون!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (stock <= _lowStockThreshold) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تنبيه: "${product['name']}" متبقي $stock فقط!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // نقل التركيز إلى حقل الكمية
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) row.qtyFocusNode.requestFocus();
    });
  }

  // ─── حقل إدخال عادي ────────────────────────────────────────
  Widget _rowTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    String? hint,
    TextAlign textAlign = TextAlign.center,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
    ValueChanged<String>? onFieldSubmitted,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      style: TextStyle(color: enabled ? AppTheme.textP : AppTheme.textM, fontSize: AppTheme.fCaption),
      textAlign: textAlign,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textM, fontSize: AppTheme.fSmall),
        filled: true,
        fillColor: enabled ? AppTheme.inputFill : Colors.transparent,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.rSmall),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.rSmall),
          borderSide: BorderSide(color: AppTheme.surface),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.rSmall),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        isDense: true,
      ),
      onChanged: onChanged,
      onSubmitted: onFieldSubmitted,
    );
  }

  // ─── ذيل الفاتورة ──────────────────────────────────────────
  Widget _buildInvoiceFooter() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.s12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // المجاميع
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _footerRow('المجموع الفرعي', '${_subtotal.toStringAsFixed(3)} د.ك'),
                  if (_totalDiscount > 0)
                    _footerRow('إجمالي الخصم', '- ${_totalDiscount.toStringAsFixed(3)} د.ك', color: AppTheme.danger),
                  const SizedBox(height: AppTheme.s6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.rSmall),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('الصافي: ', style: TextStyle(color: AppTheme.textP, fontSize: AppTheme.fSection, fontWeight: FontWeight.bold)),
                        Text('${_netTotal.toStringAsFixed(3)} د.ك', style: const TextStyle(color: AppTheme.accent, fontSize: AppTheme.fPageTitle, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s8),
          // ملاحظات
          TextField(
            controller: _notesController,
            style: const TextStyle(color: AppTheme.textP, fontSize: AppTheme.fBody),
            maxLines: 1,
            decoration: AppTheme.inputDecoration(hintText: 'ملاحظات...'),
          ),
          const SizedBox(height: AppTheme.s8),

          // ─── قسم الدفع حسب حالة الفاتورة ───────────────────
          if (_currentInvoiceId.isEmpty) ...[
            // فاتورة جديدة: شرائح طريقة الدفع + مبلغ + حفظ
            _buildNewInvoicePaymentSection(),
          ] else if (_paymentStatus == 'paid') ...[
            // فاتورة محفوظة مدفوعة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: AppTheme.success, size: AppTheme.iconSize),
                SizedBox(width: AppTheme.s4),
                Text('مدفوعة', style: TextStyle(color: AppTheme.success, fontSize: AppTheme.fBody, fontWeight: FontWeight.bold)),
              ]),
            ),
          ] else ...[
            // فاتورة محفوظة غير مدفوعة / جزئية: بطاقة الدفع
            PaymentCard(
              uid: widget.uid,
              totalAmount: _netTotal,
              invoiceId: _currentInvoiceId,
              invoiceType: 'sales',
              customerData: _selectedClientId != null ? {
                'id': _selectedClientId,
                'name': _selectedClientName,
                'nameAr': _selectedClientName,
                'phone': _selectedClientPhone,
              } : null,
              onPaymentComplete: () {
                // إعادة تحميل بيانات الفاتورة لتحديث حالة الدفع
                if (_currentInvoiceIndex >= 0) {
                  _goToInvoiceByIndex(_currentInvoiceIndex);
                }
              },
            ),
          ],

          const SizedBox(height: AppTheme.s8),
          // أزرار الطباعة + فاتورة جديدة (دائماً ظاهرة)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _printInvoice,
                icon: const Icon(Icons.print, size: AppTheme.iconSize),
                label: const Text('طباعة'),
                style: AppTheme.secondaryButton,
              ),
              const SizedBox(width: AppTheme.s8),
              OutlinedButton.icon(
                onPressed: _newInvoice,
                icon: const Icon(Icons.add_circle_outline, size: AppTheme.iconSize),
                label: const Text('فاتورة جديدة'),
                style: AppTheme.secondaryButton,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── قسم دفع الفاتورة الجديدة (inline) ─────────────────────
  Widget _buildNewInvoicePaymentSection() {
    return Column(
      children: [
        // شرائح طريقة الدفع
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('طريقة الدفع', style: TextStyle(fontSize: AppTheme.fCaption, color: AppTheme.textS)),
            const SizedBox(height: AppTheme.s4),
            Row(
              children: _paymentMethods.map((method) {
                final isSelected = _paymentMethod == method['code'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => setState(() {
                        _paymentMethod = method['code'] as String;
                        if (_paymentMethod == 'credit') {
                          _paymentAmountController.text = '0.000';
                        } else {
                          _paymentAmountController.text = _netTotal.toStringAsFixed(3);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.s4, horizontal: AppTheme.s4),
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
                            Icon(method['icon'] as IconData,
                                size: AppTheme.iconSizeSm,
                                color: isSelected ? Colors.white : AppTheme.textS),
                            const SizedBox(width: AppTheme.s4),
                            Flexible(
                              child: Text(method['ar'] as String,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppTheme.fSmall,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? Colors.white : AppTheme.textS,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.s6),
        // حقل المبلغ (لغير الآجل)
        if (_paymentMethod != 'credit') ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _paymentAmountController,
                  style: const TextStyle(fontSize: AppTheme.fBody, fontWeight: FontWeight.w600, color: AppTheme.textP),
                  decoration: AppTheme.inputDecoration(
                    hintText: 'المبلغ',
                    suffixText: 'د.ك',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppTheme.s4),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _paymentAmountController.text = _netTotal.toStringAsFixed(3);
                    });
                  },
                  child: Container(
                    height: AppTheme.inputHeight,
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.rSmall),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fullscreen_outlined, size: AppTheme.iconSizeSm, color: AppTheme.textS),
                        const SizedBox(width: AppTheme.s4),
                        Text('الكل', style: TextStyle(fontSize: AppTheme.fSmall, color: AppTheme.textS)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s4),
          // عرض معلومات المتبقي
          Builder(builder: (context) {
            final entered = double.tryParse(_paymentAmountController.text) ?? 0;
            final remaining = _netTotal - entered;
            if (remaining > 0.001) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.rSmall),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_outlined, size: AppTheme.iconSizeSm, color: AppTheme.warning),
                    const SizedBox(width: AppTheme.s4),
                    Text('آجل: ${remaining.toStringAsFixed(3)} د.ك', style: TextStyle(fontSize: AppTheme.fSmall, color: AppTheme.warning)),
                    const Spacer(),
                    Text('يُسجّل على العميل', style: TextStyle(fontSize: AppTheme.fTiny, color: AppTheme.textM)),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s4),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: AppTheme.iconSizeSm, color: AppTheme.success),
                  const SizedBox(width: AppTheme.s6),
                  Text('دفع كامل', style: TextStyle(fontSize: AppTheme.fBody, color: AppTheme.success, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }),
          const SizedBox(height: AppTheme.s6),
        ],
        // زر الحفظ
        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight + 4,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveInvoice,
            style: AppTheme.primaryButton,
            child: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, size: AppTheme.iconSize),
                      SizedBox(width: AppTheme.s6),
                      Text('حفظ الفاتورة'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _footerRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: AppTheme.textS, fontSize: AppTheme.fCaption)),
          Text(value, style: TextStyle(color: color ?? AppTheme.textP, fontSize: AppTheme.fCaption, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // دفتر الأستاذ – Ledger
  // ═══════════════════════════════════════════════════════════════
  String _getLedgerAccount(String paymentMethod) {
    switch (paymentMethod) {
      case 'cash':
        return 'الصندوق';
      case 'knet':
        return 'كي نت';
      case 'bank':
        return 'البنك';
      case 'my_invoice':
      case 'myinvoice':
        return 'ماي فاتوره';
      case 'credit':
        return 'عملاء آجلون';
      default:
        return 'الصندوق';
    }
  }

  String _getPaymentMethodAr(String paymentMethod) {
    switch (paymentMethod) {
      case 'cash':
        return 'كاش';
      case 'knet':
        return 'كي نت';
      case 'bank':
        return 'تحويل بنكي';
      case 'my_invoice':
      case 'myinvoice':
        return 'ماي فاتوره';
      case 'credit':
        return 'آجل';
      default:
        return 'كاش';
    }
  }

  Future<void> _updateLedger(String account, double amount, String timestamp, String invoiceId) async {
    try {
      await ApiService.post('/api/accounts', body: {
        'businessId': widget.uid,
        'accountName': account,
        'entry': {
          'type': 'debit',
          'amount': amount,
          'description': 'فاتورة مبيعات #$invoiceId',
          'invoiceId': invoiceId,
          'paymentMethod': _paymentMethod,
          'createdAt': timestamp,
        },
      });
    } catch (e) {
      debugPrint('Error updating ledger: $e');
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════
// موديل سطر الفاتورة – مع FocusNodes للتنقل التلقائي
// ═══════════════════════════════════════════════════════════════

class _InvoiceRow {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discountController = TextEditingController();

  final FocusNode searchFocusNode = FocusNode();
  final FocusNode qtyFocusNode = FocusNode();
  final FocusNode priceFocusNode = FocusNode();
  final FocusNode discountFocusNode = FocusNode();

  Map<String, dynamic>? selectedProduct;

  int get quantity => int.tryParse(qtyController.text) ?? 1;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get discount => double.tryParse(discountController.text) ?? 0;
  double get discountAmount => price * quantity * (discount / 100);
  double get rowTotal => (price * quantity) - discountAmount;

  void dispose() {
    searchController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
    searchFocusNode.dispose();
    qtyFocusNode.dispose();
    priceFocusNode.dispose();
    discountFocusNode.dispose();
  }
}
