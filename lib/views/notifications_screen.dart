import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../core/dates.dart';
import '../models/models.dart';
import '../viewmodels/notifications_view_model.dart';
import 'widgets/common.dart';

/// S12 Thông báo. Màn thêm cho Lab 3 để lưu lịch sử FCM trong app.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsViewModel>().reload();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    return Scaffold(
      appBar: const BackAppBar(title: 'Thông báo'),
      body: PageList(
        children: [
          if (vm.permissionMissing) ...[
            StatusBanner(
              key: const Key('notification-permission'),
              kind: BannerKind.info,
              message: 'Thông báo đang tắt',
              detail:
                  'Bạn vẫn dùng được app, nhưng sẽ không nhận được nhắc nhở. Nếu không thấy hộp thoại xin quyền, hãy bật trong Cài đặt của thiết bị.',
              actions: [
                TextButton(
                  key: const Key('notification-request'),
                  onPressed: vm.requestPermission,
                  child: const Text('Bật thông báo'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
          ],
          if (vm.items.isEmpty)
            const SizedBox(
              height: 300,
              child: MessageView(
                icon: Icons.notifications_none,
                title: 'Chưa có thông báo nào',
                body: 'Thông báo bạn nhận được sẽ được lưu lại ở đây.',
              ),
            )
          else
            for (final item in vm.items) ...[
              _NotificationCard(
                item: item,
                onTap: () => vm.open(item.id, source: 'history'),
              ),
              const SizedBox(height: AppSpace.md),
            ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('notification-${item.id}'),
      onTap: onTap,
      borderColor: item.read ? null : AppColors.primary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(Icons.notifications_outlined),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.title, style: AppText.label)),
                    if (!item.read) const Pill('Mới'),
                  ],
                ),
                if (item.body.isNotEmpty) Text(item.body, style: AppText.body),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${formatTime(item.receivedAt)} · ${formatDate(item.receivedAt)}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
