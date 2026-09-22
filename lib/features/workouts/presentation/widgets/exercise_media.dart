import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loop_video.dart';
import '../../../../data/models/exercise.dart';

/// Большая демонстрация техники выполнения (детальный экран, сессия
/// тренировки). Раньше это был Image.network/LoopVideo прямо на тёмном
/// фоне ink800 без кэша — из-за чего GIF (все квадратные, 360×360)
/// показывался с уродливыми серыми полями по бокам в широком контейнере
/// и заново перекачивался с нуля при каждом открытии. Теперь: квадратная
/// карточка точно под форму GIF, светлый фон (не зависит от тёмной темы
/// экрана — читается одинаково хорошо и на белом, и на тёмном экране
/// сессии), с in-memory кэшем и явным таймаутом на загрузку (см. _Media).
class ExerciseHero extends StatelessWidget {
  const ExerciseHero({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _Media(exercise: exercise, iconSize: 64),
        ),
      ),
    );
  }
}

/// Полноэкранная демонстрация для активной тренировки (workout_session_screen) —
/// заполняет всё доступное пространство под собой (без квадратного
/// AspectRatio, без карточки/тени — фон страницы сам служит "подложкой",
/// поэтому по бокам не серые поля, а тот же светлый фон, что и везде).
class ExerciseFullscreenMedia extends StatelessWidget {
  const ExerciseFullscreenMedia({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return _Media(exercise: exercise, iconSize: 96);
  }
}

/// Маленькое превью для строк списков (каталог, "Рекомендуемые
/// упражнения" и т.п.) — тот же светлый квадрат, просто компактнее
/// и без внутреннего отступа/тени.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exercise, this.size = 48});

  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: AppColors.ink50,
          child: _Media(exercise: exercise, iconSize: size * 0.42, thumbOnly: true),
        ),
      ),
    );
  }
}

/// Простой in-memory кэш байтов картинки на время жизни вкладки —
/// раньше здесь был пакет cached_network_image, но у него в вебе (именно
/// там и тестировал пользователь — GitHub Pages в Safari на iPhone)
/// известны зависания без таймаута на нестабильной сети (LTE): загрузка
/// подвисала бесконечно, что выглядело как "приложение не открывается".
/// Здесь — обычный http.get с явным timeout(), после которого гарантированно
/// либо картинка, либо понятная ошибка → иконка-заглушка, никогда не вечная
/// загрusка. Кэш сбрасывается при перезагрузке страницы — этого достаточно,
/// чтобы не перекачивать одну и ту же GIF повторно в рамках одной сессии.
class _ImageBytesCache {
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List>> _inFlight = {};

  static Future<Uint8List> load(String url) {
    final cached = _cache[url];
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlight[url];
    if (inFlight != null) return inFlight;

    final future = http.get(Uri.parse(url)).timeout(const Duration(seconds: 10)).then((res) {
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} for $url');
      }
      _cache[url] = res.bodyBytes;
      return res.bodyBytes;
    }).whenComplete(() => _inFlight.remove(url));

    _inFlight[url] = future;
    return future;
  }
}

class _Media extends StatefulWidget {
  const _Media({required this.exercise, required this.iconSize, this.thumbOnly = false});

  final Exercise exercise;
  final double iconSize;
  final bool thumbOnly;

  @override
  State<_Media> createState() => _MediaState();
}

class _MediaState extends State<_Media> {
  late Future<Uint8List>? _future = _urlFor(widget.exercise) != null ? _ImageBytesCache.load(_urlFor(widget.exercise)!) : null;

  String? _urlFor(Exercise exercise) {
    // В маленьком превью полноразмерный GIF не нужен — thumbUrl (лёгкий
    // статичный webp) достаточно и грузится в разы быстрее.
    return widget.thumbOnly ? (exercise.thumbUrl ?? exercise.gifUrl) : (exercise.gifUrl ?? exercise.thumbUrl);
  }

  @override
  void didUpdateWidget(covariant _Media oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = _urlFor(oldWidget.exercise);
    final newUrl = _urlFor(widget.exercise);
    if (oldUrl != newUrl) {
      setState(() => _future = newUrl != null ? _ImageBytesCache.load(newUrl) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) {
      if (widget.exercise.videoAsset != null) {
        return LoopVideo(assetPath: widget.exercise.videoAsset!, posterAssetPath: widget.exercise.videoPosterAsset);
      }
      return _fallbackIcon();
    }
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return _placeholder();
        if (snapshot.hasError || !snapshot.hasData) return _fallbackIcon();
        return Image.memory(snapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.ink50,
      child: Center(
        child: SizedBox(
          width: widget.iconSize * 0.4,
          height: widget.iconSize * 0.4,
          child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink300),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return ColoredBox(
      color: AppColors.ink50,
      child: Center(child: Icon(Icons.fitness_center_rounded, color: AppColors.ink300, size: widget.iconSize)),
    );
  }
}
