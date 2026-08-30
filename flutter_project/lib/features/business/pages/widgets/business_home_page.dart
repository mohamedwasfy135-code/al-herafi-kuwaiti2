import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
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
import 'widgets/business_orders_tab.dart';

// ─── عنصر القائمة الفرعية ─────────────────────────────────────
class _NavSubItem {
  final String key;
  final IconData icon;
  final String arLabel;
  final String enLabel;
  const _NavSubItem(this.key, this.icon, this.arLabel, this.enLabel);
}

// ─── عنصر القائمة الجانبية ───────────────────────────────────
class _NavItem {
  final String key;
  final IconData icon;
  final IconData activeIcon;
  final String arLabel;
  final String enLabel;
  final List<_NavSubItem>? subItems;
  const _NavItem(
    this.key,
    this.icon,
    this.activeIcon,
    this.arLabel,
    this.enLabel, {
    this.subItems,
  });
}

const _navItems = <_NavItem>[
  // ─── مستقل ────────────────────────────────────────────────
  _NavItem('products', Icons.inventory_2_outlined, Icons.inventory_2,
      'المنتجات', 'Products'),

  // ─── الفواتير (منسدل) ────────────────────────────────────
  _NavItem('invoices', Icons.receipt_long_outlined, Icons.receipt_long,
      'الفواتير', 'Invoices', subItems: [
    _NavSubItem('invoices_tab', Icons.list_alt_outlined, 'سجل الفواتير', 'Invoices List'),
    _NavSubItem(
        'sales_invoice', Icons.sell_outlined, 'فاتورة مبيعات', 'Sales Invoice'),
    _NavSubItem('purchase_invoice', Icons.shopping_cart_outlined,
        'فاتورة مشتريات', 'Purchase Invoice'),
    _NavSubItem(
        'sales_return', Icons.undo_outlined, 'مردود مبيعات', 'Sales Return'),
    _NavSubItem('purchase_return', Icons.redo_outlined, 'مردود مشتريات',
        'Purchase Return'),
  ]),

  // ─── المخزون ─────────────────────────────────────────────
  _NavItem('inventory', Icons.warehouse_outlined, Icons.warehouse,
      'المخزون', 'Inventory', subItems: [
    _NavSubItem('product_movement', Icons.track_changes_outlined,
        'حركة مادة', 'Product Movement'),
  ]),

  // ─── الحسابات (منسدل) ────────────────────────────────────
  _NavItem('accounting', Icons.account_balance_outlined,
      Icons.account_balance, 'الحسابات', 'Accounting', subItems: [
    _NavSubItem(
        'accounting_overview', Icons.calculate_outlined, 'نظرة عامة', 'Overview'),
    _NavSubItem('general_ledger', Icons.menu_book_outlined, 'دفتر الأستاذ',
        'General Ledger'),
    _NavSubItem('accounts_management', Icons.people_outlined,
        'إدارة الحسابات', 'Accounts Management'),
  ]),

  // ─── السندات (منسدل) ─────────────────────────────────────
  _NavItem('bonds', Icons.description_outlined, Icons.description, 'السندات',
      'Bonds', subItems: [
    _NavSubItem(
        'payment_bond', Icons.arrow_upward_outlined, 'سند صرف', 'Payment Bond'),
    _NavSubItem('receipt_bond', Icons.arrow_downward_outlined, 'سند قبض',
        'Receipt Bond'),
  ]),

  // ─── مستقل ────────────────────────────────────────────────
  _NavItem('offers', Icons.local_offer_outlined, Icons.local_offer, 'العروض',
      'Offers'),
  _NavItem('chats', Icons.chat_bubble_outline, Icons.chat_bubble,
      'المحادثات', 'Chats'),
  _NavItem('subscription', Icons.card_membership_outlined,
      Icons.card_membership, 'الاشتراك', 'Subscription'),
  _NavItem('orders', Icons.receipt_outlined, Icons.receipt, 'الطلبات',
      'Orders'),
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
  String _selectedPage = 'products';
  Set<String> _expandedGroups = {};
  List<String> _customCategories = [];
  bool _accountingLoaded = false;
  bool _sidebarCollapsed = false;

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
        _customCategories =
            List<String>.from(data['customCategories'] ?? []);
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

  // ─── معلومات الصفحة الحالية ──────────────────────────────────
  _NavItem? _getParentOf(String pageKey) {
    for (final item in _navItems) {
      if (item.key == pageKey) return item;
      if (item.subItems != null) {
        for (final sub in item.subItems!) {
          if (sub.key == pageKey) return item;
        }
      }
    }
    return null;
  }

  _NavSubItem? _getSubItem(String pageKey) {
    for (final item in _navItems) {
      if (item.subItems != null) {
        for (final sub in item.subItems!) {
          if (sub.key == pageKey) return sub;
        }
      }
    }
    return null;
  }

  String _currentPageLabel() {
    final isArabic = _isArabic;
    final sub = _getSubItem(_selectedPage);
    if (sub != null) return isArabic ? sub.arLabel : sub.enLabel;
    final parent = _getParentOf(_selectedPage);
    if (parent != null) return isArabic ? parent.arLabel : parent.enLabel;
    return '';
  }

  IconData _currentPageIcon() {
    final sub = _getSubItem(_selectedPage);
    if (sub != null) return sub.icon;
    final parent = _getParentOf(_selectedPage);
    if (parent != null) return parent.activeIcon;
    return Icons.circle;
  }

  bool _isParentSelected(_NavItem item) {
    if (item.subItems == null) return _selectedPage == item.key;
    return item.subItems!.any((sub) => sub.key == _selectedPage);
  }

  void _selectPage(String key) {
    setState(() {
      _selectedPage = key;
      for (final item in _navItems) {
        if (item.subItems != null) {
          for (final sub in item.subItems!) {
            if (sub.key == key) {
              _expandedGroups.add(item.key);
            }
          }
        }
      }
      if (key == 'accounting_overview' && !_accountingLoaded) {
        _accountingLoaded = true;
      }
    });
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
      case 'product_movement':
        return BusinessProductMovement(uid: _uid);
      case 'accounting_overview':
        return _accountingLoaded
            ? BusinessAccountingTab(
                uid: _uid, customCategories: _customCategories)
            : const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF0071E3)));
      case 'general_ledger':
        return BusinessGeneralLedger(uid: _uid);
      case 'accounts_management':
        return BusinessAccountsTab(uid: _uid);
      case 'payment_bond':
        return BusinessBonds(uid: _uid, initialType: 'payment');
      case 'receipt_bond':
        return BusinessBonds(uid: _uid, initialType: 'receipt');
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.2),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.6), width: 3),
              ),
              child: const Icon(Icons.hourglass_top,
                  size: 55, color: Colors.orange),
            ),
            const SizedBox(height: 28),
            const Text('حسابك قيد المراجعة',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 12),
            Text(
              'شكراً لتسجيلك في منصة الحرفي الكويتي.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white70),
              label:
                  const Text('تسجيل الخروج', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── القائمة الجانبية ──────────────────────────────────────
  Widget _buildSidebar(String businessName) {
    final isArabic = _isArabic;
    final collapsed = _sidebarCollapsed;
    final sidebarWidth = collapsed ? 64.0 : 230.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1F).withOpacity(0.95),
        border: Border(
          right: isArabic
              ? BorderSide.none
              : BorderSide(color: Colors.white.withOpacity(0.1)),
          left: isArabic
              ? BorderSide(color: Colors.white.withOpacity(0.1))
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          // ─── شعار / اسم المنشأة ─────────────────────────
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0071E3).withOpacity(0.2),
                    border: Border.all(
                        color: const Color(0xFF0071E3).withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.store,
                      size: 16, color: Color(0xFF0071E3)),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: Colors.white.withOpacity(0.1)),

          // ─── زر طي/فتح القائمة ──────────────────────────
          SizedBox(
            height: 40,
            child: InkWell(
              onTap: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              child: Icon(
                collapsed
                    ? (isArabic ? Icons.chevron_left : Icons.chevron_right)
                    : (isArabic ? Icons.chevron_right : Icons.chevron_left),
                color: Colors.white54,
                size: 16,
              ),
            ),
          ),

          Divider(height: 1, color: Colors.white.withOpacity(0.1)),

          // ─── عناصر التنقل ───────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (_, i) {
                final item = _navItems[i];
                final isParentSel = _isParentSelected(item);
                final isExpanded = _expandedGroups.contains(item.key);
                final hasChildren =
                    item.subItems != null && item.subItems!.isNotEmpty;

                if (hasChildren) {
                  return _buildExpandableItem(
                      item, isParentSel, isExpanded, collapsed, isArabic);
                } else {
                  return _SidebarItem(
                    icon: isParentSel ? item.activeIcon : item.icon,
                    label: isArabic ? item.arLabel : item.enLabel,
                    selected: isParentSel,
                    collapsed: collapsed,
                    onTap: () => _selectPage(item.key),
                  );
                }
              },
            ),
          ),

          Divider(height: 1, color: Colors.white.withOpacity(0.1)),

          // ─── زر تسجيل الخروج ────────────────────────────
          _SidebarItem(
            icon: Icons.logout,
            label: isArabic ? 'خروج' : 'Logout',
            selected: false,
            collapsed: collapsed,
            onTap: _logout,
            isDestructive: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── عنصر قابل للتوسيع ────────────────────────────────────
  Widget _buildExpandableItem(
    _NavItem item,
    bool isParentSelected,
    bool isExpanded,
    bool collapsed,
    bool isArabic,
  ) {
    // ─── وضع مصغّر ────────────────────────────────────────
    if (collapsed) {
      return Tooltip(
        message: isArabic ? item.arLabel : item.enLabel,
        preferBelow: false,
        child: PopupMenuButton<String>(
          offset: isArabic
              ? const Offset(-200, 0)
              : const Offset(64, 0),
          color: const Color(0xFF1D1D1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: const Color(0xFF0071E3).withOpacity(0.3)),
          ),
          onSelected: (key) => _selectPage(key),
          itemBuilder: (_) => item.subItems!.map((sub) {
            final isSubSel = _selectedPage == sub.key;
            return PopupMenuItem<String>(
              value: sub.key,
              height: 40,
              child: Row(
                children: [
                  Icon(sub.icon,
                      color: isSubSel
                          ? const Color(0xFF0071E3)
                          : Colors.white54,
                      size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? sub.arLabel : sub.enLabel,
                    style: TextStyle(
                      color: isSubSel
                          ? const Color(0xFF0071E3)
                          : Colors.white70,
                      fontWeight:
                          isSubSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: isParentSelected
                ? BoxDecoration(
                    color: const Color(0xFF0071E3).withOpacity(0.12),
                    border: Border(
                      right: Directionality.of(context) == TextDirection.rtl
                          ? const BorderSide(
                              color: Color(0xFF0071E3), width: 3)
                          : BorderSide.none,
                      left: Directionality.of(context) == TextDirection.ltr
                          ? const BorderSide(
                              color: Color(0xFF0071E3), width: 3)
                          : BorderSide.none,
                    ),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isParentSelected ? item.activeIcon : item.icon,
                  size: 22,
                  color: isParentSelected
                      ? const Color(0xFF0071E3)
                      : Colors.white54,
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down,
                    size: 12,
                    color: isParentSelected
                        ? const Color(0xFF0071E3)
                        : Colors.white38),
              ],
            ),
          ),
        ),
      );
    }

    // ─── وضع موسّع ────────────────────────────────────────
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // العنصر الأب
        InkWell(
          onTap: () {
            setState(() {
              if (_expandedGroups.contains(item.key)) {
                _expandedGroups.remove(item.key);
              } else {
                _expandedGroups.add(item.key);
              }
            });
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: isParentSelected
                ? BoxDecoration(
                    color: const Color(0xFF0071E3).withOpacity(0.08),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  isParentSelected ? item.activeIcon : item.icon,
                  size: 16,
                  color: isParentSelected
                      ? const Color(0xFF0071E3)
                      : Colors.white54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isArabic ? item.arLabel : item.enLabel,
                    style: TextStyle(
                      color: isParentSelected
                          ? const Color(0xFF0071E3)
                          : Colors.white60,
                      fontSize: 13,
                      fontWeight: isParentSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // عدد العناصر الفرعية
                if (!isExpanded)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.subItems!.length}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded
                      ? (isArabic ? -0.25 : 0.25)
                      : 0,
                  child: Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: isParentSelected
                        ? const Color(0xFF0071E3)
                        : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),

        // العناصر الفرعية
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: item.subItems!.map((sub) {
              final isSubSel = _selectedPage == sub.key;
              return InkWell(
                onTap: () => _selectPage(sub.key),
                onHover: (h) {},
                child: Container(
                  height: 40,
                  padding: EdgeInsets.only(
                    right: isArabic ? 44 : 14,
                    left: isArabic ? 14 : 44,
                  ),
                  decoration: isSubSel
                      ? BoxDecoration(
                          color: const Color(0xFF0071E3).withOpacity(0.12),
                          border: Border(
                            right: isArabic
                                ? const BorderSide(
                                    color: Color(0xFF0071E3), width: 3)
                                : BorderSide.none,
                            left: !isArabic
                                ? const BorderSide(
                                    color: Color(0xFF0071E3), width: 3)
                                : BorderSide.none,
                          ),
                        )
                      : null,
                  child: Row(
                    children: [
                      Icon(sub.icon,
                          size: 16,
                          color: isSubSel
                              ? const Color(0xFF0071E3)
                              : Colors.white38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isArabic ? sub.arLabel : sub.enLabel,
                          style: TextStyle(
                            color: isSubSel
                                ? const Color(0xFF0071E3)
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: isSubSel
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // مؤشر للسندات
                      if (sub.key == 'payment_bond')
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (sub.key == 'receipt_bond')
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      // مؤشر المخزون
                      if (sub.key == 'product_movement')
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
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
          body: Stack(children: [
            // ─── الخلفية ───────────────────────────────────
            Positioned.fill(
                child: Image.asset(
              'assets/images/ocean_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1D1D1F),
                      Color(0xFF003366),
                      Color(0xFF00509E)
                    ],
                  ),
                ),
              ),
            )),
            Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.25))),

            // ─── المحتوى الرئيسي ──────────────────────────
            if (_isPending)
              Positioned.fill(child: _buildPendingView())
            else
              Positioned.fill(
                child: Row(
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    // القائمة الجانبية
                    _buildSidebar(bName),
                    // محتوى الصفحة
                    Expanded(
                      child: Column(
                        textDirection:
                            isArabic ? TextDirection.rtl : TextDirection.ltr,
                        children: [
                          // ─── شريط علوي ──────────────────────
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              border: Border(
                                  bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.1))),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _currentPageIcon(),
                                  color: const Color(0xFF0071E3),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _currentPageLabel(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                          // ─── محتوى الصفحة ──────────────────
                          Expanded(child: _buildPageContent(_selectedPage)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ─── عنصر القائمة الجانبية (مستقل) ──────────────────────────
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovering = false;

  Color get _iconColor {
    if (widget.isDestructive) return Colors.redAccent;
    if (widget.selected) return const Color(0xFF0071E3);
    if (_hovering) return Colors.white;
    return Colors.white54;
  }

  Color get _labelColor {
    if (widget.isDestructive) return Colors.redAccent.withOpacity(0.9);
    if (widget.selected) return const Color(0xFF0071E3);
    if (_hovering) return Colors.white;
    return Colors.white60;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) {
      return Tooltip(
        message: widget.label,
        preferBelow: false,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hovering = h),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: widget.selected
                ? BoxDecoration(
                    color: const Color(0xFF0071E3).withOpacity(0.12),
                    border: Border(
                      right:
                          Directionality.of(context) == TextDirection.rtl
                              ? const BorderSide(
                                  color: Color(0xFF0071E3), width: 3)
                              : BorderSide.none,
                      left:
                          Directionality.of(context) == TextDirection.ltr
                              ? const BorderSide(
                                  color: Color(0xFF0071E3), width: 3)
                              : BorderSide.none,
                    ),
                  )
                : null,
            child: Icon(widget.icon, size: 22, color: _iconColor),
          ),
        ),
      );
    }

    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hovering = h),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: widget.selected
            ? BoxDecoration(
                color: const Color(0xFF0071E3).withOpacity(0.12),
                border: Border(
                  right: Directionality.of(context) == TextDirection.rtl
                      ? const BorderSide(
                          color: Color(0xFF0071E3), width: 3)
                      : BorderSide.none,
                  left: Directionality.of(context) == TextDirection.ltr
                      ? const BorderSide(
                          color: Color(0xFF0071E3), width: 3)
                      : BorderSide.none,
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(widget.icon, size: 16, color: _iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: _labelColor,
                  fontSize: 13,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
