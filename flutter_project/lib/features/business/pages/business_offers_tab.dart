import 'dart:ui' as ui;
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../shared/widgets/paginated_list.dart';
import 'business_dialogs.dart';

class BusinessOffersTab extends StatefulWidget {
  final String uid;
  const BusinessOffersTab({super.key, required this.uid});

  @override
  State<BusinessOffersTab> createState() => _BusinessOffersTabState();
}

class _BusinessOffersTabState extends State<BusinessOffersTab>
    with AutomaticKeepAliveClientMixin {
  late final _uid = widget.uid;

  // Offers data
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/offers', queryParameters: {'businessId': _uid});
      List<Map<String, dynamic>> offersList = [];
      if (res.success && res.data != null) {
        final list = res.data!['offers'] ?? res.data!['data'];
        if (list is List) offersList = list.cast<Map<String, dynamic>>();
      }

      // Sort by date (newest first)
      offersList.sort((a, b) {
        final aTime = _parseTimestamp(a['createdAt']);
        final bTime = _parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _offers = offersList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: const Color(0xFF0071E3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addOffer() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => buildGlassDialog(
        title: 'إضافة عرض',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          glassField(titleCtrl, 'عنوان العرض', Icons.title),
          const SizedBox(height: 10),
          glassField(descCtrl, 'تفاصيل العرض', Icons.description, maxLines: 3),
        ]),
        confirmText: 'نشر',
        cancelText: 'إلغاء',
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (ok != true || titleCtrl.text.isEmpty) return;
    try {
      await ApiService.post('/api/offers', body: {
        'businessId': _uid,
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
        'active': true,
      });
      _snack('✅ تم نشر العرض');
      _loadOffers();
    } catch (e) {
      _snack('خطأ: $e');
    }
  }

  Future<void> _editOffer(Map<String, dynamic> offer) async {
    final titleCtrl = TextEditingController(text: offer['title'] ?? '');
    final descCtrl = TextEditingController(text: offer['description'] ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => buildGlassDialog(
        title: 'تعديل عرض',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          glassField(titleCtrl, 'عنوان العرض', Icons.title),
          const SizedBox(height: 10),
          glassField(descCtrl, 'تفاصيل العرض', Icons.description, maxLines: 3),
        ]),
        confirmText: 'حفظ',
        cancelText: 'إلغاء',
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (ok != true) return;
    try {
      await ApiService.put('/api/offers/${offer['id']}', body: {
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
      });
      _snack('✅ تم تعديل العرض');
      _loadOffers();
    } catch (e) {
      _snack('خطأ: $e');
    }
  }

  Future<void> _deleteOffer(Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا العرض؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.delete('/api/offers/${offer['id']}');
        _snack('🗑️ تم حذف العرض');
        _loadOffers();
      } catch (e) {
        _snack('خطأ: $e');
      }
    }
  }

  Future<void> _toggleOfferActive(Map<String, dynamic> offer, bool value) async {
    try {
      await ApiService.put('/api/offers/${offer['id']}', body: {'active': value});
      _loadOffers();
    } catch (e) {
      _snack('خطأ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    return Scaffold(
      body: _offers.isEmpty
          ? Center(
              child: Text('لا توجد عروض بعد',
                  style: TextStyle(color: Colors.white.withOpacity(0.8))),
            )
          : PaginatedApiList(
              fetcher: ({required int page, required int pageSize}) async {
                // We already have all offers loaded, return paginated slice
                final start = page * pageSize;
                if (start >= _offers.length) return [];
                final end = (start + pageSize).clamp(0, _offers.length);
                return _offers.sublist(start, end);
              },
              pageSize: 15,
              emptyWidget: Center(
                child: Text('لا توجد عروض بعد',
                    style: TextStyle(color: Colors.white.withOpacity(0.8))),
              ),
              itemBuilder: (ctx, data, _) {
                final title = data['title'] ?? '';
                final description = data['description'] ?? '';
                final active = data['active'] as bool? ?? true;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF0071E3).withOpacity(0.2),
                            child: const Icon(Icons.local_offer,
                                color: Color(0xFF0071E3)),
                          ),
                          title: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          subtitle: Text(description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: active,
                                activeColor: const Color(0xFF0071E3),
                                onChanged: (v) => _toggleOfferActive(data, v),
                              ),
                              IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white70, size: 20),
                                  onPressed: () => _editOffer(data)),
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteOffer(data)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOffer,
        backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
        foregroundColor: const Color(0xFF1D1D1F),
        icon: const Icon(Icons.add),
        label: const Text('عرض جديد'),
      ),
    );
  }
}
