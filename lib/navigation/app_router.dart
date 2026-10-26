import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../articles/article.dart';
import '../articles/article_repository.dart';
import '../screens/article_details_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/live_screen.dart';
import '../screens/schedule_screen.dart';
import 'app_routes.dart';

GoRouter createRouter(ArticleRepository articleRepository) => GoRouter(
  initialLocation: AppRoutes.live,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _TabsScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.live,
              builder: (context, state) => const LiveScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.schedule,
              builder: (context, state) => const ScheduleScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.articles,
              builder: (context, state) =>
                  ArticlesScreen(repository: articleRepository),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.articleDetails,
      builder: (context, state) =>
          ArticleDetailsScreen(article: state.extra! as Article),
    ),
  ],
);

class _TabsScaffold extends StatelessWidget {
  const _TabsScaffold({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radio), label: 'Live'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          NavigationDestination(icon: Icon(Icons.article), label: 'Articles'),
        ],
      ),
    );
  }
}
