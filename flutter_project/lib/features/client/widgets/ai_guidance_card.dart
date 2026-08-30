import 'package:flutter/material.dart';

class AiGuidanceCard extends StatelessWidget {
  final String guidance;
  final bool isLoading;
  final VoidCallback onRefresh;
  const AiGuidanceCard({super.key, required this.guidance, required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFFF0F7FF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF1565C0), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: isLoading
                  ? const Text('...', style: TextStyle(fontSize: 14))
                  : Text(guidance, style: const TextStyle(fontSize: 14, color: Color(0xFF37474F)), textDirection: TextDirection.rtl),
            ),
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: onRefresh),
          ]),
        ),
      ),
    );
  }
}
