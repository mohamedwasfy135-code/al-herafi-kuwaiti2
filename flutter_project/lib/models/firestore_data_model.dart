/// ========== نموذج بيانات Firestore ==========
/// 
/// هذا الملف يوثق بنية البيانات في قاعدة البيانات
/// ويحتوي على النماذج (Models) المستخدمة في التطبيق
///
/// المجموعات (Collections):
/// 1. business_transactions  - معاملات الأعمال
/// 2. business_summaries     - ملخصات الحسابات

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/services/api_service.dart';

// ============================================================
// مجموعة: business_transactions
// ============================================================
//
// بنية المستند:
// {
//   "businessId": "string",        // معرّف العمل
//   "type": "string",              // نوع المعاملة: income | expense | purchase | commission
//   "amount": "number",            // المبلغ
//   "description": "string",       // الوصف
//   "category": "string | null",   // التصنيف (اختياري)
//   "createdAt": "string (ISO8601)", // تاريخ الإنشاء
//   "createdBy": "string | null",  // معرّف المستخدم الذي أنشأ المعاملة
//   "updatedAt": "string (ISO8601)", // تاريخ آخر تعديل
//   "tags": "array<string>",       // وسوم (اختياري)
//   "attachmentUrls": "array<string>", // روابط المرفقات (اختياري)
//   "isRecurring": "boolean",      // هل المعاملة متكررة
//   "recurringPeriod": "string | null", // فترة التكرار: monthly | weekly | yearly
// }

class TransactionModel {
  final String id;
  final String businessId;
  final String type;
  final double amount;
  final String description;
  final String? category;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final List<String> tags;
  final List<String> attachmentUrls;
  final bool isRecurring;
  final String? recurringPeriod;

  TransactionModel({
    required this.id,
    required this.businessId,
    required this.type,
    required this.amount,
    this.description = '',
    this.category,
    DateTime? createdAt,
    this.createdBy,
    this.updatedAt,
    this.tags = const [],
    this.attachmentUrls = const [],
    this.isRecurring = false,
    this.recurringPeriod,
  }) : createdAt = createdAt ?? DateTime.now();

  /// إنشاء من Map (بيانات API)
  factory TransactionModel.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return TransactionModel(
      id: documentId ?? data['id'] as String? ?? '',
      businessId: data['businessId'] as String? ?? '',
      type: data['type'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      description: data['description'] as String? ?? '',
      category: data['category'] as String?,
      createdAt: _parseDateTime(data['createdAt']),
      createdBy: data['createdBy'] as String?,
      updatedAt: _parseDateTime(data['updatedAt']),
      tags: List<String>.from(data['tags'] ?? []),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurringPeriod: data['recurringPeriod'] as String?,
    );
  }

  /// تحويل إلى Map (لإرسال عبر API)
  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'businessId': businessId,
      'type': type,
      'amount': amount,
      'description': description,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': DateTime.now().toIso8601String(),
      'tags': tags,
      'attachmentUrls': attachmentUrls,
      'isRecurring': isRecurring,
      'recurringPeriod': recurringPeriod,
    };
  }

  /// نسخة معدلة
  TransactionModel copyWith({
    String? type,
    double? amount,
    String? description,
    String? category,
    String? createdBy,
    List<String>? tags,
    List<String>? attachmentUrls,
    bool? isRecurring,
    String? recurringPeriod,
  }) {
    return TransactionModel(
      id: id,
      businessId: businessId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: DateTime.now(),
      tags: tags ?? this.tags,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPeriod: recurringPeriod ?? this.recurringPeriod,
    );
  }

  /// أنواع المعاملات المسموحة
  static const List<String> validTypes = [
    'income',      // إيراد
    'expense',     // مصروف
    'purchase',    // مشتريات
    'commission',  // عمولة
  ];

  /// التحقق من صحة البيانات قبل الحفظ
  bool isValid() {
    if (businessId.isEmpty) return false;
    if (!validTypes.contains(type)) return false;
    if (amount <= 0) return false;
    return true;
  }
}

// ============================================================
// مجموعة: business_summaries
// ============================================================
//
// بنية المستند (مستند واحد لكل عمل):
// معرّف المستند = businessId
//
// {
//   "businessId": "string",         // معرّف العمل
//   "totalIncome": "number",        // إجمالي الإيرادات
//   "totalExpenses": "number",      // إجمالي المصروفات
//   "totalPurchases": "number",     // إجمالي المشتريات
//   "totalCommission": "number",    // إجمالي العمولات
//   "transactionCount": "number",   // عدد المعاملات
//   "lastUpdated": "string (ISO8601)", // آخر تحديث
//   "monthlyData": {                // بيانات شهرية (اختياري)
//     "2024-01": {
//       "totalIncome": "number",
//       "totalExpenses": "number",
//       "totalPurchases": "number",
//       "totalCommission": "number",
//       "transactionCount": "number"
//     },
//     "2024-02": { ... }
//   }
// }

