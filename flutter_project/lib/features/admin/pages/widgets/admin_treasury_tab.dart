import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/openrouter_service.dart';

class AdminTreasuryTab extends StatefulWidget {
  const AdminTreasuryTab({super.key});
  @override
  State<AdminTreasuryTab> createState() => _AdminTreasuryTabState();
}

class _AdminTreasuryTabState extends State<AdminTreasuryTab> {
  Key _treasuryKey = UniqueKey();

  String _aiAnalysis = '';
  bool _aiLoading = false;

  /// Parse a dynamic value into DateTime
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try { return DateTime.parse(value); } catch (_) { return null; }
    }
    return null;
  }

  Future<void> _addExpense() async {
    final amountCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('add_expense'.tr()),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'amount'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: typeCtrl,
            decoration: InputDecoration(
              labelText: 'expense_type'.tr(),
              hintText: 'رواتب، دعاية، إيجار...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'notes'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('add'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invalid_amount'.tr()), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      await ApiService.post('/api/expenses', body: {
        'amount': amount,
        'type': typeCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      setState(() {
        _treasuryKey = UniqueKey();
        _aiAnalysis = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('saved_successfully'.tr()), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_saving_expense'.tr()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _analyzeWithAI({
    required double totalIn,
    required double totalPayouts,
    required double totalExpenses,
    required double net,
    required List<Map<String, dynamic>> expensesList,
  }) async {
    setState(() => _aiLoading = true);

    try {
      final prompt = '''
أنت محلل مالي خبير لتطبيق "الحرفي الكويتي". لديك البيانات المالية التالية للخزينة:

- إجمالي الوارد: ${totalIn.toStringAsFixed(3)} د.ك
- حوالات الحرفيين: ${totalPayouts.toStringAsFixed(3)} د.ك
- المصروفات الإدارية: ${totalExpenses.toStringAsFixed(3)} د.ك
- الصافي: ${net.toStringAsFixed(3)} د.ك

آخر 5 مصروفات:
${expensesList.take(5).map((e) => '- ${e['type']}: ${(e['amount'] as double).toStringAsFixed(3)} د.ك').join('\n')}

أعطني تحليلاً قصيراً (3-4 أسطر) بالعربية عن الوضع المالي، مع توصية واحدة قابلة للتنفيذ لتحسين الصافي.
      ''';

      final result = await OpenRouterService.chat(
        messages: [{'role': 'user', 'content': prompt}],
        temperature: 0.4,
        maxTokens: 256,
      );

      setState(() {
        _aiAnalysis = result;
        _aiLoading = false;
      });
    } catch (e) {
      setState(() {
        _aiAnalysis = 'ai_analysis_error'.tr();
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      key: _treasuryKey,
      future: Future.wait([
        FirestoreService.getRequests(status: kStatusDone),
        ApiService.get('/api/payouts', queryParameters: {'status': 'paid'}),
        ApiService.get('/api/expenses'),
      ]),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
        }

        if (snap.hasError) {
          return Center(
            child: Text('error_loading_treasury'.tr(), style: const TextStyle(color: Colors.white70)),
          );
        }

        if (!snap.hasData) {
          return Center(
            child: Text('no_data'.tr(), style: const TextStyle(color: Colors.white70)),
          );
        }

        final requestsList = snap.data![0] as List<Map<String, dynamic>>;

        // Parse payouts from API response
        final payoutsRes = snap.data![1] as ApiResponse;
        final payoutsList = (payoutsRes.success && payoutsRes.data != null)
            ? (payoutsRes.data!['payouts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []
            : <Map<String, dynamic>>[];

        // Parse expenses from API response
        final expensesRes = snap.data![2] as ApiResponse;
        final expensesListRaw = (expensesRes.success && expensesRes.data != null)
            ? (expensesRes.data!['expenses'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []
            : <Map<String, dynamic>>[];

        double totalIn = 0.0;
        for (final data in requestsList) {
          totalIn += (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
        }

        double totalPayouts = 0.0;
        for (final data in payoutsList) {
          totalPayouts += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double totalExpenses = 0.0;
        final List<Map<String, dynamic>> expensesList = [];
        for (final data in expensesListRaw) {
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          totalExpenses += amount;
          expensesList.add({
            'type': data['type'] ?? '',
            'amount': amount,
            'notes': data['notes'] ?? '',
            'createdAt': data['createdAt'],
          });
        }

        final totalOut = totalPayouts + totalExpenses;
        final net = totalIn - totalOut;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // بطاقة الخزينة الرئيسية زجاجية
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0071E3).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Color(0xFF0071E3), size: 20),
                      ),
                      const SizedBox(height: 16),
                      Text('treasury_net'.tr(),
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('${net.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _treasuryStat('treasury_in'.tr(), '${totalIn.toStringAsFixed(3)}', Colors.green),
                          Container(height: 40, width: 1, color: Colors.white.withOpacity(0.2)),
                          _treasuryStat('treasury_out'.tr(), '${totalOut.toStringAsFixed(3)}', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text('${'payouts_total'.tr()}: ${totalPayouts.toStringAsFixed(3)}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          Text('${'expenses_total'.tr()}: ${totalExpenses.toStringAsFixed(3)}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // زر تحليل AI
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _aiLoading
                    ? null
                    : () => _analyzeWithAI(
                          totalIn: totalIn,
                          totalPayouts: totalPayouts,
                          totalExpenses: totalExpenses,
                          net: net,
                          expensesList: expensesList,
                        ),
                icon: _aiLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0071E3)))
                    : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0071E3)),
                label: Text(_aiLoading ? 'analyzing'.tr() : 'analyze_treasury_ai'.tr(),
                    style: const TextStyle(color: Color(0xFF0071E3))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0071E3),
                  side: const BorderSide(color: Color(0xFF0071E3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // نتيجة تحليل AI
            if (_aiAnalysis.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0071E3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF0071E3), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _aiAnalysis,
                            style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // عنوان المصروفات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.money_off_rounded, color: Colors.red, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Text('expenses'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF1D1D1F)),
                  label: Text('add_expense'.tr(), style: const TextStyle(color: Color(0xFF1D1D1F))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (expensesList.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('no_expenses'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ]),
              )
            else
              ...expensesList.take(10).map((item) {
                final amount = item['amount'] as double;
                final type = item['type'] as String;
                final notes = item['notes'] as String;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.money_off_rounded, color: Colors.red, size: 22),
                          ),
                          title: Text(
                            type.isNotEmpty ? type : 'expense'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                          ),
                          subtitle: notes.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(notes, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                                )
                              : null,
                          trailing: Text(
                            '${amount.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _treasuryStat(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.monetization_on_rounded, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}
