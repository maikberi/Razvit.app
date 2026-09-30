import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weight_entry.dart';
import '../services/progress_api_service.dart';

/// Реальная история веса (GET /weight-entries) — раньше здесь был
/// статичный сгенерированный мок (mock_progress.dart), не отражавший
/// ничего, что пользователь реально вводил.
final weightHistoryProvider = FutureProvider<List<WeightEntry>>((ref) {
  return ref.watch(progressApiServiceProvider).listWeightEntries();
});

class WeightEntryNotifier extends StateNotifier<AsyncValue<void>> {
  WeightEntryNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> add(double weightKg) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(progressApiServiceProvider).addWeightEntry(weightKg);
      _ref.invalidate(weightHistoryProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final weightEntryNotifierProvider = StateNotifierProvider<WeightEntryNotifier, AsyncValue<void>>(
  (ref) => WeightEntryNotifier(ref),
);
