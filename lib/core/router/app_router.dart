import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dev/font_preview_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/sign_up_method_screen.dart';
import '../../features/auth/presentation/vk_callback_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../data/models/nutrition.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/nutrition/presentation/add_food_screen.dart';
import '../../features/nutrition/presentation/nutrition_plan_screen.dart';
import '../../features/nutrition/presentation/nutrition_stats_screen.dart';
import '../../features/nutrition/presentation/recipe_detail_screen.dart';
import '../../features/nutrition/presentation/recipe_form_screen.dart';
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
import '../../features/trainer/presentation/ai_assistant_screen.dart';
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

/// Куда попадает пользователь при холодном старте. По умолчанию — экран
/// приветствия; main.dart переключает на '/home' ДО runApp(), если на
/// устройстве есть сохранённая сессия и backend её подтвердил (см. main.dart).
/// `appRouter` ниже — top-level `final`, инициализируется лениво при первом
/// обращении (в app.dart), поэтому значение, выставленное в main() до
/// runApp(), успевает попасть в GoRouter.
String initialRoute = '/welcome';

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialRoute,
  routes: [
    GoRoute(path: '/font-preview', builder: (context, state) => const FontPreviewScreen()),
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(
      path: '/sign-up-method',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SignUpMethodScreen(),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          final scale = Tween(begin: 0.97, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
        },
      ),
    ),
    GoRoute(
      path: '/auth/vk-callback',
      builder: (context, state) => VkCallbackScreen(
        code: state.uri.queryParameters['code'],
        deviceId: state.uri.queryParameters['device_id'],
        codeVerifier: state.uri.queryParameters['codeVerifier'],
        state: state.uri.queryParameters['state'],
        error: state.uri.queryParameters['error'],
      ),
    ),
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
      path: '/add-food',
      builder: (context, state) => AddFoodScreen(
        mealId: state.uri.queryParameters['mealId']!,
        mealType: MealType.values.byName(state.uri.queryParameters['mealType']!),
      ),
    ),
    GoRoute(path: '/recipes', builder: (context, state) => const RecipesScreen()),
    GoRoute(path: '/recipes/new', builder: (context, state) => const RecipeFormScreen()),
    GoRoute(path: '/recipes/:id/edit', builder: (context, state) => RecipeFormScreen(recipeId: state.pathParameters['id'])),
    GoRoute(path: '/recipes/:id', builder: (context, state) => RecipeDetailScreen(recipeId: state.pathParameters['id']!)),
    GoRoute(path: '/nutrition-plan', builder: (context, state) => const NutritionPlanScreen()),
    GoRoute(path: '/nutrition-stats', builder: (context, state) => const NutritionStatsScreen()),
    GoRoute(path: '/trainer/:id', builder: (context, state) => TrainerProfileScreen(trainerId: state.pathParameters['id']!)),
    GoRoute(path: '/chat/:id', builder: (context, state) => ChatScreen(trainerId: state.pathParameters['id']!)),
    GoRoute(path: '/ai-assistant', builder: (context, state) => const AiAssistantScreen()),
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