class BusinessSummary {
  final String businessId;
  final double totalIncome;
  final double totalExpenses;
  final double totalPurchases;
  final double totalCommission;
  final int transactionCount;
  final DateTime lastUpdated;
  final Map<String, MonthlyData> monthlyData;

  BusinessSummary({
    this.businessId = '',
    this.totalIncome = 0,
    this.totalExpenses = 0,
    this.totalPurchases = 0,
    this.totalCommission = 0,
    this.transactionCount = 0,
    DateTime? lastUpdated,
    this.monthlyData = const {},
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// صافي الربح
  double get netProfit =>
      totalIncome - totalExpenses - totalPurchases - totalCommission;

  /// نسبة الربح من الإيرادات
  double get profitMargin =>
      totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0;

  /// إجمالي المصروفات + المشتريات + العمولات
  double get totalDeductions =>
      totalExpenses + totalPurchases + totalCommission;

  /// إنشاء من Map (بيانات API)
  factory BusinessSummary.fromMap(Map<String, dynamic> data) {
    final monthlyDataRaw = data['monthlyData'] as Map<String, dynamic>? ?? {};
    final monthlyDataParsed = <String, MonthlyData>{};

    monthlyDataRaw.forEach((key, value) {
      monthlyDataParsed[key] = MonthlyData.fromMap(value as Map<String, dynamic>);
    });

    return BusinessSummary(
      businessId: data['businessId'] as String? ?? '',
      totalIncome: (data['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpenses: (data['totalExpenses'] as num?)?.toDouble() ?? 0,
      totalPurchases: (data['totalPurchases'] as num?)?.toDouble() ?? 0,
      totalCommission: (data['totalCommission'] as num?)?.toDouble() ?? 0,
      transactionCount: (data['transactionCount'] as num?)?.toInt() ?? 0,
      lastUpdated: _parseDateTime(data['lastUpdated']),
      monthlyData: monthlyDataParsed,
    );
  }

  /// تحويل إلى Map (لإرسال عبر API)
  Map<String, dynamic> toMap() {
    final monthlyDataMap = <String, dynamic>{};
    monthlyData.forEach((key, value) {
      monthlyDataMap[key] = value.toMap();
    });

    return {
      'businessId': businessId,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'totalPurchases': totalPurchases,
      'totalCommission': totalCommission,
      'transactionCount': transactionCount,
      'lastUpdated': DateTime.now().toIso8601String(),
      'monthlyData': monthlyDataMap,
    };
  }
}

// ============================================================
// نموذج البيانات الشهرية
// ============================================================

class MonthlyData {
  final double totalIncome;
  final double totalExpenses;
  final double totalPurchases;
  final double totalCommission;
  final int transactionCount;

  MonthlyData({
    this.totalIncome = 0,
    this.totalExpenses = 0,
    this.totalPurchases = 0,
    this.totalCommission = 0,
    this.transactionCount = 0,
  });

  double get netProfit =>
      totalIncome - totalExpenses - totalPurchases - totalCommission;

  factory MonthlyData.fromMap(Map<String, dynamic> data) {
    return MonthlyData(
      totalIncome: (data['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpenses: (data['totalExpenses'] as num?)?.toDouble() ?? 0,
      totalPurchases: (data['totalPurchases'] as num?)?.toDouble() ?? 0,
      totalCommission: (data['totalCommission'] as num?)?.toDouble() ?? 0,
      transactionCount: (data['transactionCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'totalPurchases': totalPurchases,
      'totalCommission': totalCommission,
      'transactionCount': transactionCount,
    };
  }
}

// ============================================================
// خدمة إدارة الحسابات
// ============================================================

class AccountingService {

  /// جلب ملخص الأعمال (Stream — polling-based)
  Stream<BusinessSummary> getSummaryStream(String businessId) {
    return Stream.periodic(const Duration(seconds: 15), (_) {
      return _fetchSummary(businessId);
    }).asyncMap((future) => future);
  }

  static Future<BusinessSummary> _fetchSummary(String businessId) async {
    try {
      final res = await ApiService.get('/api/business/$businessId/summary');
      if (res.success && res.data != null) {
        final data = res.data!['summary'] as Map<String, dynamic>? ?? res.data!;
        return BusinessSummary.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error fetching summary: $e');
    }
    return BusinessSummary(businessId: businessId);
  }

  /// جلب المعاملات (Stream — polling-based)
  Stream<List<TransactionModel>> getTransactionsStream(
    String businessId, {
    int limit = 20,
  }) {
    return Stream.periodic(const Duration(seconds: 15), (_) {
      return _fetchTransactions(businessId, limit: limit);
    }).asyncMap((future) => future);
  }

  static Future<List<TransactionModel>> _fetchTransactions(
    String businessId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await ApiService.get(
        '/api/business/$businessId/transactions',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      if (res.success && res.data != null) {
        final raw = res.data!['transactions'] ?? res.data!['data'];
        if (raw is List) {
          return raw
              .cast<Map<String, dynamic>>()
              .map((d) => TransactionModel.fromMap(d))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
    return [];
  }

  /// جلب المزيد من المعاملات (Pagination — offset-based)
  Future<List<TransactionModel>> getMoreTransactions(
    String businessId,
    int offset, {
    int limit = 20,
  }) async {
    return _fetchTransactions(businessId, limit: limit, offset: offset);
  }

  /// إضافة معاملة جديدة
  Future<void> addTransaction(TransactionModel transaction) async {
    if (!transaction.isValid()) {
      throw ArgumentError('بيانات المعاملة غير صالحة');
    }

    final res = await ApiService.post(
      '/api/business/${transaction.businessId}/transactions',
      body: transaction.toMap(),
    );
    if (!res.success) {
      throw Exception('فشل إضافة المعاملة: ${res.errorMessage}');
    }
  }

  /// تحديث معاملة
  Future<void> updateTransaction(TransactionModel transaction) async {
    if (!transaction.isValid()) {
      throw ArgumentError('بيانات المعاملة غير صالحة');
    }

    final res = await ApiService.put(
      '/api/business/${transaction.businessId}/transactions/${transaction.id}',
      body: transaction.toMap(),
    );
    if (!res.success) {
      throw Exception('فشل تحديث المعاملة: ${res.errorMessage}');
    }
  }

  /// حذف معاملة
  Future<void> deleteTransaction(String businessId, String transactionId) async {
    final res = await ApiService.delete(
      '/api/business/$businessId/transactions/$transactionId',
    );
    if (!res.success) {
      throw Exception('فشل حذف المعاملة: ${res.errorMessage}');
    }
  }

  /// جلب معاملات شهر محدد
  Future<List<TransactionModel>> getMonthlyTransactions(
    String businessId,
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    try {
      final res = await ApiService.get(
        '/api/business/$businessId/transactions',
        queryParameters: {
          'createdAfter': startDate.toIso8601String(),
          'createdBefore': endDate.toIso8601String(),
          'orderBy': 'createdAt',
          'order': 'desc',
        },
      );
      if (res.success && res.data != null) {
        final raw = res.data!['transactions'] ?? res.data!['data'];
        if (raw is List) {
          return raw
              .cast<Map<String, dynamic>>()
              .map((d) => TransactionModel.fromMap(d))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching monthly transactions: $e');
    }
    return [];
  }

  /// جلب معاملات حسب التصنيف
  Future<List<TransactionModel>> getTransactionsByCategory(
    String businessId,
    String category,
  ) async {
    try {
      final res = await ApiService.get(
        '/api/business/$businessId/transactions',
        queryParameters: {
          'category': category,
          'orderBy': 'createdAt',
          'order': 'desc',
          'limit': '100',
        },
      );
      if (res.success && res.data != null) {
        final raw = res.data!['transactions'] ?? res.data!['data'];
        if (raw is List) {
          return raw
              .cast<Map<String, dynamic>>()
              .map((d) => TransactionModel.fromMap(d))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching transactions by category: $e');
    }
    return [];
  }

  /// إعادة حساب الملخص (للطوارئ فقط)
  Future<void> recalculateSummary(String businessId) async {
    try {
      final res = await ApiService.post(
        '/api/business/$businessId/recalculate-summary',
      );
      if (!res.success) {
        debugPrint('Failed to recalculate summary: ${res.errorMessage}');
      }
    } catch (e) {
      debugPrint('Error recalculating summary: $e');
    }
  }
}

// ============================================================
// دوال مساعدة لتحليل التواريخ
// ============================================================

/// تحليل قيمة تاريخ من البيانات — تدعم DateTime و ISO8601 String
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
