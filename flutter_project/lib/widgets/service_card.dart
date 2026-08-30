import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
class ServiceCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color, iconBgColor;
  final VoidCallback onTap;
  const ServiceCard({super.key, required this.title, required this.subtitle, required this.icon, required this.color, required this.iconBgColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 32, color: color)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkNavy)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: AppTheme.mediumGray)),
          ]),
        ),
      ),
    );
  }
}
