import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Service for compressing images before upload to reduce bandwidth and storage.
class ImageCompressionService {
  /// Compress an image file to reduce size.
  /// Returns the compressed file.
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
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

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
