import '../data/content_data.dart';

const tabRoutes = {'/home', '/log', '/plan', '/library'};
const notificationsRoute = '/notifications';

/// Route trong thông báo đến từ bên ngoài app nên phải kiểm tra trước khi đi tới.
String resolvePushRoute(String? route) {
  if (route == null) return notificationsRoute;
  if (tabRoutes.contains(route) || route == notificationsRoute) return route;
  final article = RegExp(r'^/library/([\w-]+)$').firstMatch(route);
  if (article != null &&
      articlesData.any((a) => a.id == article[1] && !a.externalOnly)) {
    return route;
  }
  final recipe = RegExp(r'^/plan/recipe/([\w-]+)$').firstMatch(route);
  if (recipe != null && recipesData.any((r) => r.id == recipe[1])) {
    return route;
  }
  return notificationsRoute;
}
