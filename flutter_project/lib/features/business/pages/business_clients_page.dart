import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class BusinessClientsPage extends StatefulWidget {
  final String uid;
  const BusinessClientsPage({super.key, required this.uid});

  @override
  State<BusinessClientsPage> createState() => _BusinessClientsPageState();
}

class _BusinessClientsPageState extends State<BusinessClientsPage>
    with AutomaticKeepAliveClientMixin {
  late final _uid = widget.uid;

  @override
  bool get wantKeepAlive => true;

  Future<void> _addClient() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عميل جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(_, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    final res = await ApiService.post('/api/clients', body: {
      'businessId': _uid,
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'totalPurchases': 0,
      'totalPaid': 0,
      'balance': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (!res.success) {
      _snack('❌ خطأ: ${res.errorMessage}');
      return;
    }
    _snack('✅ تم إضافة العميل');
    _loadClients();
  }

  Future<void> _recordPayment(Map<String, dynamic> clientData) async {
    final amountCtrl = TextEditingController();
    final currentBalance = (clientData['balance'] as num?)?.toDouble() ?? 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تسديد دفعة من ${clientData['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المبلغ المستحق: ${currentBalance.toStringAsFixed(3)} د.ك'),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(_, true), child: const Text('تسجيل الدفعة')),
        ],
      ),
    );
    if (ok != true) return;

    final paidAmount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (paidAmount <= 0) return;

    final newBalance = (currentBalance - paidAmount).clamp(0, double.infinity);
    final clientId = clientData['id'];

    await ApiService.put('/api/clients/$clientId', body: {
      'totalPaid': ((clientData['totalPaid'] as num?)?.toDouble() ?? 0) + paidAmount,
      'balance': newBalance,
      'lastPayment': DateTime.now().toIso8601String(),
    });

    // إضافة كإيراد في الحركات المالية
    await ApiService.post('/api/accounting/transactions', body: {
      'businessId': _uid,
      'type': 'income',
      'amount': paidAmount,
      'description': 'تسديد دفعة من ${clientData['name']}',
      'category': 'sale',
      'clientId': clientId,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': _uid,
    });

    _snack('✅ تم تسجيل الدفعة');
    _loadClients();
  }

  Future<void> _deleteClient(Map<String, dynamic> clientData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العميل'),
        content: const Text('هل أنت متأكد من حذف هذا العميل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(_, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.delete('/api/clients/${clientData['id']}');
      _snack('🗑️ تم حذف العميل');
      _loadClients();
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: const Color(0xFF0071E3), behavior: SnackBarBehavior.floating),
    );
  }

  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final res = await ApiService.get('/api/clients', queryParameters: {'businessId': _uid});
    if (res.success && res.data != null) {
      final list = res.data!['clients'] ?? res.data!['data'];
      if (list is List) {
        setState(() {
          _clients = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));

    return Scaffold(
      body: _clients.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 72, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('لا يوجد عملاء بعد', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _clients.length,
              itemBuilder: (_, i) {
                final d = _clients[i];
                final name = d['name'] as String? ?? '';
                final phone = d['phone'] as String? ?? '';
                final totalPurchases = (d['totalPurchases'] as num?)?.toDouble() ?? 0;
                final totalPaid = (d['totalPaid'] as num?)?.toDouble() ?? 0;
                final balance = (d['balance'] as num?)?.toDouble() ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: balance > 0 ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                          child: Icon(balance > 0 ? Icons.pending : Icons.check_circle, color: balance > 0 ? Colors.orange : Colors.green),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (phone.isNotEmpty)
                              Text(phone, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                            Row(
                              children: [
                                Text('المشتريات: ${totalPurchases.toStringAsFixed(3)} د.ك',
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                                const SizedBox(width: 12),
                                Text('المدفوع: ${totalPaid.toStringAsFixed(3)} د.ك',
                                    style: TextStyle(color: Colors.green.withOpacity(0.8), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        trailing: balance > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                child: Text('${balance.toStringAsFixed(3)} د.ك',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            : const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _recordPayment(d),
                                  icon: const Icon(Icons.payment, size: 16),
                                  label: const Text('تسجيل دفعة', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.withOpacity(0.3),
                                    foregroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _deleteClient(d),
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('حذف', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.withOpacity(0.3),
                                    foregroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClient,
        backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
        foregroundColor: const Color(0xFF1D1D1F),
        icon: const Icon(Icons.person_add),
        label: const Text('عميل جديد'),
      ),
    );
  }
}