import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/food_recognition.dart';

class FoodRecognitionService {
  FoodRecognitionService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<FoodRecognitionResult> scan(List<int> imageBytes, String mimeType) async {
    final json = await _client.postJson(
      '/api/v1/food-recognition/scan',
      {'imageBase64': base64Encode(imageBytes), 'mimeType': mimeType},
      // Дольше обычного: сначала backend ждёт Vision AI (до 25с), потом
      // сопоставляет продукты с базой — обычный 8-секундный таймаут для
      // остальных запросов здесь слишком короткий.
      timeout: const Duration(seconds: 35),
    );
    return FoodRecognitionResult.fromJson(json['data'] as Map<String, dynamic>);
  }
}

final foodRecognitionServiceProvider = Provider<FoodRecognitionService>((ref) => FoodRecognitionService());
