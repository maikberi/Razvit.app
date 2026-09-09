import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const foodBadgeColors = [AppColors.green600, Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899)];

Color foodBadgeColor(String id) => foodBadgeColors[id.hashCode.abs() % foodBadgeColors.length];

/// Круглая миниатюра продукта: фото, если у продукта оно есть (сейчас
/// реально приходит только от Open Food Facts), иначе — эмодзи продукта
/// (у безбрендовой эталонной базы — банан, молоко и т.п., см. миграцию
/// 013_reference_foods.sql), а если нет и его — тот же цветной значок-
/// заглушка, что был раньше везде. Фото показывается только после
/// успешной загрузки — до и в случае ошибки виден эмодзи/значок, чтобы
/// никогда не было пустого места или "прыжка" макета.
///
/// [onTap], если задан, вешается прямо на миниатюру отдельным жестом
/// (obscure hit-test), поэтому работает даже когда сама миниатюра лежит
/// внутри более крупной тappable-строки (открывающей что-то своё) — тап
/// именно по фото не долетает до строки-обёртки.
class FoodThumbnail extends StatelessWidget {
  const FoodThumbnail({super.key, required this.id, required this.imageUrl, required this.size, this.iconSize, this.emoji, this.onTap});

  final String id;
  final String? imageUrl;
  final double size;
  final double? iconSize;
  final String? emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = foodBadgeColor(id);
    final hasEmoji = emoji != null && emoji!.isNotEmpty;
    final icon = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: hasEmoji
          ? Text(emoji!, style: TextStyle(fontSize: (iconSize ?? size * 0.45) * 1.3))
          : Icon(Icons.restaurant_rounded, color: color, size: iconSize ?? size * 0.45),
    );
    final url = imageUrl;
    final content = (url == null || url.isEmpty)
        ? icon
        : ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) => progress == null ? child : icon,
                errorBuilder: (context, error, stackTrace) => icon,
              ),
            ),
          );

    if (onTap == null) return content;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content);
  }
}

/// Даёт колбэк для FoodThumbnail.onTap, который открывает фото на весь
/// экран — но только если оно реально есть (иначе не вешаем жест вовсе,
/// чтобы тап по значку-заглушке ничего не делал).
VoidCallback? foodPhotoTap(BuildContext context, String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return null;
  return () => showFoodPhotoViewer(context, imageUrl);
}

/// Полноэкранный просмотр фото продукта с зумом (pinch-to-zoom) — открыть,
/// посмотреть, что это за товар, закрыть тапом или крестиком.
void showFoodPhotoViewer(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, _, __) => _FoodPhotoViewer(imageUrl: imageUrl),
    ),
  );
}

class _FoodPhotoViewer extends StatelessWidget {
  const _FoodPhotoViewer({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
