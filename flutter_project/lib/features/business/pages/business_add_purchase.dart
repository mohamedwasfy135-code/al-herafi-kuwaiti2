import 'dart:ui' as ui;
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class BusinessAddPurchase extends StatefulWidget {
  final String uid;
  final List<String> customCategories;
  const BusinessAddPurchase({
    super.key,
    required this.uid,
    required this.customCategories,
  });

  @override
  State<BusinessAddPurchase> createState() => _BusinessAddPurchaseState();
}

class _BusinessAddPurchaseState extends State<BusinessAddPurchase> {
  final _supplierCtrl = TextEditingController();
  final _invoiceNumberCtrl = TextEditingController();

  // التصنيف العام للفاتورة
  String? _globalCategory;

  // المنتجات المضافة في الفاتورة
  final List<_PurchaseItem> _items = [];

  // البحث عن منتج موجود
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  bool _saving = false;

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    final res = await ApiService.get('/api/products', queryParameters: {'businessId': widget.uid, 'status': 'approved'});
    final List<Map<String, dynamic>> allProducts = [];
    if (res.success && res.data != null) {
      final list = res.data!['products'] ?? res.data!['data'];
      if (list is List) allProducts.addAll(list.cast<Map<String, dynamic>>());
    }

    final results = allProducts.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final sku = (d['sku'] ?? '').toString().toLowerCase();
      final q = query.toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();

    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  void _addExistingProduct(Map<String, dynamic> d) {
    final productId = d['id'] ?? '';
    final existingItem = _items.where((item) => item.productId == productId).firstOrNull;

    if (existingItem != null) {
      setState(() => existingItem.quantity += 1);
    } else {
      setState(() {
        _items.add(_PurchaseItem(
          productId: productId,
          name: d['name'] ?? '',
          sku: d['sku'] ?? '',
          costPrice: (d['costPrice'] as num?)?.toDouble() ?? (d['originalPrice'] as num?)?.toDouble() ?? 0,
          quantity: 1,
          category: _globalCategory ?? d['category'] ?? '',
        ));
      });
    }
    _searchCtrl.clear();
    _searchResults = [];
  }

