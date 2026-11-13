import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../services/meal_photo_service.dart';
import '../viewmodels/add_meal_view_model.dart';
import '../viewmodels/meal_log_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'report_sheet.dart';
import 'widgets/common.dart';
import 'widgets/meal_photo.dart';
import 'widgets/wellness.dart';

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
    final saved = await context.push<bool>('/log/add?date=${dateKey(vm.date)}');
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

  Future<void> _delete(BuildContext context, String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    final meals = context.read<AppServices>().meals;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bữa ăn này?'),
        content: Text(
          '${meal.type.label}: ${meal.description}\n\nBữa ăn sẽ bị xóa khỏi nhật ký và không khôi phục được.',
        ),
        actions: [
          TextButton(
            key: const Key('meal-delete-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            key: const Key('meal-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await meals.delete(uid, meal.id);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa bữa ăn')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa xóa được bữa ăn. Vui lòng thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SessionViewModel>().uid!;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meal.imagePath != null)
            SizedBox(
              width: 72,
              height: 72,
              child: Semantics(
                button: true,
                label: 'Xem ảnh bữa ăn',
                child: InkWell(
                  key: Key('meal-photo-${meal.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showMealPhoto(context, uid, meal.imagePath!),
                  child: MealPhotoView(
                    key: ValueKey('$uid:${meal.imagePath}'),
                    uid: uid,
                    reference: meal.imagePath!,
                    compact: true,
                  ),
                ),
              ),
            )
          else
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
                    Expanded(
                      child: Text(
                        formatTime(meal.createdAt),
                        style: AppText.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(meal.description, style: AppText.body),
                if (meal.syncStatus != null)
                  Text(switch (meal.syncStatus) {
                    'synced' => 'Đã đồng bộ',
                    'conflict' => 'Có xung đột · mở Đồng bộ',
                    'failed' => 'Cần thử đồng bộ lại',
                    _ => 'Đã lưu trên máy · chờ đồng bộ',
                  }, style: AppText.caption),
              ],
            ),
          ),
          IconButton(
            key: Key('meal-delete-${meal.id}'),
            tooltip: 'Xóa bữa ăn',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, uid),
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
    await vm.discard();
    if (!mounted) return;
    vm.logDiscard();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddMealViewModel>();
    final services = context.read<AppServices>();
    return Theme(
      data: Wellness.theme(context),
      child: PopScope(
        canPop: !vm.isDirty && !vm.busy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !vm.busy) _confirmDiscard(vm);
        },
        child: Scaffold(
          appBar: WellnessHeader(
            title: 'Thêm bữa ăn',
            onBack: vm.busy ? null : () => Navigator.of(context).maybePop(),
            demo: services.isFake && !services.isLocal,
          ),
          // CTA nằm trong body, không dùng bottomNavigationBar, để không bị bàn
          // phím che khi đang nhập tên món.
          body: Column(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: vm.busy,
                  child: PageList(
                    children: [
                      _dateCard(vm),
                      const SizedBox(height: AppSpace.md),
                      _typeCard(vm),
                      const SizedBox(height: AppSpace.md),
                      _photoCard(vm),
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
                      onPressed: vm.busy ? null : () => _submit(vm),
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
      ),
    );
  }

  Widget _dateCard(AddMealViewModel vm) {
    return WellnessCard(
      key: _sectionKeys[MealField.date],
      botanical: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WellnessSectionTitle('Ngày ăn', Icons.calendar_month_outlined),
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('meal-date'),
              onPressed: vm.busy ? null : () => _pickDate(vm),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                formatDate(vm.date),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (vm.errors.contains(MealField.date))
            const FieldError(
              'Ngày ghi nhận không được vượt quá ngày hiện tại.',
            ),
        ],
      ),
    );
  }

  Widget _typeCard(AddMealViewModel vm) {
    return WellnessCard(
      key: _sectionKeys[MealField.type],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WellnessSectionTitle('Loại bữa ăn *', Icons.restaurant_rounded),
          const SizedBox(height: AppSpace.md),
          for (final row in const [
            [MealType.breakfast, MealType.lunch],
            [MealType.dinner, MealType.snack],
          ]) ...[
            Row(
              children: [
                for (final type in row) ...[
                  Expanded(
                    child: Semantics(
                      selected: vm.type == type,
                      child: OutlinedButton(
                        key: Key('meal-type-${type.name}'),
                        onPressed: vm.busy ? null : () => vm.setType(type),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          backgroundColor: vm.type == type
                              ? Wellness.sage
                              : Wellness.paper,
                          side: BorderSide(
                            color: Wellness.forest,
                            width: vm.type == type ? 2 : 1.1,
                          ),
                        ),
                        child: Text(
                          type.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
    return WellnessCard(
      key: _sectionKeys[MealField.description],
      botanical: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WellnessSectionTitle(
            'Bạn đã ăn món gì? *',
            Icons.ramen_dining_outlined,
            trailing: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${vm.length}/${AddMealViewModel.maxLength}',
                style: AppText.caption,
              ),
            ),
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
            style: Wellness.body.copyWith(color: Wellness.forest),
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

  Widget _photoCard(AddMealViewModel vm) => WellnessCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WellnessSectionTitle(
          'Ảnh bữa ăn',
          Icons.photo_camera_outlined,
          trailing: vm.photoReference == null
              ? null
              : IconButton(
                  key: const Key('photo-remove'),
                  tooltip: 'Xóa ảnh',
                  onPressed: vm.busy ? null : vm.removePhoto,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Wellness.forest,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        if (vm.photoReference case final String reference)
          AspectRatio(
            aspectRatio: 1.65,
            child: InkWell(
              key: const Key('photo-preview'),
              onTap: () => showMealPhoto(context, vm.uid, reference),
              child: MealPhotoView(
                key: ValueKey('${vm.uid}:$reference'),
                uid: vm.uid,
                reference: reference,
              ),
            ),
          )
        else
          CustomPaint(
            foregroundPainter: const DashedPhotoBorder(),
            child: Container(
              key: const Key('photo-placeholder'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF4F5E9), Color(0xFFEDF2E2)],
                ),
              ),
              child: Column(
                children: [
                  const _PhotoIllustration(),
                  const SizedBox(height: 8),
                  const Text(
                    'Chụp hoặc chọn ảnh bữa ăn của bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Wellness.forest,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Thêm ảnh để dễ nhớ và theo dõi bữa ăn của bạn.',
                    textAlign: TextAlign.center,
                    style: Wellness.body.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('photo-camera'),
                  onPressed: vm.busy
                      ? null
                      : () => vm.pickPhoto(MealPhotoSource.camera),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 22),
                  label: const Text('Chụp ảnh', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('photo-gallery'),
                  onPressed: vm.busy
                      ? null
                      : () => vm.pickPhoto(MealPhotoSource.gallery),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 22),
                  label: const Text(
                    'Chọn từ thư viện',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (vm.pickingPhoto) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          const Text('Đang xử lý ảnh…', style: AppText.caption),
        ],
        if (vm.photoMessage != null) ...[
          const SizedBox(height: 12),
          StatusBanner(
            key: const Key('photo-message'),
            kind: vm.photoMessageIsError ? BannerKind.error : BannerKind.info,
            message: vm.photoMessage!,
          ),
        ],
      ],
    ),
  );
}

class _PhotoIllustration extends StatelessWidget {
  const _PhotoIllustration();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 65,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 8,
          top: 1,
          child: Transform.rotate(
            angle: -.24,
            child: Container(
              width: 58,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFD8E3BD),
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.landscape,
                color: Color(0xFFA8BF84),
                size: 34,
              ),
            ),
          ),
        ),
        const Positioned(
          right: 8,
          bottom: 0,
          child: Icon(
            Icons.camera_alt_rounded,
            size: 67,
            color: Color(0xFF7C9F70),
          ),
        ),
        const Positioned(
          right: 31,
          bottom: 20,
          child: Icon(Icons.circle_outlined, size: 21, color: Colors.white),
        ),
      ],
    ),
  );
}
