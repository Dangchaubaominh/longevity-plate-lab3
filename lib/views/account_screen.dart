import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../services/app_failure.dart';
import '../viewmodels/account_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'widgets/common.dart';

/// S11 Tài khoản và Khu vực trình diễn. Màn thêm cho Lab 3.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccountViewModel(
        context.read<AppServices>(),
        context.read<SessionViewModel>().uid!,
      ),
      child: const _AccountView(),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AccountViewModel>();
    final session = context.watch<SessionViewModel>();
    return Scaffold(
      appBar: const BackAppBar(title: 'Tài khoản'),
      body: PageList(
        children: [
          AppCard(
            child: Row(
              children: [
                const IconTile(Icons.person_outline),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.user?.displayName ?? 'Người dùng',
                        style: AppText.label,
                      ),
                      if (session.user?.email != null)
                        Text(session.user!.email!, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          const Text('Mục tiêu của bạn', style: AppText.heading),
          const SizedBox(height: AppSpace.sm),
          for (final goal in vm.goals)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Text('• ${goal.label}', style: AppText.body),
            ),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(
            key: const Key('account-edit-goals'),
            onPressed: () async {
              await context.push('/goals?edit=true');
              vm.reloadGoals();
            },
            child: const Text('Đổi mục tiêu'),
          ),
          const SizedBox(height: AppSpace.md),
          if (session.message != null) ...[
            StatusBanner(kind: BannerKind.error, message: session.message!),
            const SizedBox(height: AppSpace.md),
          ],
          OutlinedButton.icon(
            key: const Key('account-sign-out'),
            onPressed: session.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
          const SizedBox(height: AppSpace.xl),
          const _DemoArea(),
        ],
      ),
    );
  }
}

class _DemoArea extends StatelessWidget {
  const _DemoArea();

  Future<void> _confirmCrash(BuildContext context, AccountViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gây crash thử nghiệm?'),
        content: const Text(
          'App sẽ đóng ngay để Crashlytics ghi nhận. Mở lại app để báo cáo được gửi lên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            key: const Key('crash-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gây crash'),
          ),
        ],
      ),
    );
    if (confirmed == true) vm.testCrash();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AccountViewModel>();
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('demo-area'),
        title: const Text('Khu vực trình diễn', style: AppText.label),
        subtitle: const Text(
          'Chỉ dùng để kiểm thử Lab 3. Các lỗi ở đây là giả lập.',
          style: AppText.caption,
        ),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vm.isFake)
            const StatusBanner(
              kind: BannerKind.info,
              message: 'Đang chạy bằng dịch vụ giả lập, không kết nối Firebase.',
            ),
          const _DemoHeading('Giả lập lỗi (xảy ra một lần)'),
          for (final point in FaultPoint.values)
            SwitchListTile(
              key: Key('fault-${point.name}'),
              contentPadding: EdgeInsets.zero,
              title: Text(point.label, style: AppText.caption),
              value: vm.isArmed(point),
              onChanged: (armed) => vm.setFault(point, armed),
            ),
          const _DemoHeading('Remote Config'),
          Text(
            'max_knowledge_results = ${vm.maxKnowledgeResults}',
            key: const Key('rc-max-results'),
            style: AppText.body,
          ),
          Text(
            'suggested_recipes_enabled = ${vm.suggestedRecipesEnabled}',
            style: AppText.body,
          ),
          Text(vm.configStatus, style: AppText.caption),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(
            key: const Key('rc-refresh'),
            onPressed: vm.refreshingConfig ? null : vm.refreshConfig,
            child: Text(
              vm.refreshingConfig ? 'Đang tải…' : 'Tải lại cấu hình',
            ),
          ),
          const _DemoHeading('Cloud Messaging'),
          SelectableText(vm.token ?? 'Chưa có token.', style: AppText.caption),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(
            onPressed: vm.token == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: vm.token!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép token.')),
                    );
                  },
            child: const Text('Sao chép token'),
          ),
          const _DemoHeading('Cloud Storage'),
          OutlinedButton(
            key: const Key('storage-probe'),
            onPressed: vm.probing ? null : vm.probeForeignReport,
            child: Text(
              vm.probing ? 'Đang thử…' : 'Thử đọc báo cáo của UID khác',
            ),
          ),
          if (vm.probeResult != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              vm.probeResult!,
              key: const Key('storage-probe-result'),
              style: AppText.caption,
            ),
          ],
          const _DemoHeading('Crashlytics'),
          OutlinedButton(
            key: const Key('crash-non-fatal'),
            onPressed: vm.sendNonFatal,
            child: const Text('Ghi lỗi non-fatal'),
          ),
          if (vm.nonFatalMessage != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(vm.nonFatalMessage!, style: AppText.caption),
          ],
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(
            key: const Key('crash-test'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            onPressed: () => _confirmCrash(context, vm),
            child: const Text('Gây crash thử nghiệm'),
          ),
        ],
      ),
    );
  }
}

class _DemoHeading extends StatelessWidget {
  const _DemoHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.sm),
      child: Text(text, style: AppText.label),
    );
  }
}
