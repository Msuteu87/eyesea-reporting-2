import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

// TODO: [DOCUMENTATION] Document compression strategy and tradeoffs
// Current settings: 80% quality, max 1920x1920
// Rationale: Balances file size (~200-500KB) with detail for AI analysis
// Consider: Add to README or wiki for future maintainers

// TODO: [PERFORMANCE] Adaptive compression based on network quality
// Current: Fixed 80% quality regardless of connection speed
// Fix: Detect network type (WiFi vs cellular vs slow), adjust quality:
//   - WiFi: 90% quality for best detail
//   - Cellular: 70% quality for faster upload
//   - Slow/offline queue: 60% quality to minimize storage

/// Service for compressing images before upload to reduce bandwidth and storage.
class ImageCompressionService {
  /// Compress an image file to reduce size.
  /// Returns the compressed file stored in permanent app documents directory.
  ///
  /// Note: Images are stored in Documents/pending_images/ to survive
  /// extended offline periods (won't be cleared by OS like cache).
  ///
  /// [imageFile] - The original image file
  /// [quality] - Compression quality (0-100), default 80
  /// [maxWidth] - Max width in pixels, default 1920
  /// [maxHeight] - Max height in pixels, default 1920
  static Future<File> compressImage(
    File imageFile, {
    int quality = 80,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    // Use app documents directory (permanent) instead of cache (can be cleared)
    final dir = await getApplicationDocumentsDirectory();
    final pendingDir = Directory('${dir.path}/pending_images');

    // Create subfolder if it doesn't exist
    if (!pendingDir.existsSync()) {
      pendingDir.createSync(recursive: true);
    }

    final targetPath =
        '${pendingDir.path}/report_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception('Failed to compress image');
    }

    return File(result.path);
  }

  /// Compress image and return bytes directly (for upload).
  static Future<Uint8List> compressImageToBytes(
    File imageFile, {
    int quality = 80,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    final result = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception('Failed to compress image');
    }

    return result;
  }
}
