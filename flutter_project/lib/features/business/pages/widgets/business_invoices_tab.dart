import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

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
      final res = await ApiService.get('/api/invoices', queryParameters: {
        'businessId': widget.uid,
        'limit': '500',
      });

      List<Map<String, dynamic>> invoices = [];
      if (res.success && res.data != null) {
        final list = res.data!['invoices'] ?? res.data!['data'] ?? [];
        if (list is List) {
          invoices = list.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            if (m['id'] == null) m['id'] = '';
            return m;
          }).toList();
        }
      }

      setState(() {
        _allInvoices = invoices;
        _filteredInvoices = invoices;
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

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final d = timestamp;
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(_getTypeIcon(type), color: typeColor, size: 22),
            const SizedBox(width: 10),
            Text(
              'فاتورة ${_getTypeAr(type)} #${invoice['invoiceNumber'] ?? ''}',
              style: TextStyle(color: typeColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: Colors.white38, size: 20),
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
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF0071E3), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'العميل: ${invoice['clientName'] ?? 'عميل نقدي'}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (invoice['clientPhone'] != null && invoice['clientPhone'].toString().isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone, color: Colors.white38, size: 14),
                              const SizedBox(width: 4),
                              Text(invoice['clientPhone'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.white38, size: 14),
                        const SizedBox(width: 6),
                        Text(_formatDate(invoice['createdAt']), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const Spacer(),
                        Icon(Icons.payment, color: Colors.white38, size: 14),
                        const SizedBox(width: 4),
                        Text(_getPaymentAr(invoice['paymentMethod']), style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    // رأس الجدول
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0071E3).withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('المادة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.bold))),
                          SizedBox(width: 60, child: Text('الكمية', style: TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('السعر', style: TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('الإجمالي', style: TextStyle(color: Color(0xFF0071E3), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    // الصفوف
                    ...items.map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text(item['itemName'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                          SizedBox(width: 60, child: Text('${item['quantity'] ?? 1}', style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('${((item['unitPrice'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}', style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center)),
                          SizedBox(width: 80, child: Text('${((item['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}', style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
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
                        const Text('الإجمالي: ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          '${((invoice['netTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك',
                          style: TextStyle(color: typeColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (invoice['notes'] != null && invoice['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ملاحظات: ${invoice['notes']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ],
          ),
        ),
      )
    );
  }

  // ─── حذف فاتورة ──────────────────────────────────────────────
  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.delete, color: Colors.redAccent, size: 22),
          SizedBox(width: 10),
          Text('حذف الفاتورة', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
        ]),
        content: Text(
          'هل تريد حذف فاتورة #${invoice['invoiceNumber'] ?? ''} - ${invoice['clientName'] ?? ''}؟',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
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
        await ApiService.delete('/api/invoices/\${invoice['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الفاتورة'), backgroundColor: Colors.green)
          );
          _loadInvoices();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    return Column(
      children: [
        // ─── شريط البحث + التصفية ──────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF0071E3), size: 20),
                  const SizedBox(width: 8),
                  const Text('الفواتير', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // حقل البحث
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'بحث باسم العميل أو رقم الهاتف أو رقم الفاتورة...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 14),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                    icon: const Icon(Icons.refresh, color: Color(0xFF0071E3), size: 20),
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
                  _buildFilterChip('مبيعات', 'sales', color: Colors.green),
                  const SizedBox(width: 6),
                  _buildFilterChip('مشتريات', 'purchase', color: Colors.blue),
                  const SizedBox(width: 6),
                  _buildFilterChip('مردود مبيعات', 'sales_return', color: Colors.orange),
                  const SizedBox(width: 6),
                  _buildFilterChip('مردود مشتريات', 'purchase_return', color: Colors.purple),
                  const Spacer(),
                  Text('${_filteredInvoices.length} فاتورة', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
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
                      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد فواتير مسجلة',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
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
      ]
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
              ? (color ?? const Color(0xFF0071E3)).withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (color ?? const Color(0xFF0071E3)).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (color ?? const Color(0xFF0071E3)) : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final type = invoice['type'] as String? ?? '';
    final typeColor = _getTypeColor(type);
    final netTotal = (invoice['netTotal'] as num?)?.toDouble() ?? 0;
    final itemsCount = (invoice['items'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: typeColor.withOpacity(0.2),
        ),
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
                  child: Icon(_getTypeIcon(type), color: typeColor, size: 20),
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
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getTypeAr(type),
                              style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getPaymentAr(invoice['paymentMethod']),
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.white38, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            invoice['clientName'] ?? 'عميل نقدي',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          if (invoice['clientPhone'] != null && invoice['clientPhone'].toString().isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.phone, color: Colors.white38, size: 11),
                            const SizedBox(width: 3),
                            Text(
                              invoice['clientPhone'],
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Text('$itemsCount مادة', style: const TextStyle(color: Colors.white24, fontSize: 10)),
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
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${netTotal.toStringAsFixed(3)} د.ك',
                      style: TextStyle(color: typeColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // زر القائمة
                PopupMenuButton<String>(
                  offset: const Offset(0, 30),
                  color: const Color(0xFF1D1D1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: const Color(0xFF0071E3).withOpacity(0.3)),
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
                        const Icon(Icons.visibility, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        const Text('عرض التفاصيل', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 36,
                      child: Row(children: [
                        const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ]),
                    ),
                  ],
                  child: Icon(Icons.more_vert, color: Colors.white38, size: 14),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}
