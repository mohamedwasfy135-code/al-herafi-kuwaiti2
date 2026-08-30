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
// صفحة حركة مادة – Product Movement
// ✅ عرض جميع الفواتير التي بيعت/اشتريت فيها المادة
// ✅ عرض الكمية المتوفرة + تنبيه المخزون المنخفض
// ✅ ربط مع المستودع
// ═══════════════════════════════════════════════════════════════

class BusinessProductMovement extends StatefulWidget {
  final String uid;
  const BusinessProductMovement({super.key, required this.uid});

  @override
  State<BusinessProductMovement> createState() => _BusinessProductMovementState();
}

class _BusinessProductMovementState extends State<BusinessProductMovement> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;
  bool _searching = false;

  // ─── حساب المخزون (دائماً يعرض الرقم سواء موجب أو سالب أو صفر) ─
  int _getStock(Map<String, dynamic> product) {
    if (!product.containsKey('stockQuantity')) return 0;
    final val = product['stockQuantity'];
    if (val == null) return 0;
    return (val as num).toInt();
  }

  static const int _lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await ApiService.get('/api/products', queryParameters: {'businessId': widget.uid});
      if (res.success && res.data != null) {
        final list = res.data!['products'] ?? res.data!['data'];
        if (list is List) {
          setState(() {
            _products = list.cast<Map<String, dynamic>>();
            _loading = false;
          });
          return;
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProductMovements(String productId) async {
    setState(() => _searching = true);

    try {
      final res = await ApiService.get('/api/invoices/sales', queryParameters: {'businessId': widget.uid});
      final List<Map<String, dynamic>> invoices;
      if (res.success && res.data != null) {
        final list = res.data!['invoices'] ?? res.data!['data'];
        invoices = list is List ? list.cast<Map<String, dynamic>>() : [];
      } else {
        invoices = [];
      }

      // ترتيب يدوي حسب التاريخ (الأحدث أولاً)
      invoices.sort((a, b) {
        return _dateToMillis(b['createdAt']).compareTo(_dateToMillis(a['createdAt']));
      });

      final movements = <Map<String, dynamic>>[];

      for (final data in invoices) {
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

        for (final item in items) {
          if (item['productId'] == productId) {
            movements.add({
              'invoiceId': data['id'],
              'invoiceNumber': data['invoiceNumber'],
              'type': data['type'] ?? 'sales',
              'clientName': data['clientName'] ?? '',
              'clientPhone': data['clientPhone'] ?? '',
              'quantity': item['quantity'] ?? 0,
              'unitPrice': (item['unitPrice'] as num?)?.toDouble() ?? 0,
              'discount': (item['discount'] as num?)?.toDouble() ?? 0,
              'total': (item['total'] as num?)?.toDouble() ?? 0,
              'paymentMethod': data['paymentMethod'] ?? 'cash',
              'createdAt': data['createdAt'],
            });
            break;
          }
        }
      }

      setState(() {
        _movements = movements;
        _searching = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: _C.danger),
        );
      }
    }
  }

  void _selectProduct(Map<String, dynamic> product) {
    setState(() {
      _selectedProduct = product;
      _searchController.text = product['name'] ?? '';
    });
    _loadProductMovements(product['id']);
  }

  String _getTypeAr(String? type) {
    switch (type) {
      case 'sales':
        return 'مبيعات';
      case 'purchase':
        return 'مشتريات';
      case 'sales_return':
        return 'مردود مبيعات';
      case 'purchase_return':
        return 'مردود مشتريات';
      default:
        return type ?? '';
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'sales':
        return _C.success;
      case 'purchase':
        return _C.accent;
      case 'sales_return':
        return _C.warning;
      case 'purchase_return':
        return Color(0xFFAF52DE);
      default:
        return _C.textS;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'sales':
        return Icons.sell;
      case 'purchase':
        return Icons.shopping_cart;
      case 'sales_return':
        return Icons.undo;
      case 'purchase_return':
        return Icons.redo;
      default:
        return Icons.receipt;
    }
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

  String _formatDate(dynamic timestamp) {
    final dt = _parseDate(timestamp);
    if (dt != null) {
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  String _getPaymentAr(String? method) {
    switch (method) {
      case 'cash':
        return 'كاش';
      case 'knet':
        return 'كي نت';
      case 'bank':
        return 'تحويل بنكي';
      default:
        return method ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: _C.accent));
    }

    return Column(
      children: [
        // ─── شريط البحث ──────────────────────────────────────
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _C.surface,
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.track_changes, color: _C.accent, size: 20),
              SizedBox(width: 8),
              Text('حركة مادة', style: TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
              Spacer(),
              // حقل البحث عن مادة
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: _C.textP, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مادة لعرض حركتها...',
                    hintStyle: TextStyle(color: _C.textM, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: _C.textM, size: 14),
                    suffixIcon: _selectedProduct != null
                        ? IconButton(
                            icon: Icon(Icons.close, color: _C.danger, size: 16),
                            onPressed: () => setState(() {
                              _selectedProduct = null;
                              _movements = [];
                              _searchController.clear();
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: _C.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    if (v.isEmpty) {
                      setState(() {
                        _selectedProduct = null;
                        _movements = [];
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // ─── قائمة المواد (إذا لم يتم اختيار مادة) ──────────
        if (_selectedProduct == null)
          Expanded(
            child: _buildProductsList(),
          ),

        // ─── عرض حركة المادة المختارة ────────────────────────
        if (_selectedProduct != null)
          Expanded(
            child: _buildMovementView(),
          ),
      ],
    );
  }

  // ─── قائمة المواد للاختيار ──────────────────────────────────
  Widget _buildProductsList() {
    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? _products
        : _products.where((p) {
            final name = (p['name'] as String? ?? '').toLowerCase();
            return name.contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: _C.textM.withOpacity(0.5)),
            SizedBox(height: 16),
            Text(
              query.isNotEmpty ? 'لا توجد نتائج للبحث' : 'اختر مادة لعرض حركتها',
              style: TextStyle(color: _C.textS, fontSize: 20),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('${filtered.length} مادة', style: TextStyle(color: _C.textM, fontSize: 12)),
              Spacer(),
              Text('اضغط على مادة لعرض حركتها', style: TextStyle(color: _C.textM, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final p = filtered[i];
              final stock = _getStock(p);
              final isLow = stock >= 0 && stock <= _lowStockThreshold && stock != 0;
              final isOut = stock == 0;
              // دائماً نعرض الكمية سواء كانت سالبة أو صفر أو موجبة
              final hasStock = true; // عرض الكمية دائماً
              final price = (p['price'] as num?)?.toDouble() ?? 0;

              return GestureDetector(
                onTap: () => _selectProduct(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOut
                          ? _C.danger.withOpacity(0.3)
                          : (isLow ? _C.warning.withOpacity(0.3) : _C.border),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isOut ? Icons.warning_amber : Icons.inventory_2,
                              color: isOut ? _C.danger : (isLow ? _C.warning : _C.accent),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p['name'] ?? '',
                                style: TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (hasStock)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stock < 0
                                      ? _C.danger.withOpacity(0.1)
                                      : (isOut
                                          ? _C.danger.withOpacity(0.1)
                                          : (isLow ? _C.warning.withOpacity(0.1) : _C.success.withOpacity(0.1))),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  stock < 0
                                      ? 'المخزون: $stock'
                                      : (isOut ? 'نفد المخزون' : 'متوفر: $stock'),
                                  style: TextStyle(
                                    color: stock < 0
                                        ? _C.danger
                                        : (isOut ? _C.danger : (isLow ? _C.warning : _C.success)),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Text(
                              '${price.toStringAsFixed(3)} د.ك',
                              style: TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── عرض حركة المادة ────────────────────────────────────────
  Widget _buildMovementView() {
    final stock = _getStock(_selectedProduct ?? {});
    final isLow = stock > 0 && stock <= _lowStockThreshold;
    final isOut = stock == 0;
    final isNegative = stock < 0;

    // حساب إجماليات
    int totalSold = 0;
    int totalPurchased = 0;
    int totalReturned = 0;
    double totalSalesAmount = 0;
    double totalPurchaseAmount = 0;

    for (final m in _movements) {
      final type = m['type'] as String? ?? '';
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final total = (m['total'] as num?)?.toDouble() ?? 0;

      if (type == 'sales') {
        totalSold += qty;
        totalSalesAmount += total;
      } else if (type == 'purchase') {
        totalPurchased += qty;
        totalPurchaseAmount += total;
      } else if (type == 'sales_return') {
        totalReturned += qty;
      }
    }

    return Column(
      children: [
        // ─── بطاقة معلومات المادة ──────────────────────────
        Container(
          margin: EdgeInsets.all(12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOut
                  ? _C.danger.withOpacity(0.4)
                  : (isLow ? _C.warning.withOpacity(0.3) : _C.border),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 36,
                    decoration: BoxDecoration(
                      color: _C.accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOut ? Icons.warning_amber : Icons.inventory_2,
                      color: isOut ? _C.danger : _C.accent,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedProduct?['name'] ?? '',
                          style: TextStyle(color: _C.textP, fontSize: 21, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            if (_selectedProduct?['category'] != null && _selectedProduct!['category'].toString().isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _C.surface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_selectedProduct!['category'], style: TextStyle(color: _C.textM, fontSize: 12)),
                              ),
                            SizedBox(width: 8),
                            Text(
                              '${((_selectedProduct?['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك',
                              style: TextStyle(color: _C.accent, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // حالة المخزون - عرض دائماً
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isNegative
                          ? _C.danger.withOpacity(0.1)
                          : (isOut
                              ? _C.danger.withOpacity(0.1)
                              : (isLow ? _C.warning.withOpacity(0.1) : _C.success.withOpacity(0.1))),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isNegative
                            ? _C.danger.withOpacity(0.3)
                            : (isOut
                                ? _C.danger.withOpacity(0.3)
                                : (isLow ? _C.warning.withOpacity(0.3) : _C.success.withOpacity(0.2))),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isNegative ? '$stock' : (isOut ? 'نفد' : '$stock'),
                          style: TextStyle(
                            color: isNegative
                                ? _C.danger
                                : (isOut ? _C.danger : (isLow ? _C.warning : _C.success)),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isNegative ? 'المخزون (عجز)' : 'المخزون',
                          style: TextStyle(
                            color: isNegative
                                ? _C.danger.withOpacity(0.7)
                                : (isOut ? _C.danger.withOpacity(0.7) : (isLow ? _C.warning.withOpacity(0.7) : _C.success.withOpacity(0.7))),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // ملخص الحركة
              Row(
                children: [
                  _buildSummaryBox('المبيعات', '$totalSold', '${totalSalesAmount.toStringAsFixed(3)} د.ك', _C.success, Icons.sell),
                  SizedBox(width: 8),
                  _buildSummaryBox('المشتريات', '$totalPurchased', '${totalPurchaseAmount.toStringAsFixed(3)} د.ك', _C.accent, Icons.shopping_cart),
                  SizedBox(width: 8),
                  _buildSummaryBox('المرتجعات', '$totalReturned', '', _C.warning, Icons.undo),
                  SizedBox(width: 8),
                  _buildSummaryBox('الفواتير', '${_movements.length}', '', Color(0xFFAF52DE), Icons.receipt),
                ],
              ),
            ],
          ),
        ),

        // ─── قائمة الفواتير ────────────────────────────────
        if (_searching)
          Expanded(child: Center(child: CircularProgressIndicator(color: _C.accent)))
        else if (_movements.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 60, color: _C.textM.withOpacity(0.5)),
                  SizedBox(height: 12),
                  Text('لا توجد فواتير لهذه المادة', style: TextStyle(color: _C.textM, fontSize: 18)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                // رأس القائمة
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    border: Border(bottom: BorderSide(color: _C.border)),
                  ),
                  child: Row(
                    children: [
                      _listHeaderCell('النوع', 90),
                      _listHeaderCell('الفاتورة', 70),
                      _listHeaderCell('العميل', null, flex: 3),
                      _listHeaderCell('الكمية', 60),
                      _listHeaderCell('السعر', 80),
                      _listHeaderCell('الإجمالي', 90),
                      _listHeaderCell('التاريخ', 110),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _movements.length,
                    itemBuilder: (_, i) => _buildMovementRow(_movements[i]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryBox(String title, String value, String subtitle, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: color.withOpacity(0.7), fontSize: 14)),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: TextStyle(color: color.withOpacity(0.5), fontSize: 14), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _listHeaderCell(String text, double? width, {int? flex}) {
    final child = Text(text, style: TextStyle(color: _C.textS, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    if (flex != null && width == null) {
      return Expanded(flex: flex, child: child);
    }
    return SizedBox(width: width, child: child);
  }

  Widget _buildMovementRow(Map<String, dynamic> m) {
    final type = m['type'] as String? ?? '';
    final typeColor = _getTypeColor(type);

    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // النوع
          SizedBox(
            width: 90,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getTypeIcon(type), color: typeColor, size: 14),
                SizedBox(width: 4),
                Text(_getTypeAr(type), style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // رقم الفاتورة
          SizedBox(
            width: 70,
            child: Text('#${m['invoiceNumber'] ?? ''}', style: TextStyle(color: _C.textS, fontSize: 12), textAlign: TextAlign.center),
          ),
          // العميل
          Expanded(
            flex: 3,
            child: Text(m['clientName'] ?? '', style: TextStyle(color: _C.textS, fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
          // الكمية
          SizedBox(
            width: 60,
            child: Text('${m['quantity'] ?? 0}', style: TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ),
          // السعر
          SizedBox(
            width: 80,
            child: Text('${(m['unitPrice'] as num?)?.toDouble().toStringAsFixed(3) ?? '0.000'}', style: TextStyle(color: _C.textS, fontSize: 12), textAlign: TextAlign.center),
          ),
          // الإجمالي
          SizedBox(
            width: 90,
            child: Text('${(m['total'] as num?)?.toDouble().toStringAsFixed(3) ?? '0.000'}', style: TextStyle(color: typeColor, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ),
          // التاريخ
          SizedBox(
            width: 110,
            child: Text(_formatDate(m['createdAt']), style: TextStyle(color: _C.textM, fontSize: 12), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
