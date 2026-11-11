import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dates.dart';
import '../data/content_data.dart';
import '../models/models.dart';
import 'app_failure.dart';

// Dữ liệu người dùng lưu local theo từng uid. Đăng xuất chỉ xóa trạng thái trong
// bộ nhớ, đăng nhập lại vẫn thấy dữ liệu của chính mình.
const _latency = Duration(milliseconds: 200);

List<Map<String, dynamic>> _readList(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return [];
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

class GoalRepository {
  GoalRepository(this._prefs, this._faults);

  final SharedPreferences _prefs;
  final FaultInjector _faults;

  String _key(String uid) => '$uid.goals';

  bool isOnboarded(String uid) => _prefs.containsKey(_key(uid));

  Set<Goal> load(String uid) => {
    for (final name in _prefs.getStringList(_key(uid)) ?? const <String>[])
      Goal.values.byName(name),
  };

  Future<void> save(String uid, Set<Goal> goals) async {
    await Future<void>.delayed(_latency);
    _faults.check(FaultPoint.saveGoals);
    await _prefs.setStringList(_key(uid), [for (final g in goals) g.name]);
  }
}

class MealRepository extends ChangeNotifier {
  MealRepository(this._prefs, this._faults);

  final SharedPreferences _prefs;
  final FaultInjector _faults;

  String _key(String uid) => '$uid.meals';

  List<MealEntry> _all(String uid) => [
    for (final json in _readList(_prefs, _key(uid))) MealEntry.fromJson(json),
  ];

  Future<List<MealEntry>> forDate(
    String uid,
    String date, {
    FaultPoint? fault,
  }) async {
    await Future<void>.delayed(_latency);
    if (fault != null) _faults.check(fault);
    return _all(uid).where((m) => m.date == date).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Các bữa từ [from] đến [to], tính cả hai đầu.
  List<MealEntry> inRange(String uid, DateTime from, DateTime to) {
    final start = dateKey(from);
    final end = dateKey(to);
    return _all(uid)
        .where((m) => m.date.compareTo(start) >= 0 && m.date.compareTo(end) <= 0)
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
  }

  Future<MealEntry> add(
    String uid, {
    required String date,
    required MealType type,
    required String description,
  }) async {
    await Future<void>.delayed(_latency);
    _faults.check(FaultPoint.saveMeal);
    final now = DateTime.now();
    final entry = MealEntry(
      id: now.microsecondsSinceEpoch.toString(),
      date: date,
      type: type,
      description: description,
      createdAt: now,
    );
    final all = _all(uid)..add(entry);
    await _prefs.setString(
      _key(uid),
      jsonEncode([for (final m in all) m.toJson()]),
    );
    notifyListeners();
    return entry;
  }
}

class PlanRepository extends ChangeNotifier {
  PlanRepository(this._prefs, this._faults);

  final SharedPreferences _prefs;
  final FaultInjector _faults;

  String _key(String uid) => '$uid.plan';

  Map<String, dynamic> _all(String uid) {
    final raw = _prefs.getString(_key(uid));
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Map<PlanSlot, String> _forDate(String uid, String date) {
    final day = _all(uid)[date] as Map<String, dynamic>?;
    return {
      for (final slot in PlanSlot.values)
        if (day?[slot.name] != null) slot: day![slot.name] as String,
    };
  }

  Future<Map<PlanSlot, String>> forDate(
    String uid,
    String date, {
    FaultPoint? fault,
  }) async {
    await Future<void>.delayed(_latency);
    if (fault != null) _faults.check(fault);
    return _forDate(uid, date);
  }

  String? recipeAt(String uid, String date, PlanSlot slot) =>
      _forDate(uid, date)[slot];

  /// Chỉ ghi đúng slot được chọn, không đụng các slot khác trong ngày.
  Future<void> setSlot(
    String uid,
    String date,
    PlanSlot slot,
    String recipeId,
  ) async {
    await Future<void>.delayed(_latency);
    _faults.check(FaultPoint.savePlan);
    final all = _all(uid);
    final day = (all[date] as Map<String, dynamic>?) ?? {};
    day[slot.name] = recipeId;
    all[date] = day;
    await _prefs.setString(_key(uid), jsonEncode(all));
    notifyListeners();
  }
}

class ContentRepository {
  ContentRepository(this._faults);

  final FaultInjector _faults;

  Recipe? recipeById(String id) =>
      recipesData.where((r) => r.id == id).firstOrNull;

  List<Recipe> get recipes => recipesData;

  List<Article> get allArticles => articlesData;

  Article? articleById(String id) =>
      articlesData.where((a) => a.id == id).firstOrNull;

  Future<List<Article>> articles() async {
    await Future<void>.delayed(_latency);
    _faults.check(FaultPoint.loadLibrary);
    return articlesData;
  }

  Future<Article> article(String id) async {
    await Future<void>.delayed(_latency);
    _faults.check(FaultPoint.loadDetail);
    final found = articleById(id);
    if (found == null) throw const AppFailure('article_not_found');
    return found;
  }

  Future<Recipe> recipe(String id) async {
    await Future<void>.delayed(_latency);
    _faults.check(FaultPoint.loadDetail);
    final found = recipeById(id);
    if (found == null) throw const AppFailure('recipe_not_found');
    return found;
  }
}

class NotificationRepository extends ChangeNotifier {
  NotificationRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _pendingKey = 'notifications.pending';
  static const _maxHistory = 100;

  String _key(String uid) => '$uid.notifications';

  /// Handler nền chạy ở isolate khác và chưa biết uid, nên ghi vào hàng chờ của
  /// thiết bị. Lần đọc tiếp theo trong app sẽ chuyển sang lịch sử của người dùng.
  static Future<void> enqueueFromBackground(AppNotification item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final pending = _readList(prefs, _pendingKey)..add(item.toJson());
    await prefs.setString(_pendingKey, jsonEncode(pending));
  }

  Future<List<AppNotification>> load(String uid) async {
    await _prefs.reload();
    final items = _history(uid);
    final pending = _readList(_prefs, _pendingKey);
    if (pending.isNotEmpty) {
      for (final json in pending) {
        _merge(items, AppNotification.fromJson(json));
      }
      await _save(uid, items);
      await _prefs.remove(_pendingKey);
    }
    return items;
  }

  Future<void> add(String uid, AppNotification item) async {
    final items = _history(uid);
    _merge(items, item);
    await _save(uid, items);
    notifyListeners();
  }

  Future<void> markRead(String uid, String id) async {
    final items = _history(uid);
    final i = items.indexWhere((n) => n.id == id);
    if (i < 0) return;
    items[i] = items[i].markedRead();
    await _save(uid, items);
    notifyListeners();
  }

  List<AppNotification> _history(String uid) => [
    for (final json in _readList(_prefs, _key(uid)))
      AppNotification.fromJson(json),
  ];

  // Cùng một tin có thể đến từ cả handler nền lẫn lúc người dùng chạm mở.
  void _merge(List<AppNotification> items, AppNotification item) {
    if (items.any((n) => n.id == item.id)) return;
    items.insert(0, item);
    if (items.length > _maxHistory) items.removeRange(_maxHistory, items.length);
  }

  Future<void> _save(String uid, List<AppNotification> items) => _prefs.setString(
    _key(uid),
    jsonEncode([for (final n in items) n.toJson()]),
  );
}
