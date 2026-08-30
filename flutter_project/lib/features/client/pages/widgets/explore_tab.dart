import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/services_data.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../requests/pages/service_detail_page.dart';
import '../store_front_page.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});
  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late TabController _tabController;

  String? _selectedShopCategory;
  String? _selectedCompanyCategory;

  static const List<Color> _iconColors = [
    Color(0xFF1976D2), Color(0xFF0D47A1), Color(0xFF0288D1), Color(0xFF1565C0),
    Color(0xFF42A5F5), Color(0xFF1E88E5), Color(0xFF546E7A), Color(0xFF00838F),
    Color(0xFF00695C), Color(0xFF283593), Color(0xFF4527A0),
  ];

  List<Map<String, dynamic>> _businesses = [];
  bool _loadingBusinesses = true;
  Stream<List<Map<String, dynamic>>>? _businessStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBusinesses();
    _startBusinessPolling();
  }

  Future<void> _loadBusinesses() async {
    try {
      final res = await FirestoreService.getProducts();
      if (mounted) {
        setState(() {
          _businesses = res;
          _loadingBusinesses = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBusinesses = false);
    }
  }

  void _startBusinessPolling() {
    _businessStream = _businessPollingStream();
  }

  Stream<List<Map<String, dynamic>>> _businessPollingStream() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 10));
      try {
        final businesses = await FirestoreService.getProducts();
        yield businesses;
      } catch (_) {
        yield _businesses;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // دالة إرجاع أيقونة مناسبة لكل فئة (يمكنك تعديلها حسب ذوقك)
  IconData _iconForCategory(String category) {
    switch (category) {
      case 'محلات أدوات كهربائية':
        return Icons.electrical_services;
      case 'أدوات صحية':
        return Icons.plumbing;
      case 'محلات سيراميك ورخام':
        return Icons.carpenter;
      case 'مواد بناء':
        return Icons.construction;
      case 'محلات معدات كهربائية':
        return Icons.power;
      case 'تأجير معدات ومولدات':
        return Icons.hardware;
      case 'محلات أصباغ':
        return Icons.format_paint;
      case 'محلات ديكورات':
        return Icons.design_services;
      case 'محلات أحواض سباحة':
        return Icons.pool;
      case 'متجر':
        return Icons.store;
      case 'شركات تشطيب':
        return Icons.home_repair_service;
      case 'شركات مقاولات وترميمات':
        return Icons.engineering;
      case 'شركة':
        return Icons.business;
      case 'مكتب':
        return Icons.business_center;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // شريط التبويبات الرئيسي (خدمات، محلات، شركات)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            tabs: const [
              Tab(icon: Icon(Icons.build, size: 22), text: 'خدمات'),
              Tab(icon: Icon(Icons.store, size: 22), text: 'محلات'),
              Tab(icon: Icon(Icons.business, size: 22), text: 'شركات'),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServicesTab(),
                _buildBusinessesTab(
                  categoryList: kShopCategories,
                  selectedCategory: _selectedShopCategory,
                  onCategorySelected: (cat) =>
                      setState(() => _selectedShopCategory = cat),
                  emptyMessage: 'لا توجد محلات',
                  icon: Icons.store,
                  color: Colors.teal,
                ),
                _buildBusinessesTab(
                  categoryList: kCompanyCategories,
                  selectedCategory: _selectedCompanyCategory,
                  onCategorySelected: (cat) =>
                      setState(() => _selectedCompanyCategory = cat),
                  emptyMessage: 'لا توجد شركات',
                  icon: Icons.business,
                  color: Colors.indigo,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────── تبويب الخدمات (دون تغيير) ──────────────
  Widget _buildServicesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 3;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.75,
          ),
          itemCount: kServices.length,
          itemBuilder: (_, i) => _ServiceIcon(
            service: kServices[i],
            color: _iconColors[i % _iconColors.length],
          ),
        );
      },
    );
  }

  // ────────── تبويب المحلات / الشركات (مع شريط أيقونات) ──────────
  Widget _buildBusinessesTab({
    required List<String> categoryList,
    required String? selectedCategory,
    required ValueChanged<String?> onCategorySelected,
    required String emptyMessage,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        // شريط أيقونات الفئات
        Container(
          height: 90, // ارتفاع مناسب للأيقونة + النص
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categoryList.length,
            itemBuilder: (_, i) {
              final cat = categoryList[i];
              final isSelected = selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  onCategorySelected(isSelected ? null : cat);
                },
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0071E3).withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0071E3)
                                : Colors.white.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          _iconForCategory(cat),
                          size: 28,
                          color: isSelected
                              ? const Color(0xFF0071E3)
                              : Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? const Color(0xFF0071E3) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // قائمة المحلات / الشركات
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _businessStream,
            initialData: _businesses,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _loadingBusinesses) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0071E3)),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('تعذر تحميل البيانات',
                      style: TextStyle(color: Colors.white.withOpacity(0.7))),
                );
              }

              var docs = snapshot.data ?? _businesses;
              if (docs.isEmpty) {
                return Center(
                  child: Text(emptyMessage,
                      style: TextStyle(color: Colors.white.withOpacity(0.7))),
                );
              }

              docs = docs.where((doc) {
                final businessType = doc['businessType'] as String? ?? '';
                return businessType.isNotEmpty;
              }).toList();

              if (selectedCategory != null) {
                docs = docs.where((doc) {
                  return doc['businessType'] == selectedCategory;
                }).toList();
              } else {
                docs = docs.where((doc) {
                  return categoryList.contains(doc['businessType']);
                }).toList();
              }

              docs.sort((a, b) {
                final nameA = (a['businessName'] ?? '') as String;
                final nameB = (b['businessName'] ?? '') as String;
                return nameA.compareTo(nameB);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    selectedCategory != null
                        ? 'لا توجد منشآت في هذه الفئة'
                        : emptyMessage,
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i];
                  final docId = data['id'] as String? ?? data['businessId'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BusinessCard(
                      data: data,
                      docId: docId,
                      icon: icon,
                      color: color,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ────────────── بطاقة المنشأة (بدون تغيير) ──────────────
class _BusinessCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final IconData icon;
  final Color color;
  const _BusinessCard({
    required this.data,
    required this.docId,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['businessName'] as String? ?? '';
    final governorate = data['governorate'] as String? ?? '';
    final phone = data['phone'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoreFrontPage(
            businessId: docId,
            businessName: name,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.3),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      governorate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0071E3),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────── أيقونة الخدمة (بدون تغيير) ──────────────
class _ServiceIcon extends StatelessWidget {
  final ServiceModel service;
  final Color color;
  const _ServiceIcon({required this.service, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceDetailPage(service: service),
        ),
      ),
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
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Icon(service.icon, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            service.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
