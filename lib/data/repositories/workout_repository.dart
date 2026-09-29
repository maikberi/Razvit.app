import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_exercises.dart';
import '../mock/mock_programs.dart';
import '../models/achievement.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_api_service.dart';

final exerciseCatalogProvider = Provider<List<Exercise>>((ref) => mockExercises);

final programsProvider = Provider<List<WorkoutProgram>>((ref) => mockPrograms);

/// Программы, созданные самим пользователем (create_program_screen.dart) —
/// хранятся на backend (POST/GET /workout-programs), раньше жили только
/// в памяти вкладки и терялись при перезапуске приложения.
class CustomProgramsNotifier extends StateNotifier<AsyncValue<List<WorkoutProgram>>> {
  CustomProgramsNotifier(this._api) : super(const AsyncValue.loading()) {
    _load();
  }

  final WorkoutApiService _api;

  Future<void> _load() async {
    try {
      final programs = await _api.listPrograms();
      state = AsyncValue.data(programs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  Future<WorkoutProgram> create(WorkoutProgram draft) async {
    final created = await _api.createProgram(draft);
    state = AsyncValue.data([...(state.valueOrNull ?? const []), created]);
    return created;
  }
}

final customProgramsProvider = StateNotifierProvider<CustomProgramsNotifier, AsyncValue<List<WorkoutProgram>>>(
  (ref) => CustomProgramsNotifier(ref.watch(workoutApiServiceProvider)),
);

/// Все программы пользователя: готовые (мок) + созданные им самим.
final allProgramsProvider = Provider<List<WorkoutProgram>>((ref) {
  final custom = ref.watch(customProgramsProvider).valueOrNull ?? const [];
  return [...ref.watch(programsProvider), ...custom];
});

/// Активная программа — реальная (созданная вручную или сгенерированная
/// онбордингом, см. plan_generating_screen.dart), если она есть, иначе
/// мок-заглушка (пока пользователь вообще ничего не создал/не прошёл
/// генерацию). Последняя созданная — самая актуальная (customProgramsProvider
/// хранит их в порядке создания).
final activeProgramProvider = Provider<WorkoutProgram>((ref) {
  final custom = ref.watch(customProgramsProvider).valueOrNull ?? const [];
  if (custom.isNotEmpty) return custom.last;
  return activeProgram;
});

final todayWorkoutProvider = Provider<WorkoutDay>((ref) {
  final program = ref.watch(activeProgramProvider);
  if (!program.isCustom || program.days.isEmpty) return todayWorkout;
  return _todayOrNextDay(program);
});

/// День программы, соответствующий сегодняшнему дню недели (program.days[i]
/// соответствует program.trainingDays[i], 1=Пн..7=Вс) — а если сегодня не
/// тренировочный день, ближайший следующий по расписанию (стандартное для
/// фитнес-приложений поведение вместо пустого/непонятного состояния).
WorkoutDay _todayOrNextDay(WorkoutProgram program) {
  final today = DateTime.now().weekday;
  final n = program.days.length;

  for (var i = 0; i < program.trainingDays.length && i < n; i++) {
    if (program.trainingDays[i] == today) return program.days[i];
  }

  int? bestIndex;
  var bestDelta = 8;
  for (var i = 0; i < program.trainingDays.length && i < n; i++) {
    final delta = ((program.trainingDays[i] - today) % 7 + 7) % 7;
    if (delta > 0 && delta < bestDelta) {
      bestDelta = delta;
      bestIndex = i;
    }
  }
  return program.days[bestIndex ?? 0];
}

/// Реальная история тренировок (GET /workout-sessions) — раньше был
/// статичный mockSessions и in-memory activeWorkoutProvider: закрыл
/// приложение и весь прогресс, календарь и статистика обнулялись.
final workoutSessionsProvider = FutureProvider<List<WorkoutSession>>((ref) {
  return ref.watch(workoutApiServiceProvider).listSessions();
});

/// Текущая серия дней подряд с тренировкой — считается из реальной истории
/// (раньше был захардкоженный AppUser.streakDays = 14 всегда).
/// Сегодняшний день не обрывает серию, если тренировки ещё не было —
/// достаточно, чтобы она была вчера.
final workoutStreakProvider = Provider<int>((ref) {
  final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? const [];
  return _computeStreak(sessions);
});

int _computeStreak(List<WorkoutSession> sessions) {
  final doneDays = sessions
      .where((s) => s.status == SessionStatus.done)
      .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
      .toSet();
  if (doneDays.isEmpty) return 0;

  final today = DateTime.now();
  var cursor = DateTime(today.year, today.month, today.day);
  if (!doneDays.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (doneDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// "Топовый" подход (по весу) в упражнении за тренировку — то, что имеет
/// смысл откладывать на график прогресса и сравнивать между тренировками.
SetLog? _topSet(ExerciseLog log) {
  if (log.sets.isEmpty) return null;
  return log.sets.reduce((a, b) => a.weightKg >= b.weightKg ? a : b);
}

/// История подходов по конкретному упражнению — раньше статичный
/// mockExerciseHistory, теперь считается по всем реальным тренировкам
/// пользователя, где встречалось это упражнение. "Личный рекорд" —
/// когда топовый подход тяжелее всех предыдущих по этому упражнению.
final exerciseHistoryProvider = Provider.family<List<ExerciseHistoryEntry>, String>((ref, exerciseId) {
  final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? const [];
  final done = sessions.where((s) => s.status == SessionStatus.done).toList()..sort((a, b) => a.date.compareTo(b.date));

  final entries = <ExerciseHistoryEntry>[];
  var bestSoFar = 0.0;
  for (final session in done) {
    for (final log in session.exerciseLogs) {
      if (log.exercise.id != exerciseId) continue;
      final top = _topSet(log);
      if (top == null) continue;
      final isPR = top.weightKg > bestSoFar;
      if (isPR) bestSoFar = top.weightKg;
      entries.add(ExerciseHistoryEntry(date: session.date, weightKg: top.weightKg, reps: top.reps, isPersonalRecord: isPR));
    }
  }
  return entries;
});

/// Личные рекорды по всем упражнениям — раньше статичный mockPersonalRecords
/// (ровно 3 записи под фиксированную вёрстку из 3 карточек), теперь считаем
/// 3 самых свежих рекорда по реальной истории.
final personalRecordsProvider = Provider<List<PersonalRecord>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? const [];
  final done = sessions.where((s) => s.status == SessionStatus.done).toList()..sort((a, b) => a.date.compareTo(b.date));

  final best = <String, PersonalRecord>{};
  for (final session in done) {
    for (final log in session.exerciseLogs) {
      final top = _topSet(log);
      if (top == null) continue;
      final current = best[log.exercise.id];
      if (current == null || top.weightKg > current.weightKg) {
        best[log.exercise.id] = PersonalRecord(exerciseName: log.exercise.name, weightKg: top.weightKg, date: session.date);
      }
    }
  }
  final records = best.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  return records.take(3).toList();
});

/// Хотя бы раз превзошёл СВОЙ ЖЕ прошлый максимум в каком-то упражнении
/// (не просто первая запись по упражнению — see achievement "new_pr").
bool _hasSurpassedPreviousMax(List<WorkoutSession> sessions) {
  final done = sessions.where((s) => s.status == SessionStatus.done).toList()..sort((a, b) => a.date.compareTo(b.date));
  final bestByExercise = <String, double>{};
  for (final session in done) {
    for (final log in session.exerciseLogs) {
      final top = _topSet(log);
      if (top == null) continue;
      final prevBest = bestByExercise[log.exercise.id];
      if (prevBest != null && top.weightKg > prevBest) return true;
      bestByExercise[log.exercise.id] = prevBest == null || top.weightKg > prevBest ? top.weightKg : prevBest;
    }
  }
  return false;
}

/// Достижения — раньше статичный список (mock_achievements.dart), теперь
/// считаются из реальной истории тренировок: разблокировка отражает то,
/// что пользователь правда сделал, а не выдуманный прогресс.
final achievementsProvider = Provider<List<Achievement>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? const [];
  final streak = ref.watch(workoutStreakProvider);
  final done = sessions.where((s) => s.status == SessionStatus.done).toList();
  final totalWorkouts = done.length;
  final hasPR = _hasSurpassedPreviousMax(sessions);
  final hasBigVolume = done.any((s) => s.volumeKg >= 10000);

  return [
    Achievement(
      id: 'first_workout',
      emoji: '🏆',
      title: 'Первая тренировка',
      description: 'Ты начал свой путь в RAZVIT',
      isUnlocked: totalWorkouts >= 1,
    ),
    Achievement(
      id: 'streak_7',
      emoji: '🔥',
      title: '7 дней подряд',
      description: 'Неделя без пропусков',
      isUnlocked: streak >= 7,
      progress: streak >= 7 ? null : streak,
      target: streak >= 7 ? null : 7,
    ),
    Achievement(
      id: 'streak_30',
      emoji: '🔥',
      title: '30 дней подряд',
      description: 'Месяц стабильности',
      isUnlocked: streak >= 30,
      progress: streak >= 30 ? null : streak,
      target: streak >= 30 ? null : 30,
    ),
    Achievement(id: 'new_pr', emoji: '💪', title: 'Новый личный рекорд', description: 'Превзошёл свой прошлый максимум', isUnlocked: hasPR),
    Achievement(
      id: 'workouts_100',
      emoji: '🏋️',
      title: '100 тренировок',
      description: 'Сотня тренировок позади',
      isUnlocked: totalWorkouts >= 100,
      progress: totalWorkouts >= 100 ? null : totalWorkouts,
      target: totalWorkouts >= 100 ? null : 100,
    ),
    Achievement(id: 'volume_10000', emoji: '⚡', title: '10 000 кг объёма', description: 'За одну тренировку', isUnlocked: hasBigVolume),
  ];
});

/// Состояние активной (выполняемой сейчас) тренировки.
class ActiveWorkoutState {
  const ActiveWorkoutState({
    required this.day,
    required this.startedAt,
    this.exerciseIndex = 0,
    this.setIndex = 0,
    this.logs = const {},
    this.isResting = false,
    this.restRemaining = 0,
    this.isFinished = false,
  });

  final WorkoutDay day;
  final DateTime startedAt;
  final int exerciseIndex;
  final int setIndex;
  final Map<int, List<SetLog>> logs; // exerciseIndex -> подходы
  final bool isResting;
  final int restRemaining;
  final bool isFinished;

  ProgramExercise get currentExercise => day.exercises[exerciseIndex];
  bool get isLastExercise => exerciseIndex >= day.exercises.length - 1;
  bool get isLastSet => setIndex >= currentExercise.sets - 1;

  List<SetLog> logsFor(int exerciseIdx) => logs[exerciseIdx] ?? const [];

  int get totalCompletedSets => logs.values.fold(0, (sum, l) => sum + l.length);
  double get totalVolume =>
      logs.values.fold(0, (sum, l) => sum + l.fold(0.0, (s, set) => s + set.volume));

  /// Готовые ExerciseLog для сохранения сессии на backend — только
  /// упражнения, по которым реально был хотя бы один подход.
  List<ExerciseLog> get exerciseLogs => [
        for (var i = 0; i < day.exercises.length; i++)
          if (logs[i]?.isNotEmpty ?? false) ExerciseLog(exercise: day.exercises[i].exercise, sets: logs[i]!),
      ];

  ActiveWorkoutState copyWith({
    int? exerciseIndex,
    int? setIndex,
    Map<int, List<SetLog>>? logs,
    bool? isResting,
    int? restRemaining,
    bool? isFinished,
  }) {
    return ActiveWorkoutState(
      day: day,
      startedAt: startedAt,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      setIndex: setIndex ?? this.setIndex,
      logs: logs ?? this.logs,
      isResting: isResting ?? this.isResting,
      restRemaining: restRemaining ?? this.restRemaining,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

class ActiveWorkoutNotifier extends StateNotifier<ActiveWorkoutState?> {
  ActiveWorkoutNotifier() : super(null);

  Timer? _timer;

  void start(WorkoutDay day) {
    _timer?.cancel();
    state = ActiveWorkoutState(day: day, startedAt: DateTime.now());
  }

  void completeSet({required double weightKg, required int reps}) {
    final s = state;
    if (s == null) return;
    final updatedLogs = {...s.logs};
    final list = <SetLog>[...?updatedLogs[s.exerciseIndex]];
    list.add(SetLog(weightKg: weightKg, reps: reps));
    updatedLogs[s.exerciseIndex] = list;

    if (s.isLastSet) {
      if (s.isLastExercise) {
        state = s.copyWith(logs: updatedLogs, isFinished: true, isResting: false);
        return;
      }
      state = s.copyWith(
        logs: updatedLogs,
        exerciseIndex: s.exerciseIndex + 1,
        setIndex: 0,
        isResting: true,
        restRemaining: s.day.exercises[s.exerciseIndex + 1].restSeconds,
      );
    } else {
      state = s.copyWith(
        logs: updatedLogs,
        setIndex: s.setIndex + 1,
        isResting: true,
        restRemaining: s.currentExercise.restSeconds,
      );
    }
    _startRestTimer();
  }

  void skipExercise() {
    final s = state;
    if (s == null) return;
    _timer?.cancel();
    if (s.isLastExercise) {
      state = s.copyWith(isFinished: true, isResting: false);
      return;
    }
    state = s.copyWith(exerciseIndex: s.exerciseIndex + 1, setIndex: 0, isResting: false);
  }

  void skipRest() {
    _timer?.cancel();
    final s = state;
    if (s == null) return;
    state = s.copyWith(isResting: false, restRemaining: 0);
  }

  void _startRestTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final s = state;
      if (s == null || !s.isResting) {
        t.cancel();
        return;
      }
      if (s.restRemaining <= 1) {
        state = s.copyWith(isResting: false, restRemaining: 0);
        t.cancel();
      } else {
        state = s.copyWith(restRemaining: s.restRemaining - 1);
      }
    });
  }

  void finish() {
    _timer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final activeWorkoutProvider =
    StateNotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState?>((ref) => ActiveWorkoutNotifier());
