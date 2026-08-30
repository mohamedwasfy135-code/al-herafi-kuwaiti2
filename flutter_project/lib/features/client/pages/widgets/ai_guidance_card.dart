import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AiGuidanceCard extends StatelessWidget {
  final String guidance;
  final bool isLoading;
  final VoidCallback onRefresh;

  const AiGuidanceCard({
    super.key,
    required this.guidance,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 0 : 16,
            vertical: 12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0071E3).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF0071E3),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isLoading
                            ? const Text('...', style: TextStyle(fontSize: 14, color: Colors.white70))
                            : Text(
                                guidance,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF0071E3)),
                        onPressed: onRefresh,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'refresh',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}