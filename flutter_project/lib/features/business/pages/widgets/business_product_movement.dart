import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

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
      List<Map<String, dynamic>> products = [];
      if (res.success && res.data != null) {
        final list = res.data!['products'] ?? res.data!['data'] ?? [];
        if (list is List) {
          products = list.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            if (m['id'] == null) m['id'] = '';
            return m;
          }).toList();
        }
      }

      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProductMovements(String productId) async {
    setState(() => _searching = true);

    try {
      // البحث في جميع الفواتير التي تحتوي على هذه المادة
      final invoicesSnap = await widget.db
          .collection('business_invoices')
          .where('businessId', isEqualTo: widget.uid)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      final movements = <Map<String, dynamic>>[];

      for (final doc in invoicesSnap.docs) {
        final data = doc.data();
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

        for (final item in items) {
          if (item['productId'] == productId) {
            movements.add({
              'invoiceId': doc.id,
              'invoiceNumber': data['invoiceNumber'],
              'type': data['type'] ?? 'sales',
              'clientName': data['clientName'] ?? '',
              'clientPhone': data['clientPhone'] ?? '',
              'quantity': item['quantity'] ?? 0,
              'unitPrice': (item['unitPrice'] as num?)?.toDouble() ?? 0,
              'discount': (item['discount'] as num?)?.toDouble() ?? 0,
              'total': (item['total'] as num?)?.toDouble() ?? 0,
              'paymentMethod': data['paymentMethod'] ?? 'cash',
              'createdAt': data['createdAt']
            });
            break; // نأخذ أول تطابق فقط لكل فاتورة
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
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red)
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
        return Colors.green;
      case 'purchase':
        return Colors.blue;
      case 'sales_return':
        return Colors.orange;
      case 'purchase_return':
        return Colors.purple;
      default:
        return Colors.white54;
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

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final d = timestamp;
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    return Column(
      children: [
        // ─── شريط البحث ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              const Icon(Icons.track_changes, color: Color(0xFF0071E3), size: 20),
              const SizedBox(width: 8),
              const Text('حركة مادة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              // حقل البحث عن مادة
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مادة لعرض حركتها...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 14),
                    suffixIcon: _selectedProduct != null
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                            onPressed: () => setState(() {
                              _selectedProduct = null;
                              _movements = [];
                              _searchController.clear();
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      ]
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
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty ? 'لا توجد نتائج للبحث' : 'اختر مادة لعرض حركتها',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
        )
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('${filtered.length} مادة', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              const Text('اضغط على مادة لعرض حركتها', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final p = filtered[i];
              final stock = (p['stockQuantity'] as num?)?.toInt() ?? -1;
              final isLow = stock >= 0 && stock <= _lowStockThreshold;
              final isOut = stock == 0;
              final price = (p['price'] as num?)?.toDouble() ?? 0;

              return GestureDetector(
                onTap: () => _selectProduct(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOut
                          ? Colors.red.withOpacity(0.3)
                          : (isLow ? Colors.orange.withOpacity(0.2) : const Color(0xFF0071E3).withOpacity(0.1)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isOut ? Icons.warning_amber : Icons.inventory_2,
                              color: isOut ? Colors.redAccent : (isLow ? Colors.orange : const Color(0xFF0071E3)),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p['name'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (stock >= 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? Colors.red.withOpacity(0.15)
                                      : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOut ? 'نفد المخزون' : 'متوفر: $stock',
                                  style: TextStyle(
                                    color: isOut ? Colors.redAccent : (isLow ? Colors.orange : Colors.greenAccent),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Text(
                              '${price.toStringAsFixed(3)} د.ك',
                              style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              );
            },
          ),
        ),
      ]
    );
  }

  // ─── عرض حركة المادة ────────────────────────────────────────
  Widget _buildMovementView() {
    final stock = (_selectedProduct?['stockQuantity'] as num?)?.toInt() ?? -1;
    final isLow = stock >= 0 && stock <= _lowStockThreshold;
    final isOut = stock == 0;

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
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOut
                  ? Colors.red.withOpacity(0.4)
                  : (isLow ? Colors.orange.withOpacity(0.3) : const Color(0xFF0071E3).withOpacity(0.2)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0071E3).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOut ? Icons.warning_amber : Icons.inventory_2,
                      color: isOut ? Colors.redAccent : const Color(0xFF0071E3),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedProduct?['name'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (_selectedProduct?['category'] != null && _selectedProduct!['category'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_selectedProduct!['category'], style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              '${((_selectedProduct?['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك',
                              style: const TextStyle(color: Color(0xFF0071E3), fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // حالة المخزون
                  if (stock >= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isOut
                            ? Colors.red.withOpacity(0.15)
                            : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isOut
                              ? Colors.red.withOpacity(0.4)
                              : (isLow ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.2)),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isOut ? 'نفد' : '$stock',
                            style: TextStyle(
                              color: isOut ? Colors.redAccent : (isLow ? Colors.orange : Colors.greenAccent),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'المخزون',
                            style: TextStyle(
                              color: isOut ? Colors.redAccent.withOpacity(0.7) : (isLow ? Colors.orange.withOpacity(0.7) : Colors.greenAccent.withOpacity(0.7)),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // ملخص الحركة
              Row(
                children: [
                  _buildSummaryBox('المبيعات', '$totalSold', '${totalSalesAmount.toStringAsFixed(3)} د.ك', Colors.green, Icons.sell),
                  const SizedBox(width: 8),
                  _buildSummaryBox('المشتريات', '$totalPurchased', '${totalPurchaseAmount.toStringAsFixed(3)} د.ك', Colors.blue, Icons.shopping_cart),
                  const SizedBox(width: 8),
                  _buildSummaryBox('المرتجعات', '$totalReturned', '', Colors.orange, Icons.undo),
                  const SizedBox(width: 8),
                  _buildSummaryBox('الفواتير', '${_movements.length}', '', Colors.purple, Icons.receipt),
                ],
              ),
            ],
          ),
        ),

        // ─── قائمة الفواتير ────────────────────────────────
        if (_searching)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF0071E3))))
        else if (_movements.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 60, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text('لا توجد فواتير لهذه المادة', style: TextStyle(color: Colors.white38, fontSize: 14)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0071E3).withOpacity(0.08),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
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
      ]
    );
  }

  Widget _buildSummaryBox(String title, String value, String subtitle, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9)),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: TextStyle(color: color.withOpacity(0.5), fontSize: 8), overflow: TextOverflow.ellipsis),
          ],
        ),
      )
    );
  }

  Widget _listHeaderCell(String text, double? width, {int? flex}) {
    final child = Text(text, style: const TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
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
                const SizedBox(width: 4),
                Text(_getTypeAr(type), style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // رقم الفاتورة
          SizedBox(
            width: 70,
            child: Text('#${m['invoiceNumber'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
          ),
          // العميل
          Expanded(
            flex: 3,
            child: Text(m['clientName'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
          ),
          // الكمية
          SizedBox(
            width: 60,
            child: Text('${m['quantity'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ),
          // السعر
          SizedBox(
            width: 80,
            child: Text('${(m['unitPrice'] as num?)?.toDouble().toStringAsFixed(3) ?? '0.000'}', style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
          ),
          // الإجمالي
          SizedBox(
            width: 90,
            child: Text('${(m['total'] as num?)?.toDouble().toStringAsFixed(3) ?? '0.000'}', style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ),
          // التاريخ
          SizedBox(
            width: 110,
            child: Text(_formatDate(m['createdAt']), style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
          ),
        ],
      )
    );
  }
}
