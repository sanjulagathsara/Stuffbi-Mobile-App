import 'dart:io';
import 'package:flutter/material.dart';

/// A widget that displays images from either a network URL or a local file path.
/// Automatically detects if the path is a URL (http/https) or a local file path.
class SmartImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const SmartImage({
    Key? key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
  }) : super(key: key);

  /// Check if the path is a network URL
  bool get isNetworkImage {
    if (imagePath == null) return false;
    return imagePath!.startsWith('http://') || imagePath!.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return placeholder ?? _buildPlaceholder();
    }

    Widget imageWidget;

    if (isNetworkImage) {
      // Network image
      imageWidget = Image.network(
        imagePath!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[SmartImage] Network image error: $error');
          return placeholder ?? _buildErrorPlaceholder();
        },
      );
    } else {
      // Local file
      final file = File(imagePath!);
      
      // Check if file exists
      if (!file.existsSync()) {
        debugPrint('[SmartImage] Local file not found: $imagePath');
        return placeholder ?? _buildErrorPlaceholder();
      }
      
      imageWidget = Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[SmartImage] Local file error: $error');
          return placeholder ?? _buildErrorPlaceholder();
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_outlined,
        size: (width ?? 40) * 0.5,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.broken_image_outlined,
        size: (width ?? 40) * 0.5,
        color: Colors.grey[400],
      ),
    );
  }
}

