import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/load_state.dart';
import '../core/text.dart';
import '../models/models.dart';
import '../services/service_interfaces.dart';
import 'safe_notifier.dart';

class LibraryViewModel extends ChangeNotifier with SafeNotifier {
  LibraryViewModel(this._s) {
    _s.remoteConfig.addListener(notifyListeners);
    load();
  }

  final AppServices _s;
  Timer? _searchLog;

  LoadState _loadState = LoadState.loading;
  List<Article> _articles = const [];
  String query = '';

  /// Giá trị không hợp lệ từ Console không được làm thư viện trống.
  int get _limit {
    final value = _s.remoteConfig.maxKnowledgeResults;
    return value > 0
        ? value
        : RemoteConfigKeys.defaults[RemoteConfigKeys.maxKnowledgeResults]! as int;
  }

  List<Article> get results {
    final needle = normalizeForSearch(query);
    final matched = needle.isEmpty
        ? _articles
        : _articles.where(
            (a) =>
                normalizeForSearch(a.title).contains(needle) ||
                normalizeForSearch(a.source).contains(needle),
          );
    return matched.take(_limit).toList();
  }

  LoadState get state {
    if (_loadState == LoadState.ready && results.isEmpty) return LoadState.empty;
    return _loadState;
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
    _searchLog?.cancel();
    if (value.trim().isEmpty) return;
    // Chỉ gửi số kết quả. Từ khóa có thể chứa thông tin riêng nên không gửi.
    _searchLog = Timer(const Duration(milliseconds: 800), () {
      _s.analytics.logEvent(AnalyticsEvents.articleSearch, {
        'result_count': results.length,
      });
    });
  }

  void clearQuery() => setQuery('');

  Future<void> load() async {
    _loadState = LoadState.loading;
    notifyListeners();
    try {
      _articles = await _s.content.articles();
      _loadState = LoadState.ready;
    } catch (e, st) {
      _loadState = LoadState.error;
      await _s.crash.recordError(e, st, reason: 'library_load_failed');
    }
    notifyListeners();
  }

  /// Trả về false khi không mở được link ngoài để View báo cho người dùng.
  Future<bool> openExternal(Article article) async {
    await _s.analytics.logEvent(AnalyticsEvents.selectContent, {
      'content_type': 'external_article',
      'item_id': article.id,
    });
    return _openLink(_s, article.sourceUrl!);
  }

  @override
  void dispose() {
    _searchLog?.cancel();
    _s.remoteConfig.removeListener(notifyListeners);
    super.dispose();
  }
}

Future<bool> _openLink(AppServices s, String url) async {
  try {
    return await s.openLink(Uri.parse(url));
  } catch (e, st) {
    await s.crash.recordError(e, st, reason: 'open_link_failed');
    return false;
  }
}

class ArticleViewModel extends ChangeNotifier with SafeNotifier {
  ArticleViewModel(this._s, this.articleId) {
    load();
  }

  final AppServices _s;
  final String articleId;

  LoadState state = LoadState.loading;
  Article? article;

  Future<void> load() async {
    state = LoadState.loading;
    notifyListeners();
    try {
      article = await _s.content.article(articleId);
      state = LoadState.ready;
      await _s.analytics.logEvent(AnalyticsEvents.selectContent, {
        'content_type': 'article',
        'item_id': articleId,
      });
    } catch (e, st) {
      state = LoadState.error;
      await _s.crash.recordError(e, st, reason: 'article_load_failed');
    }
    notifyListeners();
  }

  Future<bool> openSource() => _openLink(_s, article!.sourceUrl!);

  /// Thời điểm rời bài viết, dùng đo SC03 từ lúc đọc đến lúc lưu kế hoạch.
  int startPlan() {
    _s.analytics.logEvent(AnalyticsEvents.planFromArticle, {
      'item_id': articleId,
    });
    return DateTime.now().millisecondsSinceEpoch;
  }
}
