import 'dart:async';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/pages/auth_page.dart';
import '../../chat/pages/chat_list_page.dart';
import 'business_products_tab.dart';
import 'business_offers_tab.dart';
import 'business_subscription_tab.dart';
import 'business_accounting_tab.dart';
import 'business_sales_invoice.dart';
import 'business_purchase_invoice.dart';
import 'business_sales_return.dart';
import 'business_purchase_return.dart';
import 'business_bonds.dart';
import 'business_general_ledger.dart';
import 'business_accounts_tab.dart';
import 'business_invoices_tab.dart';
import 'business_product_movement.dart';
import 'business_account_statement.dart';
import 'widgets/business_orders_tab.dart';
import 'widgets/account_card_dialog.dart';
import 'widgets/material_card_dialog.dart';

// ─── عنصر القائمة ──────────────────────────────────────────────
class _MenuItem {
  final String key;
  final IconData icon;
  final String arLabel;
  final String enLabel;
  final List<_MenuItem>? subItems;
  const _MenuItem(this.key, this.icon, this.arLabel, this.enLabel, {this.subItems});
}

// ─── القائمة: بدون تبويب المنتجات ──────────────────────────────
const _menuItems = <_MenuItem>[
  _MenuItem('invoices', Icons.receipt_long_outlined, 'الفواتير', 'Invoices', subItems: [
    _MenuItem('invoices_tab', Icons.list_alt_outlined, 'سجل الفواتير', 'Invoices List'),
    _MenuItem('sales_invoice', Icons.sell_outlined, 'فاتورة مبيعات', 'Sales Invoice'),
    _MenuItem('purchase_invoice', Icons.shopping_cart_outlined, 'فاتورة مشتريات', 'Purchase Invoice'),
    _MenuItem('sales_return', Icons.undo_outlined, 'مردود مبيعات', 'Sales Return'),
    _MenuItem('purchase_return', Icons.redo_outlined, 'مردود مشتريات', 'Purchase Return'),
  ]),
  _MenuItem('inventory', Icons.warehouse_outlined, 'المخزون', 'Inventory', subItems: [
    _MenuItem('material_card', Icons.inventory_2_outlined, 'بطاقة مادة', 'Material Card'),
    _MenuItem('product_movement', Icons.track_changes_outlined, 'حركة مادة', 'Product Movement'),
  ]),
  _MenuItem('accounting', Icons.account_balance_outlined, 'الحسابات', 'Accounting', subItems: [
    _MenuItem('account_card', Icons.person_add_outlined, 'بطاقة حساب', 'Account Card'),
    _MenuItem('accounting_overview', Icons.calculate_outlined, 'نظرة عامة', 'Overview'),
    _MenuItem('general_ledger', Icons.menu_book_outlined, 'دفتر الأستاذ', 'General Ledger'),
    _MenuItem('accounts_management', Icons.people_outlined, 'إدارة الحسابات', 'Accounts Management'),
    _MenuItem('account_statement', Icons.assignment_outlined, 'كشف حساب', 'Account Statement'),
  ]),
  _MenuItem('bonds', Icons.description_outlined, 'السندات', 'Bonds', subItems: [
    _MenuItem('payment_bond', Icons.arrow_upward_outlined, 'سند صرف', 'Payment Bond'),
    _MenuItem('receipt_bond', Icons.arrow_downward_outlined, 'سند قبض', 'Receipt Bond'),
    _MenuItem('journal_entry', Icons.swap_horiz_outlined, 'سند قيد', 'Journal Entry'),
  ]),
  _MenuItem('offers', Icons.local_offer_outlined, 'العروض', 'Offers'),
  _MenuItem('chats', Icons.chat_bubble_outline, 'المحادثات', 'Chats'),
  _MenuItem('subscription', Icons.card_membership_outlined, 'الاشتراك', 'Subscription'),
  _MenuItem('orders', Icons.receipt_outlined, 'الطلبات', 'Orders'),
];

// ─── الصفحة الرئيسية ──────────────────────────────────────────
class BusinessHomePage extends StatefulWidget {
  final String verificationStatus;
  const BusinessHomePage({super.key, this.verificationStatus = ''});

