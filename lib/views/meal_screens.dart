import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../viewmodels/add_meal_view_model.dart';
import '../viewmodels/meal_log_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'report_sheet.dart';
import 'widgets/common.dart';

/// S04 Nhật ký bữa ăn.
class MealLogScreen extends StatelessWidget {
  const MealLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MealLogViewModel(
        context.read<AppServices>(),
        context.read<SessionViewModel>().uid!,
      ),
      child: const _MealLogView(),
    );
  }
}

class _MealLogView extends StatefulWidget {
  const _MealLogView();

  @override
  State<_MealLogView> createState() => _MealLogViewState();
}

class _MealLogViewState extends State<_MealLogView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _add(MealLogViewModel vm) async {
    vm.logAddStart();
    final saved = await context.push<bool>(
      '/log/add?date=${dateKey(vm.date)}',
    );
    if (saved != true) return;
    vm.markSaved();
    // Banner nằm đầu danh sách, nhật ký dài thì phải cuộn lên mới thấy.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealLogViewModel>();
    return Scaffold(
      appBar: const RootAppBar(),
      body: PageList(
        controller: _scroll,
        children: [
          const Text('Nhật ký bữa ăn', style: AppText.title),
          const SizedBox(height: AppSpace.md),
          _DatePager(vm: vm),
          const SizedBox(height: AppSpace.lg),
          if (vm.showSaved) ...[
            const StatusBanner(
              key: Key('meal-saved'),
              kind: BannerKind.success,
              message: 'Đã lưu bữa ăn',
            ),
            const SizedBox(height: AppSpace.lg),
          ],
          ..._content(vm),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            key: const Key('log-add-meal'),
            onPressed: () => _add(vm),
            child: const Text('Thêm bữa ăn'),
          ),
          const SizedBox(height: AppSpace.md),
          OutlinedButton.icon(
            key: const Key('log-export'),
            onPressed: () => showReportSheet(context),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Xuất báo cáo PDF'),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(MealLogViewModel vm) => switch (vm.state) {
    LoadState.loading => const [
      SizedBox(height: 200, child: LoadingView('Đang tải nhật ký…')),
    ],
    LoadState.error => [
      SizedBox(
        height: 260,
        child: ErrorView(
          title: 'Chưa tải được nhật ký.',
          body: 'Kết nối có thể bị gián đoạn. Bạn có thể thử lại.',
          onRetry: vm.load,
        ),
      ),
    ],
    LoadState.empty => const [
      SizedBox(
        height: 220,
        child: MessageView(
          icon: Icons.restaurant_menu,
          title: 'Chưa có bữa ăn nào',
          body: 'Ghi nhận bữa ăn để theo dõi nhịp điệu nuôi dưỡng trong ngày.',
        ),
      ),
    ],
    LoadState.ready => [
      Row(
        children: [
          Expanded(
            child: Text(
              '${vm.dayLabel} đã ghi ${vm.meals.length} bữa',
              style: AppText.heading,
            ),
          ),
          Text('${vm.meals.length} món ăn', style: AppText.caption),
        ],
      ),
      const SizedBox(height: AppSpace.md),
      for (final meal in vm.meals) ...[
        _MealCard(meal: meal),
        const SizedBox(height: AppSpace.md),
      ],
    ],
  };
}

class _DatePager extends StatelessWidget {
  const _DatePager({required this.vm});

  final MealLogViewModel vm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          IconButton(
            key: const Key('log-prev-day'),
            tooltip: 'Ngày trước',
            onPressed: vm.previousDay,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(vm.dayLabel, style: AppText.label),
                Text(
                  formatLong(vm.date),
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('log-next-day'),
            tooltip: 'Ngày sau',
            onPressed: vm.canGoNext ? vm.nextDay : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(Icons.restaurant),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Pill(meal.type.label),
                    const SizedBox(width: AppSpace.sm),
                    Text(formatTime(meal.createdAt), style: AppText.caption),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(meal.description, style: AppText.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// S05 Thêm bữa ăn.
class AddMealScreen extends StatelessWidget {
  const AddMealScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddMealViewModel(
        context.read<AppServices>(),
        context.read<SessionViewModel>().uid!,
        initialDate: initialDate,
      ),
      child: const _AddMealView(),
    );
  }
}

class _AddMealView extends StatefulWidget {
  const _AddMealView();

  @override
  State<_AddMealView> createState() => _AddMealViewState();
}

class _AddMealViewState extends State<_AddMealView> {
  final _controller = TextEditingController();
  final _descriptionFocus = FocusNode();
  final _sectionKeys = {for (final f in MealField.values) f: GlobalKey()};

  @override
  void dispose() {
    _controller.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate(AddMealViewModel vm) async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.date.isAfter(now) ? now : vm.date,
      firstDate: addDays(now, -365),
      lastDate: now,
    );
    if (picked != null) vm.setDate(picked);
  }

  Future<void> _submit(AddMealViewModel vm) async {
    final saved = await vm.submit();
    if (!mounted) return;
    if (saved) {
      context.pop(true);
      return;
    }
    final field = vm.firstError;
    if (field == null) return;
    final target = _sectionKeys[field]!.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
      );
    }
    if (field == MealField.description) _descriptionFocus.requestFocus();
  }

  Future<void> _confirmDiscard(AddMealViewModel vm) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ nội dung chưa lưu?'),
        content: const Text(
          'Nội dung bạn vừa nhập sẽ không được lưu nếu quay lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục nhập'),
          ),
          TextButton(
            key: const Key('discard-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    vm.logDiscard();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddMealViewModel>();
    return PopScope(
      canPop: !vm.isDirty && !vm.saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !vm.saving) _confirmDiscard(vm);
      },
      child: Scaffold(
        appBar: const BackAppBar(title: 'Thêm bữa ăn', showDemoPill: true),
        // CTA nằm trong body, không dùng bottomNavigationBar, để không bị bàn
        // phím che khi đang nhập tên món.
        body: Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: vm.saving,
                child: PageList(
                  children: [
                    _dateCard(vm),
                    const SizedBox(height: AppSpace.md),
                    _typeCard(vm),
                    const SizedBox(height: AppSpace.md),
                    _descriptionCard(vm),
                  ],
                ),
              ),
            ),
            BottomCta(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vm.saveFailed) ...[
                    StatusBanner(
                      key: const Key('meal-save-error'),
                      kind: BannerKind.error,
                      message: 'Chưa lưu được bữa ăn.',
                      detail: 'Nội dung vẫn được giữ. Thử lại để tiếp tục.',
                      actions: [
                        TextButton(
                          onPressed: _descriptionFocus.requestFocus,
                          child: const Text('Sửa nội dung'),
                        ),
                        TextButton(
                          key: const Key('meal-retry'),
                          onPressed: () => _submit(vm),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  FilledButton(
                    key: const Key('meal-save'),
                    onPressed: vm.saving ? null : () => _submit(vm),
                    child: vm.saving
                        ? const SavingButtonChild('Đang lưu…')
                        : const Text('Lưu bữa ăn'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateCard(AddMealViewModel vm) {
    return AppCard(
      key: _sectionKeys[MealField.date],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ngày ăn', style: AppText.label),
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('meal-date'),
              onPressed: () => _pickDate(vm),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(formatDate(vm.date)),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Chỉ ghi nhận ngày hiện tại hoặc quá khứ (tối đa ${formatDate(today())}).',
            style: AppText.caption,
          ),
          if (vm.errors.contains(MealField.date))
            const FieldError('Ngày ghi nhận không được vượt quá ngày hiện tại.'),
        ],
      ),
    );
  }

  Widget _typeCard(AddMealViewModel vm) {
    return AppCard(
      key: _sectionKeys[MealField.type],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: Text('Loại bữa ăn *', style: AppText.label)),
              Text('Bắt buộc', style: AppText.caption),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          for (final row in const [
            [MealType.breakfast, MealType.lunch],
            [MealType.dinner, MealType.snack],
          ]) ...[
            Row(
              children: [
                for (final type in row) ...[
                  Expanded(
                    child: ChoiceTile(
                      key: Key('meal-type-${type.name}'),
                      label: type.label,
                      selected: vm.type == type,
                      onTap: () => vm.setType(type),
                    ),
                  ),
                  if (type != row.last) const SizedBox(width: AppSpace.sm),
                ],
              ],
            ),
            if (row.first == MealType.breakfast)
              const SizedBox(height: AppSpace.sm),
          ],
          if (vm.errors.contains(MealField.type))
            const FieldError('Hãy chọn loại bữa.'),
        ],
      ),
    );
  }

  Widget _descriptionCard(AddMealViewModel vm) {
    return AppCard(
      key: _sectionKeys[MealField.description],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Bạn đã ăn món gì? *', style: AppText.label),
              ),
              Text(
                '${vm.length}/${AddMealViewModel.maxLength}',
                style: AppText.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          TextField(
            key: const Key('meal-description'),
            controller: _controller,
            focusNode: _descriptionFocus,
            maxLength: AddMealViewModel.maxLength,
            minLines: 2,
            maxLines: 4,
            onChanged: vm.setDescription,
            decoration: const InputDecoration(
              hintText: 'Ví dụ: Cơm gạo lứt, rau luộc, đậu hũ…',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const Text(
            'Nhập ngắn gọn tên món, tối đa 120 ký tự.',
            style: AppText.caption,
          ),
          if (vm.errors.contains(MealField.description))
            const FieldError('Hãy nhập món ăn trước khi lưu.'),
        ],
      ),
    );
  }
}
