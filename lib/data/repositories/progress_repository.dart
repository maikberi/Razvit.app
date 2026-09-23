import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_progress.dart';

final weightHistoryProvider = Provider<List<WeightEntry>>((ref) => mockWeightHistory);
