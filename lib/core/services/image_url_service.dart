import 'dart:async';
import '../network/api_service.dart';

/// Service to manage pre-signed S3 image URLs
class ImageUrlService {
  static final ImageUrlService _instance = ImageUrlService._internal();
  factory ImageUrlService() => _instance;
  ImageUrlService._internal();

  final ApiService _apiService = ApiService();
  
  // Cache for pre-signed URLs: key -> {url, expiresAt}
  final Map<String, _CachedUrl> _urlCache = {};
  
  // Cache for local file paths: s3Url -> localPath
  // Used for immediate display after upload before sync assigns serverId
  final Map<String, String> _localFileCache = {};
  
  // Default cache duration (slightly less than S3 2-hour expiry)
  static const Duration _cacheDuration = Duration(hours: 1, minutes: 50);

  /// Check if URL is an S3 URL that needs pre-signing
  bool isS3Url(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('.s3.') && url.contains('amazonaws.com');
  }

  /// Get a viewable URL for an item image
  /// If the URL is an S3 URL, fetches a pre-signed URL from the backend
  /// Caches the result for performance
  Future<String?> getItemImageUrl(int itemId, String? originalUrl) async {
    if (originalUrl == null || originalUrl.isEmpty) return null;
    
    // If not an S3 URL, return as-is
    if (!isS3Url(originalUrl)) {
      return originalUrl;
    }

    // Cache key includes URL to invalidate when image changes
    final cacheKey = 'item_${itemId}_${originalUrl.hashCode}';
    
    // Check cache
    final cached = _urlCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Fetch pre-signed URL from backend
    try {
      final response = await _apiService.get('/items/$itemId/image/view-url');
      if (response.success && response.data != null) {
        final viewUrl = response.data['viewUrl'] as String?;
        if (viewUrl != null) {
          _urlCache[cacheKey] = _CachedUrl(viewUrl, DateTime.now().add(_cacheDuration));
          return viewUrl;
        }
      }
    } catch (e) {
      print('[ImageUrlService] Error fetching item image URL: $e');
    }
    
    return null;
  }

  /// Get a viewable URL for a bundle image
  Future<String?> getBundleImageUrl(int bundleId, String? originalUrl) async {
    if (originalUrl == null || originalUrl.isEmpty) return null;
    
    // If not an S3 URL, return as-is
    if (!isS3Url(originalUrl)) {
      return originalUrl;
    }

    // Cache key includes URL to invalidate when image changes
    final cacheKey = 'bundle_${bundleId}_${originalUrl.hashCode}';
    
    // Check cache
    final cached = _urlCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Fetch pre-signed URL from backend
    try {
      final response = await _apiService.get('/bundles/$bundleId/image/view-url');
      if (response.success && response.data != null) {
        final viewUrl = response.data['viewUrl'] as String?;
        if (viewUrl != null) {
          _urlCache[cacheKey] = _CachedUrl(viewUrl, DateTime.now().add(_cacheDuration));
          return viewUrl;
        }
      }
    } catch (e) {
      print('[ImageUrlService] Error fetching bundle image URL: $e');
    }
    
    return null;
  }

  /// Cache a local file path for an S3 URL (for immediate display after upload)
  void cacheLocalFile(String s3Url, String localPath) {
    _localFileCache[s3Url] = localPath;
  }

  /// Get cached local file path for an S3 URL
  String? getLocalFile(String? s3Url) {
    if (s3Url == null) return null;
    return _localFileCache[s3Url];
  }

  /// Clear the URL cache
  void clearCache() {
    _urlCache.clear();
    _localFileCache.clear();
  }
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  _CachedUrl(this.url, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
