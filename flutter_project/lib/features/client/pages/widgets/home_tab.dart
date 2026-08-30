import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/services_data.dart';
import '../../../requests/pages/service_detail_page.dart';
import 'ai_guidance_card.dart';

class HomeTab extends StatelessWidget {
  final String aiGuidance;
  final bool aiLoading;
  final VoidCallback onAiRefresh;
  final List<Color> iconColors;
  const HomeTab({super.key, required this.aiGuidance, required this.aiLoading, required this.onAiRefresh, required this.iconColors});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: AiGuidanceCard(guidance: aiGuidance, isLoading: aiLoading, onRefresh: onAiRefresh)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              Row(children: [
                Container(width: 6, height: 28, decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 14),
                Text('featured_services'.tr(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
              ]),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 24, childAspectRatio: 0.75),
                itemCount: kServices.length,
                itemBuilder: (_, i) {
                  final svc = kServices[i];
                  final color = iconColors[i % iconColors.length];
                  return _ServiceIcon(service: svc, color: color);
                },
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  final ServiceModel service;
  final Color color;
  const _ServiceIcon({required this.service, required this.color});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceDetailPage(service: service))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [color, color.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
              BoxShadow(color: color.withOpacity(0.7), blurRadius: 4, offset: const Offset(0, 4)),
              BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 2, offset: const Offset(-2, -2), spreadRadius: 1),
            ],
          ),
          child: Icon(service.icon, size: 38, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(1, 2))]),
        ),
        const SizedBox(height: 12),
        // ✅ النص أصبح أبيض نقي مع ظل لضمان الوضوح التام فوق أي خلفية
        Text(
          service.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}