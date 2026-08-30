import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:intl/intl.dart' as intl;

class BusinessAccountingTab extends StatefulWidget {
  final String uid;
  final List<String> customCategories;

  const BusinessAccountingTab({
    Key? key,
    required this.uid,
    this.customCategories = const [],
  }) : super(key: key);

  @override
  State<BusinessAccountingTab> createState() => _BusinessAccountingTabState();
}

class _BusinessAccountingTabState extends State<BusinessAccountingTab> {
  // ========== Timer for polling ==========
  Timer? _pollTimer;

  // ========== البيانات ==========
  double totalIncome = 0;
  double totalExpenses = 0;
  double totalPurchases = 0;
  double totalCommission = 0;
  int transactionCount = 0;
  DateTime? lastUpdated;
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoading = true;
  String? _error;

  // ========== Pagination ==========
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 20;

  // ========== فلاتر ==========
  String _selectedFilter = 'الكل';
  final List<String> _filterOptions = [
    'الكل',
    'إيراد',
    'مصروف',
    'مشتريات',
    'عمولة',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Poll every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Load summary and transactions from API
  Future<void> _loadData() async {
    try {
      // Load summary (dashboard)
      final summaryRes = await ApiService.get('/api/dashboard', queryParameters: {'businessId': widget.uid});
      if (summaryRes.success && summaryRes.data != null) {
        final data = summaryRes.data!;
        if (mounted) {
          setState(() {
            totalIncome = (data['totalIncome'] as num?)?.toDouble() ?? 0;
            totalExpenses = (data['totalExpenses'] as num?)?.toDouble() ?? 0;
            totalPurchases = (data['totalPurchases'] as num?)?.toDouble() ?? 0;
            totalCommission = (data['totalCommission'] as num?)?.toDouble() ?? 0;
            transactionCount = (data['transactionCount'] as num?)?.toInt() ?? 0;
            final lastUpdatedStr = data['lastUpdated'] as String?;
            if (lastUpdatedStr != null) {
              lastUpdated = DateTime.tryParse(lastUpdatedStr);
            }
          });
        }
      }

      // Load transactions
      final txnRes = await ApiService.get('/api/accounting/transactions', queryParameters: {
        'businessId': widget.uid,
        'limit': _pageSize,
      });

      List<Map<String, dynamic>> transactions = [];
      if (txnRes.success && txnRes.data != null) {
        final list = txnRes.data!['transactions'] ?? txnRes.data!['data'];
        if (list is List) {
          transactions = list.cast<Map<String, dynamic>>();
        }
      }

      // Sort manually by date (newest first)
      transactions.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _recentTransactions = transactions;
          _hasMore = transactions.length >= _pageSize;
          _currentPage = 1;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'خطأ في تحميل البيانات';
          _isLoading = false;
        });
      }
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Load more transactions (pagination)
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final txnRes = await ApiService.get('/api/accounting/transactions', queryParameters: {
        'businessId': widget.uid,
        'limit': _pageSize,
        'page': _currentPage + 1,
      });

      List<Map<String, dynamic>> moreTransactions = [];
      if (txnRes.success && txnRes.data != null) {
        final list = txnRes.data!['transactions'] ?? txnRes.data!['data'];
        if (list is List) {
          moreTransactions = list.cast<Map<String, dynamic>>();
        }
      }

      // Sort manually
      moreTransactions.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });

      if (moreTransactions.length < _pageSize) _hasMore = false;

      if (mounted) {
        setState(() {
          _recentTransactions.addAll(moreTransactions);
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Manual refresh
  Future<void> _refresh() async {
    _currentPage = 0;
    _hasMore = true;
    setState(() => _isLoading = true);
    await _loadData();
  }

  /// صافي الربح
  double get netProfit => totalIncome - totalExpenses - totalPurchases - totalCommission;

  /// تنسيق المبلغ
  String formatAmount(double amount) => '${amount.toStringAsFixed(3)} د.ك';

  /// لون النوع
  Color getTypeColor(String type) {
    switch (type) {
      case 'income': return Colors.green;
      case 'expense': return Colors.red;
      case 'purchase': return Colors.orange;
      case 'commission': return Colors.blue;
      default: return Colors.grey;
    }
  }

  /// اسم النوع
  String getTypeName(String type) {
    switch (type) {
      case 'income': return 'إيراد';
      case 'expense': return 'مصروف';
      case 'purchase': return 'مشتريات';
      case 'commission': return 'عمولة';
      default: return type;
    }
  }

  /// أيقونة النوع
  IconData getTypeIcon(String type) {
    switch (type) {
      case 'income': return Icons.arrow_downward;
      case 'expense': return Icons.arrow_upward;
      case 'purchase': return Icons.shopping_cart;
      case 'commission': return Icons.percent;
      default: return Icons.receipt;
    }
  }

  /// المعاملات المفلترة
  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'الكل') return _recentTransactions;
    final typeMap = {
      'إيراد': 'income',
      'مصروف': 'expense',
      'مشتريات': 'purchase',
      'عمولة': 'commission',
    };
    final filterType = typeMap[_selectedFilter];
    return _recentTransactions.where((t) => t['type'] == filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildNetProfitCard(),
          if (lastUpdated != null) _buildLastUpdated(),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 16),
          _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildCard('إجمالي الإيرادات', totalIncome, Icons.trending_up, Colors.green),
        _buildCard('إجمالي المصروفات', totalExpenses, Icons.trending_down, Colors.red),
        _buildCard('إجمالي المشتريات', totalPurchases, Icons.shopping_cart, Colors.orange),
        _buildCard('إجمالي العمولات', totalCommission, Icons.percent, Colors.blue),
      ],
    );
  }

  Widget _buildCard(String title, double amount, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(formatAmount(amount),
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNetProfitCard() {
    final isPositive = netProfit >= 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.red.shade700, Colors.red.shade500],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('صافي الربح',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(formatAmount(netProfit),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text('آخر تحديث: ${intl.DateFormat("HH:mm").format(lastUpdated!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(width: 8),
          Text('$transactionCount معاملة',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterOptions.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedFilter = filter);
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionsList() {
    final filtered = _filteredTransactions;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('لا توجد معاملات', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('أحدث المعاملات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${filtered.length} معاملة', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        ...filtered.map((t) => _buildTransactionItem(t)),
        if (_hasMore)
          TextButton(
            onPressed: _loadMore,
            child: _isLoadingMore
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تحميل المزيد'),
          ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String? ?? '';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final description = transaction['description'] as String? ?? '';
    final createdAtStr = transaction['createdAt'] as String?;
    DateTime? date;
    if (createdAtStr != null) {
      date = DateTime.tryParse(createdAtStr);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: getTypeColor(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(getTypeIcon(type), color: getTypeColor(type), size: 22),
        ),
        title: Text(
          description.isNotEmpty ? description : getTypeName(type),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: getTypeColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(getTypeName(type),
                  style: TextStyle(color: getTypeColor(type), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            if (date != null)
              Text(intl.DateFormat('yyyy/MM/dd - HH:mm').format(date),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
        trailing: Text(formatAmount(amount),
            style: TextStyle(color: getTypeColor(type), fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}
