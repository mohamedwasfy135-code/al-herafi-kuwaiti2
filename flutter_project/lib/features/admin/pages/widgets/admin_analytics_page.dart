import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/openrouter_service.dart';

/// ═══════════════════════════════════════════════════════════
/// ADMIN ANALYTICS PAGE — تحليلات ذكية بالذكاء الاصطناعي
/// ═══════════════════════════════════════════════════════════
class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  bool _analyzing = false;
  String? _aiAnalysis;
  String? _aiError;

  int _totalRequests = 0;
  int _completedRequests = 0;
  int _pendingRequests = 0;
  int _totalCraftsmen = 0;
  int _totalClients = 0;
  int _totalBusinesses = 0;
  double _totalRevenue = 0.0;
  double _avgRating = 0.0;

  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuickStats();
  }

  /// Parse a dynamic value into DateTime
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try { return DateTime.parse(value); } catch (_) { return null; }
    }
    return null;
  }

  Future<void> _loadQuickStats() async {
    setState(() => _statsLoading = true);
    try {
      final results = await Future.wait([
        FirestoreService.getRequests(),
        FirestoreService.getCraftsmen(),
        ApiService.get('/api/users', queryParameters: {'role': kRoleClient}),
        ApiService.get('/api/business'),
        FirestoreService.getRequests(status: kStatusDone),
      ]);

      final requestsList = results[0] as List<Map<String, dynamic>>;
      final craftsmenList = results[1] as List<Map<String, dynamic>>;

      final clientsRes = results[2] as ApiResponse;
      final clientsList = (clientsRes.success && clientsRes.data != null)
          ? (clientsRes.data!['users'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []
          : <Map<String, dynamic>>[];

      final businessesRes = results[3] as ApiResponse;
      final businessesList = (businessesRes.success && businessesRes.data != null)
          ? (businessesRes.data!['businesses'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []
          : <Map<String, dynamic>>[];

      final doneList = results[4] as List<Map<String, dynamic>>;

      final pendingList = requestsList.where((d) =>
          d['status'] == kStatusPending ||
          d['status'] == kStatusNotified ||
          d['status'] == kStatusAccepted).toList();

      double revenue = 0.0;
      double totalRating = 0.0;
      int ratingCount = 0;

      for (final d in requestsList) {
        final amount = (d['finalAmount'] as num?)?.toDouble() ?? 0.0;
        if (amount > 0) revenue += amount * 0.10;

        final rating = (d['clientRating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          totalRating += rating;
          ratingCount++;
        }
      }

      setState(() {
        _totalRequests = requestsList.length;
        _completedRequests = doneList.length;
        _pendingRequests = pendingList.length;
        _totalCraftsmen = craftsmenList.length;
        _totalClients = clientsList.length;
        _totalBusinesses = businessesList.length;
        _totalRevenue = revenue;
        _avgRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;
        _statsLoading = false;
      });
    } catch (e) {
      setState(() => _statsLoading = false);
      debugPrint('❌ Error loading stats: $e');
    }
  }

  Future<void> _runAiAnalysis() async {
    setState(() {
      _analyzing = true;
      _aiAnalysis = null;
      _aiError = null;
    });

    try {
      final requestsList = await FirestoreService.getRequests();
      final craftsmenList = await FirestoreService.getCraftsmen();

      final Map<String, int> serviceCounts = {};
      final Map<String, int> governorateCounts = {};
      final Map<String, int> statusCounts = {};
      final List<double> completionTimes = [];
      int cancelledCount = 0;
      int rejectedCount = 0;

      for (final d in requestsList) {
        final service = d['service'] as String? ?? 'غير محدد';
        final gov = d['clientGovernorate'] as String? ?? 'غير محدد';
        final status = d['status'] as String? ?? 'unknown';

        serviceCounts[service] = (serviceCounts[service] ?? 0) + 1;
        governorateCounts[gov] = (governorateCounts[gov] ?? 0) + 1;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        if (status == 'cancelled_by_client') cancelledCount++;
        if (status == kStatusRejected) rejectedCount++;

        final createdAt = _parseDateTime(d['createdAt']);
        final finishedAt = _parseDateTime(d['finishedAt']);
        if (createdAt != null && finishedAt != null) {
          completionTimes.add(finishedAt.difference(createdAt).inHours.toDouble());
        }
      }

      final List<Map<String, dynamic>> topCraftsmen = [];
      for (final d in craftsmenList) {
        topCraftsmen.add({
          'name': d['name'] ?? 'غير معروف',
          'rating': (d['rating'] as num?)?.toDouble() ?? 0.0,
          'totalJobs': (d['totalJobs'] as num?)?.toInt() ?? 0,
          'governorate': d['governorate'] ?? 'غير محدد',
        });
      }
      topCraftsmen.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));

      final avgCompletionTime = completionTimes.isNotEmpty
          ? completionTimes.reduce((a, b) => a + b) / completionTimes.length
          : 0.0;

      final prompt = '''
أنت محلل بيانات متخصص في منصات الخدمات المنزلية. حلل البيانات التالية وقدم تحليلاً استراتيجياً بالعربية.

📊 إحصائيات المنصة (الحرفي الكويتي):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• إجمالي الطلبات: $_totalRequests
• الطلبات المكتملة: $_completedRequests
• الطلبات المعلقة: $_pendingRequests
• إجمالي الحرفيين: $_totalCraftsmen
• إجمالي العملاء: $_totalClients
• إجمالي المنشآت: $_totalBusinesses
• إجمالي الإيرادات (عمولة 10%): ${_totalRevenue.toStringAsFixed(3)} د.ك
• متوسط تقييم الحرفيين: ${_avgRating.toStringAsFixed(1)}/5

📈 توزيع الطلبات حسب الخدمة:
${serviceCounts.entries.map((e) => '• ${e.key}: ${e.value} طلب').join('\n')}

🗺️ توزيع الطلبات حسب المحافظة:
${governorateCounts.entries.map((e) => '• ${e.key}: ${e.value} طلب').join('\n')}

📋 توزيع حالات الطلبات:
${statusCounts.entries.map((e) => '• ${e.key}: ${e.value}').join('\n')}

⚡ مؤشرات الأداء:
• متوسط وقت الإنجاز: ${avgCompletionTime.toStringAsFixed(1)} ساعة
• نسبة الإلغاء: ${cancelledCount > 0 ? ((cancelledCount / _totalRequests) * 100).toStringAsFixed(1) : 0}%
• نسبة الرفض: ${rejectedCount > 0 ? ((rejectedCount / _totalRequests) * 100).toStringAsFixed(1) : 0}%

🏆 أفضل 5 حرفيين:
${topCraftsmen.take(5).map((c) => '• ${c['name']} (⭐${c['rating']} - ${c['totalJobs']} وظيفة)').join('\n')}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

قدم تحليلاً شاملاً يتضمن:
1. 💡 ملخص تنفيذي (3-4 أسطر)
2. 📊 نقاط القوة (3 نقاط)
3. ⚠️ نقاط الضعف / التحديات (3 نقاط)
4. 🎯 توصيات عملية محددة (5 توصيات)
5. 🔮 توقعات للشهر القادم
6. 📈 اقتراحات لزيادة الإيرادات

اكتب بالعربية الفصحى بأسلوب احترافي وواضح.
''';

      final response = await OpenRouterService.chat(
        messages: [
          {'role': 'system', 'content': 'أنت محلل بيانات استراتيجي متخصص في منصات الخدمات. قدم تحليلات دقيقة وتوصيات عملية.'},
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.7,
        maxTokens: 2048,
      );

      setState(() {
        _aiAnalysis = response;
        _analyzing = false;
      });
    } catch (e) {
      setState(() {
        _aiError = 'فشل في التحليل: $e';
        _analyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadQuickStats,
      color: const Color(0xFF0071E3),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('ai_analytics'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              background: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, size: 48, color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _statsLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('quick_stats'.tr(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _statCard(Icons.request_page, 'total_requests'.tr(), '$_totalRequests', Colors.blue),
                            _statCard(Icons.check_circle, 'completed'.tr(), '$_completedRequests', Colors.green),
                            _statCard(Icons.pending_actions, 'pending'.tr(), '$_pendingRequests', Colors.orange),
                            _statCard(Icons.construction, 'craftsmen'.tr(), '$_totalCraftsmen', Colors.teal),
                            _statCard(Icons.people, 'clients'.tr(), '$_totalClients', Colors.purple),
                            _statCard(Icons.store, 'businesses'.tr(), '$_totalBusinesses', Colors.indigo),
                            _statCard(Icons.monetization_on, 'revenue'.tr(), '${_totalRevenue.toStringAsFixed(3)} د.ك', Colors.amber),
                            _statCard(Icons.star, 'avg_rating'.tr(), '${_avgRating.toStringAsFixed(1)}/5', Colors.red),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: _analyzing ? null : _runAiAnalysis,
                icon: _analyzing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D1D1F)),
                      )
                    : const Icon(Icons.auto_awesome, color: Color(0xFF1D1D1F)),
                label: Text(
                  _analyzing ? 'analyzing'.tr() : 'run_ai_analysis'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ),
          if (_aiError != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_aiError!, style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          if (_aiAnalysis != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0071E3).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.psychology, color: Color(0xFF0071E3), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text('ai_analysis_results'.tr(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                    ..._formatAnalysisText(_aiAnalysis!),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 42) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _formatAnalysisText(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith('##') ||
          RegExp(r'^\d+\.').hasMatch(trimmed) ||
          trimmed.contains('━━━━━━━━')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              trimmed.replaceAll('#', '').trim(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0071E3),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, left: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0071E3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trimmed.substring(1).trim(),
                    style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              trimmed,
              style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
