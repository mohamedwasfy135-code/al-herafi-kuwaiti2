// ═══════════════════════════════════════════════════════════════
// بطاقة الدفع – Payment Card
// قائمة منسدلة لطرق الدفع + تاريخ + مبلغ + ماي فاتورة
// الدفع الجزئي → الباقي يسجل كآجل
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

// ─── طرق الدفع ──────────────────────────────────────────────────
class PaymentMethod {
  final String code;
  final String arLabel;
  final String enLabel;
  final IconData icon;
  const PaymentMethod(this.code, this.arLabel, this.enLabel, this.icon);
}

const paymentMethods = [
  PaymentMethod('cash', 'كاش', 'Cash', Icons.money_outlined),
  PaymentMethod('knet', 'كي نت', 'KNet', Icons.credit_card_outlined),
  PaymentMethod('bank', 'بنك', 'Bank', Icons.account_balance_outlined),
  PaymentMethod('my_invoice', 'ماي فاتورة', 'My Invoice', Icons.link_outlined),
];

// ─── بطاقة الدفع ────────────────────────────────────────────────
class PaymentCard extends StatefulWidget {
  final String uid;
  final double totalAmount;       // إجمالي الفاتورة
  final String invoiceId;         // رقم الفاتورة
  final String invoiceType;       // sales أو purchase
  final Map<String, dynamic>? customerData; // بيانات العميل
  final VoidCallback? onPaymentComplete;

  const PaymentCard({
    super.key,
    required this.uid,
    required this.totalAmount,
    required this.invoiceId,
    this.invoiceType = 'sales',
    this.customerData,
    this.onPaymentComplete
  });

