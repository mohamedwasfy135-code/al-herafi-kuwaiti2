import 'dart:ui' as ui;
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/myfatoorah_service.dart';

class BusinessCreateInvoice extends StatefulWidget {
  final String uid;
  const BusinessCreateInvoice({super.key, required this.uid});

  @override
  State<BusinessCreateInvoice> createState() => _BusinessCreateInvoiceState();
}

class _BusinessCreateInvoiceState extends State<BusinessCreateInvoice> {
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');

  String _paymentType = 'cash';

  // المنتجات المختارة
  final List<Map<String, dynamic>> _selectedProducts = [];
  final Map<String, int> _quantities = {};
  final Map<String, double> _customPrices = {}; // أسعار مخصصة
  final Map<String, TextEditingController> _priceControllers = {};

  bool _loadingProducts = true;
  List<Map<String, dynamic>> _allProducts = [];
  String _searchQuery = '';

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _notesCtrl.dispose();
    _discountCtrl.dispose();
    for (final ctrl in _priceControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final res = await ApiService.get('/api/products', queryParameters: {'businessId': widget.uid, 'status': 'approved'});
    if (res.success && res.data != null) {
      final list = res.data!['products'] ?? res.data!['data'];
      if (list is List) {
        if (mounted) {
          setState(() {
            _allProducts = list.cast<Map<String, dynamic>>();
            _loadingProducts = false;
          });
        }
        return;
      }
    }
    if (mounted) setState(() => _loadingProducts = false);
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return _allProducts;
    return _allProducts.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final sku = (d['sku'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || sku.contains(query);
    }).toList();
  }

  /// السعر الفعلي للمنتج (مخصص أو أصلي)
  double getProductPrice(String id, Map<String, dynamic> product) {
    if (_customPrices.containsKey(id)) {
      return _customPrices[id]!;
    }
    return (product['discountedPrice'] ?? product['originalPrice'] ?? 0).toDouble();
  }

  double get _subtotal {
    double total = 0;
    for (final p in _selectedProducts) {
      final price = getProductPrice(p['id'], p);
      final qty = _quantities[p['id']] ?? 1;
      total += price * qty;
    }
    return total;
  }

  double get _discountAmount {
    return double.tryParse(_discountCtrl.text) ?? 0;
  }

  double get _totalAmount => _subtotal - _discountAmount;

  void _toggleProduct(Map<String, dynamic> product) {
    final id = product['id'] as String;
    setState(() {
      if (_selectedProducts.any((p) => p['id'] == id)) {
        _selectedProducts.removeWhere((p) => p['id'] == id);
        _quantities.remove(id);
        _customPrices.remove(id);
        _priceControllers[id]?.dispose();
        _priceControllers.remove(id);
      } else {
        _selectedProducts.add(product);
        _quantities[id] = 1;
        final originalPrice = (product['discountedPrice'] ?? product['originalPrice'] ?? 0).toDouble();
        _customPrices[id] = originalPrice;
        _priceControllers[id] = TextEditingController(text: originalPrice.toStringAsFixed(3));
      }
    });
  }

  bool _isSelected(String id) => _selectedProducts.any((p) => p['id'] == id);

  /// تحديث السعر المخصص
  void _updateCustomPrice(String id, String value) {
    final price = double.tryParse(value) ?? 0;
    setState(() {
      _customPrices[id] = price;
    });
  }

