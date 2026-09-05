import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Бесшовное зацикленное демо-видео упражнения — без элементов управления,
/// звук выключен, воспроизведение начинается автоматически.
class LoopVideo extends StatefulWidget {
  const LoopVideo({super.key, required this.assetPath, this.posterAssetPath, this.borderRadius = AppRadius.lg});

  final String assetPath;
  final String? posterAssetPath;
  final double borderRadius;

  @override
  State<LoopVideo> createState() => _LoopVideoState();
}

class _LoopVideoState extends State<LoopVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..setLooping(true)
      ..setVolume(0);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _ready ? _controller.value.aspectRatio : 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        color: AppColors.ink800,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.posterAssetPath != null) Image.asset(widget.posterAssetPath!, fit: BoxFit.cover),
              if (_ready)
                AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 200),
                  child: VideoPlayer(_controller),
                ),
              if (!_ready && !_failed && widget.posterAssetPath == null)
                const Center(child: CircularProgressIndicator(color: AppColors.green500)),
              if (_failed && widget.posterAssetPath == null)
                const Center(child: Icon(Icons.fitness_center_rounded, color: Colors.white38, size: 56)),
            ],
          ),
        ),
      ),
    );
  }
}
