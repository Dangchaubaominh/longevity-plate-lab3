import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../viewmodels/home_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'widgets/common.dart';

/// S03 Hôm nay.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        context.read<AppServices>(),
        context.read<SessionViewModel>().uid!,
      ),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final name = context.select<SessionViewModel, String>(
      (s) => s.greetingName,
    );
    return Scaffold(
      appBar: const RootAppBar(),
      body: switch (vm.state) {
        LoadState.loading => const LoadingView('Đang tải dữ liệu hôm nay…'),
        LoadState.error => ErrorView(
          title: 'Chưa tải được dữ liệu hôm nay.',
          body: 'Kết nối có thể bị gián đoạn. Bạn có thể thử lại.',
          onRetry: vm.load,
        ),
        _ => PageList(
          children: [
            Text('Chào $name', style: AppText.title),
            Text(formatLong(vm.date), style: AppText.caption),
            const SizedBox(height: AppSpace.lg),
            _TodayCard(vm: vm),
            const SizedBox(height: AppSpace.xl),
            _PlanSection(vm: vm),
            const SizedBox(height: AppSpace.xl),
            const Text('Kiến thức gợi ý', style: AppText.heading),
            const SizedBox(height: AppSpace.md),
            _ArticleCard(article: vm.featuredArticle),
          ],
        ),
      },
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(Icons.restaurant),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.mealCount > 0
                          ? 'Hôm nay đã ghi ${vm.mealCount} bữa'
                          : 'Hôm nay chưa ghi bữa nào',
                      style: AppText.label,
                    ),
                    Text(vm.mealSummary, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            key: const Key('home-log-meal'),
            onPressed: () => context.go('/log'),
            child: const Text('Ghi nhận bữa ăn'),
          ),
        ],
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final recipe = vm.featuredRecipe;
    final slot = vm.featuredSlot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Kế hoạch hôm nay', style: AppText.heading),
            ),
            Text(
              vm.isSuggestion ? '1 gợi ý nhẹ' : '${vm.plan.length} món đã chọn',
              style: AppText.caption,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoundedImage(recipe.image, height: 150),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Pill('Bữa ${slot.shortLabel.toLowerCase()}'),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text('Dự kiến ${slot.time}', style: AppText.caption),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(recipe.title, style: AppText.label),
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('home-view-plan'),
                  onPressed: () => context.go('/plan'),
                  child: const Text('Xem kế hoạch →'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('home-article'),
      onTap: () => context.push('/library/${article.id}'),
      child: Row(
        children: [
          RoundedImage(article.image, height: 64, width: 64),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title, style: AppText.label),
                const Text('Bài đọc ngắn', style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}
