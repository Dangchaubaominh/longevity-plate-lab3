import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/dates.dart';
import '../models/models.dart';
import '../viewmodels/session_view_model.dart';
import '../views/account_screen.dart';
import '../views/home_screen.dart';
import '../views/library_screens.dart';
import '../views/meal_screens.dart';
import '../views/notifications_screen.dart';
import '../views/onboarding_screens.dart';
import '../views/plan_screens.dart';

/// Quy tắc chặn truy cập. Tách riêng để kiểm thử không cần dựng giao diện.
String? guardRedirect({
  required String path,
  required bool isEditingGoals,
  required bool signedIn,
  required bool onboarded,
}) {
  if (!signedIn) {
    return path == '/welcome' || path == '/login' ? null : '/login';
  }
  if (path == '/login') return onboarded ? '/home' : '/goals';
  if (!onboarded) {
    return path == '/welcome' || path == '/goals' ? null : '/goals';
  }
  if (path == '/welcome') return '/home';
  if (path == '/goals' && !isEditingGoals) return '/home';
  return null;
}

/// Đường dẫn của màn trên cùng. `uri` của cấu hình không tính các màn đã push.
String currentPath(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  if (config.isEmpty) return '';
  final last = config.last;
  return (last is ImperativeRouteMatch ? last.matches : config).uri.path;
}

GoRouter buildRouter(SessionViewModel session) {
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: session,
    redirect: (context, state) => guardRedirect(
      path: state.uri.path,
      isEditingGoals: state.uri.queryParameters['edit'] == 'true',
      signedIn: session.isSignedIn,
      onboarded: session.isOnboarded,
    ),
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/goals',
        builder: (context, state) => GoalsScreen(
          isEditing: state.uri.queryParameters['edit'] == 'true',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/log',
                builder: (context, state) => const MealLogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
        ],
      ),
      // Các màn con nằm ngoài shell để không hiện bottom nav.
      GoRoute(
        path: '/log/add',
        builder: (context, state) => AddMealScreen(
          initialDate: _parseDate(state.uri.queryParameters['date']),
        ),
      ),
      GoRoute(
        path: '/plan/recipe/:id',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return RecipeScreen(
            recipeId: state.pathParameters['id']!,
            initialDate: _parseDate(query['date']),
            initialSlot: PlanSlot.values
                .where((s) => s.name == query['meal'])
                .firstOrNull,
            articleStartedAt: int.tryParse(query['t'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/library/:id',
        builder: (context, state) =>
            ArticleScreen(articleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/article-plan',
        builder: (context, state) => PlannerScreen(
          articleStartedAt:
              int.tryParse(state.uri.queryParameters['t'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  try {
    return parseDateKey(value);
  } on FormatException {
    return null;
  }
}

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index),
        destinations: const [
          NavigationDestination(
            key: Key('tab-home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            key: Key('tab-log'),
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Nhật ký',
          ),
          NavigationDestination(
            key: Key('tab-plan'),
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Kế hoạch',
          ),
          NavigationDestination(
            key: Key('tab-library'),
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Kiến thức',
          ),
        ],
      ),
    );
  }
}
