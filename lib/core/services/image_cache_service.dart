import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service to handle local image caching for offline support.
/// Caches images from S3 URLs to local storage.
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  static const String _cacheDir = 'image_cache';
  
  /// In-memory cache of URL -> local path mappings for quick lookup
  final Map<String, String> _pathCache = {};

  /// Get the cache directory path
  Future<Directory> get _cacheDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, _cacheDir));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate a unique cache key from the S3 URL
  /// Uses MD5 hash to create a safe filename
  String _getCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Get the local file path for a cached image
  /// Returns null if the image is not cached
  Future<String?> getCachedImagePath(String originalUrl) async {
    // Check in-memory cache first
    if (_pathCache.containsKey(originalUrl)) {
      final cachedPath = _pathCache[originalUrl]!;
      if (await File(cachedPath).exists()) {
        return cachedPath;
      } else {
        _pathCache.remove(originalUrl);
      }
    }

    // Check file system
    final cacheKey = _getCacheKey(originalUrl);
    final cacheDir = await _cacheDirectory;
    final cachedFile = File(path.join(cacheDir.path, cacheKey));
    
    if (await cachedFile.exists()) {
      _pathCache[originalUrl] = cachedFile.path;
      return cachedFile.path;
    }
    
    return null;
  }

  /// Check if an image URL is cached
  Future<bool> isCached(String originalUrl) async {
    return await getCachedImagePath(originalUrl) != null;
  }

  /// Download an image from a pre-signed URL and cache it
  /// Returns the local file path if successful, null otherwise
  Future<String?> downloadAndCache(String originalUrl, String presignedUrl) async {
    try {
      debugPrint('[ImageCacheService] Downloading and caching: $originalUrl');
      
      final response = await http.get(Uri.parse(presignedUrl));
      if (response.statusCode == 200) {
        final cacheKey = _getCacheKey(originalUrl);
        final cacheDir = await _cacheDirectory;
        final cachedFile = File(path.join(cacheDir.path, cacheKey));
        
        await cachedFile.writeAsBytes(response.bodyBytes);
        _pathCache[originalUrl] = cachedFile.path;
        
        debugPrint('[ImageCacheService] Cached successfully: ${cachedFile.path}');
        return cachedFile.path;
      } else {
        debugPrint('[ImageCacheService] Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ImageCacheService] Error caching image: $e');
    }
    return null;
  }

  /// Cache an image from a local file (used after local upload)
  Future<String?> cacheFromLocalFile(String originalUrl, String localFilePath) async {
    try {
      final sourceFile = File(localFilePath);
      if (!await sourceFile.exists()) {
        debugPrint('[ImageCacheService] Source file not found: $localFilePath');
        return null;
      }

      final cacheKey = _getCacheKey(originalUrl);
      final cacheDir = await _cacheDirectory;
      final cachedFile = File(path.join(cacheDir.path, cacheKey));
      
      await sourceFile.copy(cachedFile.path);
      _pathCache[originalUrl] = cachedFile.path;
      
      debugPrint('[ImageCacheService] Cached from local file: ${cachedFile.path}');
      return cachedFile.path;
    } catch (e) {
      debugPrint('[ImageCacheService] Error caching from local file: $e');
    }
    return null;
  }

  /// Update cache if the image URL has changed
  /// Call this when syncing from server to detect image changes
  Future<void> updateCacheIfChanged(String? oldUrl, String? newUrl, String? presignedUrl) async {
    if (newUrl == null || presignedUrl == null) return;
    
    // If URL changed, download and cache the new image
    if (oldUrl != newUrl) {
      debugPrint('[ImageCacheService] Image URL changed, updating cache');
      await downloadAndCache(newUrl, presignedUrl);
      
      // Remove old cache if it exists
      if (oldUrl != null) {
        await removeFromCache(oldUrl);
      }
    }
  }

  /// Remove an image from cache
  Future<void> removeFromCache(String originalUrl) async {
    try {
      final cacheKey = _getCacheKey(originalUrl);
      final cacheDir = await _cacheDirectory;
      final cachedFile = File(path.join(cacheDir.path, cacheKey));
      
      if (await cachedFile.exists()) {
        await cachedFile.delete();
        debugPrint('[ImageCacheService] Removed from cache: $originalUrl');
      }
      _pathCache.remove(originalUrl);
    } catch (e) {
      debugPrint('[ImageCacheService] Error removing from cache: $e');
    }
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    try {
      final cacheDir = await _cacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      _pathCache.clear();
      debugPrint('[ImageCacheService] Cache cleared');
    } catch (e) {
      debugPrint('[ImageCacheService] Error clearing cache: $e');
    }
  }

  /// Get the total size of cached images in bytes
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _cacheDirectory;
      int totalSize = 0;
      
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('[ImageCacheService] Error getting cache size: $e');
      return 0;
    }
  }

  /// Get human-readable cache size
  Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
