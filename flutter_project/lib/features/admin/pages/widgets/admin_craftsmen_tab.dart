import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../shared/widgets/paginated_list.dart';

class AdminCraftsmenTab extends StatelessWidget {
  const AdminCraftsmenTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PaginatedApiList(
      fetcher: ({required int page, required int pageSize}) => FirestoreService.getCraftsmen(),
      pageSize: 20,
      emptyWidget: Center(
        child: Text('no_craftsmen'.tr(), style: const TextStyle(color: Colors.white70)),
      ),
      itemBuilder: (ctx, d, _) {
        final isAvail = d['isAvailable'] as bool? ?? false;
        final docId = d['id'] as String? ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAvail ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Icon(Icons.person, color: isAvail ? Colors.green : Colors.red),
                  ),
                  title: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(
                    '${d['job'] ?? ''} | ${d['governorate'] ?? ''} | ⭐${d['rating'] ?? ''} | ${d['totalJobs'] ?? 0} ${'jobs'.tr()}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  trailing: Switch(
                    value: isAvail,
                    activeColor: const Color(0xFF0071E3),
                    onChanged: (v) => ApiService.put('/api/users/$docId', body: {'isAvailable': v}),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