  void _addNewProduct() {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String? category = _globalCategory;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة منتج جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'كود SKU', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder())),
            if (widget.customCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                items: widget.customCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => category = v,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _items.add(_PurchaseItem(
                  productId: 'new_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  sku: skuCtrl.text.trim(),
                  costPrice: double.tryParse(priceCtrl.text.trim()) ?? 0,
                  quantity: int.tryParse(qtyCtrl.text.trim()) ?? 1,
                  category: category ?? 'أخرى',
                  isNew: true,
                ));
              });
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePurchase() async {
    if (_items.isEmpty) {
      _snack('❌ الرجاء إضافة منتج واحد على الأقل');
      return;
    }

    setState(() => _saving = true);

    final totalAmount = _items.fold(0.0, (sum, item) => sum + (item.costPrice * item.quantity));
    final invoiceNumber = _invoiceNumberCtrl.text.trim().isNotEmpty
        ? _invoiceNumberCtrl.text.trim()
        : 'PUR-${DateTime.now().millisecondsSinceEpoch}';
    final supplier = _supplierCtrl.text.trim().isNotEmpty ? _supplierCtrl.text.trim() : 'مورد';

    // 1. حفظ حركة المشتريات في دفتر الأستاذ
    await ApiService.post('/api/accounting/transactions', body: {
      'businessId': widget.uid,
      'type': 'purchase',
      'amount': totalAmount,
      'description': 'فاتورة مشتريات #$invoiceNumber من $supplier',
      'category': 'purchase',
      'invoiceNumber': invoiceNumber,
      'supplier': supplier,
      'products': _items.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'sku': item.sku,
        'costPrice': item.costPrice,
        'quantity': item.quantity,
        'category': item.category,
        'isNew': item.isNew,
      }).toList(),
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': widget.uid,
    });

    // 2. إضافة/تحديث المنتجات في المستودع
    for (final item in _items) {
      if (item.isNew) {
        await ApiService.post('/api/products', body: {
          'businessId': widget.uid,
          'name': item.name,
          'sku': item.sku,
          'originalPrice': item.costPrice,
          'costPrice': item.costPrice,
          'stock': item.quantity,
          'category': item.category,
          'supplier': supplier,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else if (item.productId.isNotEmpty) {
        await ApiService.put('/api/products/${item.productId}', body: {
          'stockIncrement': item.quantity,
          'costPrice': item.costPrice,
          'supplier': supplier,
        });
      }
    }

    if (mounted) {
      _snack('✅ تم حفظ فاتورة المشتريات وإضافة ${_items.length} منتج للمستودع');
      Navigator.pop(context, true);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: const Color(0xFF0071E3), behavior: SnackBarBehavior.floating),
    );
  }

  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + (item.costPrice * item.quantity));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1D1F),
      appBar: AppBar(
        title: const Text('فاتورة مشتريات'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // المورد ورقم الفاتورة
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _supplierCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco('اسم المورد', Icons.business),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _invoiceNumberCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco('رقم الفاتورة', Icons.receipt),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // التصنيف العام
                  if (widget.customCategories.isNotEmpty) ...[
                    const Text('تصنيف الفاتورة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _globalCategory,
                      dropdownColor: const Color(0xFF003366),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'اختر التصنيف',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: widget.customCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setState(() => _globalCategory = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // البحث عن منتج موجود
                  const Text('إضافة منتجات للفاتورة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          onChanged: _searchProducts,
                          decoration: InputDecoration(
                            hintText: '🔍 بحث عن منتج موجود...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0071E3))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addNewProduct,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('جديد', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0071E3).withOpacity(0.2),
                          foregroundColor: const Color(0xFF0071E3),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),

                  // نتائج البحث
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (_, i) {
                          final d = _searchResults[i];
                          final cat = d['category'] as String? ?? '';
                          return ListTile(
                            dense: true,
                            title: Text(d['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            subtitle: cat.isNotEmpty
                                ? Text('🏷️ $cat', style: TextStyle(color: const Color(0xFF0071E3).withOpacity(0.7), fontSize: 11))
                                : null,
                            trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF0071E3), size: 20),
                            onTap: () => _addExistingProduct(d),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // المنتجات المضافة للفاتورة
                  if (_items.isNotEmpty) ...[
                    const Text('المنتجات في الفاتورة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      if (item.sku.isNotEmpty) Text('SKU: ${item.sku}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 14),
                                  onPressed: () => setState(() => _items.removeAt(i)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // الكمية
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    controller: TextEditingController(text: '${item.quantity}'),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'الكمية',
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.1),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    onChanged: (v) {
                                      final qty = int.tryParse(v) ?? 1;
                                      setState(() => item.quantity = qty);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // سعر الشراء
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    controller: TextEditingController(text: '${item.costPrice}'),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'السعر',
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.1),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    onChanged: (v) {
                                      final price = double.tryParse(v) ?? 0;
                                      setState(() => item.costPrice = price);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // التصنيف الفردي
                                if (widget.customCategories.isNotEmpty)
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: item.category.isNotEmpty ? item.category : _globalCategory,
                                      dropdownColor: const Color(0xFF003366),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.1),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      items: widget.customCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
                                      onChanged: (v) => setState(() => item.category = v ?? ''),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('الإجمالي: ${(item.costPrice * item.quantity).toStringAsFixed(3)} د.ك',
                                style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // الشريط السفلي
          if (_items.isNotEmpty)
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
                        Text('${_items.length} منتج | ${_items.fold(0, (sum, item) => sum + item.quantity)} قطعة',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                        Text('${_totalAmount.toStringAsFixed(3)} د.ك',
                            style: const TextStyle(color: Color(0xFF0071E3), fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _savePurchase,
                    icon: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(Icons.save, color: Color(0xFF1D1D1F)),
                    label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الفاتورة', style: const TextStyle(color: Color(0xFF1D1D1F), fontWeight: FontWeight.bold)),
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

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0071E3))),
    );
  }
}

// نموذج عنصر في فاتورة المشتريات
class _PurchaseItem {
  final String productId;
  final String name;
  final String sku;
  double costPrice;
  int quantity;
  String category;
  final bool isNew;

  _PurchaseItem({
    required this.productId,
    required this.name,
    required this.sku,
    required this.costPrice,
    required this.quantity,
    required this.category,
    this.isNew = false,
  });
}