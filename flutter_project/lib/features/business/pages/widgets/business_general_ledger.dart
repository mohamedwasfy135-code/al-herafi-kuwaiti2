import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';

class BusinessGeneralLedger extends StatefulWidget {
  final String uid;
  const BusinessGeneralLedger({super.key, required this.uid});

  @override
  State<BusinessGeneralLedger> createState() => _BusinessGeneralLedgerState();
}

class _BusinessGeneralLedgerState extends State<BusinessGeneralLedger>
    with AutomaticKeepAliveClientMixin {

  String? _filterType; // null = الكل, 'income', 'expense', 'commission', 'purchase'
  String? _filterMonth; // '2026-06' مثلاً
  String? _filterPaymentMethod; // null = الكل, 'cash', 'knet', 'bank'
  String? _filterLedgerAccount; // null = الكل, 'الصندوق', 'كي نت', 'البنك'
  List<String> _availableMonths = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    final snap = await ApiService
        .collection('business_transactions')
        .where('businessId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .get();

    final months = <String>{};
    for (final doc in snap.docs) {
      final ts = doc.data()['createdAt'] as DateTime?;
      if (ts != null) {
        months.add(DateFormat('yyyy-MM').format(ts));
      }
    }
    if (mounted) setState(() => _availableMonths = months.toList()..sort((a, b) => b.compareTo(a)));
  }

  Query _buildQuery() {
    var query = ApiService
        .collection('business_transactions')
        .where('businessId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true);

    if (_filterType != null) {
      query = query.where('type', isEqualTo: _filterType);
    }

    return query;
  }

  // ─── أيقونة طريقة الدفع ─────────────────────────────────────
  IconData _paymentIcon(String? method) {
    switch (method) {
      case 'cash': return Icons.payments;
      case 'knet': return Icons.credit_card;
      case 'bank': return Icons.account_balance;
      default: return Icons.receipt_long;
    }
  }

  Color _paymentColor(String? method) {
    switch (method) {
      case 'cash': return Colors.green;
      case 'knet': return Colors.blue;
      case 'bank': return Colors.purple;
      default: return Colors.white38;
    }
  }

  String _paymentAr(String? method) {
    switch (method) {
      case 'cash': return 'كاش';
      case 'knet': return 'كي نت';
      case 'bank': return 'تحويل بنكي';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
        children: [
          // ── شريط الفلاتر العلوي ──
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // فلتر الشهر
                if (_availableMonths.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _filterMonth ?? 'كل الأشهر',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    onSelected: (v) => setState(() => _filterMonth = v == 'all' ? null : v),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'all', child: Text('كل الأشهر', style: TextStyle(color: _filterMonth == null ? const Color(0xFF0071E3) : Colors.white))),
                      ..._availableMonths.map((m) => PopupMenuItem(value: m, child: Text(m, style: TextStyle(color: _filterMonth == m ? const Color(0xFF0071E3) : Colors.white)))),
                    ],
                  ),
              ],
            ),
          ),

          // ── أرصدة الحسابات (دفتر الأستاذ) ──
          _buildLedgerAccountsBar(),

          // ── أزرار تصفية النوع ──
          Container(
            height: 36,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterChip('الكل', null, _filterType),
                _buildFilterChip('إيرادات', 'income', _filterType),
                _buildFilterChip('مصروفات', 'expense', _filterType),
                _buildFilterChip('مشتريات', 'purchase', _filterType),
                _buildFilterChip('مردود مبيعات', 'sales_return', _filterType),
                _buildFilterChip('مردود مشتريات', 'purchase_return', _filterType),
                _buildFilterChip('عمولات', 'commission', _filterType),
              ],
            ),
          ),

          // ── أزرار تصفية طريقة الدفع ──
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildPaymentFilterChip('كل الطرق', null),
                _buildPaymentFilterChip('كاش', 'cash'),
                _buildPaymentFilterChip('كي نت', 'knet'),
                _buildPaymentFilterChip('بنك', 'bank'),
              ],
            ),
          ),

          // ── القائمة ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
                }

                final docs = snap.data?.docs ?? <QueryDocumentSnapshot>[];

                // تصفية حسب الشهر
                var filteredDocs = docs;
                if (_filterMonth != null) {
                  filteredDocs = docs.where((doc) {
                    final ts = (doc.data() as Map<String, dynamic>)['createdAt'] as DateTime?;
                    if (ts == null) return false;
                    return DateFormat('yyyy-MM').format(ts) == _filterMonth;
                  }).toList();
                }

                // تصفية حسب طريقة الدفع
                if (_filterPaymentMethod != null) {
                  filteredDocs = filteredDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['paymentMethod'] == _filterPaymentMethod;
                  }).toList();
                }

                // تصفية حسب حساب الأستاذ
                if (_filterLedgerAccount != null) {
                  filteredDocs = filteredDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['ledgerAccount'] == _filterLedgerAccount;
                  }).toList();
                }

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('لا توجد حركات مالية', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      ],
                    )
                  );
                }

                // حساب الرصيد التراكمي
                double runningBalance = 0;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredDocs.length + 1, // +1 للرصيد النهائي
                  itemBuilder: (_, i) {
                    if (i == filteredDocs.length) {
                      // صف الرصيد النهائي
                      return Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0071E3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الرصيد النهائي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0071E3))),
                            Text('${runningBalance.toStringAsFixed(3)} د.ك',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0071E3))),
                          ],
                        )
                      );
                    }

                    final doc = filteredDocs[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final type = d['type'] as String? ?? 'expense';
                    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
                    final description = d['description'] as String? ?? '';
                    final category = d['category'] as String? ?? '';
                    final paymentMethod = d['paymentMethod'] as String?;
                    final ledgerAccount = d['ledgerAccount'] as String?;
                    final createdAt = d['createdAt'] as DateTime?;
                    final dateStr = createdAt != null ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt) : '';

                    IconData icon;
                    Color color;
                    double balanceChange;

                    switch (type) {
                      case 'income':
                        icon = Icons.arrow_downward;
                        color = Colors.green;
                        balanceChange = amount;
                        break;
                      case 'expense':
                        icon = Icons.arrow_upward;
                        color = Colors.red;
                        balanceChange = -amount;
                        break;
                      case 'purchase':
                        icon = Icons.shopping_cart;
                        color = Colors.orange;
                        balanceChange = -amount;
                        break;
                      case 'sales_return':
                        icon = Icons.undo;
                        color = Colors.deepOrange;
                        balanceChange = -amount;
                        break;
                      case 'purchase_return':
                        icon = Icons.redo;
                        color = Colors.teal;
                        balanceChange = amount;
                        break;
                      case 'commission':
                        icon = Icons.handshake;
                        color = Colors.amber;
                        balanceChange = -amount;
                        break;
                      default:
                        icon = Icons.swap_horiz;
                        color = Colors.grey;
                        balanceChange = 0;
                    }

                    runningBalance += balanceChange;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            right: type == 'income'
                                ? BorderSide(color: Colors.green.withOpacity(0.4), width: 3)
                                : type == 'purchase'
                                    ? BorderSide(color: Colors.orange.withOpacity(0.4), width: 3)
                                    : BorderSide(color: Colors.red.withOpacity(0.3), width: 3),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(icon, size: 16, color: color),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(description.isNotEmpty ? description : 'حركة مالية',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              // ✅ أيقونة طريقة الدفع
                              if (paymentMethod != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _paymentColor(paymentMethod).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_paymentIcon(paymentMethod), color: _paymentColor(paymentMethod), size: 10),
                                      const SizedBox(width: 2),
                                      Text(_paymentAr(paymentMethod), style: TextStyle(color: _paymentColor(paymentMethod), fontSize: 8, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
                              const SizedBox(width: 6),
                              Text(_translateCategory(category), style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
                              // ✅ حساب الأستاذ
                              if (ledgerAccount != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0071E3).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(ledgerAccount, style: const TextStyle(color: Color(0xFF0071E3), fontSize: 8)),
                                ),
                              ],
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${balanceChange >= 0 ? '+' : ''}${amount.toStringAsFixed(3)} د.ك',
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('${runningBalance.toStringAsFixed(3)} د.ك',
                                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
                            ],
                          ),
                        ),
                      )
                    );
                  }
                );
              },
            ),
          ),
        ]
    );
  }

  // ── شريط أرصدة الحسابات ──────────────────────────────────────
  Widget _buildLedgerAccountsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: ApiService
          .collection('business_ledger')
          .doc(_uid)
          .collection('accounts')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();

        final accounts = snap.data!.docs;
        double totalBalance = 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('أرصدة الحسابات', style: TextStyle(color: Color(0xFF0071E3), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: accounts.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final accountName = data['accountName'] as String? ?? doc.id;
                  final balance = (data['balance'] as num?)?.toDouble() ?? 0;
                  totalBalance += balance;

                  // تحديد اللون حسب الحساب
                  Color accColor;
                  IconData accIcon;
                  if (accountName == 'الصندوق') {
                    accColor = Colors.green;
                    accIcon = Icons.payments;
                  } else if (accountName == 'كي نت') {
                    accColor = Colors.blue;
                    accIcon = Icons.credit_card;
                  } else if (accountName == 'البنك') {
                    accColor = Colors.purple;
                    accIcon = Icons.account_balance;
                  } else {
                    accColor = Colors.white54;
                    accIcon = Icons.folder;
                  }

                  final isSelected = _filterLedgerAccount == accountName;

                  return GestureDetector(
                    onTap: () => setState(() {
                      _filterLedgerAccount = isSelected ? null : accountName;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? accColor.withOpacity(0.2) : accColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? accColor.withOpacity(0.5) : accColor.withOpacity(0.2),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(accIcon, color: accColor, size: 14),
                          const SizedBox(width: 6),
                          Text(accountName, style: TextStyle(color: accColor, fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text('${balance.toStringAsFixed(3)}', style: TextStyle(color: accColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  );
                }).toList(),
              ),
              // الإجمالي
              if (accounts.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Text('إجمالي الأرصدة: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      Text('${totalBalance.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          )
        );
      }
    );
  }

  // ── أزرار الفلتر ────────────────────────────────────────────
  Widget _buildFilterChip(String label, String? type, String? currentFilter) {
    final isSelected = currentFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0071E3).withOpacity(0.3) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0071E3) : Colors.white.withOpacity(0.2)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF0071E3) : Colors.white60, fontSize: 11)),
      )
    );
  }

  Widget _buildPaymentFilterChip(String label, String? method) {
    final isSelected = _filterPaymentMethod == method;
    Color chipColor;
    if (method == 'cash') chipColor = Colors.green;
    else if (method == 'knet') chipColor = Colors.blue;
    else if (method == 'bank') chipColor = Colors.purple;
    else chipColor = const Color(0xFF0071E3);

    return GestureDetector(
      onTap: () => setState(() => _filterPaymentMethod = method),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? chipColor.withOpacity(0.5) : Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (method != null) ...[
              Icon(_paymentIcon(method), color: chipColor, size: 12),
              const SizedBox(width: 3),
            ],
            Text(label, style: TextStyle(color: isSelected ? chipColor : Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      )
    );
  }

  String _translateCategory(String cat) {
    const map = {
      'salary': 'رواتب',
      'rent': 'إيجار',
      'hospitality': 'ضيافة',
      'petty_cash': 'نثريات',
      'delivery': 'توصيل',
      'materials': 'مواد',
      'utilities': 'فواتير',
      'sale': 'مبيعات',
      'مبيعات': 'مبيعات',
      'مشتريات': 'مشتريات',
      'مردود مبيعات': 'مردود مبيعات',
      'مردود مشتريات': 'مردود مشتريات',
      'سند صرف': 'سند صرف',
      'سند قبض': 'سند قبض',
      'other': 'أخرى'
    };
    return map[cat] ?? cat;
  }
}
