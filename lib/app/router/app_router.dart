import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/auth_providers.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/signup_screen.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/home/presentation/handelha_app_shell.dart';
import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/assistant/presentation/chat_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/projects/presentation/project_workspace_screen.dart';
import '../../features/projects/presentation/project_settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/projects/presentation/handelha_focus_session_screen.dart';
import '../../shared/widgets/splash_screen.dart';

Page<T> _buildCalmTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return MaterialPage<T>(
    key: state.pageKey,
    child: child,
  );
}

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final path = state.uri.path;

      final isAuthPath = path.startsWith('/login') ||
          path.startsWith('/signup') ||
          path.startsWith('/forgot-password');

      // While loading: keep the user on the current page instead of
      // bouncing them around. Only redirect to /splash on the very first
      // launch (path hasn't been set to an auth/home page yet).
      if (authState.isLoading) {
        // If we're on an auth page (login/signup), stay there — the user
        // is in the middle of a sign-in/sign-up flow.
        if (isAuthPath) return null;
        // If we're already on splash, stay on splash until loading finishes.
        if (path == '/splash') return null;
        // Otherwise redirect to splash (first launch scenario).
        return '/splash';
      }

      final isLoggedIn = authState.value != null;
      final isOnboardingPath = path.startsWith('/onboarding');

      if (path == '/splash') {
        return isLoggedIn ? '/home' : '/login';
      }

      if (!isLoggedIn && !isAuthPath) return '/login';
      if (isLoggedIn && isAuthPath) return '/home';
      if (isLoggedIn && isOnboardingPath) return null;

      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _buildCalmTransition(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => HandelhaAppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _buildCalmTransition(
              context: context,
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/tasks',
            pageBuilder: (context, state) => _buildCalmTransition(
              context: context,
              state: state,
              child: const TasksScreen(),
            ),
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) => _buildCalmTransition(
              context: context,
              state: state,
              child: const ChatScreen(),
            ),
          ),
          GoRoute(
            path: '/projects',
            pageBuilder: (context, state) => _buildCalmTransition(
              context: context,
              state: state,
              child: const ProjectsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => _buildCalmTransition(
          context: context,
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _buildCalmTransition(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/project-workspace',
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, String>? ?? const {};
          Color? color;
          if (data.containsKey('color')) {
            final colorInt = int.tryParse(data['color']!);
            if (colorInt != null) color = Color(colorInt);
          }
          return _buildCalmTransition(
            context: context,
            state: state,
            child: ProjectWorkspaceScreen(
              projectId: data['id'] ?? '1',
              projectTitle: data['title'] ?? 'إطلاق نسخة هندلها',
              projectGoal: data['goal'] ?? 'نشر نسخة تجريبية قابلة للاستخدام',
              accentColor: color,
            ),
          );
        },
      ),
      GoRoute(
        path: '/project-settings',
        pageBuilder: (context, state) => _buildCalmTransition(
          context: context,
          state: state,
          child: const ProjectSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/focus-session',
        pageBuilder: (context, state) {
          final taskTitle = state.extra as String? ?? 'مهمة بدون عنوان';
          return _buildCalmTransition(
            context: context,
            state: state,
            child: HandelhaFocusSessionScreen(taskTitle: taskTitle),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 16),
            const Text('الصفحة غير موجودة', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    ),
  );
});