  Future<void> _createInvoice() async {
    if (_clientNameCtrl.text.trim().isEmpty) {
      _snack('الرجاء إدخال اسم العميل');
      return;
    }
    if (_selectedProducts.isEmpty) {
      _snack('الرجاء اختيار منتج واحد على الأقل');
      return;
    }
    if (_totalAmount <= 0) {
      _snack('إجمالي الفاتورة يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() => _loadingProducts = true);

    final invoiceNumber = 'INV-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final products = _selectedProducts.map((p) {
      final id = p['id'];
      return {
        'productId': id,
        'name': p['name'],
        'originalPrice': (p['discountedPrice'] ?? p['originalPrice'] ?? 0).toDouble(),
        'sellingPrice': _customPrices[id] ?? (p['discountedPrice'] ?? p['originalPrice'] ?? 0).toDouble(),
        'quantity': _quantities[id] ?? 1,
        'total': (_customPrices[id] ?? (p['discountedPrice'] ?? p['originalPrice'] ?? 0).toDouble()) * (_quantities[id] ?? 1),
      };
    }).toList();

    try {
      final invoiceData = {
        'businessId': widget.uid,
        'type': 'invoice',
        'invoiceNumber': invoiceNumber,
        'clientName': _clientNameCtrl.text.trim(),
        'clientPhone': _clientPhoneCtrl.text.trim(),
        'paymentType': _paymentType,
        'paymentStatus': _paymentType == 'cash' ? 'paid' : 'pending',
        'products': products,
        'subtotal': _subtotal,
        'discount': _discountAmount,
        'totalAmount': _totalAmount,
        'notes': _notesCtrl.text.trim(),
        'productCount': _selectedProducts.length,
        'totalQuantity': _quantities.values.fold(0, (sum, qty) => sum + qty),
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': widget.uid,
      };

      // حفظ الفاتورة في مجموعة invoices
      final invoiceRes = await ApiService.post('/api/invoices/sales', body: invoiceData);

      if (_paymentType == 'myfatoorah') {
        final result = await MyFatoorahService.createPaymentLink(
          requestId: invoiceNumber,
          amount: _totalAmount,
          clientName: _clientNameCtrl.text.trim(),
          clientPhone: _clientPhoneCtrl.text.trim(),
          service: 'فاتورة #$invoiceNumber',
        );

        if (result != null && result['success'] == true && invoiceRes.success && invoiceRes.data != null) {
          final invoiceId = invoiceRes.data!['id'] ?? invoiceRes.data!['invoice']?['id'];
          if (invoiceId != null) {
            await ApiService.put('/api/invoices/sales/$invoiceId', body: {
              'paymentUrl': result['paymentURL'],
            });
          }
        }
      }

      // إضافة معاملة مالية
      final invoiceId = invoiceRes.success ? (invoiceRes.data?['id'] ?? invoiceRes.data?['invoice']?['id'] ?? '') : '';
      await ApiService.post('/api/accounting/transactions', body: {
        'businessId': widget.uid,
        'type': 'income',
        'amount': _totalAmount,
        'description': 'فاتورة مبيعات #$invoiceNumber',
        'category': 'sale',
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'clientName': _clientNameCtrl.text.trim(),
        'paymentType': _paymentType,
        'paymentStatus': _paymentType == 'cash' ? 'paid' : 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': widget.uid,
      });

      // لو آجل، نحدّث/ننشئ سجل العميل
      if (_paymentType == 'credit') {
        await _updateClientRecord();
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1D1D1F),
            title: const Text('تم إنشاء الفاتورة', style: TextStyle(color: Color(0xFF0071E3))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('رقم الفاتورة', invoiceNumber),
                _infoRow('العميل', _clientNameCtrl.text.trim()),
                _infoRow('المجموع الفرعي', '${_subtotal.toStringAsFixed(3)} د.ك'),
                if (_discountAmount > 0)
                  _infoRow('الخصم', '-${_discountAmount.toStringAsFixed(3)} د.ك'),
                _infoRow('الإجمالي', '${_totalAmount.toStringAsFixed(3)} د.ك'),
                _infoRow('طريقة الدفع', _paymentType == 'cash' ? 'نقداً' : _paymentType == 'credit' ? 'آجل' : 'ماي فاتورة'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text('حسناً', style: TextStyle(color: Color(0xFF0071E3))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _snack('خطأ: $e');
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  /// تحديث أو إنشاء سجل العميل
  Future<void> _updateClientRecord() async {
    final clientPhone = _clientPhoneCtrl.text.trim();
    final clientName = _clientNameCtrl.text.trim();

    final now = DateTime.now().toIso8601String();

    if (clientPhone.isEmpty) {
      await ApiService.post('/api/clients', body: {
        'businessId': widget.uid,
        'name': clientName,
        'phone': '',
        'totalPurchases': _totalAmount,
        'totalPaid': 0,
        'balance': _totalAmount,
        'invoiceCount': 1,
        'lastTransaction': now,
        'createdAt': now,
      });
      return;
    }

    // البحث عن عميل موجود
    final searchRes = await ApiService.get('/api/clients', queryParameters: {'businessId': widget.uid, 'phone': clientPhone});
    if (searchRes.success && searchRes.data != null) {
      final list = searchRes.data!['clients'] ?? searchRes.data!['data'];
      if (list is List && list.isNotEmpty) {
        final clientId = list[0]['id'];
        await ApiService.put('/api/clients/$clientId', body: {
          'totalPurchasesIncrement': _totalAmount,
          'balanceIncrement': _totalAmount,
          'invoiceCountIncrement': 1,
          'lastTransaction': now,
          'name': clientName,
        });
        return;
      }
    }

    await ApiService.post('/api/clients', body: {
      'businessId': widget.uid,
      'name': clientName,
      'phone': clientPhone,
      'totalPurchases': _totalAmount,
      'totalPaid': 0,
      'balance': _totalAmount,
      'invoiceCount': 1,
      'lastTransaction': now,
      'createdAt': now,
    });
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: const Color(0xFF0071E3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1D1F),
      appBar: AppBar(
        title: const Text('فاتورة جديدة'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF0071E3)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessInvoicesHistory(uid: widget.uid),
                ),
              );
            },
            tooltip: 'الفواتير السابقة',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── بيانات العميل ──
                  _sectionTitle('بيانات العميل'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _clientNameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco('اسم العميل', Icons.person),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _clientPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco('رقم الهاتف', Icons.phone),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── نوع الدفع ──
                  _sectionTitle('طريقة الدفع'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _paymentTypeChip('cash', 'نقداً', Icons.money),
                      const SizedBox(width: 8),
                      _paymentTypeChip('credit', 'آجل', Icons.assignment),
                      const SizedBox(width: 8),
                      _paymentTypeChip('myfatoorah', 'ماي فاتورة', Icons.credit_card),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── المنتجات المختارة ──
                  if (_selectedProducts.isNotEmpty) ...[
                    _sectionTitle('المنتجات المختارة (${_selectedProducts.length})'),
                    const SizedBox(height: 12),
                    ..._selectedProducts.map((p) => _buildSelectedProductCard(p)),
                    const SizedBox(height: 16),

                    // ── الخصم ──
                    _sectionTitle('خصم على الفاتورة'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('مبلغ الخصم (د.ك)', Icons.discount),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── ملخص الفاتورة ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0071E3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('المجموع الفرعي', '${_subtotal.toStringAsFixed(3)} د.ك'),
                          if (_discountAmount > 0)
                            _summaryRow('الخصم', '-${_discountAmount.toStringAsFixed(3)} د.ك', color: Colors.red),
                          const Divider(color: Color(0xFF0071E3)),
                          _summaryRow('الإجمالي', '${_totalAmount.toStringAsFixed(3)} د.ك',
                              isBold: true, fontSize: 18),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],

                  // ── ملاحظات ──
                  _sectionTitle('ملاحظات'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: _inputDeco('ملاحظات إضافية...', Icons.note),
                  ),

                  const SizedBox(height: 20),

                  // ── البحث عن منتج ──
                  _sectionTitle('إضافة منتجات'),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو الكود...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0071E3))),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── قائمة المنتجات ──
                  if (_loadingProducts)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                  else if (_filteredProducts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('لا توجد منتجات',
                            style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      ),
                    )
                  else
                    ...(_filteredProducts.map((d) {
                      final id = d['id'] ?? '';
                      final name = d['name'] ?? '';
                      final originalPrice = (d['originalPrice'] ?? 0).toDouble();
                      final discountedPrice = (d['discountedPrice'] ?? 0).toDouble();
                      final displayPrice = discountedPrice > 0 ? discountedPrice : originalPrice;
                      final selected = _isSelected(id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF0071E3).withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: selected
                                  ? const Color(0xFF0071E3).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          title: Text(name,
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Row(
                            children: [
                              Text('${displayPrice.toStringAsFixed(3)} د.ك',
                                  style: const TextStyle(
                                      color: Color(0xFF0071E3), fontSize: 12)),
                              if (discountedPrice > 0 && originalPrice > discountedPrice)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text('${originalPrice.toStringAsFixed(3)}',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 10,
                                          decoration: TextDecoration.lineThrough)),
                                ),
                            ],
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: Color(0xFF0071E3))
                              : const Icon(Icons.add_circle_outline, color: Colors.white54),
                          onTap: () => _toggleProduct({
                            'id': id,
                            'name': name,
                            'discountedPrice': discountedPrice,
                            'originalPrice': originalPrice,
                          }),
                        ),
                      );
                    })),
                ],
              ),
            ),
          ),

          // ── الشريط السفلي ──
          if (_selectedProducts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1F),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_selectedProducts.length} منتج | ${_quantities.values.fold(0, (sum, qty) => sum + qty)} وحدة',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                        Text('${_totalAmount.toStringAsFixed(3)} د.ك',
                            style: const TextStyle(
                                color: Color(0xFF0071E3), fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _loadingProducts ? null : _createInvoice,
                    icon: const Icon(Icons.check, color: Color(0xFF1D1D1F)),
                    label: const Text('إنشاء الفاتورة',
                        style: TextStyle(
                            color: Color(0xFF1D1D1F), fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0071E3),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// بطاقة المنتج المختار مع تعديل السعر والكمية
  Widget _buildSelectedProductCard(Map<String, dynamic> product) {
    final id = product['id'] as String;
    final name = product['name'] ?? '';
    final originalPrice = (product['discountedPrice'] ?? product['originalPrice'] ?? 0).toDouble();
    final qty = _quantities[id] ?? 1;
    final customPrice = _customPrices[id] ?? originalPrice;
    final lineTotal = customPrice * qty;
    final priceChanged = customPrice != originalPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المنتج + زر حذف
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                onPressed: () => _toggleProduct(product),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // السعر + الكمية
          Row(
            children: [
              // السعر المخصص
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('السعر',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _priceControllers[id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          color: priceChanged ? Colors.orange : Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          suffixText: 'د.ك',
                          suffixStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        ),
                        onChanged: (value) => _updateCustomPrice(id, value),
                      ),
                    ),
                    if (priceChanged)
                      Text('الأصلي: ${originalPrice.toStringAsFixed(3)}',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // الكمية
              Column(
                children: [
                  Text('الكمية',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
                        onPressed: () {
                          if (qty > 1) {
                            setState(() => _quantities[id] = qty - 1);
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text('$qty',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0071E3), size: 20),
                        onPressed: () => setState(() => _quantities[id] = qty + 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // إجمالي السطر
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('الإجمالي',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('${lineTotal.toStringAsFixed(3)}',
                      style: const TextStyle(
                          color: Color(0xFF0071E3), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: Color(0xFF0071E3), fontSize: 13, fontWeight: FontWeight.bold));
  }

  Widget _summaryRow(String label, String value, {Color? color, bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: fontSize * 0.85)),
          Text(value,
              style: TextStyle(
                  color: color ?? const Color(0xFF0071E3),
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: fontSize)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0071E3))),
    );
  }

  Widget _paymentTypeChip(String value, String label, IconData icon) {
    final isSelected = _paymentType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0071E3).withOpacity(0.3) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? const Color(0xFF0071E3) : Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: isSelected ? const Color(0xFF0071E3) : Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: isSelected ? const Color(0xFF0071E3) : Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// صفحة سجل الفواتير السابقة
// ============================================================

class BusinessInvoicesHistory extends StatefulWidget {
  final String uid;
  const BusinessInvoicesHistory({super.key, required this.uid});

  @override
  State<BusinessInvoicesHistory> createState() => _BusinessInvoicesHistoryState();
}

class _BusinessInvoicesHistoryState extends State<BusinessInvoicesHistory> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];
  String _searchQuery = '';
  String _filterPayment = 'الكل';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    try {
      final res = await ApiService.get('/api/invoices/sales', queryParameters: {'businessId': widget.uid});
      if (res.success && res.data != null) {
        final list = res.data!['invoices'] ?? res.data!['data'];
        if (list is List) {
          final invoices = list.cast<Map<String, dynamic>>();
          invoices.sort((a, b) => _dateToMillis(b['createdAt']).compareTo(_dateToMillis(a['createdAt'])));
          setState(() {
            _allInvoices = invoices;
            _filteredInvoices = _allInvoices;
            _isLoading = false;
          });
          return;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterInvoices() {
    setState(() {
      _filteredInvoices = _allInvoices.where((inv) {
        // فلتر البحث
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final invoiceNum = (inv['invoiceNumber'] ?? '').toString().toLowerCase();
          final clientName = (inv['clientName'] ?? '').toString().toLowerCase();
          final clientPhone = (inv['clientPhone'] ?? '').toString().toLowerCase();
          if (!invoiceNum.contains(query) &&
              !clientName.contains(query) &&
              !clientPhone.contains(query)) {
            return false;
          }
        }

        // فلتر طريقة الدفع
        if (_filterPayment != 'الكل') {
          final paymentMap = {
            'نقداً': 'cash',
            'آجل': 'credit',
            'ماي فاتورة': 'myfatoorah',
          };
          if (inv['paymentType'] != paymentMap[_filterPayment]) return false;
        }

        // فلتر التاريخ
        if (_startDate != null) {
          final createdAt = _parseDate(inv['createdAt']);
          if (createdAt == null || createdAt.isBefore(_startDate!)) return false;
        }
        if (_endDate != null) {
          final createdAt = _parseDate(inv['createdAt']);
          if (createdAt == null || createdAt.isAfter(_endDate!)) return false;
        }

        return true;
      }).toList();
    });
  }

  double get _totalFiltered {
    return _filteredInvoices.fold(0.0, (sum, inv) {
      return sum + ((inv['totalAmount'] as num?)?.toDouble() ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1D1F),
      appBar: AppBar(
        title: const Text('الفواتير السابقة'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── شريط البحث والفلترة ──
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) {
                    _searchQuery = v;
                    _filterInvoices();
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الفاتورة أو اسم العميل...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['الكل', 'نقداً', 'آجل', 'ماي فاتورة'].map((type) {
                      final isSelected = _filterPayment == type;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (_) {
                            _filterPayment = type;
                            _filterInvoices();
                          },
                          selectedColor: const Color(0xFF0071E3).withOpacity(0.3),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── ملخص ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_filteredInvoices.length} فاتورة',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                Text('الإجمالي: ${_totalFiltered.toStringAsFixed(3)} د.ك',
                    style: const TextStyle(
                        color: Color(0xFF0071E3), fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // ── قائمة الفواتير ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                : _filteredInvoices.isEmpty
                    ? Center(
                        child: Text('لا توجد فواتير',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          return _buildInvoiceCard(_filteredInvoices[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final invoiceNumber = invoice['invoiceNumber'] ?? '';
    final clientName = invoice['clientName'] ?? '';
    final totalAmount = (invoice['totalAmount'] as num?)?.toDouble() ?? 0;
    final paymentType = invoice['paymentType'] ?? 'cash';
    final paymentStatus = invoice['paymentStatus'] ?? 'pending';
    final createdAt = _parseDate(invoice['createdAt']);
    final productCount = invoice['productCount'] ?? 0;

    final paymentLabel = paymentType == 'cash'
        ? 'نقداً'
        : paymentType == 'credit'
            ? 'آجل'
            : 'ماي فاتورة';
    final paymentColor = paymentType == 'cash'
        ? Colors.green
        : paymentType == 'credit'
            ? Colors.orange
            : Colors.blue;
    final isPaid = paymentStatus == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: paymentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            color: paymentColor,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(clientName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: paymentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(paymentLabel,
                  style: TextStyle(color: paymentColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text('#$invoiceNumber',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                const SizedBox(width: 8),
                if (createdAt != null)
                  Text(DateFormat('yyyy/MM/dd HH:mm').format(createdAt),
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 2),
            Text('$productCount منتج',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${totalAmount.toStringAsFixed(3)} د.ك',
                style: const TextStyle(
                    color: Color(0xFF0071E3), fontWeight: FontWeight.bold, fontSize: 14)),
            if (!isPaid)
              const Text('غير مدفوعة',
                  style: TextStyle(color: Colors.red, fontSize: 10)),
          ],
        ),
        onTap: () {
          _showInvoiceDetails(invoice);
        },
      ),
    );
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    final products = List<Map<String, dynamic>>.from(invoice['products'] ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1D1F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('تفاصيل الفاتورة',
                  style: TextStyle(
                      color: Color(0xFF0071E3), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _detailRow('رقم الفاتورة', invoice['invoiceNumber'] ?? ''),
              _detailRow('العميل', invoice['clientName'] ?? ''),
              _detailRow('الهاتف', invoice['clientPhone'] ?? '-'),
              _detailRow('طريقة الدفع',
                  invoice['paymentType'] == 'cash' ? 'نقداً' : invoice['paymentType'] == 'credit' ? 'آجل' : 'ماي فاتورة'),
              _detailRow('الحالة', invoice['paymentStatus'] == 'paid' ? 'مدفوعة' : 'غير مدفوعة'),
              const SizedBox(height: 16),
              const Text('المنتجات',
                  style: TextStyle(color: Color(0xFF0071E3), fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...products.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(p['name'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text('x${p['quantity'] ?? 1}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text('${((p['sellingPrice'] ?? p['price'] ?? 0) as num).toDouble().toStringAsFixed(3)}',
                            style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12)),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF0071E3)),
              _detailRow('المجموع الفرعي', '${((invoice['subtotal'] ?? 0) as num).toDouble().toStringAsFixed(3)} د.ك'),
              if ((invoice['discount'] ?? 0) > 0)
                _detailRow('الخصم', '-${((invoice['discount'] ?? 0) as num).toDouble().toStringAsFixed(3)} د.ك'),
              _detailRow('الإجمالي', '${((invoice['totalAmount'] ?? 0) as num).toDouble().toStringAsFixed(3)} د.ك',
                  valueColor: const Color(0xFF0071E3), isBold: true),
              if (invoice['notes'] != null && invoice['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailRow('ملاحظات', invoice['notes']),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
