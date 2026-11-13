import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../viewmodels/planner_view_model.dart';
import '../viewmodels/recipe_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'widgets/common.dart';

String recipeLocation(
  String id, {
  required DateTime date,
  PlanSlot? slot,
  int? articleStartedAt,
}) {
  final query = {
    'date': dateKey(date),
    'meal': ?slot?.name,
    't': ?articleStartedAt?.toString(),
  };
  return Uri(path: '/plan/recipe/$id', queryParameters: query).toString();
}

/// S06 Kế hoạch tuần. Vào từ S09 thì có nút Back thay cho header của tab.
class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key, this.articleStartedAt});

  final int? articleStartedAt;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlannerViewModel(
        context.read<AppServices>(),
        context.read<SessionViewModel>().uid!,
      ),
      child: _PlannerView(articleStartedAt: articleStartedAt),
    );
  }
}

class _PlannerView extends StatefulWidget {
  const _PlannerView({this.articleStartedAt});

  final int? articleStartedAt;

  @override
  State<_PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<_PlannerView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openRecipe(
    PlannerViewModel vm,
    String id, {
    PlanSlot? slot,
  }) async {
    final result = await context.push<PlanSaveResult>(
      recipeLocation(
        id,
        date: vm.selectedDate,
        slot: slot,
        articleStartedAt: widget.articleStartedAt,
      ),
    );
    if (result == null) return;
    vm.applySaveResult(result);
    // Banner nằm đầu màn, còn "Món gợi ý" nằm cuối nên phải cuộn lên mới thấy.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _chooseRecipe(PlannerViewModel vm, PlanSlot slot) async {
    final recipeId = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Text('Chọn món cho ${slot.label}', style: AppText.heading),
            ),
            const SizedBox(height: AppSpace.sm),
            for (final recipe in vm.recipes)
              ListTile(
                key: Key('pick-${recipe.id}'),
                minTileHeight: 64,
                leading: RoundedImage(recipe.image, height: 48, width: 48),
                title: Text(recipe.title, style: AppText.label),
                subtitle: const Text(
                  'Công thức minh họa',
                  style: AppText.caption,
                ),
                onTap: () => Navigator.pop(context, recipe.id),
              ),
          ],
        ),
      ),
    );
    if (recipeId != null && mounted) {
      await _openRecipe(vm, recipeId, slot: slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlannerViewModel>();
    final fromArticle = widget.articleStartedAt != null;
    return Scaffold(
      appBar: fromArticle
          ? const BackAppBar(title: 'Kế hoạch tuần')
          : const RootAppBar(),
      body: PageList(
        controller: _scroll,
        children: [
          if (!fromArticle) ...[
            const Text('Kế hoạch tuần', style: AppText.title),
            const SizedBox(height: AppSpace.md),
          ],
          _WeekPager(vm: vm),
          const SizedBox(height: AppSpace.md),
          _DayRail(vm: vm),
          const SizedBox(height: AppSpace.lg),
          if (vm.banner != null) ...[
            StatusBanner(
              key: const Key('plan-banner'),
              kind: BannerKind.success,
              message: vm.banner!,
            ),
            const SizedBox(height: AppSpace.lg),
          ],
          ..._dayContent(vm),
          if (vm.showSuggestions && vm.state == LoadState.ready) ...[
            const SizedBox(height: AppSpace.xl),
            const Text('Món gợi ý', style: AppText.heading),
            const SizedBox(height: AppSpace.md),
            _SuggestionCard(
              recipe: vm.suggestedRecipe,
              onOpen: () => _openRecipe(vm, vm.suggestedRecipe.id),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _dayContent(PlannerViewModel vm) {
    return switch (vm.state) {
      LoadState.loading => const [
        SizedBox(height: 220, child: LoadingView('Đang tải kế hoạch tuần…')),
      ],
      LoadState.error => [
        SizedBox(
          height: 280,
          child: ErrorView(
            title: 'Chưa tải được kế hoạch.',
            body: 'Vui lòng thử tải lại hoặc kiểm tra kết nối thiết bị.',
            onRetry: vm.load,
          ),
        ),
      ],
      _ => [
        Row(
          children: [
            Expanded(
              child: Text(
                formatLongNoYear(vm.selectedDate),
                style: AppText.heading,
              ),
            ),
            const Text('Kế hoạch 3 bữa', style: AppText.caption),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        for (final slot in PlanSlot.values) ...[
          _SlotCard(
            slot: slot,
            recipe: vm.recipeFor(slot),
            isPrimaryEmpty: vm.firstEmptySlot == slot,
            onChoose: () => _chooseRecipe(vm, slot),
            onView: () => _openRecipe(vm, vm.slots[slot]!, slot: slot),
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ],
    };
  }
}

class _WeekPager extends StatelessWidget {
  const _WeekPager({required this.vm});

  final PlannerViewModel vm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          IconButton(
            key: const Key('plan-prev-week'),
            tooltip: 'Tuần trước',
            onPressed: vm.previousWeek,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('Khoảng thời gian', style: AppText.caption),
                Text(
                  '${formatDayMonth(vm.weekStart)} – ${formatDate(vm.weekEnd)}',
                  style: AppText.label,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('plan-next-week'),
            tooltip: 'Tuần sau',
            onPressed: vm.nextWeek,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _DayRail extends StatefulWidget {
  const _DayRail({required this.vm});

  final PlannerViewModel vm;

  @override
  State<_DayRail> createState() => _DayRailState();
}

class _DayRailState extends State<_DayRail> {
  final _selectedKey = GlobalKey();

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(_DayRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reveal();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final day in vm.days)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: _DayChip(
                key: isSameDay(day, vm.selectedDate) ? _selectedKey : null,
                day: day,
                selected: isSameDay(day, vm.selectedDate),
                onTap: () => vm.selectDay(day),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onPrimary : AppColors.text;
    return Semantics(
      button: true,
      selected: selected,
      label: formatLong(day),
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          key: Key('plan-day-${dateKey(day)}'),
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  shortWeekday(day),
                  style: AppText.caption.copyWith(color: color),
                ),
                Text(
                  '${day.day}',
                  style: AppText.label.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.recipe,
    required this.isPrimaryEmpty,
    required this.onChoose,
    required this.onView,
  });

  final PlanSlot slot;
  final Recipe? recipe;
  final bool isPrimaryEmpty;
  final VoidCallback onChoose;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final recipe = this.recipe;
    return AppCard(
      key: Key('slot-${slot.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(slot.label, style: AppText.label)),
              Text('Dự kiến ${slot.time}', style: AppText.caption),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          if (recipe == null) ...[
            const Text('Chưa có món', style: AppText.caption),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              width: double.infinity,
              child: isPrimaryEmpty
                  ? FilledButton(
                      key: Key('choose-${slot.name}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: onChoose,
                      child: const Text('Chọn món'),
                    )
                  : OutlinedButton(
                      key: Key('choose-${slot.name}'),
                      onPressed: onChoose,
                      child: const Text('Chọn món'),
                    ),
            ),
          ] else
            Row(
              children: [
                RoundedImage(recipe.image, height: 64, width: 64),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title, style: AppText.label),
                      TextButton(
                        key: Key('view-${slot.name}'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: onView,
                        child: const Text('Xem chi tiết'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.recipe, required this.onOpen});

  final Recipe recipe;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('plan-suggestion'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoundedImage(recipe.image, height: 150),
          const SizedBox(height: AppSpace.md),
          Text(recipe.title, style: AppText.label),
          const Text('Công thức minh họa', style: AppText.caption),
          const SizedBox(height: AppSpace.xs),
          Text(recipe.summary, style: AppText.body),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('plan-open-suggestion'),
              onPressed: onOpen,
              child: const Text('Xem món →'),
            ),
          ),
        ],
      ),
    );
  }
}

/// S07 Chi tiết món và thêm vào kế hoạch.
class RecipeScreen extends StatelessWidget {
  const RecipeScreen({
    super.key,
    required this.recipeId,
    this.initialDate,
    this.initialSlot,
    this.articleStartedAt,
  });

  final String recipeId;
  final DateTime? initialDate;
  final PlanSlot? initialSlot;
  final int? articleStartedAt;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeViewModel(
        context.read<AppServices>(),
        context.read<SessionViewModel>().uid!,
        recipeId,
        initialDate: initialDate,
        initialSlot: initialSlot,
        articleStartedAt: articleStartedAt,
      ),
      child: const _RecipeView(),
    );
  }
}

class _RecipeView extends StatelessWidget {
  const _RecipeView();

  Future<void> _submit(BuildContext context, RecipeViewModel vm) async {
    if (vm.needsReplaceConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thay thế món hiện tại?'),
          content: Text(
            'Kế hoạch ngày ${formatDate(vm.date)} cho bữa ${vm.slot.shortLabel} đã có món ăn. Bạn có chắc muốn thay thế bằng món này không?',
          ),
          actions: [
            TextButton(
              key: const Key('replace-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              key: const Key('replace-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Thay thế'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final result = await vm.save();
    if (result != null && context.mounted) context.pop(result);
  }

  Future<void> _pickDate(BuildContext context, RecipeViewModel vm) async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.date,
      firstDate: addDays(now, -365),
      lastDate: addDays(now, 365),
    );
    if (picked != null) vm.setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecipeViewModel>();
    return PopScope(
      canPop: !vm.saving,
      child: Scaffold(
        appBar: const BackAppBar(title: 'Chi tiết món', showDemoPill: true),
        body: switch (vm.state) {
          LoadState.loading => const LoadingView('Đang tải thông tin món ăn…'),
          LoadState.ready || LoadState.empty => _content(context, vm),
          LoadState.error => ErrorView(
            title: 'Không thể kết nối',
            body: 'Chưa tải được công thức.',
            onRetry: vm.load,
          ),
        },
        bottomNavigationBar: vm.state == LoadState.ready
            ? BottomCta(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vm.saveFailed) ...[
                      StatusBanner(
                        key: const Key('plan-save-error'),
                        kind: BannerKind.error,
                        message:
                            'Chưa lưu được kế hoạch. Lựa chọn vẫn được giữ.',
                        actions: [
                          TextButton(
                            key: const Key('plan-retry'),
                            onPressed: () => _submit(context, vm),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                    ],
                    FilledButton(
                      key: const Key('recipe-add'),
                      onPressed: vm.saving ? null : () => _submit(context, vm),
                      child: vm.saving
                          ? const SavingButtonChild('Đang lưu…')
                          : const Text('Thêm vào kế hoạch'),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget _content(BuildContext context, RecipeViewModel vm) {
    final recipe = vm.recipe!;
    return AbsorbPointer(
      absorbing: vm.saving,
      child: PageList(
        children: [
          RoundedImage(recipe.image, height: 200),
          const SizedBox(height: AppSpace.lg),
          Text(recipe.title, style: AppText.title),
          const SizedBox(height: AppSpace.xs),
          const Align(
            alignment: Alignment.centerLeft,
            child: Pill('Công thức minh họa'),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(recipe.summary, style: AppText.body),
          const SizedBox(height: AppSpace.xl),
          const Text('Nguyên liệu', style: AppText.heading),
          const SizedBox(height: AppSpace.sm),
          for (final item in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Text('• $item', style: AppText.body),
            ),
          const SizedBox(height: AppSpace.lg),
          const Text('Cách làm', style: AppText.heading),
          const SizedBox(height: AppSpace.sm),
          for (final (i, step) in recipe.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text('${i + 1}. $step', style: AppText.body),
            ),
          const SizedBox(height: AppSpace.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thêm vào kế hoạch', style: AppText.heading),
                const SizedBox(height: AppSpace.md),
                const Text('Ngày', style: AppText.label),
                const SizedBox(height: AppSpace.xs),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('recipe-date'),
                    onPressed: () => _pickDate(context, vm),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(formatDate(vm.date)),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                const Text('Bữa ăn', style: AppText.label),
                const SizedBox(height: AppSpace.xs),
                Row(
                  children: [
                    for (final slot in PlanSlot.values) ...[
                      Expanded(
                        child: ChoiceTile(
                          key: Key('recipe-slot-${slot.name}'),
                          label: slot.shortLabel,
                          selected: vm.slot == slot,
                          onTap: () => vm.setSlot(slot),
                        ),
                      ),
                      if (slot != PlanSlot.values.last)
                        const SizedBox(width: AppSpace.sm),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
