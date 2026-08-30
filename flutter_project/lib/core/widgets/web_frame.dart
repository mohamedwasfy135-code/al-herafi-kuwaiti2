import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// WEB FRAME — يحاكي شكل الموبايل على الويب
// على الموبايل: يعرض المحتوى مباشرة
// على الويب: يضع المحتوى في إطار موبايل في المنتصف
// ══════════════════════════════════════════════════════════════

class WebFrame extends StatelessWidget {
  final Widget child;
  const WebFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final screenWidth = MediaQuery.of(context).size.width;

    // على شاشات صغيرة (موبايل ويب) — عرض كامل
    if (screenWidth <= 500) return child;

    // على شاشات كبيرة — إطار موبايل في المنتصف
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Center(
        child: Container(
          width: 420,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
      ),
    );
  }
}
