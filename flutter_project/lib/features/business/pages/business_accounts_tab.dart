import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// صفحة إدارة الحسابات – Accounts Tab
// عملاء / موردين / حسابات مصروفات (إيجارات / نثريات / هاتف / رواتب)
// ═══════════════════════════════════════════════════════════════

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
            color: _C.bg,
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: _C.accent, size: 20),
              const SizedBox(width: 8),
              const Text('إدارة الحسابات', style: TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // ─── التبويبات ────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: _C.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _C.accent,
            unselectedLabelColor: _C.textM,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.people, size: 16), text: 'العملاء'),
              Tab(icon: Icon(Icons.store, size: 16), text: 'الموردين'),
              Tab(icon: Icon(Icons.account_balance, size: 16), text: 'حسابات المصروفات'),
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
      ],
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
              const Text('العملاء', style: TextStyle(color: _C.textS, fontSize: 13)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddAccountDialog('client'),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('إضافة عميل', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
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
                final list = res.data!['clients'] ?? res.data!['data'];
                if (list is List) return list.cast<Map<String, dynamic>>();
              }
              return <Map<String, dynamic>>[];
            }),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _C.accent));
              }
              final docs = snap.data ?? [];
              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 60, color: _C.textM.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text('لا يوجد عملاء مسجلين', style: TextStyle(color: _C.textM, fontSize: 18)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i];
                  return _buildAccountCard(
                    data: data,
                    type: 'client',
                    icon: Icons.person,
                    color: _C.accent,
                    nameKey: 'name',
                    phoneKey: 'phone',
                    extra: 'إجمالي المشتريات: ${((data['totalPurchases'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك',
                  );
                },
              );
            },
          ),
        ),
      ],
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
              const Text('الموردين', style: TextStyle(color: _C.textS, fontSize: 13)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddAccountDialog('supplier'),
                icon: const Icon(Icons.store, size: 16),
                label: const Text('إضافة مورد', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
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
                final list = res.data!['suppliers'] ?? res.data!['data'];
                if (list is List) return list.cast<Map<String, dynamic>>();
              }
              return <Map<String, dynamic>>[];
            }),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _C.accent));
              }
              final docs = snap.data ?? [];
              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_outlined, size: 60, color: _C.textM.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text('لا يوجد موردين مسجلين', style: TextStyle(color: _C.textM, fontSize: 18)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i];
                  return _buildAccountCard(
                    data: data,
                    type: 'supplier',
                    icon: Icons.store,
                    color: Colors.teal,
                    nameKey: 'name',
                    phoneKey: 'phone',
                    extra: 'إجمالي التوريد: ${((data['totalPurchases'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك',
                  );
                },
              );
            },
          ),
        ),
      ],
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
              const Text('حسابات المصروفات', style: TextStyle(color: _C.textS, fontSize: 13)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseAccountDialog(),
                icon: const Icon(Icons.add_circle, size: 16),
                label: const Text('إضافة حساب', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
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
            future: ApiService.get('/api/categories', queryParameters: {'businessId': widget.uid, 'type': 'expense_account'}).then((res) {
              if (res.success && res.data != null) {
                final list = res.data!['categories'] ?? res.data!['data'];
                if (list is List) return list.cast<Map<String, dynamic>>();
              }
              return <Map<String, dynamic>>[];
            }),
            builder: (_, snap) {
              final customAccounts = snap.data ?? [];

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
                  if (i < expenseCategories.length) {
                    final cat = expenseCategories[i];
                    return _buildExpenseCategoryCard(
                      name: cat['nameAr'] as String,
                      icon: cat['icon'] as IconData,
                      color: cat['color'] as Color,
                      isDefault: true,
                    );
                  }
                  final data = customAccounts[i - expenseCategories.length];
                  return _buildExpenseCategoryCard(
                    name: data['name'] ?? '',
                    icon: Icons.folder,
                    color: _C.textM,
                    isDefault: false,
                    data: data,
                  );
                },
              );
            },
          ),
        ),
      ],
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
    String? extra,
  }) {
    final name = data[nameKey] as String? ?? '';
    final phone = data[phoneKey] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: color, width: 3), left: BorderSide.none, top: BorderSide.none, bottom: BorderSide.none),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.w600)),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.phone, color: _C.textS, size: 11),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(color: _C.textM, fontSize: 12)),
                    ]),
                  ),
                if (extra != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(extra, style: const TextStyle(color: _C.textM, fontSize: 14)),
                  ),
              ],
            ),
          ),
          // أزرار
          IconButton(
            onPressed: () => _editAccountDialog(type, data),
            icon: Icon(Icons.edit, color: _C.accent, size: 15),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            onPressed: () => _deleteAccount(type, data),
            icon: Icon(Icons.delete_outline, color: _C.danger, size: 15),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  // ─── بطاقة فئة المصروفات ────────────────────────────────
  Widget _buildExpenseCategoryCard({
    required String name,
    required IconData icon,
    required Color color,
    required bool isDefault,
    Map<String, dynamic>? data,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (isDefault) {
              _openExpensePayment(name);
            } else if (data != null) {
              _showExpenseAccountActions(data, name);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 6),
                Text(name, style: TextStyle(color: _C.textP, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                // علامة "مفعّل" للحسابات
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: _C.success, size: 11),
                      SizedBox(width: 2),
                      Text('مفعّل', style: TextStyle(color: _C.success, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (!isDefault && data != null)
                  IconButton(
                    onPressed: () => _deleteExpenseAccount(data),
                    icon: Icon(Icons.close, color: _C.danger, size: 13),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
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
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(isClient ? Icons.person_add : Icons.store, color: _C.accent, size: 22),
          const SizedBox(width: 10),
          Text(isClient ? 'إضافة عميل جديد' : 'إضافة مورد جديد', style: const TextStyle(color: _C.textP, fontSize: 20)),
        ]),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: _C.textP),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isClient ? 'اسم العميل *' : 'اسم المورد *',
                  labelStyle: const TextStyle(color: _C.accent, fontSize: 13),
                  prefixIcon: Icon(isClient ? Icons.person : Icons.store, color: _C.accent, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                  prefixIcon: const Icon(Icons.phone, color: _C.textM, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                  prefixIcon: const Icon(Icons.location_on, color: _C.textM, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                style: const TextStyle(color: _C.textP),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'ملاحظات (اختياري)...',
                  hintStyle: const TextStyle(color: _C.textM, fontSize: 13),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton.icon(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'address': addressController.text.trim(),
                'notes': notesController.text.trim(),
              });
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('إضافة'),
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final endpoint = isClient ? '/api/clients' : '/api/suppliers';
        await ApiService.post(endpoint, body: {
          'businessId': widget.uid,
          'name': result['name'],
          'phone': result['phone'] ?? '',
          'address': result['address'] ?? '',
          'notes': result['notes'] ?? '',
          'totalPurchases': 0,
          'invoiceCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إضافة ${isClient ? "العميل" : "المورد"} بنجاح'), backgroundColor: _C.success),
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
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(isClient ? 'تعديل بيانات العميل' : 'تعديل بيانات المورد', style: const TextStyle(color: _C.textP, fontSize: 20)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  labelStyle: const TextStyle(color: _C.accent, fontSize: 13),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                style: const TextStyle(color: _C.textP),
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  labelStyle: const TextStyle(color: _C.textS, fontSize: 13),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                style: const TextStyle(color: _C.textP),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'ملاحظات...',
                  hintStyle: const TextStyle(color: _C.textM, fontSize: 13),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'address': addressController.text.trim(),
                'notes': notesController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final endpoint = isClient ? '/api/clients' : '/api/suppliers';
        await ApiService.put('$endpoint/${data['id']}', body: {
          'name': result['name'],
          'phone': result['phone'],
          'address': result['address'],
          'notes': result['notes'],
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم التعديل بنجاح'), backgroundColor: _C.success),
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

  // ─── حذف حساب ──────────────────────────────────────────
  Future<void> _deleteAccount(String type, Map<String, dynamic> data) async {
    final isClient = type == 'client';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('حذف ${isClient ? "العميل" : "المورد"}', style: const TextStyle(color: _C.danger)),
        content: Text('هل تريد حذف "${data['name']}" نهائياً؟', style: const TextStyle(color: _C.textP)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _C.danger, foregroundColor: Colors.white), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final endpoint = isClient ? '/api/clients' : '/api/suppliers';
        await ApiService.delete('$endpoint/${data['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحذف'), backgroundColor: _C.success),
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

  // ─── إضافة حساب مصروفات مخصص ─────────────────────────
  Future<void> _showAddExpenseAccountDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.add_circle, color: _C.accent, size: 22),
          SizedBox(width: 10),
          Text('إضافة حساب مصروفات', style: TextStyle(color: _C.textP, fontSize: 20)),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: _C.textP),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم الحساب *',
                  labelStyle: const TextStyle(color: _C.accent, fontSize: 13),
                  prefixIcon: const Icon(Icons.folder, color: _C.accent, size: 14),
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('مثال: صيانة سيارات، وقود، إصلاحات...', style: TextStyle(color: _C.textM, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton.icon(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, nameController.text.trim());
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('إضافة'),
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ApiService.post('/api/categories', body: {
          'businessId': widget.uid,
          'type': 'expense_account',
          'name': result,
          'createdAt': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إضافة حساب "$result"'), backgroundColor: _C.success),
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

  // ─── تعديل حساب مصروفات مخصص ─────────────────────────
  Future<void> _editExpenseAccountDialog(Map<String, dynamic> data) async {
    final nameController = TextEditingController(text: data['name'] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('تعديل الحساب', style: TextStyle(color: _C.textP, fontSize: 20)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: _C.textP),
          decoration: InputDecoration(
            labelText: 'اسم الحساب',
            labelStyle: const TextStyle(color: _C.accent),
            filled: true,
            fillColor: _C.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _C.accent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ApiService.put('/api/categories/${data['id']}', body: {'name': result});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم التعديل'), backgroundColor: _C.success),
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

  // ─── فتح سند صرف لحساب مصروفات ───────────────────────────
  void _openExpensePayment(String accountName) {
    // التوجيه لصفحة سند الصرف مع تعبئة حساب المصروفات
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('سيتم فتح سند صرف لحساب: $accountName'),
        backgroundColor: _C.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── إجراءات حساب المصروفات المخصص ───────────────────────
  void _showExpenseAccountActions(Map<String, dynamic> data, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: const TextStyle(color: _C.textP, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.payment, color: _C.success, size: 20),
              title: const Text('سند صرف', style: TextStyle(color: _C.textP, fontSize: 18)),
              subtitle: const Text('إنشاء سند صرف لهذا الحساب', style: TextStyle(color: _C.textM, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _openExpensePayment(name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: _C.accent, size: 20),
              title: const Text('تعديل', style: TextStyle(color: _C.textP, fontSize: 18)),
              onTap: () {
                Navigator.pop(ctx);
                _editExpenseAccountDialog(data);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: _C.danger, size: 20),
              title: const Text('حذف', style: TextStyle(color: _C.danger, fontSize: 18)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteExpenseAccount(data);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── حذف حساب مصروفات مخصص ───────────────────────────
  Future<void> _deleteExpenseAccount(Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('حذف الحساب', style: TextStyle(color: _C.danger)),
        content: Text('هل تريد حذف "${data['name']}"؟', style: const TextStyle(color: _C.textP)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _C.danger, foregroundColor: Colors.white), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.delete('/api/categories/${data['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحذف'), backgroundColor: _C.success),
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
}
