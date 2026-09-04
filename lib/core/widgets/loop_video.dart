import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Бесшовное зацикленное демо-видео упражнения — без элементов управления,
/// звук выключен, воспроизведение начинается автоматически.
class LoopVideo extends StatefulWidget {
  const LoopVideo({super.key, required this.assetPath, this.borderRadius = AppRadius.lg});

  final String assetPath;
  final double borderRadius;

  @override
  State<LoopVideo> createState() => _LoopVideoState();
}

class _LoopVideoState extends State<LoopVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        color: AppColors.ink800,
        child: _ready
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.green500)),
              ),
      ),
    );
  }
}
