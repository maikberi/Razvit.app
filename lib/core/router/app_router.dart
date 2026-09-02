import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/nutrition/presentation/add_food_screen.dart';
import '../../features/nutrition/presentation/nutrition_plan_screen.dart';
import '../../features/nutrition/presentation/nutrition_stats_screen.dart';
import '../../features/nutrition/presentation/recipes_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow_screen.dart';
import '../../features/onboarding/presentation/plan_generating_screen.dart';
import '../../features/onboarding/presentation/plan_ready_screen.dart';
import '../../features/profile/presentation/achievements_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/nutrition/presentation/nutrition_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/trainer/presentation/chat_screen.dart';
import '../../features/trainer/presentation/trainer_profile_screen.dart';
import '../../features/trainer/presentation/trainer_screen.dart';
import '../../features/workouts/presentation/create_program_screen.dart';
import '../../features/workouts/presentation/exercise_detail_screen.dart';
import '../../features/workouts/presentation/workout_calendar_screen.dart';
import '../../features/workouts/presentation/workout_session_complete_screen.dart';
import '../../features/workouts/presentation/workout_session_screen.dart';
import '../../features/workouts/presentation/workout_stats_screen.dart';
import '../../features/workouts/presentation/workouts_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingFlowScreen()),
    GoRoute(path: '/plan-generating', builder: (context, state) => const PlanGeneratingScreen()),
    GoRoute(path: '/plan-ready', builder: (context, state) => const PlanReadyScreen()),

    // Полноэкранные маршруты без нижней навигации.
    GoRoute(path: '/exercise/:id', builder: (context, state) => ExerciseDetailScreen(exerciseId: state.pathParameters['id']!)),
    GoRoute(path: '/workout-session', builder: (context, state) => const WorkoutSessionScreen()),
    GoRoute(path: '/workout-session/complete', builder: (context, state) => const WorkoutSessionCompleteScreen()),
    GoRoute(path: '/create-program', builder: (context, state) => const CreateProgramScreen()),
    GoRoute(path: '/workout-calendar', builder: (context, state) => const WorkoutCalendarScreen()),
    GoRoute(path: '/workout-stats', builder: (context, state) => const WorkoutStatsScreen()),
    GoRoute(
      path: '/add-food/:mealType',
      builder: (context, state) => AddFoodScreen(mealType: state.pathParameters['mealType']!),
    ),
    GoRoute(path: '/recipes', builder: (context, state) => const RecipesScreen()),
    GoRoute(path: '/nutrition-plan', builder: (context, state) => const NutritionPlanScreen()),
    GoRoute(path: '/nutrition-stats', builder: (context, state) => const NutritionStatsScreen()),
    GoRoute(path: '/trainer/:id', builder: (context, state) => TrainerProfileScreen(trainerId: state.pathParameters['id']!)),
    GoRoute(path: '/chat/:id', builder: (context, state) => ChatScreen(trainerId: state.pathParameters['id']!)),
    GoRoute(path: '/achievements', builder: (context, state) => const AchievementsScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/workouts', builder: (context, state) => const WorkoutsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/nutrition', builder: (context, state) => const NutritionScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/trainer', builder: (context, state) => const TrainerScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ]),
      ],
    ),
  ],
);
