import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

class CraftsmanEarningsTab extends StatefulWidget {
  final String uid;
  const CraftsmanEarningsTab({super.key, required this.uid});

  @override
  State<CraftsmanEarningsTab> createState() => _CraftsmanEarningsTabState();
}

class _CraftsmanEarningsTabState extends State<CraftsmanEarningsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _selectedMonth;
  List<String> _availableMonths = [];
  bool _loading = true;

  int _totalCompletedRequests = 0;
  int _activeRequests = 0;
  double _averageRating = 0.0;
  double _totalEarnings = 0.0;
  double _totalPaidOut = 0.0;
  double _netBalance = 0.0;
  double _deduction = 0.0;
  String _currentMonth = '';
  Map<String, double> _monthlyEarnings = {};
  List<Map<String, dynamic>> _paidPayouts = [];
  List<Map<String, dynamic>> _pendingPayouts = [];

  @override
  void initState() {
    super.initState();
    _currentMonth = _monthStr(DateTime.now());
    _loadData();
  }

  String _monthStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  DateTime? _parseDate(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final uid = widget.uid;

      final results = await Future.wait([
        ApiService.get('/api/requests', queryParameters: {
          'craftsmanId': uid, 'status': kStatusDone,
        }),
        ApiService.get('/api/requests', queryParameters: {
          'craftsmanId': uid,
          'status': 'notified,accepted,in_progress,price_proposed,payment_pending,payment_confirmed',
        }),
        ApiService.get('/api/payouts', queryParameters: {
          'craftsmanId': uid, 'status': 'paid',
        }),
        ApiService.get('/api/payouts', queryParameters: {
          'craftsmanId': uid, 'status': 'pending',
        }),
        ApiService.get('/api/craftsmen/$uid'),
      ]);

      // Completed requests
      final doneData = results[0].data;
      final doneList = (doneData?['requests'] ?? doneData?['data'] ?? []) as List;
      final Set<String> months = {};
      double totalRating = 0;
      int ratingCount = 0;
      double totalEarnings = 0.0;
      final Map<String, double> monthlyEarnings = {};

      _totalCompletedRequests = doneList.length;

      for (final item in doneList) {
        final d = item as Map<String, dynamic>;
        final finishedAt = _parseDate(d['finishedAt']);
        if (finishedAt != null) {
          final monthStr = DateFormat('yyyy-MM').format(finishedAt);
          months.add(monthStr);
          final amount = (d['finalAmount'] as num?)?.toDouble() ?? 0.0;
          monthlyEarnings[monthStr] = (monthlyEarnings[monthStr] ?? 0) + amount;
          totalEarnings += amount;
        }
        final rating = (d['clientRating'] as num?)?.toDouble();
        if (rating != null) {
          totalRating += rating;
          ratingCount++;
        }
      }

      // Active requests
      final activeData = results[1].data;
      final activeList = (activeData?['requests'] ?? activeData?['data'] ?? []) as List;
      _activeRequests = activeList.length;

      _averageRating = ratingCount > 0 ? (totalRating / ratingCount) : 0.0;

      final sortedMonths = months.toList()..sort((a, b) => b.compareTo(a));
      _availableMonths = sortedMonths;
      _monthlyEarnings = monthlyEarnings;
      if (sortedMonths.isNotEmpty && _selectedMonth == null) {
        _selectedMonth = sortedMonths.first;
      }

      // Paid payouts
      final paidData = results[2].data;
      final paidList = (paidData?['payouts'] ?? paidData?['data'] ?? []) as List;
      double totalPaidOut = 0.0;
      final List<Map<String, dynamic>> paidItems = [];
      for (final item in paidList) {
        final data = item as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        totalPaidOut += amount;
        paidItems.add({
          'amount': amount,
          'reference': data['reference'] ?? '',
          'processedAt': data['processedAt'],
        });
      }
      _totalPaidOut = totalPaidOut;
      _paidPayouts = paidItems;

      // Pending payouts
      final pendingData = results[3].data;
      final pendingList = (pendingData?['payouts'] ?? pendingData?['data'] ?? []) as List;
      final List<Map<String, dynamic>> pendingItems = [];
      for (final item in pendingList) {
        final data = item as Map<String, dynamic>;
        pendingItems.add({
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'requestedAt': data['requestedAt'],
        });
      }
      _pendingPayouts = pendingItems;

      // Craftsman data
      final craftRes = results[4];
      final craftData = craftRes.data?['craftsman'] ?? craftRes.data;
      if (craftData is Map<String, dynamic>) {
        final subscriptionStatus =
            craftData['subscriptionStatus'] as String?;
        final subscriptionPrice =
            (craftData['subscriptionPrice'] as num?)?.toDouble() ?? 0.0;
        final lastDeductionMonth =
            craftData['lastSubscriptionDeductionMonth'] as String?;

        double deduction = 0.0;
        if (subscriptionStatus == 'approved' &&
            subscriptionPrice > 0 &&
            lastDeductionMonth != _currentMonth) {
          deduction = subscriptionPrice;
        }
        _deduction = deduction;
      }

      _totalEarnings = totalEarnings;
      _netBalance =
          (totalEarnings - totalPaidOut - _deduction).clamp(0.0, double.infinity);
    } catch (e) {
      debugPrint('Error loading earnings: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _selectedMonthEarnings => _selectedMonth != null
      ? (_monthlyEarnings[_selectedMonth] ?? 0.0)
      : 0.0;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0071E3)),
      );
    }

    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return Center(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF0071E3),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 20),
              _buildStatsCard(),
              const SizedBox(height: 20),
              if (_availableMonths.isNotEmpty) _buildMonthSelector(),
              const SizedBox(height: 20),
              if (_netBalance > 0) _buildWithdrawButton(),
              const SizedBox(height: 20),
              if (_paidPayouts.isNotEmpty) ...[
                Text('previous_payouts'.tr(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                ..._paidPayouts.take(5).map((e) => _payoutTile(e, paid: true)),
                const SizedBox(height: 20),
              ],
              if (_pendingPayouts.isNotEmpty) ...[
                Text('pending_payouts'.tr(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)),
                const SizedBox(height: 12),
                ..._pendingPayouts.map((e) => _payoutTile(e, paid: false)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0071E3).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet,
              color: Color(0xFF0071E3), size: 50),
          const SizedBox(height: 12),
          Text('available_balance'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
              '${_netBalance.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _balanceItem('total_earnings'.tr(), _totalEarnings),
              _balanceItem('total_paid_out'.tr(), _totalPaidOut),
              if (_deduction > 0)
                _balanceItem('subscription_fee_deducted'.tr(), _deduction),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceItem(String label, double amount) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text('${amount.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0071E3).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Color(0xFF0071E3)),
            ),
            const SizedBox(width: 12),
            Text('performance_stats'.tr(),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            _statItem(Icons.task_alt, '$_totalCompletedRequests',
                'completed_requests'.tr(), Colors.green),
            const SizedBox(width: 16),
            _statItem(Icons.hourglass_top, '$_activeRequests',
                'active_requests'.tr(), Colors.orange),
            const SizedBox(width: 16),
            _statItem(Icons.star_rounded, _averageRating.toStringAsFixed(1),
                'avg_rating'.tr(), Colors.amber),
          ]),
        ],
      ),
    );
  }

  Widget _statItem(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ]),
    );
  }

  Widget _buildMonthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0071E3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_month,
                color: Color(0xFF0071E3)),
          ),
          const SizedBox(width: 12),
          Text('monthly_report'.tr(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMonth,
              icon: const Icon(Icons.expand_more, color: Colors.white70),
              dropdownColor: const Color(0xFF1E2A3A),
              style: const TextStyle(color: Colors.white),
              items: _availableMonths
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMonth = v),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0071E3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
          ),
          child: Text(
            '${'monthly_earnings'.tr()}: ${_selectedMonthEarnings.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0071E3)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _requestWithdrawal,
        icon: const Icon(Icons.money_off, color: Color(0xFF1D1D1F)),
        label: Text('request_withdrawal'.tr(),
            style: const TextStyle(color: Color(0xFF1D1D1F))),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  Widget _payoutTile(Map<String, dynamic> item, {required bool paid}) {
    final amount = item['amount'] as double;
    final reference = item['reference'] as String?;
    final dateStr = _parseTimestamp(item['processedAt'] ?? item['requestedAt']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: paid
              ? const Color(0xFF0071E3).withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          child: Icon(
              paid ? Icons.check_circle : Icons.hourglass_empty,
              color: paid ? const Color(0xFF0071E3) : Colors.orange),
        ),
        title: Text('$amount ${'kwd_currency'.tr()}',
            style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          paid && reference != null && reference.isNotEmpty
              ? '${'reference_number'.tr()}: $reference'
              : 'pending_status'.tr(),
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        trailing: Text(
          dateStr != null ? _formatDate(dateStr) : '',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
      ),
    );
  }

  Future<void> _requestWithdrawal() async {
    final grossCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('request_withdrawal'.tr(),
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${'available_balance'.tr()}: ${_netBalance.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: grossCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'withdrawal_amount_gross'.tr(),
                labelStyle: const TextStyle(color: Colors.white70),
                suffixText: 'kwd_currency'.tr(),
                suffixStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr(),
                  style: const TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
              foregroundColor: const Color(0xFF1D1D1F),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final grossAmount = double.tryParse(grossCtrl.text.trim()) ?? 0.0;
    if (grossAmount <= 0 || grossAmount > _netBalance) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('invalid_withdrawal_amount'.tr()),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final commission = grossAmount * 0.1;
    final netAmount = grossAmount - commission;

    try {
      final craftRes = await ApiService.get('/api/craftsmen/${widget.uid}');
      final craftData = craftRes.data?['craftsman'] ?? craftRes.data;
      if (craftData is! Map<String, dynamic>) throw 'Failed to load craftsman data';
      final craftsmanName = craftData['name'] ?? '';

      await ApiService.post('/api/payouts', body: {
        'craftsmanId': widget.uid,
        'craftsmanName': craftsmanName,
        'grossAmount': grossAmount,
        'amount': netAmount,
        'commission': commission,
        'phone': craftData['phone'] ?? '',
        'email': craftData['email'] ?? '',
        'profileImageUrl': craftData['profileImageUrl'] ?? '',
        'civilIdUrl': craftData['civilIdUrl'] ?? '',
        'bankName': craftData['bankName'] ?? '',
        'accountNumber': craftData['accountNumber'] ?? '',
        'iban': craftData['iban'] ?? '',
        'wamdPhone': craftData['wamdPhone'] ?? '',
        'status': 'pending',
        'requestedAt': DateTime.now().toIso8601String(),
        'availableBalanceAtRequest': _netBalance,
        'subscriptionDeduction': _deduction,
      });

      if (_deduction > 0) {
        await ApiService.put('/api/craftsmen/${widget.uid}', body: {
          'lastSubscriptionDeductionMonth': _currentMonth,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('withdrawal_request_sent'.tr()),
              backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${'error_label'.tr()}: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
