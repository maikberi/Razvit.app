import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_achievements.dart';
import '../mock/mock_exercises.dart';
import '../mock/mock_programs.dart';
import '../mock/mock_sessions.dart';
import '../models/achievement.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';

final exerciseCatalogProvider = Provider<List<Exercise>>((ref) => mockExercises);

final programsProvider = Provider<List<WorkoutProgram>>((ref) => mockPrograms);

class CustomProgramsNotifier extends StateNotifier<List<WorkoutProgram>> {
  CustomProgramsNotifier() : super([]);

  void add(WorkoutProgram program) => state = [...state, program];
}

final customProgramsProvider =
    StateNotifierProvider<CustomProgramsNotifier, List<WorkoutProgram>>((ref) => CustomProgramsNotifier());

/// Все программы пользователя: готовые (мок) + созданные им самим.
final allProgramsProvider = Provider<List<WorkoutProgram>>((ref) {
  return [...ref.watch(programsProvider), ...ref.watch(customProgramsProvider)];
});

final activeProgramProvider = Provider<WorkoutProgram>((ref) => activeProgram);

final todayWorkoutProvider = Provider<WorkoutDay>((ref) => todayWorkout);

final exerciseHistoryProvider =
    Provider.family<List<ExerciseHistoryEntry>, String>((ref, exerciseId) => mockExerciseHistory[exerciseId] ?? const []);

final personalRecordsProvider = Provider<List<PersonalRecord>>((ref) => mockPersonalRecords);

final workoutSessionsProvider = Provider<List<WorkoutSession>>((ref) => mockSessions);

final achievementsProvider = Provider<List<Achievement>>((ref) => mockAchievements);

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
