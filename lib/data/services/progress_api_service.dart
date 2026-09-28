import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/weight_entry.dart';

/// Клиент истории веса backend RAZVIT (GET/POST/DELETE /weight-entries) —
/// заменяет прежний захардкоженный mockWeightHistory настоящей историей,
/// которую пользователь сам пополняет.
class ProgressApiService {
  ProgressApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<WeightEntry>> listWeightEntries() async {
    final json = await _client.getJson('/api/v1/weight-entries');
    final data = (json['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(_fromJson).toList();
  }

  Future<WeightEntry> addWeightEntry(double weightKg) async {
    final json = await _client.postJson('/api/v1/weight-entries', {'weightKg': weightKg});
    return _fromJson(json['data'] as Map<String, dynamic>);
  }

  WeightEntry _fromJson(Map<String, dynamic> json) => WeightEntry(
        DateTime.parse(json['loggedAt'] as String).toLocal(),
        (json['weightKg'] as num).toDouble(),
      );
}

final progressApiServiceProvider = Provider<ProgressApiService>((ref) => ProgressApiService());
