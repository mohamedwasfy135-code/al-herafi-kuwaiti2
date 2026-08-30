// ═══════════════════════════════════════════════════════════════
// Apple Design System – sana3i (الحرفي الكويتي)
// ألوان هادئة: أسود للنصوص، أحمر للتحذيرات، أزرق خفيف فقط للروابط
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class AppTheme {
  // ═══════════════════════════════════════════════════════════════
  // الألوان – هادئة ومحتشمة
  // ═══════════════════════════════════════════════════════════════

  static const Color bg = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F8FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE0E0E0);
  static const Color accent = Color(0xFF0071E3);         // للروابط والأزرار الرئيسية فقط
  static const Color accentLight = Color(0xFFF0F5FF);
  static const Color textP = Color(0xFF111111);          // أسود قوي
  static const Color textS = Color(0xFF555555);          // رمادي داكن
  static const Color textM = Color(0xFF888888);          // رمادي خفيف
  static const Color inputFill = Color(0xFFF8F8FA);
  static const Color danger = Color(0xFFCC0000);         // أحمر داكن للتحذيرات
  static const Color success = Color(0xFF1A7A1A);        // أخضر داكن
  static const Color warning = Color(0xFFB8600A);        // برتقالي داكن
  static const Color selectedBg = Color(0xFFF0F0F0);     // خلفية العنصر المحدد

  // ═══════════════════════════════════════════════════════════════
  // أحجام الخطوط – مدمجة
  // ═══════════════════════════════════════════════════════════════

  static const double fPageTitle = 18;
  static const double fSection = 15;
  static const double fSubtitle = 13;
  static const double fBody = 12;
  static const double fCaption = 11;
  static const double fSmall = 10;
  static const double fTiny = 9;

  // ═══════════════════════════════════════════════════════════════
  // ارتفاعات – مضغوطة
  // ═══════════════════════════════════════════════════════════════

  static const double rowHeight = 32;
  static const double rowHeightLg = 36;
  static const double topBarHeight = 40;
  static const double buttonHeight = 28;
  static const double buttonHeightSm = 24;
  static const double inputHeight = 32;
  static const double iconSize = 14;
  static const double iconSizeSm = 12;

  // ═══════════════════════════════════════════════════════════════
  // المسافات
  // ═══════════════════════════════════════════════════════════════

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;

  // ═══════════════════════════════════════════════════════════════
  // حواف مستديرة
  // ═══════════════════════════════════════════════════════════════

  static const double rSmall = 4;
  static const double rMedium = 6;
  static const double rLarge = 10;
  static const double rPill = 980;

  // ═══════════════════════════════════════════════════════════════
  // أنماط النص – أسود أساسي
  // ═══════════════════════════════════════════════════════════════

  static const TextStyle sPageTitle = TextStyle(
    fontSize: fPageTitle,
    fontWeight: FontWeight.w700,
    color: textP,
    height: 1.3,
  );

  static const TextStyle sSection = TextStyle(
    fontSize: fSection,
    fontWeight: FontWeight.w700,
    color: textP,
    height: 1.3,
  );

  static const TextStyle sSubtitle = TextStyle(
    fontSize: fSubtitle,
    fontWeight: FontWeight.w600,
    color: textP,
    height: 1.4,
  );

  static const TextStyle sBody = TextStyle(
    fontSize: fBody,
    fontWeight: FontWeight.w400,
    color: textP,
    height: 1.4,
  );

  static const TextStyle sBodyBold = TextStyle(
    fontSize: fBody,
    fontWeight: FontWeight.w600,
    color: textP,
    height: 1.4,
  );

  static const TextStyle sCaption = TextStyle(
    fontSize: fCaption,
    fontWeight: FontWeight.w400,
    color: textS,
    height: 1.3,
  );

  static const TextStyle sSmall = TextStyle(
    fontSize: fSmall,
    fontWeight: FontWeight.w400,
    color: textM,
    height: 1.3,
  );

  static const TextStyle sTiny = TextStyle(
    fontSize: fTiny,
    fontWeight: FontWeight.w500,
    color: textM,
    height: 1.2,
  );

  static const TextStyle sLink = TextStyle(
    fontSize: fBody,
    fontWeight: FontWeight.w500,
    color: accent,
    height: 1.4,
    decoration: TextDecoration.underline,
    decorationColor: accent,
  );

  static const TextStyle sDanger = TextStyle(
    fontSize: fBody,
    fontWeight: FontWeight.w500,
    color: danger,
    height: 1.4,
  );

  // ═══════════════════════════════════════════════════════════════
  // أنماط الأزرار – مدمجة وبسيطة
  // ═══════════════════════════════════════════════════════════════

  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: textP,
    foregroundColor: Colors.white,
    disabledBackgroundColor: textP.withOpacity(0.3),
    disabledForegroundColor: Colors.white.withOpacity(0.5),
    elevation: 0,
    minimumSize: const Size(0, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(rSmall),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    textStyle: const TextStyle(
      fontSize: fBody,
      fontWeight: FontWeight.w600,
    ),
  );

  static final ButtonStyle primaryButtonSm = ElevatedButton.styleFrom(
    backgroundColor: textP,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size(0, buttonHeightSm),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(rSmall),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    textStyle: const TextStyle(
      fontSize: fSmall,
      fontWeight: FontWeight.w600,
    ),
  );

  static final ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: textP,
    side: const BorderSide(color: border, width: 1),
    minimumSize: const Size(0, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(rSmall),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    textStyle: const TextStyle(
      fontSize: fBody,
      fontWeight: FontWeight.w500,
    ),
  );

  static final ButtonStyle dangerButton = ElevatedButton.styleFrom(
    backgroundColor: danger,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size(0, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(rSmall),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    textStyle: const TextStyle(
      fontSize: fBody,
      fontWeight: FontWeight.w600,
    ),
  );

  static final ButtonStyle textButton = TextButton.styleFrom(
    foregroundColor: textP,
    minimumSize: const Size(0, buttonHeightSm),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    textStyle: const TextStyle(
      fontSize: fBody,
      fontWeight: FontWeight.w500,
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // حقل الإدخال – مدمج
  // ═══════════════════════════════════════════════════════════════

  static InputDecoration inputDecoration({
    String? hintText,
    String? labelText,
    IconData? prefixIcon,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: const TextStyle(color: textM, fontSize: fBody),
      labelStyle: const TextStyle(color: textS, fontSize: fCaption),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: textS, size: iconSizeSm)
          : null,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rSmall),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rSmall),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rSmall),
        borderSide: const BorderSide(color: textP, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rSmall),
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rSmall),
        borderSide: const BorderSide(color: danger, width: 1),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // بطاقة – بسيطة بلا ظل
  // ═══════════════════════════════════════════════════════════════

  static BoxDecoration cardDecoration({
    Color? accentBorderColor,
    Color? customBg,
  }) {
    return BoxDecoration(
      color: customBg ?? card,
      borderRadius: BorderRadius.circular(rMedium),
      border: Border.all(
        color: accentBorderColor ?? border,
        width: 0.5,
      ),
    );
  }

  static BoxDecoration cardWithSideAccent({
    required Color sideColor,
    bool isRTL = true,
  }) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(rMedium),
      border: Border(
        right: isRTL
            ? BorderSide(color: sideColor, width: 2)
            : BorderSide.none,
        left: isRTL
            ? BorderSide.none
            : BorderSide(color: sideColor, width: 2),
        top: BorderSide.none,
        bottom: BorderSide.none,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ويدجت جاهزة
  // ═══════════════════════════════════════════════════════════════

  static Widget buildTopBar({
    required String title,
    required IconData icon,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return Container(
      height: topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: s10),
      decoration: const BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: Row(
        children: [
          if (leading != null) leading,
          if (leading != null) const SizedBox(width: s8),
          Icon(icon, color: textP, size: iconSize),
          const SizedBox(width: s6),
          Text(title, style: sSubtitle),
          const Spacer(),
          if (actions != null) ...actions,
        ],
      ),
    );
  }

  static Widget divider() => const Divider(color: border, thickness: 0.5, height: 1);
  static SizedBox gap([double h = s8]) => SizedBox(height: h);
  static SizedBox gapW([double w = s8]) => SizedBox(width: w);

  static Widget emptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: textM.withOpacity(0.3)),
            const SizedBox(height: s10),
            Text(message, style: sSubtitle.copyWith(color: textS), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: s4),
              Text(subtitle, style: sCaption, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  static Widget loadingIndicator() =>
      const Center(child: CircularProgressIndicator(color: textP, strokeWidth: 2));

  // ═══════════════════════════════════════════════════════════════
  // نظام الأرقام التسلسلية
  // ═══════════════════════════════════════════════════════════════

  /// الدفاتر الرئيسية تبدأ من 1
  static const int notebookStart = 1;

  /// الحسابات تبدأ من 101
  static const int accountStart = 101;

  /// المواد تبدأ من 1001
  static const int materialStart = 1001;

  // ═══════════════════════════════════════════════════════════════
  // تصنيفات الحسابات الافتراضية
  // ═══════════════════════════════════════════════════════════════

  static const List<Map<String, dynamic>> defaultAccountCategories = [
    {'code': 101, 'nameAr': 'عملاء', 'nameEn': 'Clients', 'type': 'client'},
    {'code': 102, 'nameAr': 'موردين', 'nameEn': 'Suppliers', 'type': 'supplier'},
    {'code': 103, 'nameAr': 'إيجارات', 'nameEn': 'Rent', 'type': 'expense'},
    {'code': 104, 'nameAr': 'رواتب', 'nameEn': 'Salaries', 'type': 'expense'},
    {'code': 105, 'nameAr': 'مصاريف إدارية', 'nameEn': 'Admin Expenses', 'type': 'expense'},
    {'code': 106, 'nameAr': 'نثريات', 'nameEn': 'Petty Cash', 'type': 'expense'},
    {'code': 107, 'nameAr': 'مصاريف هاتف', 'nameEn': 'Phone Expenses', 'type': 'expense'},
    {'code': 108, 'nameAr': 'مصاريف نقل وتوصيل', 'nameEn': 'Shipping & Delivery', 'type': 'expense'},
    {'code': 109, 'nameAr': 'مصاريف ضيافة', 'nameEn': 'Hospitality', 'type': 'expense'},
    {'code': 110, 'nameAr': 'إيرادات مبيعات', 'nameEn': 'Sales Revenue', 'type': 'revenue'},
    {'code': 111, 'nameAr': 'إيرادات خدمات', 'nameEn': 'Service Revenue', 'type': 'revenue'},
    {'code': 112, 'nameAr': 'إيرادات أخرى', 'nameEn': 'Other Revenue', 'type': 'revenue'},
  ];

  // ═══════════════════════════════════════════════════════════════
  // الثيم الكامل
  // ═══════════════════════════════════════════════════════════════

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: textP,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.light(
          primary: textP,
          secondary: accent,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textP,
          onSecondary: Colors.white,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          foregroundColor: textP,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            color: textP,
            fontSize: fSubtitle,
            fontWeight: FontWeight.w700,
          ),
          surfaceTintColor: Colors.transparent,
        ),
        tabBarTheme: TabBarThemeData(
          indicator: BoxDecoration(
            color: selectedBg,
            borderRadius: BorderRadius.circular(rSmall),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: textP,
          unselectedLabelColor: textM,
          labelStyle: const TextStyle(fontSize: fBody, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: fSmall),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
        outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
        textButtonTheme: TextButtonThemeData(style: textButton),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rSmall),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rSmall),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rSmall),
            borderSide: const BorderSide(color: textP, width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rSmall),
            borderSide: const BorderSide(color: danger),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          hintStyle: const TextStyle(color: textM, fontSize: fBody),
          labelStyle: const TextStyle(color: textS, fontSize: fCaption),
        ),
        cardTheme: CardThemeData(
          color: card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMedium),
            side: const BorderSide(color: border, width: 0.5),
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rLarge),
            side: const BorderSide(color: border, width: 0.5),
          ),
          titleTextStyle: const TextStyle(fontSize: fSection, fontWeight: FontWeight.w700, color: textP),
          contentTextStyle: const TextStyle(fontSize: fBody, color: textP),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSmall)),
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 0.5, space: 0),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: bg,
          selectedItemColor: textP,
          unselectedItemColor: textM,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: fSmall, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: fSmall),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: bg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMedium),
            side: const BorderSide(color: border, width: 0.5),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surface,
          selectedColor: selectedBg,
          labelStyle: const TextStyle(fontSize: fSmall, color: textP),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rSmall),
            side: const BorderSide(color: border, width: 0.5),
          ),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowHeight: rowHeightLg,
          dataRowHeight: rowHeight,
          headingTextStyle: const TextStyle(fontSize: fSmall, fontWeight: FontWeight.w600, color: textS),
          dataTextStyle: const TextStyle(fontSize: fBody, color: textP),
          dividerThickness: 0.5,
          horizontalMargin: s8,
          columnSpacing: s10,
        ),
      );
}
