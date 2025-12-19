import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_url_service.dart';
import '../services/image_cache_service.dart';
import '../sync/connectivity_service.dart';

/// A widget that displays S3 images by fetching pre-signed URLs from the backend.
/// For local files or non-S3 URLs, displays them directly.
/// Supports offline mode by caching images locally.
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
  final ImageCacheService _imageCacheService = ImageCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
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

      // 1. Check local cache first (works offline)
      final cachedPath = await _imageCacheService.getCachedImagePath(widget.imagePath!);
      if (cachedPath != null) {
        debugPrint('[SmartS3Image] Using cached image: $cachedPath');
        if (mounted) {
          setState(() {
            _resolvedUrl = cachedPath;
            _isLoading = false;
            _hasError = false;
          });
        }
        
        // If online, check if we should update the cache in background
        if (_connectivityService.isConnected) {
          _updateCacheInBackground();
        }
        return;
      }

      // 2. If offline and no cache, show error immediately
      if (!_connectivityService.isConnected) {
        debugPrint('[SmartS3Image] Offline and no cached image for: ${widget.imagePath}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        return;
      }

      // 3. Online - fetch pre-signed URL
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

      // 4. Download and cache the image for offline use
      if (presignedUrl != null && presignedUrl.startsWith('http')) {
        final localCachePath = await _imageCacheService.downloadAndCache(
          widget.imagePath!,
          presignedUrl,
        );
        if (localCachePath != null) {
          // Use cached file instead of network URL for faster loading
          presignedUrl = localCachePath;
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
  
  /// Update cache in background when online (for image changes on server)
  Future<void> _updateCacheInBackground() async {
    if (widget.imagePath == null) return;
    
    try {
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
      }
      
      if (presignedUrl != null && presignedUrl.startsWith('http')) {
        // Re-download and update cache (will overwrite if URL changed)
        await _imageCacheService.downloadAndCache(widget.imagePath!, presignedUrl);
        debugPrint('[SmartS3Image] Background cache update complete');
      }
    } catch (e) {
      debugPrint('[SmartS3Image] Background cache update failed: $e');
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

