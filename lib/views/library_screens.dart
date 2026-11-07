import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../viewmodels/library_view_model.dart';
import 'widgets/common.dart';

void _showLinkError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Không mở được đường dẫn. Vui lòng thử lại.')),
  );
}

/// S08 Thư viện kiến thức.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryViewModel(context.read<AppServices>()),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear(LibraryViewModel vm) {
    _controller.clear();
    vm.clearQuery();
  }

  Future<void> _open(LibraryViewModel vm, Article article) async {
    if (!article.externalOnly) {
      context.push('/library/${article.id}');
      return;
    }
    final opened = await vm.openExternal(article);
    if (!opened && mounted) _showLinkError(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LibraryViewModel>();
    return Scaffold(
      appBar: const RootAppBar(),
      body: PageList(
        children: [
          const Row(
            children: [
              Expanded(child: Text('Thư viện kiến thức', style: AppText.title)),
              Pill('Nội dung minh họa'),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Khám phá những ý tưởng nhỏ cho bữa ăn mỗi ngày.',
            style: AppText.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            key: const Key('library-search'),
            controller: _controller,
            onChanged: vm.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm bài viết',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: vm.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () => _clear(vm),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          ..._results(vm),
        ],
      ),
    );
  }

  List<Widget> _results(LibraryViewModel vm) {
    return switch (vm.state) {
      LoadState.loading => const [
        SizedBox(
          height: 240,
          child: LoadingView(
            'Đang tải bài viết…',
            detail: 'Vui lòng chờ trong giây lát',
          ),
        ),
      ],
      LoadState.error => [
        SizedBox(
          height: 300,
          child: ErrorView(
            title: 'Chưa tải được thư viện.',
            body:
                'Đã xảy ra lỗi kết nối khi lấy danh sách bài viết. Dữ liệu chưa thay đổi.',
            onRetry: vm.load,
          ),
        ),
      ],
      LoadState.empty => [
        SizedBox(
          height: 300,
          child: MessageView(
            icon: Icons.search_off,
            title: 'Không tìm thấy bài viết phù hợp',
            body:
                'Hãy thử tìm kiếm với cụm từ khác hoặc làm mới lại bộ lọc tìm kiếm.',
            actionLabel: 'Xóa tìm kiếm',
            onAction: () => _clear(vm),
          ),
        ),
      ],
      LoadState.ready => [
        for (final (i, article) in vm.results.indexed) ...[
          if (i == 0)
            _HeroCard(article: article, onOpen: () => _open(vm, article))
          else
            _CompactCard(article: article, onOpen: () => _open(vm, article)),
          const SizedBox(height: AppSpace.md),
        ],
      ],
    };
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.article, required this.onOpen});

  final Article article;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('article-${article.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoundedImage(article.image, height: 170),
          const SizedBox(height: AppSpace.md),
          Text(article.source, style: AppText.caption),
          if (article.sourceDate != null)
            Text(article.sourceDate!, style: AppText.caption),
          const SizedBox(height: AppSpace.xs),
          Text(article.title, style: AppText.heading),
          const SizedBox(height: AppSpace.md),
          FilledButton(
            key: const Key('article-read'),
            onPressed: onOpen,
            child: Text(article.externalOnly ? 'Mở nguồn ↗' : 'Đọc bài →'),
          ),
        ],
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.article, required this.onOpen});

  final Article article;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('article-${article.id}'),
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoundedImage(article.image, height: 72, width: 72),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title, style: AppText.label),
                const SizedBox(height: AppSpace.xs),
                Text(article.source, style: AppText.caption),
                if (article.summary != null)
                  Text(article.summary!, style: AppText.caption),
              ],
            ),
          ),
          if (article.externalOnly)
            const Padding(
              padding: EdgeInsets.only(left: AppSpace.sm),
              child: Icon(
                Icons.open_in_new,
                size: 20,
                color: AppColors.muted,
                semanticLabel: 'Mở trang ngoài',
              ),
            ),
        ],
      ),
    );
  }
}

/// S09 Chi tiết bài viết.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ArticleViewModel(context.read<AppServices>(), articleId),
      child: const _ArticleView(),
    );
  }
}

class _ArticleView extends StatelessWidget {
  const _ArticleView();

  void _plan(BuildContext context, ArticleViewModel vm) {
    final startedAt = vm.startPlan();
    context.push('/article-plan?t=$startedAt');
  }

  Future<void> _openSource(BuildContext context, ArticleViewModel vm) async {
    final opened = await vm.openSource();
    if (!opened && context.mounted) _showLinkError(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ArticleViewModel>();
    return Scaffold(
      appBar: const BackAppBar(title: 'Chi tiết bài viết'),
      body: switch (vm.state) {
        LoadState.loading => const LoadingView('Đang tải bài viết…'),
        LoadState.ready || LoadState.empty => _content(context, vm),
        LoadState.error => ErrorView(
          title: 'Chưa tải được bài viết.',
          body: 'Bạn có thể thử tải lại.',
          onRetry: vm.load,
        ),
      },
      bottomNavigationBar: vm.state == LoadState.ready
          ? BottomCta(
              child: FilledButton(
                key: const Key('article-plan'),
                onPressed: () => _plan(context, vm),
                child: const Text('Lập kế hoạch bữa ăn →'),
              ),
            )
          : null,
    );
  }

  Widget _content(BuildContext context, ArticleViewModel vm) {
    final article = vm.article!;
    return PageList(
      children: [
        RoundedImage(article.image, height: 180),
        const SizedBox(height: AppSpace.lg),
        Text(article.title, style: AppText.title),
        const SizedBox(height: AppSpace.md),
        AppCard(
          color: AppColors.selected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.source, style: AppText.label),
              if (article.sourceDate != null)
                Text(
                  'Nguồn cập nhật ${article.sourceDate}',
                  style: AppText.caption,
                ),
              if (article.note != null)
                Text(article.note!, style: AppText.caption),
              if (article.sourceUrl != null) ...[
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  key: const Key('article-source'),
                  onPressed: () => _openSource(context, vm),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(article.sourceLinkLabel ?? 'Xem nguồn'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        for (final section in article.sections) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: AppText.label),
                const SizedBox(height: AppSpace.xs),
                Text(section.body, style: AppText.body),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ],
    );
  }
}
