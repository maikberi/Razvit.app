import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';

class OnboardingNotifier extends StateNotifier<OnboardingProfile> {
  OnboardingNotifier() : super(const OnboardingProfile());

  void setGoal(FitnessGoal v) => state = state.copyWith(goal: v);
  void setGender(Gender v) => state = state.copyWith(gender: v);
  void setAge(int v) => state = state.copyWith(age: v);
  void setHeight(int v) => state = state.copyWith(heightCm: v);
  void setWeight(double v) => state = state.copyWith(weightKg: v);
  void setExperience(ExperienceLevel v) => state = state.copyWith(experience: v);
  void setPlace(TrainingPlace v) => state = state.copyWith(place: v);
  void toggleEquipment(HomeEquipment v) {
    final next = {...state.equipment};
    if (next.contains(v)) {
      next.remove(v);
    } else {
      next.add(v);
    }
    state = state.copyWith(equipment: next);
  }

  void toggleLimitation(BodyLimitation v) {
    final next = {...state.limitations};
    if (next.contains(v)) {
      next.remove(v);
    } else {
      next.add(v);
    }
    state = state.copyWith(limitations: next);
  }

  void clearLimitations() => state = state.copyWith(limitations: {});

  void setWorkoutsPerWeek(int v) => state = state.copyWith(workoutsPerWeek: v);
  void setDuration(WorkoutDuration v) => state = state.copyWith(duration: v);
  void setMotivation(Motivation v) => state = state.copyWith(motivation: v);
  void setAiTone(AiTone v) => state = state.copyWith(aiTone: v);

  void reset() => state = const OnboardingProfile();
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingProfile>((ref) => OnboardingNotifier());
