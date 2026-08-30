import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/cross_platform_utils.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة فاتورة المبيعات – Sales Invoice (إصدار 6)
// ✅ بحث مواد بـ RawAutocomplete (تنقل بالأسهم + نقر + Enter)
// ✅ تنقل تلقائي: مادة → كمية → سعر → خصم → سطر جديد
// ✅ رقم فاتورة تلقائي + زر طباعة + عرض الكمية المتوفرة
// ✅ إشعار قرب انتهاء المخزون
// ═══════════════════════════════════════════════════════════════

class BusinessSalesInvoice extends StatefulWidget {
  final String uid;
  final String? initialInvoiceId;
  const BusinessSalesInvoice({super.key, required this.uid, this.initialInvoiceId});

  @override
  State<BusinessSalesInvoice> createState() => _BusinessSalesInvoiceState();
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
  bool _loading = true;
  bool _saving = false;

  // رقم الفاتورة
  int _invoiceNumber = 0;
  String _currentInvoiceId = '';

  // طريقة الدفع
  String _paymentMethod = 'cash'; // cash | knet | bank

  // تنقل بين الفواتير
  List<String> _invoiceIds = [];
  int _currentInvoiceIndex = -1;

  // عتبة تنبيه المخزون
  static const int _lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _clientFieldController.dispose();
    _notesController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  // ─── تحميل البيانات ─────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.collection(kColBusinesses).doc(widget.uid).get(),
        ApiService.collection('business_clients').doc(widget.uid).collection('items').get(),
        ApiService.collection('business_invoices')
            .where('businessId', isEqualTo: widget.uid)
            .where('type', isEqualTo: 'sales')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get(),
      ]);

      if (mounted) {
        setState(() {
          _businessData = (results[0] as DocumentSnapshot).exists
              ? (results[0] as DocumentSnapshot).data() as Map<String, dynamic> : {};
          _clients = (results[1] as QuerySnapshot).docs.map((d) { final m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m; }).toList();
          _invoiceIds = (results[2] as QuerySnapshot).docs.map((d) => d.id).toList();
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
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── تحميل رقم الفاتورة التالي ──────────────────────────────
  Future<void> _loadNextInvoiceNumber() async {
    try {
      final counterRef = ApiService
          .collection('business_counters')
          .doc(widget.uid);

      final counterDoc = await counterRef.get();
      if (counterDoc.exists) {
        final data = counterDoc.data()!;
        setState(() {
          _invoiceNumber = (data['salesInvoiceNumber'] as num?)?.toInt() ?? 0;
        });
      } else {
        // حساب من الفواتير الموجودة
        final snap = await ApiService
            .collection('business_invoices')
            .where('businessId', isEqualTo: widget.uid)
            .where('type', isEqualTo: 'sales')
            .get();
        setState(() {
          _invoiceNumber = snap.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading invoice number: $e');
    }
  }

  // ─── تحديث قائمة المنتجات من الـ Stream ─────────────────
  void _updateProductsFromSnapshot(QuerySnapshot snap) {
    final products = snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
    if (_products.length != products.length || _products != products) {
      _products = products;
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
        const SnackBar(content: Text('اختر عميل أو اختر عميل نقدي'), backgroundColor: Colors.orange)
      );
      return;
    }

    final filledRows = _rows.where((r) => r.selectedProduct != null && r.price > 0).toList();
    if (filledRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مادة واحدة على الأقل'), backgroundColor: Colors.orange)
      );
      return;
    }

    // التحقق من توفر الكمية في المخزون
    for (final row in filledRows) {
      final stockQty = _getProductStock(row.selectedProduct!);
      if (stockQty >= 0 && row.quantity > stockQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الكمية المطلوبة من "${row.selectedProduct!['name']}" (${$row.quantity}) أكبر من المتوفر ($stockQty)'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          )
        );
        return;
      }
    }

    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    setState(() {
      _saving = true;
      _paymentMethod = paymentMethod;
    });

    try {
      final now = DateTime.now().toIso8601String();
      final invoiceId = ApiService.collection('business_invoices').doc().id;

      // زيادة رقم الفاتورة
      final newInvoiceNumber = _invoiceNumber + 1;

      final itemsData = filledRows.map((r) => {
        'productId': r.selectedProduct!['id'],
        'itemName': r.selectedProduct!['name'] ?? '',
        'quantity': r.quantity,
        'unitPrice': r.price,
        'discount': r.discount,
        'discountAmount': r.discountAmount,
        'total': r.rowTotal
      }).toList();

      final clientName = _selectedClientName.isEmpty ? 'عميل نقدي' : _selectedClientName;

      await ApiService.collection('business_invoices').doc(invoiceId).set({
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
        'status': 'paid',
        'createdAt': now
      });

      // تحديث عداد رقم الفاتورة
      final counterRef = ApiService.collection('business_counters').doc(widget.uid);
      await counterRef.set({
        'salesInvoiceNumber': newInvoiceNumber
      }, SetOptions(merge: true));

      // تحديث المخزون - تقليل كمية المواد المباعة
      for (final row in filledRows) {
        final productId = row.selectedProduct!['id'];
        await ApiService.collection(kColProducts).doc(productId).update({
          'stockQuantity': FieldValue.increment(-row.quantity)
        });
      }

      final String ledgerAccount = _getLedgerAccount(_paymentMethod);
      final String paymentMethodAr = _getPaymentMethodAr(_paymentMethod);

      await ApiService.collection('business_transactions').add({
        'businessId': widget.uid,
        'type': 'income',
        'amount': _netTotal,
        'category': 'مبيعات',
        'description': 'فاتورة مبيعات #$newInvoiceNumber - $paymentMethodAr',
        'invoiceId': invoiceId,
        'clientId': _selectedClientId,
        'paymentMethod': _paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now
      });

      await _updateLedger(ledgerAccount, _netTotal, now, invoiceId);

      if (_selectedClientId != null) {
        await ApiService
            .collection('business_clients')
            .doc(widget.uid)
            .collection('items')
            .doc(_selectedClientId)
            .update({
          'totalPurchases': FieldValue.increment(_netTotal),
          'lastPurchaseAt': now,
          'invoiceCount': FieldValue.increment(1)
        });
      } else if (clientName != 'عميل نقدي' && clientName.isNotEmpty) {
        await ApiService.collection('business_clients').doc(widget.uid).collection('items').add({
          'name': clientName,
          'phone': _selectedClientPhone,
          'totalPurchases': _netTotal,
          'lastPurchaseAt': now,
          'invoiceCount': 1,
          'createdAt': now
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الفاتورة #$newInvoiceNumber بنجاح'), backgroundColor: Colors.green)
        );
        _newInvoice();
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

  void _newInvoice() {
    for (final r in _rows) { r.dispose(); }
    setState(() {
      _rows = [_InvoiceRow()];
      _selectedClientId = null;
      _selectedClientName = '';
      _selectedClientPhone = '';
      _clientFieldController.clear();
      _notesController.clear();
      _currentInvoiceIndex = -1;
      _currentInvoiceId = '';
      _showClientSuggestions = false;
      _invoiceNumber++;
    });
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
        body { padding: 20px; color: #001F3F; background: #fff; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #001F3F; padding-bottom: 16px; margin-bottom: 20px; }
        .business-name { font-size: 22px; font-weight: 700; color: #001F3F; }
        .business-info { font-size: 12px; color: #666; margin-top: 4px; }
        .invoice-title { text-align: left; }
        .invoice-title h2 { font-size: 14px; color: #001F3F; }
        .invoice-title p { font-size: 12px; color: #666; }
        .client-info { background: #f8f9fa; border-radius: 8px; padding: 12px; margin-bottom: 16px; }
        .client-info span { font-weight: 600; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
        th { background: #001F3F; color: #FFD700; padding: 10px; font-size: 13px; text-align: center; }
        td { font-size: 13px; }
        .totals { text-align: left; direction: ltr; }
        .totals div { margin: 4px 0; font-size: 14px; }
        .net-total { font-size: 20px; font-weight: 700; color: #001F3F; background: #FFF8E1; padding: 10px 20px; border-radius: 8px; display: inline-block; margin-top: 8px; }
        .notes { margin-top: 16px; font-size: 12px; color: #666; }
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
      <div style="margin-top:24px;font-size:11px;color:#999;text-align:center">شكراً لتعاملكم معنا</div>
    </body>
    </html>
    ''';

    await CrossPlatformUtils.openHtmlContent(htmlContent, 'sales_invoice_$invoiceNumStr.html');
  }

  // ─── الحصول على كمية المخزون ────────────────────────────────
  int _getProductStock(Map<String, dynamic> product) {
    return (product['stockQuantity'] as num?)?.toInt() ?? -1; // -1 يعني غير محدد
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
      final doc = await ApiService.collection('business_invoices').doc(_invoiceIds[newIndex]).get();
      if (!doc.exists) return;
      final data = doc.data()!;

      for (final r in _rows) { r.dispose(); }

      setState(() {
        _currentInvoiceIndex = newIndex;
        _currentInvoiceId = doc.id;
        _currentInvoiceNumber = data['invoiceNumber'];
        _selectedClientId = data['clientId'];
        _selectedClientName = data['clientName'] ?? 'عميل نقدي';
        _selectedClientPhone = data['clientPhone'] ?? '';
        _clientFieldController.text = _selectedClientName;
        _notesController.text = data['notes'] ?? '';
        _showClientSuggestions = false;
        _paymentMethod = data['paymentMethod'] ?? 'cash';

        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        _rows = [];
        for (final item in items) {
          final row = _InvoiceRow();
          final matchedProduct = _products.firstWhere(
            (p) => p['id'] == item['productId'],
            orElse: () => <String, dynamic>{}
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
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('إضافة عميل جديد', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'اسم العميل',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'رقم الهاتف',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {'name': nameController.text.trim(), 'phone': phoneController.text.trim()});
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F)),
            child: const Text('إضافة'),
          ),
        ],
      )
    );

    if (result != null) {
      try {
        final docRef = await ApiService
            .collection('business_clients')
            .doc(widget.uid)
            .collection('items')
            .add({
          'name': result['name'],
          'phone': result['phone'] ?? '',
          'totalPurchases': 0,
          'invoiceCount': 0,
          'createdAt': DateTime.now().toIso8601String()
        });

        setState(() {
          _clients.add({'id': docRef.id, 'name': result['name'], 'phone': result['phone'] ?? ''});
          _selectedClientId = docRef.id;
          _selectedClientName = result['name']!;
          _selectedClientPhone = result['phone'] ?? '';
          _clientFieldController.text = result['name']!;
          _showClientSuggestions = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red)
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
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('إضافة مادة جديدة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اسم المادة',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.inventory_2, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'السعر (د.ك)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'الكمية المتوفرة',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.warehouse, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'الفئة (اختياري)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.category, color: Colors.white38, size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'price': priceController.text.trim(),
                'category': categoryController.text.trim(),
                'stock': stockController.text.trim()
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0071E3),
              foregroundColor: const Color(0xFF1D1D1F),
            ),
            child: const Text('إضافة'),
          ),
        ],
      )
    );

    if (result != null) {
      try {
        final double price = double.tryParse(result['price'] ?? '') ?? 0;
        final int stock = int.tryParse(result['stock'] ?? '') ?? 0;
        final docRef = await ApiService.collection(kColProducts).add({
          'businessId': widget.uid,
          'name': result['name'],
          'price': price,
          'category': result['category'] ?? '',
          'stockQuantity': stock,
          'isActive': true,
          'createdAt': DateTime.now().toIso8601String()
        });

        final newProduct = {
          'id': docRef.id,
          'name': result['name'],
          'price': price,
          'category': result['category'] ?? '',
          'stockQuantity': stock,
          'businessId': widget.uid
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
            SnackBar(content: Text('تم إضافة "${result['name']}" بنجاح'), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red)
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: ApiService
          .collection(kColProducts)
          .where('businessId', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, productsSnap) {
        if (productsSnap.hasData) {
          _updateProductsFromSnapshot(productsSnap.data!);
        }
        return Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
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
          ]
        );
      }
    );
  }

  // ─── شريط الأدوات ──────────────────────────────────────────
  Widget _buildToolbar() {
    final invoiceLabel = _currentInvoiceIndex == -1
        ? 'فاتورة مبيعات جديدة #${_invoiceNumber + 1}'
        : 'فاتورة #${_currentInvoiceNumber ?? _invoiceIds[_currentInvoiceIndex].substring(0, 8)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Color(0xFF0071E3), size: 20),
          const SizedBox(width: 8),
          Text(
            invoiceLabel,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // زر الطباعة
          IconButton(
            onPressed: _printInvoice,
            icon: const Icon(Icons.print, size: 20),
            color: const Color(0xFF0071E3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'طباعة الفاتورة',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _invoiceIds.isNotEmpty && _currentInvoiceIndex < _invoiceIds.length - 1 ? () => _goToInvoice(1) : null,
            icon: const Icon(Icons.arrow_upward, size: 14),
            color: const Color(0xFF0071E3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'فاتورة أحدث',
          ),
          Text(
            '${_currentInvoiceIndex + 1}/${_invoiceIds.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          IconButton(
            onPressed: _currentInvoiceIndex > 0 ? () => _goToInvoice(-1) : null,
            icon: const Icon(Icons.arrow_downward, size: 14),
            color: const Color(0xFF0071E3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'فاتورة أقدم',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _newInvoice,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            color: const Color(0xFF0071E3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'فاتورة جديدة',
          ),
          IconButton(
            onPressed: () => _addNewProduct(_rows.firstWhere((r) => r.selectedProduct == null, orElse: () => _rows.last)),
            icon: const Icon(Icons.add_box_outlined, size: 20),
            color: const Color(0xFF0071E3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'إضافة مادة جديدة',
          ),
        ],
      )
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0071E3).withOpacity(0.1),
              border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3), width: 2),
            ),
            child: bLogo.isNotEmpty
                ? ClipOval(child: Image.network(bLogo, width: 52, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 26, color: Color(0xFF0071E3))))
                : const Icon(Icons.store, size: 26, color: Color(0xFF0071E3)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bName, style: const TextStyle(color: Color(0xFF0071E3), fontSize: 13, fontWeight: FontWeight.bold)),
                if (bPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [Icon(Icons.phone, color: Colors.white38, size: 11), const SizedBox(width: 4), Text(bPhone, style: TextStyle(color: Colors.white54, fontSize: 11))]),
                ],
                if (bAddress.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Row(children: [Icon(Icons.location_on, color: Colors.white38, size: 11), const SizedBox(width: 4), Text(bAddress, style: TextStyle(color: Colors.white54, fontSize: 11))]),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('فاتورة مبيعات', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('رقم: $invoiceNumStr', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_formatDate(DateTime.now()), style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      )
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF0071E3), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _clientFieldController,
                      style: TextStyle(
                        color: _selectedClientId != null ? const Color(0xFF0071E3) : Colors.white,
                        fontSize: 14,
                        fontWeight: _selectedClientId != null ? FontWeight.bold : FontWeight.normal,
                      ),
                      decoration: InputDecoration(
                        hintText: 'اسم العميل أو رقم الهاتف...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 14),
                        suffixIcon: _selectedClientId != null
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
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
                        fillColor: Colors.white.withOpacity(0.06),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF0071E3), width: 1.5),
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
                          color: const Color(0xFF1D1D1F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8)],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filteredClients.length,
                          itemBuilder: (_, i) {
                            final c = filteredClients[i];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              leading: const Icon(Icons.person_outline, color: Color(0xFF0071E3), size: 16),
                              title: Text(c['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                              subtitle: c['phone'] != null && c['phone'].toString().isNotEmpty
                                  ? Text(c['phone'], style: const TextStyle(color: Colors.white38, fontSize: 10))
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
                              }
                            );
                          },
                        ),
                      ),
                    if (_showClientSuggestions && filteredClients.isEmpty && _clientFieldController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1D1F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            const Text('لا يوجد عميل بهذا الاسم', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _showClientSuggestions = false);
                                _addNewClient();
                              },
                              icon: const Icon(Icons.person_add, size: 14),
                              label: const Text('إضافة', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF0071E3)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _addNewClient,
                icon: const Icon(Icons.person_add, color: Color(0xFF0071E3), size: 22),
                tooltip: 'إضافة عميل جديد',
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedClientId = null;
                  _selectedClientName = 'عميل نقدي';
                  _selectedClientPhone = '';
                  _clientFieldController.text = 'عميل نقدي';
                  _showClientSuggestions = false;
                }),
                icon: const Icon(Icons.payments, size: 16),
                label: const Text('نقدي', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: _selectedClientName == 'عميل نقدي' ? const Color(0xFF0071E3) : Colors.white54,
                ),
              ),
            ],
          ),
          if (_selectedClientId != null || _selectedClientName == 'عميل نقدي')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Text('العميل: $_selectedClientName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  if (_selectedClientPhone.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(_selectedClientPhone, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ],
              ),
            ),
        ],
      )
    );
  }

  // ─── جدول الفاتورة ─────────────────────────────────────────
  Widget _buildInvoiceTable() {
    return Column(
      children: [
        // رأس الجدول
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0071E3).withOpacity(0.12),
            border: Border(bottom: BorderSide(color: const Color(0xFF0071E3).withOpacity(0.3), width: 1.5)),
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
          padding: const EdgeInsets.all(8),
          child: TextButton.icon(
            onPressed: _addRowAndFocus,
            icon: const Icon(Icons.add_circle, color: Color(0xFF0071E3), size: 20),
            label: const Text('إضافة سطر', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
          ),
        ),
      ]
    );
  }

  Widget _tableHeaderCell(String text, double? width, {int? flex}) {
    final child = Text(text, style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
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
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: hasProduct
            ? const Color(0xFF0071E3).withOpacity(0.05)
            : Colors.white.withOpacity(0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
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
                color: hasProduct ? const Color(0xFF0071E3).withOpacity(0.2) : Colors.white.withOpacity(0.06),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: TextStyle(color: hasProduct ? const Color(0xFF0071E3) : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
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
                    ? const Color(0xFF0071E3).withOpacity(0.1)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.rowTotal > 0 ? '${row.rowTotal.toStringAsFixed(3)}' : '-',
                style: TextStyle(
                  color: row.rowTotal > 0 ? const Color(0xFF0071E3) : Colors.white24,
                  fontSize: 13,
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
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  )
                : null,
          ),
        ],
      )
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
        if (query.isEmpty) return const Iterable.empty>();
        if (row.selectedProduct != null && textEditingValue.text == row.selectedProduct!['name']) {
          return const Iterable.empty>();
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
        final stock = row.selectedProduct != null ? _getProductStock(row.selectedProduct!) : -1;
        final isLowStock = stock >= 0 && stock <= _lowStockThreshold;

        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          style: TextStyle(
            color: row.selectedProduct != null ? const Color(0xFF0071E3) : Colors.white,
            fontSize: 13,
            fontWeight: row.selectedProduct != null ? FontWeight.w600 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث عن مادة...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            prefixIcon: Icon(
              row.selectedProduct != null ? Icons.check_circle : Icons.search,
              color: row.selectedProduct != null
                  ? (isLowStock ? Colors.orange : Colors.green)
                  : Colors.white38,
              size: 16,
            ),
            suffixIcon: row.selectedProduct != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // عرض الكمية المتوفرة
                      if (stock >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4, right: 4),
                          decoration: BoxDecoration(
                            color: isLowStock
                                ? Colors.red.withOpacity(0.2)
                                : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isLowStock
                                  ? Colors.red.withOpacity(0.4)
                                  : Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$stock',
                            style: TextStyle(
                              color: isLowStock ? Colors.redAccent : Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 14),
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
            fillColor: Colors.white.withOpacity(0.06),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: row.selectedProduct != null ? const Color(0xFF0071E3).withOpacity(0.3) : Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF0071E3), width: 1.5),
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
          }
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1D1D1F),
            child: Container(
              width: 380,
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.4)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // عنوان القائمة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0071E3).withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2, color: Color(0xFF0071E3), size: 14),
                        const SizedBox(width: 6),
                        Text('نتائج البحث (${options.length})', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('↑↓ للتنقل  Enter للاختيار', style: TextStyle(color: Colors.white38, fontSize: 9)),
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
                        final pStock = (p['stockQuantity'] as num?)?.toInt() ?? -1;
                        final isLow = pStock >= 0 && pStock <= _lowStockThreshold;
                        final isOutOfStock = pStock == 0;

                        return InkWell(
                          onTap: () => onSelected(p),
                          hoverColor: const Color(0xFF0071E3).withOpacity(0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                              color: isOutOfStock ? Colors.red.withOpacity(0.05) : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOutOfStock ? Icons.warning_amber : Icons.inventory_2_outlined,
                                  color: isOutOfStock ? Colors.redAccent : (isLow ? Colors.orange : const Color(0xFF0071E3)),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name'] ?? '', style: TextStyle(color: isOutOfStock ? Colors.redAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                      if (pCategory.isNotEmpty)
                                        Text(pCategory, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                                    ],
                                  ),
                                ),
                                // الكمية المتوفرة
                                if (pStock >= 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? Colors.red.withOpacity(0.2)
                                          : (isLow ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isOutOfStock
                                            ? Colors.red.withOpacity(0.4)
                                            : (isLow ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.2)),
                                      ),
                                    ),
                                    child: Text(
                                      isOutOfStock ? 'نفد' : '$pStock',
                                      style: TextStyle(
                                        color: isOutOfStock ? Colors.redAccent : (isLow ? Colors.orange : Colors.greenAccent),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Text('$pPrice د.ك', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        );
      }
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

    // تنبيه إذا كانت الكمية منخفضة
    final stock = _getProductStock(product);
    if (stock == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تحذير: "${product['name']}" نفد من المخزون!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        )
      );
    } else if (stock > 0 && stock <= _lowStockThreshold) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تنبيه: "${product['name']}" متبقي $stock فقط!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        )
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
    bool enabled = true
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.white24, fontSize: 13),
      textAlign: textAlign,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: enabled ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF0071E3), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        isDense: true,
      ),
      onChanged: onChanged,
      onSubmitted: onFieldSubmitted
    );
  }

  // ─── ذيل الفاتورة ──────────────────────────────────────────
  Widget _buildInvoiceFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _footerRow('المجموع الفرعي', '${_subtotal.toStringAsFixed(3)} د.ك'),
                  if (_totalDiscount > 0)
                    _footerRow('إجمالي الخصم', '- ${_totalDiscount.toStringAsFixed(3)} د.ك', color: Colors.redAccent),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0071E3).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('الصافي: ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('${_netTotal.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'ملاحظات...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          if (_paymentMethod != 'cash')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _paymentMethod == 'knet' ? Colors.blue.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _paymentMethod == 'knet' ? Colors.blue.withOpacity(0.3) : Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_paymentMethod == 'knet' ? Icons.credit_card : Icons.account_balance, color: _paymentMethod == 'knet' ? Colors.blue : Colors.purple, size: 16),
                  const SizedBox(width: 6),
                  Text('طريقة الدفع: ${_getPaymentMethodAr(_paymentMethod)}', style: TextStyle(color: _paymentMethod == 'knet' ? Colors.blue : Colors.purple, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveInvoice,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D1D1F)))
                    : const Icon(Icons.save, size: 14),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الفاتورة', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _printInvoice,
                icon: const Icon(Icons.print, size: 14),
                label: const Text('طباعة', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0071E3),
                  side: const BorderSide(color: Color(0xFF0071E3)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _newInvoice,
                icon: const Icon(Icons.add_circle_outline, size: 14),
                label: const Text('فاتورة جديدة', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      )
    );
  }

  Widget _footerRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      )
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // حوار طريقة الدفع
  // ═══════════════════════════════════════════════════════════════
  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Column(
          children: [
            const Icon(Icons.payment, color: Color(0xFF0071E3), size: 32),
            const SizedBox(height: 8),
            const Text('طريقة الدفع', style: TextStyle(color: Color(0xFF0071E3), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('الإجمالي: ${_netTotal.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _paymentMethodOption(ctx, 'cash', Icons.payments, 'كاش', 'دفع نقداً', Colors.green),
            const SizedBox(height: 10),
            _paymentMethodOption(ctx, 'knet', Icons.credit_card, 'كي نت', 'دفع عبر شبكة كي نت', Colors.blue),
            const SizedBox(height: 10),
            _paymentMethodOption(ctx, 'bank', Icons.account_balance, 'تحويل بنكي', 'تحويل لحساب بنكي', Colors.purple),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white38)),
          ),
        ],
      )
    );
  }

  Widget _paymentMethodOption(BuildContext ctx, String value, IconData icon, String title, String subtitle, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios, color: color.withOpacity(0.5), size: 16),
          ],
        ),
      )
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
      default:
        return 'كاش';
    }
  }

  Future<void> _updateLedger(String account, double amount, FieldValue timestamp, String invoiceId) async {
    final ledgerRef = ApiService
        .collection('business_ledger')
        .doc(widget.uid)
        .collection('accounts')
        .doc(account);

    try {
      final doc = await ledgerRef.get();

      if (doc.exists) {
        await ledgerRef.update({
          'balance': FieldValue.increment(amount),
          'totalDebit': FieldValue.increment(amount),
          'lastTransactionAt': timestamp,
          'transactionCount': FieldValue.increment(1)
        });
      } else {
        await ledgerRef.set({
          'accountName': account,
          'businessId': widget.uid,
          'balance': amount,
          'totalDebit': amount,
          'totalCredit': 0,
          'transactionCount': 1,
          'lastTransactionAt': timestamp,
          'createdAt': timestamp
        });
      }

      await ledgerRef.collection('entries').add({
        'type': 'debit',
        'amount': amount,
        'description': 'فاتورة مبيعات #$invoiceId',
        'invoiceId': invoiceId,
        'paymentMethod': _paymentMethod,
        'createdAt': timestamp
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
