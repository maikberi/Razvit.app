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

/// Прогревает кэш GIF/превью для списка упражнений заранее — например,
/// сразу для всех упражнений дня в момент начала тренировки. Сама загрузка
/// идёт в фоне и не блокирует ничего; к моменту, когда пользователь дойдёт
/// до второго-третьего упражнения, их анимации уже скачаны и появляются
/// без задержки вместо "опять грузится с нуля".
void prefetchExerciseMedia(Iterable<Exercise> exercises) {
  for (final e in exercises) {
    if (e.thumbUrl != null) {
      // ignore: unawaited_futures
      _ImageBytesCache.load(e.thumbUrl!).catchError((_) => Uint8List(0));
    }
    if (e.gifUrl != null) {
      // ignore: unawaited_futures
      _ImageBytesCache.load(e.gifUrl!).catchError((_) => Uint8List(0));
    }
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
  // Для полноразмерного вида грузим ОБА варианта параллельно: лёгкий
  // статичный webp (обычно 10-30 КБ, готов почти мгновенно) и полный GIF
  // (обычно 150-500 КБ). Пока GIF ещё не пришёл, показываем уже готовый
  // превью вместо пустого спиннера — экран никогда не выглядит "висящим".
  Future<Uint8List>? _thumbFuture;
  Future<Uint8List>? _fullFuture;
  Timer? _watchdog;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _load(widget.exercise);
  }

  bool get _hasMedia => widget.exercise.thumbUrl != null || widget.exercise.gifUrl != null;

  // http.get(...).timeout(10s) внутри _ImageBytesCache.load — основная защита
  // от вечной загрузки. Но на нестабильной мобильной сети (именно там и
  // тестировал пользователь — Safari/iPhone, LTE) изредка ловился случай,
  // когда несмотря на это спиннер всё равно не сменялся иконкой — судя по
  // всему, редкий гоночный случай в связке FutureBuilder/StatefulWidget при
  // самом первом построении экрана. Этот таймер — независимая гарантия
  // поверх: что бы ни случилось с самим Future, через 12 секунд UI точно
  // покажет заглушку, а не бесконечный кружок.
  void _load(Exercise exercise) {
    _watchdog?.cancel();
    _timedOut = false;

    if (widget.thumbOnly) {
      // Маленькое превью в списках — только лёгкий webp (или GIF, если
      // превью почему-то нет), полноразмерная анимация тут не нужна.
      final url = exercise.thumbUrl ?? exercise.gifUrl;
      _thumbFuture = url != null ? _ImageBytesCache.load(url) : null;
      _fullFuture = null;
    } else {
      final thumbUrl = exercise.thumbUrl;
      final fullUrl = exercise.gifUrl ?? thumbUrl;
      _thumbFuture = thumbUrl != null ? _ImageBytesCache.load(thumbUrl) : null;
      _fullFuture = fullUrl != null ? _ImageBytesCache.load(fullUrl) : null;
    }

    final primary = _fullFuture ?? _thumbFuture;
    if (primary != null) {
      _watchdog = Timer(const Duration(seconds: 12), () {
        if (mounted) setState(() => _timedOut = true);
      });
      primary.whenComplete(() => _watchdog?.cancel());
    }
  }

  @override
  void didUpdateWidget(covariant _Media oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.thumbUrl != widget.exercise.thumbUrl || oldWidget.exercise.gifUrl != widget.exercise.gifUrl) {
      setState(() => _load(widget.exercise));
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMedia) {
      if (widget.exercise.videoAsset != null) {
        return LoopVideo(assetPath: widget.exercise.videoAsset!, posterAssetPath: widget.exercise.videoPosterAsset);
      }
      return _fallbackIcon();
    }
    if (_timedOut) return _fallbackIcon();

    if (widget.thumbOnly) {
      return FutureBuilder<Uint8List>(
        future: _thumbFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return _placeholder();
          if (snapshot.hasError || !snapshot.hasData) return _fallbackIcon();
          return Image.memory(snapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
        },
      );
    }

    return FutureBuilder<Uint8List>(
      future: _fullFuture,
      builder: (context, fullSnapshot) {
        if (fullSnapshot.connectionState == ConnectionState.done && fullSnapshot.hasData) {
          return Image.memory(fullSnapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
        }
        if (_thumbFuture == null) {
          return fullSnapshot.hasError ? _fallbackIcon() : _placeholder();
        }
        return FutureBuilder<Uint8List>(
          future: _thumbFuture,
          builder: (context, thumbSnapshot) {
            if (thumbSnapshot.connectionState == ConnectionState.done && thumbSnapshot.hasData) {
              return Image.memory(thumbSnapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
            }
            return (fullSnapshot.hasError && thumbSnapshot.hasError) ? _fallbackIcon() : _placeholder();
          },
        );
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
