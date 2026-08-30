import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة فاتورة المشتريات – Purchase Invoice
// ═══════════════════════════════════════════════════════════════

class BusinessPurchaseInvoice extends StatefulWidget {
  final String uid;
  const BusinessPurchaseInvoice({super.key, required this.uid});

  @override
  State<BusinessPurchaseInvoice> createState() => _BusinessPurchaseInvoiceState();
}

class _BusinessPurchaseInvoiceState extends State<BusinessPurchaseInvoice> {
  // ─── المتغيرات ──────────────────────────────────────────────
  final _supplierNameController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _searchController = TextEditingController();
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();

  List<_PurchaseItem> _items = [];
  List<Map<String, dynamic>> _suppliers = [];
  String? _selectedSupplierId;
  String _itemFilter = '';
  double _discount = 0;
  double _discountPercent = 0;
  bool _isPercentDiscount = true;
  bool _saving = false;
  bool _loadingSuppliers = true;

  // حقول إضافة صنف جديد
  final _newItemNameController = TextEditingController();
  final _newItemPriceController = TextEditingController();
  final _newItemQtyController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _searchController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _newItemNameController.dispose();
    _newItemPriceController.dispose();
    _newItemQtyController.dispose();
    super.dispose();
  }

  // ─── تحميل الموردين ────────────────────────────────────────
  Future<void> _loadSuppliers() async {
    try {
      final snap = await ApiService
          .collection('business_suppliers')
          .doc(widget.uid)
          .collection('items')
          .get();

      if (mounted) {
        setState(() {
          _suppliers = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          _loadingSuppliers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  // ─── حساب المجاميع ──────────────────────────────────────────
  double get _subtotal {
    double total = 0;
    for (final item in _items) {
      total += item.price * item.quantity;
    }
    return total;
  }

  double get _discountAmount {
    if (_isPercentDiscount) {
      return _subtotal * (_discountPercent / 100);
    }
    return _discount;
  }

  double get _total => _subtotal - _discountAmount;

  // ─── إضافة صنف ──────────────────────────────────────────────
  void _addItem() {
    final name = _newItemNameController.text.trim();
    final price = double.tryParse(_newItemPriceController.text.trim()) ?? 0;
    final qty = int.tryParse(_newItemQtyController.text.trim()) ?? 1;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الصنف والسعر'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() {
      _items.add(_PurchaseItem(
        name: name,
        price: price,
        quantity: qty < 1 ? 1 : qty,
      ));
    });

    _newItemNameController.clear();
    _newItemPriceController.clear();
    _newItemQtyController.text = '1';
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateItemQty(int index, int newQty) {
    setState(() => _items[index].quantity = newQty < 1 ? 1 : newQty);
  }

  void _updateItemPrice(int index, double newPrice) {
    setState(() => _items[index].price = newPrice);
  }

  // ─── حفظ فاتورة المشتريات ───────────────────────────────────
  Future<void> _saveInvoice() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنف واحد على الأقل'), backgroundColor: Colors.orange)
      );
      return;
    }
    if (_total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إجمالي الفاتورة يجب أن يكون أكبر من صفر'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final invoiceId = ApiService.collection('business_invoices').doc().id;
      final supplierName = _supplierNameController.text.trim();

      // بناء عناصر الفاتورة
      final itemsData = _items.map((item) => {
        'itemName': item.name,
        'unitPrice': item.price,
        'quantity': item.quantity,
        'total': item.price * item.quantity
      }).toList();

      // حفظ الفاتورة
      await ApiService.collection('business_invoices').doc(invoiceId).set({
        'id': invoiceId,
        'businessId': widget.uid,
        'type': 'purchase',
        'supplierId': _selectedSupplierId,
        'supplierName': supplierName.isEmpty ? 'مورد غير محدد' : supplierName,
        'supplierPhone': _supplierPhoneController.text.trim(),
        'items': itemsData,
        'subtotal': _subtotal,
        'discountType': _isPercentDiscount ? 'percent' : 'fixed',
        'discountValue': _isPercentDiscount ? _discountPercent : _discount,
        'discountAmount': _discountAmount,
        'total': _total,
        'notes': _notesController.text.trim(),
        'status': 'paid',
        'createdAt': now
      });

      // إنشاء حركة مالية (مصروف)
      await ApiService.collection('business_transactions').add({
        'businessId': widget.uid,
        'type': 'purchase',
        'amount': _total,
        'category': 'مشتريات',
        'description': 'فاتورة مشتريات #$invoiceId',
        'invoiceId': invoiceId,
        'supplierId': _selectedSupplierId,
        'createdAt': now
      });

      // تحديث/إنشاء بيانات المورد
      if (_selectedSupplierId != null) {
        await ApiService
            .collection('business_suppliers')
            .doc(widget.uid)
            .collection('items')
            .doc(_selectedSupplierId)
            .update({
          'totalPurchases': FieldValue.increment(_total),
          'lastPurchaseAt': now,
          'invoiceCount': FieldValue.increment(1)
        });
      } else if (supplierName.isNotEmpty) {
        // إنشاء مورد جديد
        await ApiService
            .collection('business_suppliers')
            .doc(widget.uid)
            .collection('items')
            .add({
          'name': supplierName,
          'phone': _supplierPhoneController.text.trim(),
          'totalPurchases': _total,
          'lastPurchaseAt': now,
          'invoiceCount': 1,
          'createdAt': now
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ فاتورة المشتريات بنجاح'), backgroundColor: Colors.green)
        );
        _resetForm();
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
      _items.clear();
      _selectedSupplierId = null;
      _supplierNameController.clear();
      _supplierPhoneController.clear();
      _discountController.clear();
      _notesController.clear();
      _discount = 0;
      _discountPercent = 0;
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
              // العمود الأيسر: المورد + الأصناف
              Expanded(flex: 3, child: _buildLeftColumn()),
              const SizedBox(width: 12),
              // العمود الأيمن: ملخص الفاتورة
              Expanded(flex: 2, child: _buildRightColumn()),
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
          const Icon(Icons.shopping_cart, color: Color(0xFF0071E3), size: 22),
          const SizedBox(width: 8),
          const Text('فاتورة مشتريات جديدة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessPurchaseInvoicesHistory(, uid: widget.uid))),
            icon: const Icon(Icons.history, color: Color(0xFF0071E3), size: 14),
            label: const Text('السجل', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
          ),
        ],
      )
    );
  }

  // ─── العمود الأيسر ─────────────────────────────────────────
  Widget _buildLeftColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupplierSection(),
          const SizedBox(height: 16),
          _buildAddItemSection(),
          const SizedBox(height: 12),
          _buildItemsList(),
        ],
      )
    );
  }

  // ─── قسم المورد ────────────────────────────────────────────
  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: Color(0xFF0071E3), size: 14),
              const SizedBox(width: 8),
              const Text('المورد', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedSupplierId != null)
                TextButton(
                  onPressed: () => setState(() {
                    _selectedSupplierId = null;
                    _supplierNameController.clear();
                    _supplierPhoneController.clear();
                  }),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // اسم المورد
          TextField(
            controller: _supplierNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'اسم المورد',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white38, size: 14),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (v) {
              // إذا عدّل الاسم بعد اختيار مورد، نلغي الاختيار
              if (_selectedSupplierId != null) {
                setState(() => _selectedSupplierId = null);
              }
            },
          ),
          const SizedBox(height: 8),
          // رقم الهاتف
          TextField(
            controller: _supplierPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'رقم الهاتف (اختياري)',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.phone, color: Colors.white38, size: 14),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          // قائمة الموردين المحفوظين
          if (_suppliers.isNotEmpty && _selectedSupplierId == null) ...[
            const SizedBox(height: 10),
            const Text('الموردون المحفوظون:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suppliers.length,
                itemBuilder: (_, i) {
                  final supplier = _suppliers[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.store, color: Colors.white54, size: 16),
                    title: Text(supplier['name'] ?? '', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    subtitle: supplier['phone'] != null ? Text(supplier['phone'], style: TextStyle(color: Colors.white38, fontSize: 10)) : null,
                    onTap: () => setState(() {
                      _selectedSupplierId = supplier['id'];
                      _supplierNameController.text = supplier['name'] ?? '';
                      _supplierPhoneController.text = supplier['phone'] ?? '';
                    })
                  );
                },
              ),
            ),
          ],
        ],
      )
    );
  }

  // ─── إضافة صنف جديد ────────────────────────────────────────
  Widget _buildAddItemSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline, color: Color(0xFF0071E3), size: 14),
              const SizedBox(width: 8),
              const Text('إضافة صنف', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // اسم الصنف
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newItemNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'اسم الصنف',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 6),
              // السعر
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _newItemPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'السعر',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 6),
              // الكمية
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _newItemQtyController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'الكمية',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // زر إضافة
              IconButton(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle, color: Color(0xFF0071E3), size: 28),
              ),
            ],
          ),
        ],
      )
    );
  }

  // ─── قائمة الأصناف المضافة ──────────────────────────────────
  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: Text('لم تُضاف أصناف بعد', style: TextStyle(color: Colors.white38, fontSize: 13))
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Text('الأصناف', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_items.length} صنف', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...List.generate(_items.length, (i) => _buildItemRow(i)),
      ]
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // رقم
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0071E3).withOpacity(0.15),
            ),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          // الاسم
          Expanded(
            flex: 3,
            child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          // السعر
          SizedBox(
            width: 80,
            child: TextField(
              controller: TextEditingController(text: item.price.toStringAsFixed(3)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                isDense: true,
              ),
              onChanged: (v) {
                final val = double.tryParse(v) ?? item.price;
                _updateItemPrice(index, val);
              },
            ),
          ),
          const SizedBox(width: 6),
          // x
          Text('x', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 6),
          // الكمية
          SizedBox(
            width: 50,
            child: TextField(
              controller: TextEditingController(text: item.quantity.toString()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                isDense: true,
              ),
              onChanged: (v) {
                final val = int.tryParse(v) ?? 1;
                _updateItemQty(index, val);
              },
            ),
          ),
          const SizedBox(width: 8),
          // المجموع
          SizedBox(
            width: 85,
            child: Text(
              '${(item.price * item.quantity).toStringAsFixed(3)} د.ك',
              style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          // حذف
          IconButton(
            onPressed: () => _removeItem(index),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      )
    );
  }

  // ─── العمود الأيمن – ملخص الفاتورة ─────────────────────────
  Widget _buildRightColumn() {
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
            const Row(
              children: [
                Icon(Icons.summarize, color: Color(0xFF0071E3), size: 20),
                SizedBox(width: 8),
                Text('ملخص الفاتورة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _summaryRow('عدد الأصناف', '${_items.length}'),
            const Divider(color: Colors.white12, height: 20),
            _summaryRow('المجموع الفرعي', '${_subtotal.toStringAsFixed(3)} د.ك'),
            const SizedBox(height: 10),

            // الخصم
            Row(
              children: [
                const Text('الخصم', style: TextStyle(color: Colors.white60, fontSize: 13)),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _discountTypeButton('%', _isPercentDiscount),
                      _discountTypeButton('د.ك', !_isPercentDiscount),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF0071E3), fontSize: 14),
              decoration: InputDecoration(
                hintText: _isPercentDiscount ? 'نسبة الخصم %' : 'مبلغ الخصم',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                suffixText: _isPercentDiscount ? '%' : 'د.ك',
                suffixStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) {
                final val = double.tryParse(v) ?? 0;
                setState(() {
                  if (_isPercentDiscount) {
                    _discountPercent = val.clamp(0, 100);
                    _discount = 0;
                  } else {
                    _discount = val;
                    _discountPercent = 0;
                  }
                });
              },
            ),
            if (_discountAmount > 0) ...[
              const SizedBox(height: 4),
              Text('- ${_discountAmount.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],

            const Divider(color: Colors.white12, height: 24),

            // الإجمالي
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0071E3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('${_total.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ملاحظات
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'ملاحظات...',
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
                onPressed: _saving ? null : _saveInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D1D1F)))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 8),
                        Text('حفظ فاتورة المشتريات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ]),
              ),
            ),
          ],
        ),
      )
    );
  }

  Widget _discountTypeButton(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() {
        _isPercentDiscount = label == '%';
        _discountController.clear();
        _discount = 0;
        _discountPercent = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0071E3).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF0071E3) : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// موديل صنف المشتريات