  @override
  State<BusinessHomePage> createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage> {
  final _uid = AuthService.currentUser!.id;
  String _selectedPage = 'invoices_tab';
  List<String> _customCategories = [];
  bool _accountingLoaded = false;

  // ─── Polling-based stream for business data ──────────────────
  Map<String, dynamic>? _businessData;
  final _businessController = StreamController<Map<String, dynamic>?>.broadcast();
  Timer? _pollTimer;

  bool get _isPending =>
      widget.verificationStatus == kVerificationStatusPending;

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _businessController.close();
    super.dispose();
  }

  void _startPolling() {
    _loadBusinessData();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadBusinessData());
  }

  Future<void> _loadBusinessData() async {
    final data = await FirestoreService.getBusiness(_uid);
    if (data != null && mounted) {
      _businessData = data;
      _businessController.add(data);
    }
  }

  Future<void> _loadCustomCategories() async {
    final data = await FirestoreService.getBusiness(_uid);
    if (data != null && mounted) {
      setState(() {
        _customCategories = List<String>.from(data['customCategories'] ?? []);
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
  }

  bool get _isArabic {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'ar';
  }

  // ─── تبديل اللغة ──────────────────────────────────────────────
  void _toggleLocale() {
    final newLocale = _isArabic ? const Locale('en') : const Locale('ar');
    context.setLocale(newLocale);
  }

  // ─── معلومات الصفحة الحالية ──────────────────────────────────
  String _currentPageLabel() {
    final isArabic = _isArabic;
    for (final item in _menuItems) {
      if (item.key == _selectedPage) return isArabic ? item.arLabel : item.enLabel;
      if (item.subItems != null) {
        for (final sub in item.subItems!) {
          if (sub.key == _selectedPage) return isArabic ? sub.arLabel : sub.enLabel;
        }
      }
    }
    return '';
  }

  IconData _currentPageIcon() {
    for (final item in _menuItems) {
      if (item.key == _selectedPage) return item.icon;
      if (item.subItems != null) {
        for (final sub in item.subItems!) {
          if (sub.key == _selectedPage) return sub.icon;
        }
      }
    }
    return Icons.circle;
  }

  void _selectPage(String key) {
    setState(() {
      _selectedPage = key;
      if (key == 'accounting_overview' && !_accountingLoaded) {
        _accountingLoaded = true;
      }
    });
  }

  bool _isNarrowPage(String key) {
    return [
      'sales_invoice', 'purchase_invoice', 'sales_return', 'purchase_return',
      'payment_bond', 'receipt_bond', 'journal_entry',
      'material_card', 'account_card',
    ].contains(key);
  }

  // ─── اختصار سريع ──────────────────────────────────────────────
  Widget _buildQuickShortcut(IconData icon, String tooltip, String pageKey) {
    final isActive = _selectedPage == pageKey;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: () => _selectPage(pageKey),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: isActive ? AppTheme.accent : AppTheme.textM),
              const SizedBox(width: 4),
              Text(tooltip, style: TextStyle(
                color: isActive ? AppTheme.accent : AppTheme.textM,
                fontSize: AppTheme.fCaption,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── زر تبديل اللغة ──────────────────────────────────────────
  Widget _buildLangToggle() {
    final isAr = _isArabic;
    return Tooltip(
      message: isAr ? 'Switch to English' : 'التحويل للعربية',
      preferBelow: false,
      child: InkWell(
        onTap: _toggleLocale,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 13, color: AppTheme.textS),
              const SizedBox(width: 4),
              Text(
                isAr ? 'EN' : 'عربي',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: AppTheme.fSmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── بناء المحتوى حسب الصفحة ──────────────────────────────
  Widget _buildPageContent(String key) {
    switch (key) {
      case 'products':
        return BusinessProductsTab(uid: _uid);
      case 'offers':
        return BusinessOffersTab(uid: _uid);
      case 'invoices_tab':
        return BusinessInvoicesTab(uid: _uid);
      case 'sales_invoice':
        return BusinessSalesInvoice(uid: _uid);
      case 'purchase_invoice':
        return BusinessPurchaseInvoice(uid: _uid);
      case 'sales_return':
        return BusinessSalesReturn(uid: _uid);
      case 'purchase_return':
        return BusinessPurchaseReturn(uid: _uid);
      case 'material_card':
        return _buildMaterialCardPage();
      case 'account_card':
        return _buildAccountCardPage();
      case 'product_movement':
        return BusinessProductMovement(uid: _uid);
      case 'accounting_overview':
        return _accountingLoaded
            ? BusinessAccountingTab(uid: _uid, customCategories: _customCategories)
            : const Center(child: CircularProgressIndicator(color: AppTheme.accent));
      case 'general_ledger':
        return BusinessGeneralLedger(uid: _uid);
      case 'accounts_management':
        return BusinessAccountsTab(uid: _uid);
      case 'account_statement':
        return BusinessAccountStatement(uid: _uid);
      case 'payment_bond':
        return BusinessBonds(key: Key('bond_payment_$_selectedPage'), uid: _uid, initialType: 'payment');
      case 'receipt_bond':
        return BusinessBonds(key: Key('bond_receipt_$_selectedPage'), uid: _uid, initialType: 'receipt');
      case 'journal_entry':
        return BusinessBonds(key: Key('bond_journal_$_selectedPage'), uid: _uid, initialType: 'journal');
      case 'chats':
        return const ChatListPage();
      case 'subscription':
        return BusinessSubscriptionTab(uid: _uid);
      case 'orders':
        return BusinessOrdersTab(uid: _uid);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── شاشة قيد المراجعة ──────────────────────────────────────
  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.warning.withOpacity(0.08),
              ),
              child: Icon(Icons.hourglass_top, size: 24, color: AppTheme.warning),
            ),
            const SizedBox(height: 16),
            const Text('حسابك قيد المراجعة',
                style: TextStyle(
                  fontSize: AppTheme.fPageTitle,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textP,
                )),
            const SizedBox(height: 8),
            Text('شكراً لتسجيلك في منصة الحرفي الكويتي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fBody,
                color: AppTheme.textS,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 14, color: AppTheme.textS),
              label: const Text('تسجيل الخروج',
                style: TextStyle(
                  color: AppTheme.textS,
                  fontSize: AppTheme.fBody,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── صفحة بطاقة الحساب ──────────────────────────────────
  Widget _buildAccountCardPage() {
    return Column(
      children: [
        AppTheme.buildTopBar(title: 'بطاقة حساب', icon: Icons.person_add_outlined),
        Expanded(
          child: Center(
            child: Container(
              width: 480,
              child: AccountCardDialog(uid: _uid),
            ),
          ),
        ),
      ],
    );
  }

  // ─── صفحة بطاقة المادة ──────────────────────────────────
  Widget _buildMaterialCardPage() {
    return Column(
      children: [
        AppTheme.buildTopBar(title: 'بطاقة مادة', icon: Icons.inventory_2_outlined),
        Expanded(
          child: Center(
            child: Container(
              width: 480,
              child: MaterialCardDialog(uid: _uid),
            ),
          ),
        ),
      ],
    );
  }

  // ─── القائمة المنسدلة (هامبرجر) ──────────────────────────────
  Widget _buildHamburgerMenu() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      color: AppTheme.bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.rMedium),
        side: const BorderSide(color: AppTheme.border, width: 0.5),
      ),
      onSelected: (key) {
        if (key == '__logout__') {
          _logout();
        } else {
          _selectPage(key);
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];
        for (final item in _menuItems) {
          if (item.subItems != null && item.subItems!.isNotEmpty) {
            // عنوان المجموعة
            items.add(PopupMenuItem<String>(
              enabled: false,
              height: 30,
              child: Row(
                children: [
                  Icon(item.icon, size: 13, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    _isArabic ? item.arLabel : item.enLabel,
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: AppTheme.fCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ));
            // العناصر الفرعية
            for (final sub in item.subItems!) {
              final isSelected = _selectedPage == sub.key;
              items.add(PopupMenuItem<String>(
                value: sub.key,
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    children: [
                      Icon(sub.icon, size: 13,
                          color: isSelected ? AppTheme.accent : AppTheme.textM),
                      const SizedBox(width: 8),
                      Text(
                        _isArabic ? sub.arLabel : sub.enLabel,
                        style: TextStyle(
                          color: isSelected ? AppTheme.accent : AppTheme.textS,
                          fontSize: AppTheme.fBody,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ));
            }
            // فاصل
            items.add(const PopupMenuDivider(height: 4));
          } else {
            final isSelected = _selectedPage == item.key;
            items.add(PopupMenuItem<String>(
              value: item.key,
              height: 32,
              child: Row(
                children: [
                  Icon(item.icon, size: 13,
                      color: isSelected ? AppTheme.accent : AppTheme.textM),
                  const SizedBox(width: 8),
                  Text(
                    _isArabic ? item.arLabel : item.enLabel,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textS,
                      fontSize: AppTheme.fBody,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ));
          }
        }
        // تسجيل الخروج
        items.add(const PopupMenuDivider(height: 4));
        items.add(PopupMenuItem<String>(
          value: '__logout__',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.logout, size: 13, color: AppTheme.danger),
              const SizedBox(width: 8),
              Text(_isArabic ? 'تسجيل الخروج' : 'Logout', style: TextStyle(
                color: AppTheme.danger,
                fontSize: AppTheme.fBody,
                fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ));
        return items;
      },
      onCanceled: () {},
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(Icons.menu, size: 16, color: AppTheme.textP),
      ),
    );
  }

  // ─── البناء الرئيسي ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _businessController.stream,
      initialData: _businessData,
      builder: (_, snap) {
        final data = snap.hasData && snap.data != null
            ? snap.data!
            : <String, dynamic>{};
        final bName = data['businessName'] as String? ?? 'المنشأة';

        if (_selectedPage == 'accounting_overview' && !_accountingLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _accountingLoaded = true);
          });
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: _isPending
              ? _buildPendingView()
              : Column(
                  textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  children: [
                    // ─── شريط علوي مدمج ────────────────────────
                    Container(
                      height: AppTheme.topBarHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: const BoxDecoration(
                        color: AppTheme.bg,
                        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
                      ),
                      child: Row(
                        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                        children: [
                          // زر الهامبرجر
                          _buildHamburgerMenu(),
                          const SizedBox(width: 10),
                          // أيقونة الصفحة + الاسم
                          Icon(_currentPageIcon(), color: AppTheme.accent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _currentPageLabel(),
                            style: TextStyle(
                              color: AppTheme.textP,
                              fontSize: AppTheme.fSubtitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // اسم المنشأة
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentLight,
                              borderRadius: BorderRadius.circular(980),
                            ),
                            child: Text(bName,
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: AppTheme.fSmall,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          // اختصارات سريعة
                          _buildQuickShortcut(Icons.sell, _isArabic ? 'مبيعات' : 'Sales', 'sales_invoice'),
                          const SizedBox(width: 4),
                          _buildQuickShortcut(Icons.shopping_cart, _isArabic ? 'مشتريات' : 'Purchases', 'purchase_invoice'),
                          const SizedBox(width: 4),
                          _buildQuickShortcut(Icons.receipt_long, _isArabic ? 'الفواتير' : 'Invoices', 'invoices_tab'),
                          const SizedBox(width: 4),
                          _buildQuickShortcut(Icons.swap_horiz, _isArabic ? 'قيد' : 'Journal', 'journal_entry'),
                          const SizedBox(width: 6),
                          // فاصل
                          Container(width: 0.5, height: 20, color: AppTheme.border),
                          const SizedBox(width: 6),
                          // زر اللغة
                          _buildLangToggle(),
                        ],
                      ),
                    ),
                    // ─── محتوى الصفحة ──────────────────────
                    Expanded(
                      child: _isNarrowPage(_selectedPage)
                          ? Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 960),
                                child: _buildPageContent(_selectedPage),
                              ),
                            )
                          : _buildPageContent(_selectedPage),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
