import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../viewmodels/report_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'widgets/common.dart';

Future<void> showReportSheet(BuildContext context) {
  final services = context.read<AppServices>();
  final uid = context.read<SessionViewModel>().uid!;
  return showModalBottomSheet<void>(
    context: context,
    // Che cả thanh tab để không chuyển màn được khi đang tải lên.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => ReportViewModel(services, uid),
      child: const _ReportSheet(),
    ),
  );
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    return PopScope(
      canPop: !vm.isBusy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: pageMargin(context)).add(
            const EdgeInsets.only(bottom: AppSpace.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Xuất báo cáo PDF', style: AppText.heading),
              const SizedBox(height: AppSpace.xs),
              const Text(
                'Tổng hợp bữa ăn trong 7 ngày gần nhất và lưu vào không gian riêng của tài khoản trên Cloudinary.',
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpace.lg),
              ..._body(context, vm),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, ReportViewModel vm) {
    return switch (vm.phase) {
      ReportPhase.idle => [
        FilledButton(
          key: const Key('report-start'),
          onPressed: vm.export,
          child: const Text('Tạo và tải lên'),
        ),
      ],
      ReportPhase.building => const [
        LinearProgressIndicator(),
        SizedBox(height: AppSpace.sm),
        Text('Đang tạo tệp PDF…', style: AppText.label),
      ],
      ReportPhase.uploading => [
        LinearProgressIndicator(value: vm.progress),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Đang tải lên ${(vm.progress * 100).round()}%',
          key: const Key('report-progress'),
          style: AppText.label,
        ),
      ],
      ReportPhase.success => [
        StatusBanner(
          key: const Key('report-success'),
          kind: BannerKind.success,
          message: 'Đã tải báo cáo lên (${vm.mealCount} bữa).',
        ),
        const SizedBox(height: AppSpace.md),
        SelectableText(vm.url!, style: AppText.caption),
        const SizedBox(height: AppSpace.md),
        FilledButton(
          onPressed: vm.openReport,
          child: const Text('Mở báo cáo'),
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: vm.url!));
            vm.showNotice('Đã sao chép đường dẫn.');
          },
          child: const Text('Sao chép đường dẫn'),
        ),
        // Hiện ngay trong sheet vì SnackBar sẽ nằm khuất phía sau sheet.
        if (vm.notice != null) ...[
          const SizedBox(height: AppSpace.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              vm.notice!,
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
      ReportPhase.failure => [
        StatusBanner(
          key: const Key('report-failure'),
          kind: BannerKind.error,
          message: vm.errorMessage!,
        ),
        const SizedBox(height: AppSpace.md),
        FilledButton(
          key: const Key('report-retry'),
          onPressed: vm.export,
          child: const Text('Thử lại'),
        ),
      ],
    };
  }
}
