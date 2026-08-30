import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة المنتجات – Products Tab (إصدار 2)
// ✅ بطاقات المواد مع الكمية المتوفرة + تنبيه المخزون
// ✅ زر إضافة يعمل + بحث مباشر + حركة مادة
// ═══════════════════════════════════════════════════════════════

class BusinessProductsTab extends StatefulWidget {
  final String uid;
  const BusinessProductsTab({super.key, required this.uid});

  @override
  State<BusinessProductsTab> createState() => _BusinessProductsTabState();
}

class _BusinessProductsTabState extends State<BusinessProductsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterCategory;
  bool _showAddDialog = false;

  static const int _lowStockThreshold = 5;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── إضافة مادة جديدة ──────────────────────────────────────
  Future<void> _showAddProductDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    final descController = TextEditingController();
    final stockController = TextEditingController(text: '0');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.inventory_2, color: Color(0xFF0071E3), size: 22),
          SizedBox(width: 10),
          Text('إضافة مادة جديدة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم المادة *',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  prefixIcon: const Icon(Icons.inventory_2, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0071E3), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'السعر (د.ك) *',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0071E3), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'الكمية المتوفرة في المخزون',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  prefixIcon: const Icon(Icons.warehouse, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0071E3), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'الفئة (اختياري)',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  prefixIcon: const Icon(Icons.category, color: Colors.white38, size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'وصف (اختياري)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
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
          ElevatedButton.icon(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              if (priceController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'price': priceController.text.trim(),
                'category': categoryController.text.trim(),
                'description': descController.text.trim(),
                'stock': stockController.text.trim()
              });
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('إضافة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0071E3),
              foregroundColor: const Color(0xFF1D1D1F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      )
    );

    if (result != null) {
      try {
        final double price = double.tryParse(result['price'] ?? '') ?? 0;
        final int stock = int.tryParse(result['stock'] ?? '') ?? 0;
        await widget.db.collection(kColProducts).add({
          'businessId': widget.uid,
          'name': result['name'],
          'price': price,
          'category': result['category'] ?? '',
          'description': result['description'] ?? '',
          'stockQuantity': stock,
          'isActive': true,
          'createdAt': DateTime.now().toIso8601String()
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

  // ─── تعديل مادة ────────────────────────────────────────────
  Future<void> _editProduct(Map<String, dynamic> product) async {
    final nameController = TextEditingController(text: product['name'] ?? '');
    final priceController = TextEditingController(text: (product['price'] ?? 0).toString());
    final categoryController = TextEditingController(text: product['category'] ?? '');
    final descController = TextEditingController(text: product['description'] ?? '');
    final stockController = TextEditingController(text: (product['stockQuantity'] ?? 0).toString());

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.edit, color: Color(0xFF0071E3), size: 22),
          SizedBox(width: 10),
          Text('تعديل المادة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'اسم المادة',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'السعر (د.ك)',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'الكمية المتوفرة في المخزون',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  prefixIcon: const Icon(Icons.warehouse, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'الفئة',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'وصف...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'price': priceController.text.trim(),
                'category': categoryController.text.trim(),
                'description': descController.text.trim(),
                'stock': stockController.text.trim()
              });
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('حفظ'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F)),
          ),
        ],
      )
    );

    if (result != null) {
      try {
        final double price = double.tryParse(result['price'] ?? '') ?? 0;
        final int stock = int.tryParse(result['stock'] ?? '') ?? 0;
        await widget.db.collection(kColProducts).doc(product['id']).update({
          'name': result['name'],
          'price': price,
          'category': result['category'],
          'description': result['description'],
          'stockQuantity': stock
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تعديل المادة بنجاح'), backgroundColor: Colors.green)
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

  // ─── حذف مادة ──────────────────────────────────────────────
  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.delete, color: Colors.redAccent, size: 22),
          SizedBox(width: 10),
          Text('حذف المادة', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
        ]),
        content: Text('هل تريد حذف "${product['name']}" نهائياً؟', style: const TextStyle(color: Colors.white, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await ApiService.delete('/api/products/${product['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المادة'), backgroundColor: Colors.green)
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

  // ─── أيقونة الفئة ──────────────────────────────────────────
  IconData _categoryIcon(String? cat) {
    if (cat == null || cat.isEmpty) return Icons.inventory_2;
    final lower = cat.toLowerCase();
    if (lower.contains('خدم') || lower.contains('service')) return Icons.build;
    if (lower.contains('قطع') || lower.contains('spare')) return Icons.settings;
    if (lower.contains('كهرب') || lower.contains('electr')) return Icons.electrical_services;
    if (lower.contains('سباك') || lower.contains('plumb')) return Icons.plumbing;
    if (lower.contains('دهان') || lower.contains('paint')) return Icons.format_paint;
    if (lower.contains('نجار') || lower.contains('carpent')) return Icons.carpenter;
    if (lower.contains('تنظيف') || lower.contains('clean')) return Icons.cleaning_services;
    return Icons.inventory_2;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── شريط البحث + زر الإضافة ──────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Color(0xFF0071E3), size: 20),
              const SizedBox(width: 8),
              const Text('المنتجات', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مادة...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 14),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add_circle, size: 20),
                label: const Text('إضافة مادة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),

        // ─── قائمة المنتجات ──────────────────────────────────
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.get('/api/products', queryParameters: {'businessId': widget.uid}).then((res) {
              if (res.success && res.data != null) {
                final list = res.data!['products'] ?? res.data!['data'] ?? [];
                return list.cast<Map<String, dynamic>>();
              }
              return <Map<String, dynamic>>[];
            }),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
              }

              var docs = snap.data ?? <Map<String, dynamic>>[];

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((item) {
                  final name = (item['name'] as String? ?? '').toLowerCase();
                  final category = (item['category'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) || category.contains(_searchQuery);
                }).toList();
              }

              if (_filterCategory != null) {
                docs = docs.where((item) {
                  return item['category'] == _filterCategory;
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد مواد مسجلة',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showAddProductDialog,
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: const Text('أضف مادة جديدة', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0071E3),
                          foregroundColor: const Color(0xFF1D1D1F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  )
                );
              }

              final categories = <String>{};
              for (final item in docs) {
                final cat = (item['category'] as String?) ?? '';
                if (cat.isNotEmpty) categories.add(cat);
              }

              // حساب عدد المواد منخفضة المخزون
              int lowStockCount = 0;
              for (final item in docs) {
                final stock = (item['stockQuantity'] as num?)?.toInt() ?? -1;
                if (stock >= 0 && stock <= _lowStockThreshold) lowStockCount++;
              }

              return Column(
                children: [
                  // تنبيه المخزون المنخفض
                  if (lowStockCount > 0)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            '$lowStockCount مادة لديها مخزون منخفض أو نفد',
                            style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  // فئات التصفية
                  if (categories.isNotEmpty)
                    Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryChip('الكل', null),
                          ...categories.map((c) => _buildCategoryChip(c, c)),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text('${docs.length} مادة', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  // شبكة البطاقات
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = Map<String, dynamic>.from(docs[i]);
                        if (data['id'] == null) data['id'] = '';
                        return _buildProductCard(data);
                      },
                    ),
                  ),
                ]
              );
            },
          ),
        ),
      ]
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _filterCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _filterCategory = value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0071E3).withOpacity(0.2) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF0071E3).withOpacity(0.5) : Colors.white.withOpacity(0.1)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF0071E3) : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
      )
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final category = product['category'] as String? ?? '';
    final description = product['description'] as String? ?? '';
    final isActive = product['isActive'] as bool? ?? true;
    final stock = (product['stockQuantity'] as num?)?.toInt() ?? -1;
    final isLow = stock >= 0 && stock <= _lowStockThreshold;
    final isOut = stock == 0;
    final icon = _categoryIcon(category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOut
              ? Colors.red.withOpacity(0.3)
              : (isLow ? Colors.orange.withOpacity(0.2) : (isActive ? const Color(0xFF0071E3).withOpacity(0.15) : Colors.redAccent.withOpacity(0.2))),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _editProduct(product),
          onLongPress: () => _deleteProduct(product),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصف العلوي: أيقونة + اسم + قائمة
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isOut
                            ? Colors.red.withOpacity(0.12)
                            : (isLow ? Colors.orange.withOpacity(0.12) : const Color(0xFF0071E3).withOpacity(0.12)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOut ? Icons.warning_amber : icon,
                        color: isOut ? Colors.redAccent : (isLow ? Colors.orange : const Color(0xFF0071E3)),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    // زر القائمة
                    PopupMenuButton<String>(
                      offset: const Offset(0, 30),
                      color: const Color(0xFF1D1D1F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: const Color(0xFF0071E3).withOpacity(0.3))),
                      onSelected: (v) {
                        if (v == 'edit') _editProduct(product);
                        if (v == 'delete') _deleteProduct(product);
                        if (v == 'toggle') {
                          ApiService.put('/api/products/${product['id']}', body: {'isActive': !isActive});
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', height: 36, child: Row(children: [const Icon(Icons.edit, color: Colors.blue, size: 16), const SizedBox(width: 8), const Text('تعديل', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                        PopupMenuItem(value: 'toggle', height: 36, child: Row(children: [Icon(isActive ? Icons.visibility_off : Icons.visibility, color: Colors.orange, size: 16), const SizedBox(width: 8), Text(isActive ? 'إلغاء التفعيل' : 'تفعيل', style: const TextStyle(color: Colors.white70, fontSize: 12))])),
                        PopupMenuItem(value: 'delete', height: 36, child: Row(children: [const Icon(Icons.delete, color: Colors.redAccent, size: 16), const SizedBox(width: 8), const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 12))])),
                      ],
                      child: const Icon(Icons.more_vert, color: Colors.white38, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // الفئة
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(category, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ),
                const Spacer(),
                // المخزون والسعر
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // حالة المخزون
                    if (stock >= 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOut
                              ? Colors.red.withOpacity(0.15)
                              : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.08)),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isOut
                                ? Colors.red.withOpacity(0.3)
                                : (isLow ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.15)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOut ? Icons.remove_circle_outline : Icons.warehouse,
                              color: isOut ? Colors.redAccent : (isLow ? Colors.orange : Colors.green),
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isOut ? 'نفد' : '$stock',
                              style: TextStyle(
                                color: isOut ? Colors.redAccent : (isLow ? Colors.orange : Colors.greenAccent),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // السعر
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${price.toStringAsFixed(3)}',
                          style: const TextStyle(color: Color(0xFF0071E3), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Text('د.ك', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                // الوصف
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(description, style: const TextStyle(color: Colors.white24, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ),
      )
    );
  }
}
