import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
/// сессии), кэш на диске через cached_network_image + мгновенный
/// blur-up с thumbUrl, пока грузится полный GIF.
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

class _Media extends StatelessWidget {
  const _Media({required this.exercise, required this.iconSize, this.thumbOnly = false});

  final Exercise exercise;
  final double iconSize;
  final bool thumbOnly;

  @override
  Widget build(BuildContext context) {
    // В маленьком превью полноразмерный GIF не нужен — thumbUrl (лёгкий
    // статичный webp) достаточно и грузится/кэшируется в разы быстрее.
    final url = thumbOnly ? (exercise.thumbUrl ?? exercise.gifUrl) : (exercise.gifUrl ?? exercise.thumbUrl);

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, _) => _placeholder(),
        errorWidget: (context, _, __) => _fallbackIcon(),
      );
    }
    if (exercise.videoAsset != null) {
      return LoopVideo(assetPath: exercise.videoAsset!, posterAssetPath: exercise.videoPosterAsset);
    }
    return _fallbackIcon();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.ink50,
      child: Center(
        child: SizedBox(
          width: iconSize * 0.4,
          height: iconSize * 0.4,
          child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink300),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return ColoredBox(
      color: AppColors.ink50,
      child: Center(child: Icon(Icons.fitness_center_rounded, color: AppColors.ink300, size: iconSize)),
    );
  }
}
