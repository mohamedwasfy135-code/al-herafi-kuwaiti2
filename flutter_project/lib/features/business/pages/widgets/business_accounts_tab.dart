import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة إدارة الحسابات – Accounts Tab
// عملاء / موردين / حسابات مصروفات (إيجارات / نثريات / هاتف / رواتب)
// ═══════════════════════════════════════════════════════════════

class BusinessAccountsTab extends StatefulWidget {
  final String uid;
  const BusinessAccountsTab({super.key, required this.uid});

  @override
  State<BusinessAccountsTab> createState() => _BusinessAccountsTabState();
}

class _BusinessAccountsTabState extends State<BusinessAccountsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── شريط العنوان ────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Color(0xFF0071E3), size: 20),
              const SizedBox(width: 8),
              const Text('إدارة الحسابات', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // ─── التبويبات ────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFF0071E3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF0071E3),
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.people, size: 14), text: 'العملاء'),
              Tab(icon: Icon(Icons.store, size: 14), text: 'الموردين'),
              Tab(icon: Icon(Icons.account_balance, size: 14), text: 'حسابات المصروفات'),
            ],
          ),
        ),

        // ─── محتوى التبويب ────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildClientsTab(),
              _buildSuppliersTab(),
              _buildExpenseAccountsTab(),
            ],
          ),
        ),
      ]
    );
  }

  // ═══════════════════════════════════════════════════════════
  // تبويب العملاء
  // ═══════════════════════════════════════════════════════════
  Widget _buildClientsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Text('العملاء', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddAccountDialog('client'),
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text('إضافة عميل', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.get('/api/clients', queryParameters: {'businessId': widget.uid}).then((res) {
              if (res.success && res.data != null) {
                final list = res.data!['clients'] ?? res.data!['data'] ?? [];
                return list.cast<Map<String, dynamic>>();
              }
              return <Map<String, dynamic>>[];
            }),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
              }
              final docs = snap.data ?? <Map<String, dynamic>>[];
              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 60, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('لا يوجد عملاء مسجلين', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = Map<String, dynamic>.from(docs[i]);
                  if (data['id'] == null) data['id'] = '';
                  return _buildAccountCard(
                    data: data,
                    type: 'client',
                    icon: Icons.person,
                    color: Colors.blue,
                    nameKey: 'name',
                    phoneKey: 'phone',
                    extra: 'إجمالي المشتريات: ${((data['totalPurchases'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك'
                  );
                }
              );
            },
          ),
        ),
      ]
    );
  }

  // ═══════════════════════════════════════════════════════════
  // تبويب الموردين
  // ═══════════════════════════════════════════════════════════
  Widget _buildSuppliersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Text('الموردين', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddAccountDialog('supplier'),
                icon: const Icon(Icons.store, size: 14),
                label: const Text('إضافة مورد', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.get('/api/suppliers', queryParameters: {'businessId': widget.uid}).then((res) {
              if (res.success && res.data != null) {
                final list = res.data!['suppliers'] ?? res.data!['data'] ?? [];
                return list.cast<Map<String, dynamic>>();
              }
              return <Map<String, dynamic>>[];
            }),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
              }
              final docs = snap.data ?? <Map<String, dynamic>>[];
              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_outlined, size: 60, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('لا يوجد موردين مسجلين', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = Map<String, dynamic>.from(docs[i]);
                  if (data['id'] == null) data['id'] = '';
                  return _buildAccountCard(
                    data: data,
                    type: 'supplier',
                    icon: Icons.store,
                    color: Colors.teal,
                    nameKey: 'name',
                    phoneKey: 'phone',
                    extra: 'إجمالي التوريد: ${((data['totalPurchases'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك'
                  );
                }
              );
            },
          ),
        ),
      ]
    );
  }

  // ═══════════════════════════════════════════════════════════
  // تبويب حسابات المصروفات
  // ═══════════════════════════════════════════════════════════
  Widget _buildExpenseAccountsTab() {
    // حسابات المصروفات الافتراضية
    final expenseCategories = [
      {'key': 'rent', 'nameAr': 'إيجارات', 'icon': Icons.home_work, 'color': Colors.orange},
      {'key': 'salary', 'nameAr': 'رواتب عمال', 'icon': Icons.badge, 'color': Colors.indigo},
      {'key': 'utilities', 'nameAr': 'مصاريف هاتف وانترنت', 'icon': Icons.wifi, 'color': Colors.cyan},
      {'key': 'petty_cash', 'nameAr': 'نثريات', 'icon': Icons.coffee, 'color': Colors.brown},
      {'key': 'hospitality', 'nameAr': 'ضيافة', 'icon': Icons.celebration, 'color': Colors.pink},
      {'key': 'delivery', 'nameAr': 'توصيل', 'icon': Icons.local_shipping, 'color': Colors.green},
      {'key': 'materials', 'nameAr': 'مواد', 'icon': Icons.inventory_2, 'color': Colors.amber},
      {'key': 'other', 'nameAr': 'مصروفات أخرى', 'icon': Icons.more_horiz, 'color': Colors.grey},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Text('حسابات المصروفات', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseAccountDialog(),
                icon: const Icon(Icons.add_circle, size: 14),
                label: const Text('إضافة حساب', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        // حسابات المصروفات المخصصة من Firestore
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.get('/api/expense-accounts', queryParameters: {'businessId': widget.uid}).then((res) {
              if (res.success && res.data != null) {
                final list = res.data!['accounts'] ?? res.data!['data'] ?? [];
                return list.cast<Map<String, dynamic>>();
              }
              return <Map<String, dynamic>>[];
            }),
            builder: (_, snap) {
              final customAccounts = snap.data ?? <Map<String, dynamic>>[];

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: expenseCategories.length + customAccounts.length,
                itemBuilder: (_, i) {
                  // الحسابات الافتراضية أولاً
                  if (i < expenseCategories.length) {
                    final cat = expenseCategories[i];
                    return _buildExpenseCategoryCard(
                      name: cat['nameAr'] as String,
                      icon: cat['icon'] as IconData,
                      color: cat['color'] as Color,
                      isDefault: true
                    );
                  }
                  // الحسابات المخصصة
                  final data = Map<String, dynamic>.from(customAccounts[i - expenseCategories.length]);
                  if (data['id'] == null) data['id'] = '';
                  return _buildExpenseCategoryCard(
                    name: data['name'] ?? '',
                    icon: Icons.folder,
                    color: Colors.white54,
                    isDefault: false,
                    data: data
                  );
                }
              );
            },
          ),
        ),
      ]
    );
  }

  // ─── بطاقة حساب ──────────────────────────────────────────
  Widget _buildAccountCard({
    required Map<String, dynamic> data,
    required String type,
    required IconData icon,
    required Color color,
    required String nameKey,
    required String phoneKey,
    String? extra
  }) {
    final name = data[nameKey] as String? ?? '';
    final phone = data[phoneKey] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: color.withOpacity(0.4), width: 3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.phone, color: Colors.white38, size: 10),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ]),
                  ),
                if (extra != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(extra, style: const TextStyle(color: Colors.white24, fontSize: 9)),
                  ),
              ],
            ),
          ),
          // أزرار
          IconButton(
            onPressed: () => _editAccountDialog(type, data),
            icon: const Icon(Icons.edit, color: Colors.blue, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            onPressed: () => _deleteAccount(type, data),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      )
    );
  }

  // ─── بطاقة فئة المصروفات ────────────────────────────────
  Widget _buildExpenseCategoryCard({
    required String name,
    required IconData icon,
    required Color color,
    required bool isDefault,
    Map<String, dynamic>? data
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isDefault ? null : () => _editExpenseAccountDialog(data!),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (!isDefault && data != null)
                  IconButton(
                    onPressed: () => _deleteExpenseAccount(data),
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  ),
              ],
            ),
          ),
        ),
      )
    );
  }

  // ═══════════════════════════════════════════════════════════
  // نوافذ الحوار
  // ═══════════════════════════════════════════════════════════

  // ─── إضافة حساب (عميل / مورد) ─────────────────────────
  Future<void> _showAddAccountDialog(String type) async {
    final isClient = type == 'client';
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(isClient ? Icons.person_add : Icons.store, color: const Color(0xFF0071E3), size: 22),
          const SizedBox(width: 10),
          Text(isClient ? 'إضافة عميل جديد' : 'إضافة مورد جديد', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        ]),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isClient ? 'اسم العميل *' : 'اسم المورد *',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  prefixIcon: Icon(isClient ? Icons.person : Icons.store, color: const Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  prefixIcon: const Icon(Icons.phone, color: Colors.white38, size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  prefixIcon: const Icon(Icons.location_on, color: Colors.white38, size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'ملاحظات (اختياري)...',
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
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'address': addressController.text.trim(),
                'notes': notesController.text.trim()
              });
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('إضافة'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F)),
          ),
        ],
      )
    );

    if (result != null) {
      try {
        final collection = isClient ? 'business_clients' : 'business_suppliers';
        await widget.db.collection(collection).doc(widget.uid).collection('items').add({
          'name': result['name'],
          'phone': result['phone'] ?? '',
          'address': result['address'] ?? '',
          'notes': result['notes'] ?? '',
          'totalPurchases': 0,
          'invoiceCount': 0,
          'createdAt': DateTime.now().toIso8601String()
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إضافة ${isClient ? "العميل" : "المورد"} بنجاح'), backgroundColor: Colors.green)
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

  // ─── تعديل حساب ────────────────────────────────────────
  Future<void> _editAccountDialog(String type, Map<String, dynamic> data) async {
    final isClient = type == 'client';
    final nameController = TextEditingController(text: data['name'] ?? '');
    final phoneController = TextEditingController(text: data['phone'] ?? '');
    final addressController = TextEditingController(text: data['address'] ?? '');
    final notesController = TextEditingController(text: data['notes'] ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(isClient ? 'تعديل بيانات العميل' : 'تعديل بيانات المورد', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'ملاحظات...',
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'address': addressController.text.trim(),
                'notes': notesController.text.trim()
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F)),
            child: const Text('حفظ'),
          ),
        ],
      )
    );

    if (result != null) {
      try {
        final collection = isClient ? 'business_clients' : 'business_suppliers';
        await widget.db.collection(collection).doc(widget.uid).collection('items').doc(data['id']).update({
          'name': result['name'],
          'phone': result['phone'],
          'address': result['address'],
          'notes': result['notes']
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم التعديل بنجاح'), backgroundColor: Colors.green)
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

  // ─── حذف حساب ──────────────────────────────────────────
  Future<void> _deleteAccount(String type, Map<String, dynamic> data) async {
    final isClient = type == 'client';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('حذف ${isClient ? "العميل" : "المورد"}', style: const TextStyle(color: Colors.redAccent)),
        content: Text('هل تريد حذف "${data['name']}" نهائياً؟', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), child: const Text('حذف')),
        ],
      )
    );

    if (confirm == true) {
      try {
        final collection = isClient ? 'business_clients' : 'business_suppliers';
        await widget.db.collection(collection).doc(widget.uid).collection('items').doc(data['id']).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green)
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

  // ─── إضافة حساب مصروفات مخصص ─────────────────────────
  Future<void> _showAddExpenseAccountDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.add_circle, color: Color(0xFF0071E3), size: 22),
          SizedBox(width: 10),
          Text('إضافة حساب مصروفات', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم الحساب *',
                  labelStyle: const TextStyle(color: Color(0xFF0071E3), fontSize: 13),
                  prefixIcon: const Icon(Icons.folder, color: Color(0xFF0071E3), size: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('مثال: صيانة سيارات، وقود، إصلاحات...', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton.icon(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, nameController.text.trim());
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('إضافة'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F)),
          ),
        ],
      )
    );

    if (result != null) {
      try {
        await widget.db.collection('business_expense_accounts').doc(widget.uid).collection('items').add({
          'name': result,
          'createdAt': DateTime.now().toIso8601String()
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إضافة حساب "$result"'), backgroundColor: Colors.green)
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

  // ─── تعديل حساب مصروفات مخصص ─────────────────────────
  Future<void> _editExpenseAccountDialog(Map<String, dynamic> data) async {
    final nameController = TextEditingController(text: data['name'] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('تعديل الحساب', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'اسم الحساب',
            labelStyle: const TextStyle(color: Color(0xFF0071E3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F)),
            child: const Text('حفظ'),
          ),
        ],
      )
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ApiService.put('/api/expense-accounts/${data['id']}', body: {'name': result});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم التعديل'), backgroundColor: Colors.green)
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

  // ─── حذف حساب مصروفات مخصص ───────────────────────────
  Future<void> _deleteExpenseAccount(Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        title: const Text('حذف الحساب', style: TextStyle(color: Colors.redAccent)),
        content: Text('هل تريد حذف "${data['name']}"؟', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), child: const Text('حذف')),
        ],
      )
    );

    if (confirm == true) {
      try {
        await ApiService.delete('/api/expense-accounts/${data['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green)
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
}
