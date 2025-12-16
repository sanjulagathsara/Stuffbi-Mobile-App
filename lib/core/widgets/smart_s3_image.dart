import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_url_service.dart';

/// A widget that displays S3 images by fetching pre-signed URLs from the backend.
/// For local files or non-S3 URLs, displays them directly.
class SmartS3Image extends StatefulWidget {
  final String? imagePath;
  final int? itemServerId;    // Server ID for items (used to fetch pre-signed URL)
  final int? bundleServerId;  // Server ID for bundles (used to fetch pre-signed URL)
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const SmartS3Image({
    Key? key,
    required this.imagePath,
    this.itemServerId,
    this.bundleServerId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<SmartS3Image> createState() => _SmartS3ImageState();
}

class _SmartS3ImageState extends State<SmartS3Image> {
  final ImageUrlService _imageUrlService = ImageUrlService();
  String? _resolvedUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveImageUrl();
  }

  @override
  void didUpdateWidget(SmartS3Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.itemServerId != widget.itemServerId ||
        oldWidget.bundleServerId != widget.bundleServerId) {
      _resolveImageUrl();
    }
  }

  Future<void> _resolveImageUrl() async {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resolvedUrl = null;
        });
      }
      return;
    }

    // Check if it's an S3 URL that needs pre-signing
    if (_imageUrlService.isS3Url(widget.imagePath)) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }

      String? presignedUrl;
      
      if (widget.itemServerId != null) {
        presignedUrl = await _imageUrlService.getItemImageUrl(
          widget.itemServerId!,
          widget.imagePath,
        );
      } else if (widget.bundleServerId != null) {
        presignedUrl = await _imageUrlService.getBundleImageUrl(
          widget.bundleServerId!,
          widget.imagePath,
        );
      } else {
        // No server ID available - check local file cache for recently uploaded images
        final localPath = _imageUrlService.getLocalFile(widget.imagePath);
        if (localPath != null) {
          debugPrint('[SmartS3Image] Using cached local file: $localPath');
          presignedUrl = localPath; // Use local path for display
        } else {
          debugPrint('[SmartS3Image] S3 URL but no server ID and no cached local file');
        }
      }

      if (mounted) {
        setState(() {
          _resolvedUrl = presignedUrl;
          _isLoading = false;
          _hasError = presignedUrl == null;
        });
      }
    } else {
      // Not an S3 URL, use directly
      if (mounted) {
        setState(() {
          _resolvedUrl = widget.imagePath;
          _isLoading = false;
          _hasError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingPlaceholder();
    }

    if (_hasError || _resolvedUrl == null) {
      return widget.placeholder ?? _buildErrorPlaceholder();
    }

    Widget imageWidget;

    // Check if network or local file
    if (_resolvedUrl!.startsWith('http://') || _resolvedUrl!.startsWith('https://')) {
      imageWidget = Image.network(
        _resolvedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[SmartS3Image] Network image error: $error');
          return widget.placeholder ?? _buildErrorPlaceholder();
        },
      );
    } else {
      // Local file
      final file = File(_resolvedUrl!);
      if (!file.existsSync()) {
        return widget.placeholder ?? _buildErrorPlaceholder();
      }
      
      imageWidget = Image.file(
        file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[SmartS3Image] Local file error: $error');
          return widget.placeholder ?? _buildErrorPlaceholder();
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_outlined,
        size: (widget.width ?? 40) * 0.5,
        color: Colors.grey[400],
      ),
    );
  }
}

