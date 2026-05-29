import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/navigation/app_routes.dart';
import 'package:expense_budget_manager/core/navigation/app_scaffold.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/features/accounts/account_detail_screen.dart';
import 'package:expense_budget_manager/features/accounts/accounts_screen.dart';
import 'package:expense_budget_manager/features/add_edit/add_edit_screen.dart';
import 'package:expense_budget_manager/features/analytics/analytics_screen.dart';
import 'package:expense_budget_manager/features/budgets/budgets_screen.dart';
import 'package:expense_budget_manager/features/categories/categories_screen.dart';
import 'package:expense_budget_manager/features/dashboard/dashboard_screen.dart';
import 'package:expense_budget_manager/features/onboarding/onboarding_screen.dart';
import 'package:expense_budget_manager/features/search/search_screen.dart';
import 'package:expense_budget_manager/features/settings/settings_screen.dart';
import 'package:expense_budget_manager/features/transactions/transactions_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final goingToOnboarding = state.uri.toString() == AppRoutes.onboarding;
      if (!settings.onboarded && !goingToOnboarding) return AppRoutes.onboarding;
      if (settings.onboarded && goingToOnboarding) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (c, s) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => BottomNavShell(
          location: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (c, s) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.transactions,
            builder: (c, s) => const TransactionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (c, s) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (c, s) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addEdit,
        builder: (c, s) {
          final id = s.uri.queryParameters['txId'];
          return AddEditScreen(transactionId: id == null ? null : int.tryParse(id));
        },
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (c, s) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.accounts,
        builder: (c, s) => const AccountsScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountDetail,
        builder: (c, s) {
          final id = int.parse(s.pathParameters['id']!);
          return AccountDetailScreen(accountId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.budgets,
        builder: (c, s) => const BudgetsScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (c, s) => const SearchScreen(),
      ),
    ],
    errorBuilder: (c, s) => Scaffold(
      body: Center(child: Text('Route not found: ${s.uri}')),
    ),
  );
});