  @override
  State<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<PaymentCard> {
  String _selectedMethod = 'cash';
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  final _referenceController = TextEditingController();
  bool _isProcessing = false;
  double _alreadyPaid = 0;

  double get _remaining {
    final entered = double.tryParse(_amountController.text) ?? 0;
    return widget.totalAmount - _alreadyPaid - entered;
  }

  double get _maxPayable => widget.totalAmount - _alreadyPaid;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.totalAmount.toStringAsFixed(3)
    );
    _dateController = TextEditingController(
      text: _todayString()
    );
    _loadPayments();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPayments() async {
    final res = await ApiService.get('/api/businesses/${widget.uid}/payments', queryParameters: {
      'invoiceId': widget.invoiceId,
    });

    double paid = 0;
    if (res.success && res.data != null) {
      final list = res.data!['payments'] ?? res.data!['data'] ?? [];
      if (list is List) {
        for (final item in list) {
          paid += ((item as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    if (mounted) {
      setState(() {
        _alreadyPaid = paid;
        _amountController.text = (_maxPayable).toStringAsFixed(3);
      });
    }
  }

  // ─── معالجة الدفع ──────────────────────────────────────────
  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount <= 0) {
      _showError('المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    if (amount > _maxPayable + 0.001) {
      _showError('المبلغ أكبر من المتبقي ($_maxPayable)');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // ─── ماي فاتورة: توليد رابط الدفع ──────────────────────
      if (_selectedMethod == 'my_invoice') {
        await _generatePaymentLink(amount);
        return;
      }

      // ─── تسجيل الدفع مباشرة ────────────────────────────────
      await _recordPayment(amount, _selectedMethod, isConfirmed: true);

    } catch (e) {
      _showError('خطأ: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _recordPayment(
    double amount,
    String method, {
    bool isConfirmed = true,
    String? paymentLink
  }) async {
    final paymentData = {
      'invoiceId': widget.invoiceId,
      'invoiceType': widget.invoiceType,
      'amount': amount,
      'method': method,
      'date': _dateController.text.trim(),
      'reference': _referenceController.text.trim(),
      'isConfirmed': isConfirmed,
      'paymentLink': paymentLink,
      'customerId': widget.customerData?['id'],
      'customerName': widget.customerData?['nameAr'] ?? widget.customerData?['name'] ?? '',
      'createdAt': DateTime.now().toIso8601String()
    };

    await ApiService.post('/api/businesses/${widget.uid}/payments', body: paymentData);

    // ─── تحديث حالة الفاتورة ──────────────────────────────────
    final newPaidTotal = _alreadyPaid + amount;
    String status;
    if (newPaidTotal >= widget.totalAmount - 0.001) {
      status = 'paid';
    } else if (newPaidTotal > 0) {
      status = 'partial';
    } else {
      status = 'unpaid';
    }

    final invoiceType = widget.invoiceType;
    final endpoint = invoiceType == 'purchase' ? '/api/invoices/purchase' : '/api/invoices/sales';
    await ApiService.put('$endpoint/${widget.invoiceId}', body: {
      'paymentStatus': status,
      'paidAmount': newPaidTotal,
      'remainingAmount': widget.totalAmount - newPaidTotal,
    });

    // ─── تحديث رصيد العميل (آجل) ──────────────────────────────
    if (widget.customerData != null && status != 'paid') {
      final customerId = widget.customerData?['id'];
      if (customerId != null) {
        final remaining = widget.totalAmount - newPaidTotal;
        if (remaining > 0) {
          await ApiService.put('/api/clients/$customerId', body: {
            'balanceIncrement': remaining,
          });
        }
      }
    }

    if (mounted) {
      widget.onPaymentComplete?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConfirmed
                ? 'تم تسجيل الدفع بنجاح'
                : 'تم توليد رابط الدفع',
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        )
      );
      await _loadPayments();
    }
  }

  // ─── توليد رابط ماي فاتورة ──────────────────────────────────
  Future<void> _generatePaymentLink(double amount) async {
    // توليد رابط الدفع عبر Cloud Function
    final payload = {
      'amount': amount,
      'currency': 'KWD',
      'invoiceId': widget.invoiceId,
      'businessId': widget.uid,
      'customerPhone': widget.customerData?['phone'] ?? '',
      'customerName': widget.customerData?['nameAr'] ?? '',
      'isPartial': amount < widget.totalAmount
    };

    try {
      // محاولة استدعاء Cloud Function
      final res = await ApiService.post('/api/payments/create-link', body: {
        ...payload,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final paymentLink = res.success ? (res.data?['paymentUrl'] ?? res.data?['paymentLink'] ?? '') : '';

      // نسخ الرابط
      await Clipboard.setData(ClipboardData(text: paymentLink));

      // تسجيل كدفع معلق
      await _recordPayment(
        amount,
        'my_invoice',
        isConfirmed: false,
        paymentLink: paymentLink
      );

      if (mounted) {
        _showPaymentLinkDialog(paymentLink, amount);
      }
    } catch (e) {
      // fallback: تسجيل كمعلق بدون رابط
      await _recordPayment(amount, 'my_invoice', isConfirmed: false);
      if (mounted) {
        _showError('تعذر توليد رابط الدفع. تم التسجيل كمعلق.');
      }
    }
  }

  void _showPaymentLinkDialog(String link, double amount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('رابط الدفع', style: AppTheme.sSection),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              amount >= widget.totalAmount
                  ? 'رابط دفع كامل: ${amount.toStringAsFixed(3)} د.ك'
                  : 'رابط دفع جزئي: ${amount.toStringAsFixed(3)} د.ك من ${widget.totalAmount.toStringAsFixed(3)} د.ك',
              style: AppTheme.sBody,
            ),
            const SizedBox(height: AppTheme.s8),
            Container(
              padding: const EdgeInsets.all(AppTheme.s8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(link, style: const TextStyle(
                fontSize: AppTheme.fCaption,
                color: AppTheme.accent,
                decoration: TextDecoration.underline,
              )),
            ),
            const SizedBox(height: AppTheme.s8),
            const Text('تم نسخ الرابط. سيتم تأكيد الدفع تلقائياً عند الدفع عبر الرابط.',
              style: AppTheme.sCaption),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () async {
              // فتح واتساب لإرسال الرابط
              final phone = widget.customerData?['phone'] ?? '';
              if (phone.isNotEmpty) {
                final msg = Uri.encodeComponent(
                  'رابط دفع فاتورة ${widget.invoiceId}\nالمبلغ: ${amount.toStringAsFixed(3)} د.ك\n$link'
                );
                final waUrl = 'https://wa.me/$phone?text=$msg';
                final uri = Uri.parse(waUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('واتساب'),
          ),
        ],
      )
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger)
    );
  }

  // ─── البناء ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.rMedium),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          AppTheme.divider(),
          Padding(
            padding: const EdgeInsets.all(AppTheme.s10),
            child: Column(
              children: [
                _buildSummaryRow(),
                const SizedBox(height: AppTheme.s8),
                _buildMethodSelector(),
                const SizedBox(height: AppTheme.s8),
                _buildAmountRow(),
                const SizedBox(height: AppTheme.s8),
                if (_selectedMethod != 'my_invoice') ...[
                  _buildDateAndRef(),
                  const SizedBox(height: AppTheme.s8),
                ],
                _buildRemainingInfo(),
                const SizedBox(height: AppTheme.s8),
                _buildPayButton(),
              ],
            ),
          ),
        ],
      )
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s10, vertical: AppTheme.s8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.rMedium),
          topRight: Radius.circular(AppTheme.rMedium),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment_outlined, size: AppTheme.iconSize, color: AppTheme.textP),
          const SizedBox(width: AppTheme.s6),
          const Text('الدفع', style: AppTheme.sSubtitle),
          const Spacer(),
          if (_alreadyPaid > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.s6, vertical: AppTheme.s2),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
              ),
              child: Text('مدفوع: ${_alreadyPaid.toStringAsFixed(3)} د.ك',
                style: TextStyle(fontSize: AppTheme.fSmall, color: AppTheme.success)),
            ),
        ],
      )
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rSmall),
      ),
      child: Row(
        children: [
          _summaryItem('الإجمالي', '${widget.totalAmount.toStringAsFixed(3)} د.ك', AppTheme.textP),
          Container(width: 0.5, height: 16, color: AppTheme.border),
          _summaryItem('المدفوع', '${_alreadyPaid.toStringAsFixed(3)} د.ك', AppTheme.success),
          Container(width: 0.5, height: 16, color: AppTheme.border),
          _summaryItem('المتبقي', '${_maxPayable.toStringAsFixed(3)} د.ك',
            _maxPayable > 0 ? AppTheme.danger : AppTheme.success),
        ],
      )
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: AppTheme.fTiny, color: AppTheme.textM)),
          Text(value, style: TextStyle(fontSize: AppTheme.fBody, fontWeight: FontWeight.w600, color: color)),
        ],
      )
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('طريقة الدفع', style: TextStyle(fontSize: AppTheme.fCaption, color: AppTheme.textS)),
        const SizedBox(height: AppTheme.s4),
        Row(
          children: paymentMethods.map((m) {
            final isSelected = _selectedMethod == m.code;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => setState(() => _selectedMethod = m.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.s4, horizontal: AppTheme.s4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.textP : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.rSmall),
                      border: Border.all(
                        color: isSelected ? AppTheme.textP : AppTheme.border,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(m.icon,
                            size: AppTheme.iconSizeSm,
                            color: isSelected ? Colors.white : AppTheme.textS),
                        const SizedBox(width: AppTheme.s4),
                        Flexible(
                          child: Text(m.arLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTheme.fSmall,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? Colors.white : AppTheme.textS,
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            );
          }).toList(),
        ),
      ]
    );
  }

  Widget _buildAmountRow() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _amountController,
            style: const TextStyle(fontSize: AppTheme.fBody, fontWeight: FontWeight.w600, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(
              hintText: 'المبلغ',
              suffixText: 'د.ك',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: AppTheme.s4),
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: () {
              setState(() {
                _amountController.text = _maxPayable.toStringAsFixed(3);
              });
            },
            child: Container(
              height: AppTheme.inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fullscreen_outlined, size: AppTheme.iconSizeSm, color: AppTheme.textS),
                  const SizedBox(width: AppTheme.s4),
                  Text('المتبقي', style: TextStyle(fontSize: AppTheme.fSmall, color: AppTheme.textS)),
                ],
              ),
            ),
          ),
        ),
      ]
    );
  }

  Widget _buildDateAndRef() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _dateController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(
              hintText: 'التاريخ',
              prefixIcon: Icons.calendar_today_outlined,
            ),
            readOnly: true,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2030)
              );
              if (picked != null) {
                _dateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              }
            },
          ),
        ),
        const SizedBox(width: AppTheme.s4),
        Expanded(
          child: TextFormField(
            controller: _referenceController,
            style: const TextStyle(fontSize: AppTheme.fBody, color: AppTheme.textP),
            decoration: AppTheme.inputDecoration(hintText: 'مرجع / رقم'),
          ),
        ),
      ]
    );
  }

  Widget _buildRemainingInfo() {
    final entered = double.tryParse(_amountController.text) ?? 0;
    final remaining = _maxPayable - entered;

    if (remaining <= 0.001) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s6),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppTheme.rSmall),
          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: AppTheme.iconSizeSm, color: AppTheme.success),
            const SizedBox(width: AppTheme.s6),
            Text('دفع كامل', style: TextStyle(fontSize: AppTheme.fBody, color: AppTheme.success, fontWeight: FontWeight.w500)),
          ],
        )
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s6),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.rSmall),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: AppTheme.iconSizeSm, color: AppTheme.warning),
          const SizedBox(width: AppTheme.s6),
          Text(
            'آجل: ${remaining.toStringAsFixed(3)} د.ك',
            style: TextStyle(fontSize: AppTheme.fBody, color: AppTheme.warning, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            'يُسجّل على العميل',
            style: TextStyle(fontSize: AppTheme.fSmall, color: AppTheme.textM),
          ),
        ],
      )
    );
  }

  Widget _buildPayButton() {
    final entered = double.tryParse(_amountController.text) ?? 0;
    final isValid = entered > 0 && entered <= _maxPayable + 0.001;

    return SizedBox(
      width: double.infinity,
      height: AppTheme.buttonHeight + 4,
      child: ElevatedButton(
        onPressed: (_isProcessing || !isValid) ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedMethod == 'my_invoice' ? AppTheme.accent : AppTheme.textP,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rSmall)),
        ),
        child: _isProcessing
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedMethod == 'my_invoice' ? Icons.link_outlined : Icons.check_outlined,
                    size: AppTheme.iconSize,
                  ),
                  const SizedBox(width: AppTheme.s6),
                  Text(
                    _selectedMethod == 'my_invoice' ? 'توليد رابط الدفع' : 'تسجيل الدفع',
                    style: const TextStyle(fontSize: AppTheme.fBody, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      )
    );
  }
}
