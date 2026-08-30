import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';

class AdminVerificationTab extends StatefulWidget {
  const AdminVerificationTab({super.key});

  @override
  State<AdminVerificationTab> createState() => _AdminVerificationTabState();
}

class _AdminVerificationTabState extends State<AdminVerificationTab> {
  /// Parse a dynamic value into DateTime
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try { return DateTime.parse(value); } catch (_) { return null; }
    }
    return null;
  }

  Future<void> _approve(String docId, String userId, {required bool isCraftsman}) async {
    try {
      final collectionPath = isCraftsman ? '/api/users/$docId' : '/api/business/$docId';
      await ApiService.put(collectionPath, body: {'verificationStatus': 'approved'});
      await FirestoreService.updateUser(userId, {'verificationStatus': 'approved'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تمت الموافقة على الحساب'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشلت الموافقة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(String docId, String userId, {required bool isCraftsman}) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('رفض الحساب'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'سبب الرفض (اختياري)', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final collectionPath = isCraftsman ? '/api/users/$docId' : '/api/business/$docId';
      await ApiService.put(collectionPath, body: {
        'verificationStatus': 'rejected',
        'rejectionReason': reasonCtrl.text.trim(),
      });
      await FirestoreService.updateUser(userId, {'verificationStatus': 'rejected'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚫 تم رفض الحساب'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل الرفض: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _viewImage(String? url, String title) {
    if (url == null || url.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 100, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء بطاقة حرفي أو محل
  Widget _buildCard(Map<String, dynamic> data, String docId, {required bool isCraftsman}) {
    final userId = docId;
    final name = data['name'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final civilIdUrl = data['civilIdImage'] as String?;
    final licenseUrl = data['licenseImage'] as String?;
    final profileUrl = data['profileImage'] as String?;
    final createdAt = _parseDateTime(data['createdAt']);

    final title = isCraftsman
        ? (name.isNotEmpty ? name : 'فني')
        : (data['businessName'] as String? ?? 'محل');
    final subtitle = isCraftsman
        ? (data['job'] as String? ?? 'حرفي')
        : (data['businessType'] as String? ?? 'غير محدد');
    final icon = isCraftsman ? Icons.construction : Icons.store;

    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0071E3), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Text('قيد المراجعة', style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.person, isCraftsman ? 'الفني: $name' : 'المسؤول: $name'),
            _infoRow(Icons.phone, 'الهاتف: $phone'),
            _infoRow(Icons.info, isCraftsman ? 'المهنة: $subtitle' : 'النشاط: $subtitle'),
            if (createdAt != null)
              _infoRow(Icons.calendar_today, 'تاريخ التسجيل: ${createdAt.toString().substring(0, 10)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewImage(civilIdUrl, 'البطاقة المدنية'),
                    icon: const Icon(Icons.credit_card, color: Colors.white70),
                    label: const Text('البطاقة المدنية', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                if (isCraftsman && profileUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewImage(profileUrl, 'الصورة الشخصية'),
                      icon: const Icon(Icons.person, color: Colors.white70),
                      label: const Text('الصورة الشخصية', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (!isCraftsman && licenseUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewImage(licenseUrl, 'الرخصة التجارية'),
                      icon: const Icon(Icons.badge, color: Colors.white70),
                      label: const Text('الرخصة التجارية', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(docId, userId, isCraftsman: isCraftsman),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('موافقة', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reject(docId, userId, isCraftsman: isCraftsman),
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text('رفض', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white60),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  /// Polling stream for verification data
  Stream<List<Map<String, dynamic>>> _verificationStream(String role) async* {
    while (true) {
      try {
        final res = await ApiService.get('/api/users', queryParameters: {
          'role': role,
          'verificationStatus': 'submitted',
        });
        if (res.success && res.data != null) {
          final items = res.data!['users'] as List<dynamic>?;
          yield items?.cast<Map<String, dynamic>>() ?? [];
        } else {
          yield [];
        }
      } catch (_) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // قسم الحرفيين
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _verificationStream('craftsman'),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              children: snap.data!.map((d) {
                final docId = d['id'] as String? ?? '';
                return _buildCard(d, docId, isCraftsman: true);
              }).toList(),
            );
          },
        ),
        // قسم المحلات والشركات
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _verificationStream('business'),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              children: snap.data!.map((d) {
                final docId = d['id'] as String? ?? '';
                return _buildCard(d, docId, isCraftsman: false);
              }).toList(),
            );
          },
        ),
        // رسالة "لا توجد حسابات" إذا كان كلاهما فارغًا
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _verificationStream('craftsman'),
          builder: (_, snapCrafts) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _verificationStream('business'),
              builder: (_, snapBiz) {
                if (snapCrafts.connectionState == ConnectionState.waiting || snapBiz.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                final hasCraftsmen = snapCrafts.hasData && snapCrafts.data!.isNotEmpty;
                final hasBusinesses = snapBiz.hasData && snapBiz.data!.isNotEmpty;
                if (!hasCraftsmen && !hasBusinesses) {
                  return SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('لا توجد حسابات قيد المراجعة',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ],
    );
  }
}
