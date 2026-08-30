import 'package:flutter/material.dart';

import '../../../core/services/ai_analytics_service.dart';

// ══════════════════════════════════════════════════════════════
// ADMIN ANALYTICS PAGE — لوحة تحليلات الأدمن بالذكاء الاصطناعي
// ══════════════════════════════════════════════════════════════

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  AnalyticsReport? _report;
  bool _loading = true;
  String _period = '30'; // أيام

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    final days = int.tryParse(_period) ?? 30;
    final report = await AiAnalyticsService.generateReport(
      from: DateTime.now().subtract(Duration(days: days)),
    );
    if (mounted) setState(() { _report = report; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('تحليلات ذكية'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          // فلتر الفترة
          PopupMenuButton<String>(
            initialValue: _period,
            onSelected: (v) { setState(() => _period = v); _loadReport(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '7',  child: Text('آخر 7 أيام')),
              const PopupMenuItem(value: '30', child: Text('آخر 30 يوم')),
              const PopupMenuItem(value: '90', child: Text('آخر 90 يوم')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text('$_period يوم'),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text('الذكاء الاصطناعي يحلل البيانات...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ))
          : _report == null
              ? const Center(child: Text('تعذّر تحميل التقرير'))
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _aiSummaryCard(),
                      const SizedBox(height: 16),
                      _statsRow(),
                      const SizedBox(height: 16),
                      _insightsCard(),
                      const SizedBox(height: 16),
                      _servicesChart(),
                      const SizedBox(height: 16),
                      _governoratesChart(),
                      const SizedBox(height: 16),
                      _pricesCard(),
                    ],
                  ),
                ),
    );
  }

  // ── ملخص AI ───────────────────────────────────────────────
  Widget _aiSummaryCard() {
    if (_report!.aiSummary.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('ملخص الذكاء الاصطناعي',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        Text(_report!.aiSummary,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.6)),
      ]),
    );
  }

  // ── الإحصائيات الرئيسية ────────────────────────────────────
  Widget _statsRow() {
    final r = _report!;
    return Row(children: [
      _statCard('إجمالي الطلبات', r.totalRequests.toString(),
          Icons.list_alt, Colors.blue),
      const SizedBox(width: 10),
      _statCard('نسبة الإنجاز',
          '${r.completionRate.toStringAsFixed(1)}%',
          Icons.check_circle, Colors.green),
      const SizedBox(width: 10),
      _statCard('متوسط التقييم',
          '⭐ ${r.avgRating.toStringAsFixed(1)}',
          Icons.star, Colors.amber),
      const SizedBox(width: 10),
      _statCard('وقت الاستجابة',
          '${r.avgResponseTime.toStringAsFixed(0)}د',
          Icons.timer, Colors.orange),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    ));
  }

  // ── Insights الذكية ────────────────────────────────────────
  Widget _insightsCard() {
    if (_report!.insights.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('💡 توصيات الذكاء الاصطناعي',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 10),
      ..._report!.insights.map(_insightTile),
    ]);
  }

  Widget _insightTile(AnalyticsInsight insight) {
    final colors = {
      'warning': Colors.orange,
      'success': Colors.green,
      'info':    Colors.blue,
      'tip':     Colors.purple,
    };
    final icons = {
      'warning': Icons.warning_amber,
      'success': Icons.check_circle,
      'info':    Icons.info,
      'tip':     Icons.lightbulb,
    };
    final color = colors[insight.type] ?? Colors.blue;
    final icon  = icons[insight.type]  ?? Icons.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(insight.title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color, fontSize: 13)),
            const SizedBox(height: 4),
            Text(insight.description,
                style: const TextStyle(fontSize: 12, height: 1.5)),
            if (insight.action.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('→ ${insight.action}',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        )),
      ]),
    );
  }

  // ── مخطط الخدمات ──────────────────────────────────────────
  Widget _servicesChart() {
    final r      = _report!;
    final sorted = r.servicesDemand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();

    final max = sorted.first.value.toDouble();

    return _card(
      title: '🔧 الخدمات الأكثر طلباً',
      child: Column(
        children: sorted.take(8).map((e) {
          final pct = max > 0 ? e.value / max : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(
                width: 110,
                child: Text(e.key,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(child: Stack(children: [
                Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    )),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ])),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text('${e.value}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── مخطط المحافظات ────────────────────────────────────────
  Widget _governoratesChart() {
    final r      = _report!;
    final sorted = r.govDemand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();

    final max = sorted.first.value.toDouble();

    return _card(
      title: '📍 المناطق الأكثر طلباً',
      child: Column(
        children: sorted.take(6).map((e) {
          final pct = max > 0 ? e.value / max : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(
                width: 130,
                child: Text(e.key,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(child: Stack(children: [
                Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    )),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ])),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text('${e.value}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── الأسعار ───────────────────────────────────────────────
  Widget _pricesCard() {
    final prices = _report!.avgPrices;
    if (prices.isEmpty) return const SizedBox.shrink();

    return _card(
      title: '💰 متوسط الأسعار بالدينار الكويتي',
      child: Column(
        children: prices.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(e.key,
                style: const TextStyle(fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                '${e.value.toStringAsFixed(3)} د.ك',
                style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ]),
        )).toList(),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}
