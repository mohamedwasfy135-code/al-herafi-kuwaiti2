import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/cross_platform_utils.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:sana3i_kuwait/core/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// Apple Design System Colors
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

// ═══════════════════════════════════════════════════════════════
// صفحة تبويب الفواتير – Invoices Tab
// ✅ عرض جميع الفواتير (مبيعات / مشتريات / مردودات)
// ✅ بحث باسم العميل أو رقم التليفون
// ✅ تصفية حسب النوع والتاريخ
// ═══════════════════════════════════════════════════════════════

class BusinessInvoicesTab extends StatefulWidget {
  final String uid;
  const BusinessInvoicesTab({super.key, required this.uid});

  @override
  State<BusinessInvoicesTab> createState() => _BusinessInvoicesTabState();
}

class _BusinessInvoicesTabState extends State<BusinessInvoicesTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // all | sales | purchase | sales_return | purchase_return
  bool _loading = true;
  List<Map<String, dynamic>> _allInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];

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
      final invoices = await FirestoreService.getSalesInvoices(businessId: widget.uid);
      final purchaseInvoices = await FirestoreService.getPurchaseInvoices(businessId: widget.uid);
      final allInvoices = [...invoices, ...purchaseInvoices];

      // ترتيب يدوي حسب التاريخ (الأحدث أولاً)
      allInvoices.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _allInvoices = allInvoices;
        _filteredInvoices = allInvoices;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterInvoices() {
    setState(() {
      _filteredInvoices = _allInvoices.where((inv) {
        // تصفية حسب النوع
        if (_filterType != 'all') {
          final type = inv['type'] as String? ?? '';
          if (type != _filterType) return false;
        }

        // تصفية حسب البحث
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final clientName = (inv['clientName'] as String? ?? '').toLowerCase();
          final clientPhone = (inv['clientPhone'] as String? ?? '').toLowerCase();
          final invoiceNum = (inv['invoiceNumber']?.toString() ?? '').toLowerCase();
          return clientName.contains(query) ||
              clientPhone.contains(query) ||
              invoiceNum.contains(query);
        }

        return true;
      }).toList();
    });
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

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'sales':
        return _C.success;
      case 'purchase':
        return _C.accent;
      case 'sales_return':
        return _C.warning;
      case 'purchase_return':
        return const Color(0xFFAF52DE);
      default:
        return _C.textS;
    }
  }

  String _getPaymentAr(String? method) {
    switch (method) {
      case 'cash':
        return 'كاش';
      case 'knet':
        return 'كي نت';
      case 'bank':
        return 'تحويل بنكي';
      case 'myinvoice':
        return 'ماي فاتوره';
      case 'credit':
        return 'آجل';
      default:
        return method ?? '';
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is String) {
      final d = DateTime.tryParse(timestamp);
      if (d != null) {
        return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  // ─── عرض تفاصيل الفاتورة ──────────────────────────────────
  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    final type = invoice['type'] as String? ?? '';
    final typeColor = _getTypeColor(type);
    final items = List<Map<String, dynamic>>.from(invoice['items'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(_getTypeIcon(type), color: typeColor, size: 22),
            const SizedBox(width: 10),
            Text(
              'فاتورة ${_getTypeAr(type)} #${invoice['invoiceNumber'] ?? ''}',
              style: TextStyle(color: _C.textP, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: _C.textS, size: 20),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات العميل
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: _C.accent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'العميل: ${invoice['clientName'] ?? 'عميل نقدي'}',
                          style: const TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (invoice['clientPhone'] != null && invoice['clientPhone'].toString().isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone, color: _C.textS, size: 14),
                              const SizedBox(width: 4),
                              Text(invoice['clientPhone'], style: const TextStyle(color: _C.textS, fontSize: 13)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: _C.textS, size: 14),
                        const SizedBox(width: 6),
                        Text(_formatDate(invoice['createdAt']), style: const TextStyle(color: _C.textS, fontSize: 13)),
                        const Spacer(),
                        const Icon(Icons.payment, color: _C.textS, size: 14),
                        const SizedBox(width: 4),
                        Text(_getPaymentAr(invoice['paymentMethod']), style: const TextStyle(color: _C.textS, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // جدول المواد
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: [
                    // رأس الجدول
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: _C.accentLight,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('المادة', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.bold))),
                          SizedBox(width: 60, child: Text('الكمية', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('السعر', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('الإجمالي', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    // الصفوف
                    ...items.map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _C.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text(item['itemName'] ?? '', style: const TextStyle(color: _C.textP, fontSize: 13))),
                          SizedBox(width: 60, child: Text('${item['quantity'] ?? 1}', style: const TextStyle(color: _C.textS, fontSize: 13), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('${((item['unitPrice'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}', style: const TextStyle(color: _C.textS, fontSize: 13), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('${((item['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}', style: const TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // الإجمالي
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('الإجمالي: ', style: TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(
                          '${((invoice['netTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك',
                          style: TextStyle(color: typeColor, fontSize: 21, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (invoice['notes'] != null && invoice['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ملاحظات: ${invoice['notes']}', style: const TextStyle(color: _C.textM, fontSize: 12)),
              ],
              // قسم السداد للفواتير غير المدفوعة
              if (invoice['paymentStatus'] == 'unpaid' || invoice['paymentStatus'] == 'partial') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.danger.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber, color: _C.danger, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            invoice['paymentStatus'] == 'unpaid' ? 'فاتورة غير مدفوعة' : 'مدفوعة جزئياً',
                            style: const TextStyle(color: _C.danger, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            'المتبقي: ${(((invoice['netTotal'] as num?)?.toDouble() ?? 0) - ((invoice['amountPaid'] as num?)?.toDouble() ?? 0)).toStringAsFixed(3)} د.ك',
                            style: const TextStyle(color: _C.warning, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _payInvoiceFromTab(invoice);
                          },
                          icon: const Icon(Icons.payment, size: 14),
                          label: const Text('سداد الفاتورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── حذف فاتورة ──────────────────────────────────────────────
  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.delete, color: _C.danger, size: 22),
          SizedBox(width: 10),
          Text('حذف الفاتورة', style: TextStyle(color: _C.danger, fontSize: 20)),
        ]),
        content: Text(
          'هل تريد حذف فاتورة #${invoice['invoiceNumber'] ?? ''} - ${invoice['clientName'] ?? ''}؟',
          style: const TextStyle(color: _C.textP, fontSize: 18),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _C.danger, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final invId = invoice['id'];
        final invType = invoice['type'] as String? ?? 'sales';
        final endpoint = invType == 'purchase' ? '/api/invoices/purchase' : '/api/invoices/sales';
        await ApiService.delete('$endpoint/$invId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الفاتورة'), backgroundColor: _C.success),
          );
          _loadInvoices();
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

  // ─── سداد فاتورة آجلة ──────────────────────────────────────
  Future<void> _payInvoiceFromTab(Map<String, dynamic> invoice) async {
    final netTotal = (invoice['netTotal'] as num?)?.toDouble() ?? 0;
    final amountPaid = (invoice['amountPaid'] as num?)?.toDouble() ?? 0;
    final remaining = netTotal - amountPaid;
    final invoiceId = invoice['id'] as String?;

    if (invoiceId == null || remaining <= 0) return;

    // اختيار طريقة الدفع
    final paymentMethod = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.payment, color: _C.accent, size: 22),
          SizedBox(width: 10),
          Text('طريقة السداد', style: TextStyle(color: _C.accent, fontSize: 14)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المبلغ المتبقي: ${remaining.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.textS, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _payMethodButton(ctx, 'كاش', 'cash', Icons.payments, _C.success),
              _payMethodButton(ctx, 'كي نت', 'knet', Icons.credit_card, _C.accent),
              _payMethodButton(ctx, 'بنك', 'bank', Icons.account_balance, const Color(0xFFAF52DE)),
              _payMethodButton(ctx, 'ماي فاتوره', 'myinvoice', Icons.receipt_long, _C.warning),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
        ],
      ),
    );

    if (paymentMethod == null) return;

    // سؤال عن المبلغ
    final payAmount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(3));
        return AlertDialog(
          backgroundColor: _C.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('سداد الفاتورة', style: TextStyle(color: _C.accent, fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المبلغ المتبقي: ${remaining.toStringAsFixed(3)} د.ك', style: const TextStyle(color: _C.textS, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: _C.accent, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'المبلغ المراد دفعه',
                  labelStyle: const TextStyle(color: _C.textS),
                  suffixText: 'د.ك',
                  filled: true,
                  fillColor: _C.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.accent, width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: _C.textS))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, remaining),
              child: const Text('دفع الكل', style: TextStyle(color: _C.accent)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(amountCtrl.text.trim()) ?? 0),
              style: ElevatedButton.styleFrom(backgroundColor: _C.accent, foregroundColor: Colors.white),
              child: const Text('دفع'),
            ),
          ],
        );
      },
    );

    if (payAmount == null || payAmount <= 0) return;

    try {
      final now = DateTime.now().toIso8601String();
      final newAmountPaid = amountPaid + payAmount;
      final newStatus = newAmountPaid >= netTotal ? 'paid' : 'partial';

      // تحديث الفاتورة
      final invType = invoice['type'] as String? ?? 'sales';
      final endpoint = invType == 'purchase' ? '/api/invoices/purchase' : '/api/invoices/sales';
      await ApiService.put('$endpoint/$invoiceId', body: {
        'paymentStatus': newStatus,
        'amountPaid': newAmountPaid,
        'status': newStatus,
      });

      // تحديد حساب الأستاذ
      String ledgerAccount;
      switch (paymentMethod) {
        case 'cash': ledgerAccount = 'الصندوق'; break;
        case 'knet': ledgerAccount = 'كي نت'; break;
        case 'bank': ledgerAccount = 'البنك'; break;
        case 'myinvoice': ledgerAccount = 'ماي فاتوره'; break;
        default: ledgerAccount = 'الصندوق';
      }

      String paymentMethodAr;
      switch (paymentMethod) {
        case 'cash': paymentMethodAr = 'كاش'; break;
        case 'knet': paymentMethodAr = 'كي نت'; break;
        case 'bank': paymentMethodAr = 'تحويل بنكي'; break;
        case 'myinvoice': paymentMethodAr = 'ماي فاتوره'; break;
        default: paymentMethodAr = 'كاش';
      }

      // إنشاء حركة مالية
      await ApiService.post('/api/bonds', body: {
        'businessId': widget.uid,
        'type': 'income',
        'amount': payAmount,
        'category': 'سداد فاتورة آجلة',
        'description': 'سداد فاتورة #${invoice['invoiceNumber'] ?? ''} - $paymentMethodAr',
        'invoiceId': invoiceId,
        'clientId': invoice['clientId'],
        'paymentMethod': paymentMethod,
        'ledgerAccount': ledgerAccount,
        'createdAt': now,
      });

      // تحديث دفتر الأستاذ
      await ApiService.post('/api/accounts', body: {
        'businessId': widget.uid,
        'accountName': ledgerAccount,
        'amount': payAmount,
        'type': 'debit',
        'refId': invoiceId,
        'refType': 'سداد فاتورة آجلة',
        'paymentMethod': paymentMethod,
        'createdAt': now,
      });

      // إرسال واتساب لماي فاتوره
      if (paymentMethod == 'myinvoice') {
        final phone = (invoice['clientPhone'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.isNotEmpty) {
          String cleanPhone = phone;
          if (cleanPhone.startsWith('0')) {
            cleanPhone = '965${cleanPhone.substring(1)}';
          } else if (!cleanPhone.startsWith('965')) {
            cleanPhone = '965$cleanPhone';
          }
          final message = 'مرحباً، يرجى سداد المبلغ ${payAmount.toStringAsFixed(3)} د.ك للفاتورة #${invoice['invoiceNumber'] ?? ''} عبر رابط الدفع الآمن.\n\nشكراً لتعاملكم معنا.';
          final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
          await CrossPlatformUtils.openUrl(url);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'paid' ? 'تم سداد الفاتورة بالكامل' : 'تم سداد ${payAmount.toStringAsFixed(3)} د.ك - المتبقي: ${(netTotal - newAmountPaid).toStringAsFixed(3)} د.ك'),
            backgroundColor: _C.success,
          ),
        );
        _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: _C.danger),
        );
      }
    }
  }

  Widget _payMethodButton(BuildContext ctx, String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(ctx, value),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.4))),
          padding: const EdgeInsets.symmetric(vertical: 6),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.accent));
    }

    return Column(
      children: [
        // ─── شريط البحث + التصفية ──────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: _C.surface,
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: _C.accent, size: 14),
                  const SizedBox(width: 8),
                  const Text('الفواتير', style: TextStyle(color: _C.textP, fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // حقل البحث
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: _C.textP, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'بحث باسم العميل أو رقم الهاتف أو رقم الفاتورة...',
                        hintStyle: const TextStyle(color: _C.textM, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: _C.textS, size: 16),
                        filled: true,
                        fillColor: _C.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.accent, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        _searchQuery = v.toLowerCase();
                        _filterInvoices();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _loadInvoices,
                    icon: const Icon(Icons.refresh, color: _C.accent, size: 14),
                    tooltip: 'تحديث',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // أزرار التصفية حسب النوع
              Row(
                children: [
                  _buildFilterChip('الكل', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip('مبيعات', 'sales', color: _C.success),
                  const SizedBox(width: 6),
                  _buildFilterChip('مشتريات', 'purchase', color: _C.accent),
                  const SizedBox(width: 6),
                  _buildFilterChip('مردود مبيعات', 'sales_return', color: _C.warning),
                  const SizedBox(width: 6),
                  _buildFilterChip('مردود مشتريات', 'purchase_return', color: const Color(0xFFAF52DE)),
                  const Spacer(),
                  Text('${_filteredInvoices.length} فاتورة', style: const TextStyle(color: _C.textM, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        // تنبيه الفواتير غير المدفوعة
        if (_allInvoices.any((inv) => inv['paymentStatus'] == 'unpaid'))
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.danger.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: _C.danger, size: 14),
                const SizedBox(width: 8),
                Text(
                  '${_allInvoices.where((inv) => inv['paymentStatus'] == 'unpaid').length} فاتورة غير مدفوعة',
                  style: const TextStyle(color: _C.danger, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterType = 'all';
                      _searchQuery = '';
                    });
                  },
                  child: const Text('عرض', style: TextStyle(color: _C.danger, fontSize: 12)),
                ),
              ],
            ),
          ),

        // ─── قائمة الفواتير ──────────────────────────────────
        Expanded(
          child: _filteredInvoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 80, color: _C.textM.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد فواتير مسجلة',
                        style: const TextStyle(color: _C.textS, fontSize: 20),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: _filteredInvoices.length,
                  itemBuilder: (_, i) {
                    final inv = _filteredInvoices[i];
                    return _buildInvoiceCard(inv);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        _filterType = value;
        _filterInvoices();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? _C.accent).withOpacity(0.15)
              : _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (color ?? _C.accent).withOpacity(0.5)
                : _C.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (color ?? _C.accent) : _C.textS,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status) {
      case 'paid': return _C.success;
      case 'partial': return _C.warning;
      case 'unpaid': return _C.danger;
      default: return _C.success; // افتراضي: مدفوعة
    }
  }

  String _getPaymentStatusAr(String? status) {
    switch (status) {
      case 'paid': return 'مدفوعة';
      case 'partial': return 'مدفوعة جزئياً';
      case 'unpaid': return 'غير مدفوعة';
      default: return 'مدفوعة';
    }
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final type = invoice['type'] as String? ?? '';
    final typeColor = _getTypeColor(type);
    final netTotal = (invoice['netTotal'] as num?)?.toDouble() ?? 0;
    final itemsCount = (invoice['items'] as List?)?.length ?? 0;
    final paymentStatus = invoice['paymentStatus'] as String? ?? 'paid';
    final statusColor = _getPaymentStatusColor(paymentStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showInvoiceDetails(invoice),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // أيقونة النوع
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getTypeIcon(type), color: typeColor, size: 14),
                ),
                const SizedBox(width: 12),
                // معلومات الفاتورة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${invoice['invoiceNumber'] ?? ''}',
                            style: const TextStyle(color: _C.textP, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getPaymentStatusAr(paymentStatus),
                              style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getTypeAr(type),
                              style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _C.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getPaymentAr(invoice['paymentMethod']),
                              style: const TextStyle(color: _C.textM, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, color: _C.textS, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            invoice['clientName'] ?? 'عميل نقدي',
                            style: const TextStyle(color: _C.textS, fontSize: 13),
                          ),
                          if (invoice['clientPhone'] != null && invoice['clientPhone'].toString().isNotEmpty) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.phone, color: _C.textS, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              invoice['clientPhone'],
                              style: const TextStyle(color: _C.textM, fontSize: 12),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Text('$itemsCount مادة', style: const TextStyle(color: _C.border, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                // التاريخ والإجمالي
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(invoice['createdAt']),
                      style: const TextStyle(color: _C.textM, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${netTotal.toStringAsFixed(3)} د.ك',
                      style: TextStyle(color: typeColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // زر القائمة
                PopupMenuButton<String>(
                  offset: const Offset(0, 30),
                  color: _C.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: _C.border),
                  ),
                  onSelected: (v) {
                    if (v == 'view') _showInvoiceDetails(invoice);
                    if (v == 'delete') _deleteInvoice(invoice);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'view',
                      height: 36,
                      child: Row(children: [
                        const Icon(Icons.visibility, color: _C.accent, size: 16),
                        const SizedBox(width: 8),
                        const Text('عرض التفاصيل', style: TextStyle(color: _C.textS, fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 36,
                      child: Row(children: [
                        const Icon(Icons.delete, color: _C.danger, size: 16),
                        const SizedBox(width: 8),
                        const Text('حذف', style: TextStyle(color: _C.danger, fontSize: 13)),
                      ]),
                    ),
                  ],
                  child: const Icon(Icons.more_vert, color: _C.textS, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
