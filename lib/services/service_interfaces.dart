import 'package:flutter/foundation.dart';

// View và ViewModel chỉ biết các interface này, không import Firebase SDK.

class SignInCancelled implements Exception {
  const SignInCancelled();
}

class AppUser {
  const AppUser({required this.uid, this.displayName, this.email});

  final String uid;
  final String? displayName;
  final String? email;
}

abstract interface class AuthService {
  Stream<AppUser?> get userChanges;
  AppUser? get currentUser;

  /// Ném [SignInCancelled] khi người dùng hủy, `AppFailure` khi lỗi khác.
  Future<void> signInWithGoogle();
  Future<void> signOut();

  /// ID token Firebase của người đang đăng nhập, gửi cho server báo cáo để
  /// server tự biết UID. Trả về null khi chưa đăng nhập.
  Future<String?> idToken();
}

class UploadProgress {
  const UploadProgress(this.fraction, {this.downloadUrl});

  final double fraction;
  final String? downloadUrl;
}

abstract interface class ReportStorageService {
  Stream<UploadProgress> upload({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  });

  /// Thử xin link báo cáo của UID khác để chứng minh server đang chặn.
  /// Trả về mã kết quả, ví dụ `unauthorized`.
  Future<String> probeForeignReport();
}

enum PushPermission { granted, denied, notDetermined }

class PushMessage {
  const PushMessage({
    required this.id,
    required this.title,
    required this.body,
    this.route,
  });

  final String id;
  final String title;
  final String body;
  final String? route;
}

abstract interface class MessagingService {
  Stream<PushMessage> get onForeground;
  Stream<PushMessage> get onOpened;
  Future<PushMessage?> initialMessage();
  Future<PushPermission> permissionStatus();
  Future<PushPermission> requestPermission();
  Future<String?> token();
}

abstract interface class AnalyticsService {
  Future<void> logEvent(String name, [Map<String, Object> parameters]);
  Future<void> logScreen(String name);
  Future<void> setUserId(String? uid);
}

abstract interface class CrashService {
  Future<void> recordError(Object error, StackTrace? stack, {required String reason});
  Future<void> setUserId(String uid);
  Future<void> setKey(String key, String value);
  void testCrash();
}

/// Tên tham số và giá trị mặc định dùng chung cho Firebase Console và bản giả lập.
abstract final class RemoteConfigKeys {
  static const maxKnowledgeResults = 'max_knowledge_results';
  static const suggestedRecipesEnabled = 'suggested_recipes_enabled';

  static const defaults = <String, Object>{
    maxKnowledgeResults: 3,
    suggestedRecipesEnabled: true,
  };
}

abstract class RemoteConfigService extends ChangeNotifier {
  int get maxKnowledgeResults;
  bool get suggestedRecipesEnabled;
  String get status;
  Future<void> init();
  Future<void> refresh();
}

/// Danh sách đầy đủ và lý do từng sự kiện nằm ở docs/analytics-plan.md.
abstract final class AnalyticsEvents {
  static const login = 'login';
  static const logout = 'logout';
  static const tutorialBegin = 'tutorial_begin';
  static const tutorialComplete = 'tutorial_complete';
  static const mealAddStart = 'meal_add_start';
  static const mealSaved = 'meal_saved';
  static const mealSaveFailed = 'meal_save_failed';
  static const mealDraftDiscarded = 'meal_draft_discarded';
  static const selectContent = 'select_content';
  static const articleSearch = 'article_search';
  static const planFromArticle = 'plan_from_article';
  static const recipeView = 'recipe_view';
  static const planSlotSaved = 'plan_slot_saved';
  static const planSaveFailed = 'plan_save_failed';
  static const reportExported = 'report_exported';
  static const reportExportFailed = 'report_export_failed';
  static const notificationOpened = 'notification_opened';
}
