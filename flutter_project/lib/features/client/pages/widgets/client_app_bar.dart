import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';

class ClientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSignOut;
  final String uid;

  const ClientAppBar({super.key, required this.onSignOut, required this.uid});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: FutureBuilder<Map<String, dynamic>?>(
        future: FirestoreService.getUser(uid),
        builder: (context, snapshot) {
          final userName = snapshot.data?['name'] as String? ?? 'User';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('app_name'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('hello'.tr(args: [userName]),
                  style: const TextStyle(fontSize: 13)),
            ],
          );
        },
      ),
      backgroundColor: Colors.black.withOpacity(0.3),
      foregroundColor: Colors.white,
      actions: [
        StreamBuilder<int>(
          stream: NotificationService.unreadCountStream(uid),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text('$unreadCount', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.language),
          onPressed: () {
            final newLocale = context.locale == const Locale('ar') ? const Locale('en') : const Locale('ar');
            context.setLocale(newLocale);
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: onSignOut,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
