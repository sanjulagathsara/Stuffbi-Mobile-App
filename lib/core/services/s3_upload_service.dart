import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../network/api_service.dart';

/// Service for uploading images to S3 via backend presigned URLs
class S3UploadService {
  static final S3UploadService _instance = S3UploadService._internal();
  factory S3UploadService() => _instance;
  S3UploadService._internal();

  final ApiService _apiService = ApiService();

  /// Upload an item image to S3
  /// Returns the S3 URL to store in the database, or null on failure
  Future<String?> uploadItemImage(File imageFile) async {
    try {
      // 1. Get content type
      final contentType = _getContentType(imageFile.path);
      if (contentType == null) {
        print('[S3UploadService] Unsupported image type');
        return null;
      }

      // 2. Get presigned upload URL from backend (for new items)
      final presignResponse = await _apiService.post(
        '/items/image/presign',
        {'contentType': contentType},
      );

      if (!presignResponse.success || presignResponse.data == null) {
        print('[S3UploadService] Failed to get presign URL: ${presignResponse.error}');
        return null;
      }

      final uploadUrl = presignResponse.data['uploadUrl'] as String?;
      final s3Url = presignResponse.data['url'] as String?;

      if (uploadUrl == null || s3Url == null) {
        print('[S3UploadService] Invalid presign response');
        return null;
      }

      // 3. Upload file to S3 using presigned URL
      final success = await _uploadToS3(imageFile, uploadUrl, contentType);
      
      if (success) {
        print('[S3UploadService] Successfully uploaded item image to S3');
        return s3Url;
      } else {
        print('[S3UploadService] Failed to upload to S3');
        return null;
      }
    } catch (e) {
      print('[S3UploadService] Error uploading item image: $e');
      return null;
    }
  }

  /// Upload a bundle image to S3 using the bundle's server ID
  /// Returns the S3 URL to store in the database, or null on failure
  /// Requires bundleServerId to ensure images are saved to bundles/{bundleId}/ folder
  Future<String?> uploadBundleImage(File imageFile, {required int bundleServerId}) async {
    try {
      // 1. Get content type
      final contentType = _getContentType(imageFile.path);
      if (contentType == null) {
        print('[S3UploadService] Unsupported image type');
        return null;
      }

      // 2. Get presigned upload URL from backend using bundle ID
      // This ensures images are saved to bundles/{bundleId}/ folder (same as web frontend)
      final presignResponse = await _apiService.post(
        '/bundles/$bundleServerId/image/presign',
        {'contentType': contentType},
      );

      if (!presignResponse.success || presignResponse.data == null) {
        print('[S3UploadService] Failed to get presign URL: ${presignResponse.error}');
        return null;
      }

      final uploadUrl = presignResponse.data['uploadUrl'] as String?;
      final s3Url = presignResponse.data['url'] as String?;

      if (uploadUrl == null || s3Url == null) {
        print('[S3UploadService] Invalid presign response');
        return null;
      }

      // 3. Upload file to S3 using presigned URL
      final success = await _uploadToS3(imageFile, uploadUrl, contentType);
      
      if (success) {
        print('[S3UploadService] Successfully uploaded bundle image to S3');
        return s3Url;
      } else {
        print('[S3UploadService] Failed to upload to S3');
        return null;
      }
    } catch (e) {
      print('[S3UploadService] Error uploading bundle image: $e');
      return null;
    }
  }

  /// Upload file bytes to S3 using a presigned PUT URL
  Future<bool> _uploadToS3(File file, String uploadUrl, String contentType) async {
    try {
      final bytes = await file.readAsBytes();
      
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': contentType,
        },
        body: bytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('[S3UploadService] S3 upload failed with status: ${response.statusCode}');
        print('[S3UploadService] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[S3UploadService] Error during S3 upload: $e');
      return false;
    }
  }

  /// Get content type from file path
  String? _getContentType(String filePath) {
    final mimeType = lookupMimeType(filePath);
    
    // Only allow supported image types
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
    if (mimeType != null && allowedTypes.contains(mimeType)) {
      return mimeType;
    }
    
    // Fallback based on extension
    final ext = filePath.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }
}
