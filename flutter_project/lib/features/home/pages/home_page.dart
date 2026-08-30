import 'dart:async';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/services_data.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/api_service.dart';
import '../../auth/pages/auth_page.dart';
import '../../shared/ai/ai_assistant_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedShopType;
  String? _selectedCompanyType;

  static const List<Color> _iconColors = [
    Color(0xFF1976D2),
    Color(0xFF0D47A1),
    Color(0xFF0288D1),
    Color(0xFF1565C0),
    Color(0xFF42A5F5),
    Color(0xFF1E88E5),
    Color(0xFF546E7A),
    Color(0xFF00838F),
    Color(0xFF00695C),
    Color(0xFF283593),
    Color(0xFF4527A0),
  ];

  static const Map<String, IconData> _shopIcons = {
    'محلات أدوات كهربائية': Icons.bolt,
    'أدوات صحية': Icons.plumbing,
    'محلات سيراميك ورخام': Icons.diamond,
    'مواد بناء': Icons.construction,
    'محلات معدات كهربائية': Icons.cable,
    'تأجير معدات ومولدات': Icons.build_circle,
    'محلات أصباغ': Icons.format_paint,
    'محلات ديكورات': Icons.chair,
    'محلات أحواض سباحة': Icons.pool,
    'متجر': Icons.store,
  };

  static const Map<String, IconData> _companyIcons = {
    'شركات تشطيب': Icons.handyman,
    'شركات مقاولات وترميمات': Icons.construction,
    'شركة': Icons.business,
    'مكتب': Icons.work,
  };

  /// Polling stream for businesses
  Stream<List<Map<String, dynamic>>> _businessesStream() async* {
    while (true) {
      try {
        final res = await FirestoreService.getProducts(); // businesses use same pattern
        // Use direct API call for businesses since FirestoreService.getProducts is for products
        // We'll fetch businesses via ApiService
        yield []; // placeholder — will be replaced by actual businesses fetch below
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 15));
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    final kuwaitFlagTitle = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF007A3D),
          Color(0xFFFFFFFF),
          Color(0xFFCE1126),
          Color(0xFF000000),
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
      ).createShader(bounds),
      child: Text(
        'app_name'.tr(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ocean_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: isDesktop ? 160 : 140,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                title: kuwaitFlagTitle,
                centerTitle: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Column(
                            children: [
                              Container(
                                width: 44,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.9),
                                      width: 1.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.handyman,
                                    size: 22, color: Color(0xFF0D47A1)),
                              ),
                              const SizedBox(height: 2),
                              Transform.flip(
                                flipY: true,
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white70,
                                      Colors.transparent
                                    ],
                                  ).createShader(bounds),
                                  child: Container(
                                    width: 44,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.handyman,
                                        size: 22, color: Color(0xFF0D47A1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.language, color: Colors.white),
                    tooltip: 'language'.tr(),
                    onPressed: () {
                      final newLocale = context.locale == const Locale('ar')
                          ? const Locale('en')
                          : const Locale('ar');
                      context.setLocale(newLocale);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ElevatedButton.icon(
                      onPressed: _goToAuth,
                      icon: const Icon(Icons.login, size: 14),
                      label: Text('login_register'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0071E3),
                        foregroundColor: const Color(0xFF1D1D1F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF0071E3),
                      unselectedLabelColor: Colors.white70,
                      indicator: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.build, size: 20),
                          text: 'services_tab'.tr(),
                        ),
                        Tab(
                          icon: const Icon(Icons.store, size: 20),
                          text: 'محلات',
                        ),
                        Tab(
                          icon: const Icon(Icons.business, size: 20),
                          text: 'شركات',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildServicesTab(context),
                  _buildShopsTab(context),
                  _buildCompaniesTab(context),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AiAssistantPage())),
        icon: const Icon(Icons.auto_awesome, color: Color(0xFF1D1D1F)),
        label: Text('ai_assistant'.tr(),
            style: const TextStyle(
                color: Color(0xFF1D1D1F), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0071E3),
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return 6;
    if (width >= 600) return 4;
    return 3;
  }

  Widget _buildServicesTab(BuildContext context) {
    final crossAxisCount = _getCrossAxisCount(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF0071E3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text('featured_services'.tr(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.75,
          ),
          itemCount: kServices.length,
          itemBuilder: (_, i) => _buildServiceIcon(
              service: kServices[i],
              color: _iconColors[i % _iconColors.length]),
        ),
        const SizedBox(height: 32),
        _buildCraftsmanBanner(context),
      ],
    );
  }

  Widget _buildServiceIcon({required ServiceModel service, required Color color}) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _goToAuth,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 8)),
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 4)),
              ],
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(service.icon,
                size: 32,
                color: Colors.white,
                shadows: [
                  Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(1, 2))
                ]),
          ),
          const SizedBox(height: 10),
          Text(service.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _buildShopsTab(BuildContext context) {
    return _buildCategoryTab(
      context: context,
      categories: kShopCategories,
      categoryIcons: _shopIcons,
      selectedCategory: _selectedShopType,
      onCategorySelected: (type) {
        setState(() {
          _selectedShopType = (_selectedShopType == type) ? null : type;
        });
      },
    );
  }

  Widget _buildCompaniesTab(BuildContext context) {
    return _buildCategoryTab(
      context: context,
      categories: kCompanyCategories,
      categoryIcons: _companyIcons,
      selectedCategory: _selectedCompanyType,
      onCategorySelected: (type) {
        setState(() {
          _selectedCompanyType = (_selectedCompanyType == type) ? null : type;
        });
      },
    );
  }

  Widget _buildCategoryTab({
    required BuildContext context,
    required List<String> categories,
    required Map<String, IconData> categoryIcons,
    required String? selectedCategory,
    required void Function(String) onCategorySelected,
  }) {
    final crossAxisCount = _getCrossAxisCount(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.75,
          ),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final type = categories[i];
            final icon = categoryIcons[type] ?? Icons.store;
            final color = _iconColors[i % _iconColors.length];
            final isSelected = selectedCategory == type;
            return _buildCategoryIcon(
              label: type,
              icon: icon,
              color: color,
              isSelected: isSelected,
              onTap: () => onCategorySelected(type),
            );
          },
        ),
        const SizedBox(height: 24),
        _BusinessesList(
          selectedCategory: selectedCategory,
          categoryIcons: categoryIcons,
          iconColors: _iconColors,
          crossAxisCount: crossAxisCount,
          onGoToAuth: _goToAuth,
        ),
      ],
    );
  }

  Widget _buildCategoryIcon({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF0071E3).withOpacity(0.8),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: Offset.zero,
                  ),
              ],
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0071E3)
                    : Colors.white.withOpacity(0.3),
                width: isSelected ? 2.5 : 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 32,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(1, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? const Color(0xFF0071E3) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> d) {
    final businessType = d['businessType'] as String? ?? '';
    final icon = _shopIcons[businessType] ?? _companyIcons[businessType] ?? Icons.store;
    final colorIndex = kShopCategories.contains(businessType)
        ? kShopCategories.indexOf(businessType)
        : kCompanyCategories.indexOf(businessType);
    final Color baseColor = colorIndex >= 0
        ? _iconColors[colorIndex % _iconColors.length]
        : Colors.teal;

    return Card(
      color: Colors.white.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _goToAuth,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [baseColor, baseColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: baseColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(d['businessName'] ?? d['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(d['governorate'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
              const SizedBox(height: 4),
              if (d['phone'] != null)
                Text('${d['phone']}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0071E3))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCraftsmanBanner(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.engineering_rounded,
                      size: 40, color: Color(0xFF0071E3)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('are_you_craftsman'.tr(),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('join_platform_message'.tr(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _goToAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0071E3),
                    foregroundColor: const Color(0xFF1D1D1F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                  ),
                  child: Text('join_us'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.engineering_rounded,
                      size: 40, color: Color(0xFF0071E3)),
                ),
                const SizedBox(height: 16),
                Text('are_you_craftsman'.tr(),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('join_platform_message'.tr(),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _goToAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0071E3),
                    foregroundColor: const Color(0xFF1D1D1F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 6),
                  ),
                  child: Text('join_us'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
    );
  }
}

/// Separate stateful widget for the businesses list with polling
class _BusinessesList extends StatefulWidget {
  final String? selectedCategory;
  final Map<String, IconData> categoryIcons;
  final List<Color> iconColors;
  final int crossAxisCount;
  final VoidCallback onGoToAuth;

  const _BusinessesList({
    required this.selectedCategory,
    required this.categoryIcons,
    required this.iconColors,
    required this.crossAxisCount,
    required this.onGoToAuth,
  });

  @override
  State<_BusinessesList> createState() => _BusinessesListState();
}

class _BusinessesListState extends State<_BusinessesList> {
  List<Map<String, dynamic>> _businesses = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadBusinesses());
  }

  @override
  void didUpdateWidget(covariant _BusinessesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _loadBusinesses();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    try {
      final res = await FirestoreService.getCraftsmen(); // Fetches businesses
      // Use direct API call for businesses
      final apiRes = await ApiService.get('/api/business');
      if (apiRes.success && apiRes.data != null) {
        final list = apiRes.data!['businesses'] ?? apiRes.data!['data'] ?? [];
        if (list is List && mounted) {
          setState(() {
            _businesses = list.cast<Map<String, dynamic>>();
            _loading = false;
            _error = null;
          });
        }
      } else if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _businesses = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }
    if (_error != null) {
      return Center(child: Text('تعذر تحميل البيانات', style: TextStyle(color: Colors.red.shade300)));
    }
    if (_businesses.isEmpty) {
      return Center(child: Text('no_businesses_registered'.tr(), style: const TextStyle(color: Colors.white70)));
    }

    final filtered = _businesses.where((doc) {
      if (widget.selectedCategory == null) return true;
      final businessType = doc['businessType'] as String? ?? '';
      return businessType == widget.selectedCategory;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text('لا توجد نتائج', style: const TextStyle(color: Colors.white70)),
      ));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final d = filtered[i];
        return _buildBusinessCard(d);
      },
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> d) {
    final businessType = d['businessType'] as String? ?? '';
    final icon = widget.categoryIcons[businessType] ?? Icons.store;
    final colorIndex = kShopCategories.contains(businessType)
        ? kShopCategories.indexOf(businessType)
        : kCompanyCategories.indexOf(businessType);
    final Color baseColor = colorIndex >= 0
        ? widget.iconColors[colorIndex % widget.iconColors.length]
        : Colors.teal;

    return Card(
      color: Colors.white.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onGoToAuth,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [baseColor, baseColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: baseColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(d['businessName'] ?? d['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(d['governorate'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
              const SizedBox(height: 4),
              if (d['phone'] != null)
                Text('${d['phone']}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0071E3))),
            ],
          ),
        ),
      ),
    );
  }
}