// ═══════════════════════════════════════════════════════════════
class _PurchaseItem {
  String name;
  double price;
  int quantity;
  _PurchaseItem({required this.name, required this.price, required this.quantity});
}

// ═══════════════════════════════════════════════════════════════
// سجل فواتير المشتريات – Purchase Invoices History
// ═══════════════════════════════════════════════════════════════

class BusinessPurchaseInvoicesHistory extends StatefulWidget {
  final String uid;
  const BusinessPurchaseInvoicesHistory({super.key, required this.uid});

  @override
  State<BusinessPurchaseInvoicesHistory> createState() => _BusinessPurchaseInvoicesHistoryState();
}

class _BusinessPurchaseInvoicesHistoryState extends State<BusinessPurchaseInvoicesHistory> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DocumentSnapshot? _lastDoc;
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    try {
      Query query = ApiService
          .collection('business_invoices')
          .where('businessId', isEqualTo: widget.uid)
          .where('type', isEqualTo: 'purchase')
          .orderBy('createdAt', descending: true)
          .limit(20);

      final snap = await query.get();
      _invoices = snap.docs.map((d) { final m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m; }).toList();
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    } catch (e) {
      debugPrint('Error loading purchase invoices: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_lastDoc == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      Query query = ApiService
          .collection('business_invoices')
          .where('businessId', isEqualTo: widget.uid)
          .where('type', isEqualTo: 'purchase')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(20);

      final snap = await query.get();
      final more = snap.docs.map((d) { final m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m; }).toList();
      _invoices.addAll(more);
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _invoices;
    return _invoices.where((inv) {
      final supplier = (inv['supplierName'] as String? ?? '').toLowerCase();
      final id = (inv['id'] as String? ?? '').toLowerCase();
      return supplier.contains(_searchQuery) || id.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D1D1F), Color(0xFF003366)]))),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    const Text('سجل فواتير المشتريات', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'بحث...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 14),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                    : _filtered.isEmpty
                        ? Center(child: Text('لا توجد فواتير مشتريات', style: TextStyle(color: Colors.white38, fontSize: 13)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length + 1,
                            itemBuilder: (_, i) {
                              if (i == _filtered.length) {
                                return _loadingMore
                                    ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: Color(0xFF0071E3))))
                                    : _lastDoc != null
                                        ? TextButton(onPressed: _loadMore, child: const Text('تحميل المزيد', style: TextStyle(color: Color(0xFF0071E3))))
                                        : const SizedBox.shrink();
                              }
                              return _buildInvoiceCard(_filtered[i]);
                            },
                          ),
              ),
            ],
          ),
        ],
      )
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final supplierName = inv['supplierName'] as String? ?? 'مورد غير محدد';
    final items = List<Map<String, dynamic>>.from(inv['items'] ?? []);
    final createdAt = inv['createdAt'] as DateTime?;
    final dateStr = createdAt != null ? _formatDate(createdAt) : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${inv['id']?.toString().substring(0, 8) ?? ''}', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('مشتريات', style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text(supplierName, style: const TextStyle(color: Colors.white, fontSize: 13)),
              const Spacer(),
              Text('${total.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: items.take(4).map((item) => Chip(
                label: Text('${item['itemName']} x${item['quantity']}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                backgroundColor: Colors.white.withOpacity(0.06),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
          const SizedBox(height: 4),
          Text(dateStr, style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      )
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
