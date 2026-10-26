import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

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

/// Полноэкранная демонстрация для активной тренировки (workout_session_screen).
/// Раньше квадратное видео (360×360) просто растягивалось/вписывалось в
/// высокий прямоугольник во весь верх экрана прямо на плоском белом фоне —
/// без рамки и подложки это выглядело как случайно "подвисший не по центру"
/// кадр, а не как осознанный макет. Теперь — мягкий брендовый градиент на
/// весь фон (вместо плоского белого) и само видео в белой карточке со
/// скруглением и тенью (тот же язык, что у ExerciseHero), сверху по центру
/// под шапкой с таймером. Карточка всегда квадратная и видео в ней целиком
/// видно (contain, без обрезки), просто теперь это явная, "спроектированная"
/// композиция, а не голый full-bleed на пустом фоне.
class ExerciseFullscreenMedia extends StatelessWidget {
  const ExerciseFullscreenMedia({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.green50, AppColors.white],
          stops: [0, 0.7],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 92, AppSpacing.xl, AppSpacing.xl),
          child: Align(
            alignment: Alignment.topCenter,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.raised,
                ),
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: _Media(exercise: exercise, iconSize: 72),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
/// загрузка. Кэш сбрасывается при перезагрузке страницы — этого достаточно,
/// чтобы не перекачивать один и тот же файл повторно в рамках одной сессии.
/// Используется для статичных webp-превью (списки, постер под видео) —
/// сама анимация (exercise.gifUrl) теперь не GIF, а короткое MP4 (см.
/// _VideoMedia ниже): оно в разы легче (десятки КБ вместо сотен) и играет
/// по сети напрямую через video_player, без ручной докачки байтов целиком.
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

/// Прогревает webp-превью и HTTP-кэш MP4 для списка упражнений заранее —
/// например, сразу для всех упражнений дня в момент начала тренировки (или
/// ещё раньше, см. AppShell/workout_repository). MP4 теперь настолько
/// лёгкие (десятки КБ), что докачивать их байты целиком заранее — дёшево и
/// просто прогревает сетевой кэш браузера/ОС к моменту, когда video_player
/// откроет тот же URL для проигрывания.
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
  Future<Uint8List>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    _load(widget.exercise);
  }

  bool get _hasMedia => widget.exercise.thumbUrl != null || widget.exercise.gifUrl != null;

  void _load(Exercise exercise) {
    // В списках (thumbOnly) показываем лёгкий статичный webp — анимация там
    // не нужна, превью и так маленькое. Полноразмерный вид (не thumbOnly)
    // целиком отрисовывает _VideoMedia ниже.
    final url = exercise.thumbUrl ?? exercise.gifUrl;
    _thumbFuture = widget.thumbOnly && url != null ? _ImageBytesCache.load(url) : null;
  }

  @override
  void didUpdateWidget(covariant _Media oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.thumbUrl != widget.exercise.thumbUrl || oldWidget.exercise.gifUrl != widget.exercise.gifUrl) {
      setState(() => _load(widget.exercise));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMedia) {
      if (widget.exercise.videoAsset != null) {
        return LoopVideo(assetPath: widget.exercise.videoAsset!, posterAssetPath: widget.exercise.videoPosterAsset);
      }
      return _fallbackIcon(widget.iconSize);
    }

    if (widget.thumbOnly) {
      return FutureBuilder<Uint8List>(
        future: _thumbFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return _placeholder(widget.iconSize);
          if (snapshot.hasError || !snapshot.hasData) return _fallbackIcon(widget.iconSize);
          return Image.memory(snapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
        },
      );
    }

    if (widget.exercise.gifUrl == null) {
      return _StaticExerciseImage(url: widget.exercise.thumbUrl, iconSize: widget.iconSize);
    }
    return _VideoMedia(
      key: ValueKey(widget.exercise.gifUrl),
      videoUrl: widget.exercise.gifUrl!,
      posterUrl: widget.exercise.thumbUrl,
      iconSize: widget.iconSize,
    );
  }
}

Widget _placeholder(double iconSize) {
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

Widget _fallbackIcon(double iconSize) {
  return ColoredBox(
    color: AppColors.ink50,
    child: Center(child: Icon(Icons.fitness_center_rounded, color: AppColors.ink300, size: iconSize)),
  );
}

/// Статичный webp (когда у упражнения почему-то нет видео) — та же логика
/// кэша, что и для списков.
class _StaticExerciseImage extends StatefulWidget {
  const _StaticExerciseImage({required this.url, required this.iconSize});

  final String? url;
  final double iconSize;

  @override
  State<_StaticExerciseImage> createState() => _StaticExerciseImageState();
}

class _StaticExerciseImageState extends State<_StaticExerciseImage> {
  late Future<Uint8List>? _future = widget.url != null ? _ImageBytesCache.load(widget.url!) : null;

  @override
  Widget build(BuildContext context) {
    if (_future == null) return _fallbackIcon(widget.iconSize);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return _placeholder(widget.iconSize);
        if (snapshot.hasError || !snapshot.hasData) return _fallbackIcon(widget.iconSize);
        return Image.memory(snapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }
}

/// Полноразмерная демонстрация техники — короткое зацикленное MP4 по сети
/// (см. комментарий у _ImageBytesCache про переход с GIF на видео). Пока
/// видео инициализируется, под ним виден статичный webp-постер (та же
/// картинка, что и в списках) — в отличие от прежнего GIF здесь это не
/// "подмена на пережатый кадр похуже", а узнаваемый первый кадр того же
/// видео, который просто "оживает" через секунду-другую.
class _VideoMedia extends StatefulWidget {
  const _VideoMedia({super.key, required this.videoUrl, required this.posterUrl, required this.iconSize});

  final String videoUrl;
  final String? posterUrl;
  final double iconSize;

  @override
  State<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends State<_VideoMedia> {
  VideoPlayerController? _controller;
  Timer? _watchdog;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true)
      ..setVolume(0);
    _controller = controller;
    // На плохой сети initialize() у video_player может зависнуть без
    // собственного таймаута (тот же класс проблемы, что раньше ловили на
    // http.get для GIF) — здесь та же независимая гарантия: через 12 секунд
    // UI точно покажет заглушку вместо вечного постера/спиннера.
    _watchdog = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
    controller.initialize().then((_) {
      _watchdog?.cancel();
      if (!mounted) return;
      setState(() => _ready = true);
      controller.play();
    }).catchError((_) {
      _watchdog?.cancel();
      if (!mounted) return;
      setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _fallbackIcon(widget.iconSize);
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        _StaticExerciseImage(url: widget.posterUrl, iconSize: widget.iconSize),
        if (_ready && controller != null)
          AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 200),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
      ],
    );
  }
}
