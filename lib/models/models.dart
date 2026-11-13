enum Goal {
  logMeals('Ghi nhận bữa ăn đều đặn.'),
  planMeals('Chuẩn bị bữa ăn có kế hoạch.'),
  learn('Hiểu thêm về kiến thức ăn uống.');

  const Goal(this.label);
  final String label;
}

enum MealType {
  breakfast('Bữa sáng'),
  lunch('Bữa trưa'),
  dinner('Bữa tối'),
  snack('Bữa phụ');

  const MealType(this.label);
  final String label;
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.createdAt,
    this.imagePath,
    this.syncStatus,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
    id: json['id'] as String,
    date: json['date'] as String,
    type: MealType.values.byName(json['type'] as String),
    description: json['description'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    imagePath: json['imagePath'] is String ? json['imagePath'] as String : null,
    syncStatus: json['syncStatus'] as String?,
  );

  final String id;
  final String date;
  final MealType type;
  final String description;
  final DateTime createdAt;

  /// Optional relative sandbox reference. Older records have no photo.
  final String? imagePath;
  final String? syncStatus;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'type': type.name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    if (imagePath != null) 'imagePath': imagePath,
  };
}

enum PlanSlot {
  breakfast('Sáng', 'Bữa Sáng', '07:00', 7),
  lunch('Trưa', 'Bữa Trưa', '12:30', 12),
  dinner('Tối', 'Bữa Tối', '19:00', 19);

  const PlanSlot(this.shortLabel, this.label, this.time, this.hour);
  final String shortLabel;
  final String label;
  final String time;
  final int hour;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.summary,
    required this.image,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String title;
  final String summary;
  final String image;
  final List<String> ingredients;
  final List<String> steps;
}

class ArticleSection {
  const ArticleSection(this.title, this.body);

  final String title;
  final String body;
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.source,
    required this.image,
    this.sourceDate,
    this.note,
    this.summary,
    this.sections = const [],
    this.sourceUrl,
    this.sourceLinkLabel,
    this.externalOnly = false,
  });

  final String id;
  final String title;
  final String source;
  final String image;
  final String? sourceDate;
  final String? note;
  final String? summary;
  final List<ArticleSection> sections;
  final String? sourceUrl;
  final String? sourceLinkLabel;

  /// Bài chỉ có nguồn ngoài: chạm mở link thay vì vào S09.
  final bool externalOnly;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.receivedAt,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        route: json['route'] as String?,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
        read: json['read'] as bool? ?? false,
      );

  final String id;
  final String title;
  final String body;
  final String? route;
  final DateTime receivedAt;
  final bool read;

  AppNotification markedRead() => AppNotification(
    id: id,
    title: title,
    body: body,
    route: route,
    receivedAt: receivedAt,
    read: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'route': route,
    'receivedAt': receivedAt.toIso8601String(),
    'read': read,
  };
}
