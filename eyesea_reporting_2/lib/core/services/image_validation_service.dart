import 'dart:io';
import 'dart:typed_data';

/// Validation result with optional error message.
class ImageValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ImageValidationResult.valid() : isValid = true, errorMessage = null;
  const ImageValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// Service for validating image files before upload.
///
/// Performs client-side validation for:
/// - File size limits
/// - MIME type verification via magic bytes
///
/// Note: Server-side validation should also be configured in Supabase Storage
/// bucket policies as defense-in-depth.
class ImageValidationService {
  /// Maximum file size for report images (10 MB)
  static const int maxReportImageSize = 10 * 1024 * 1024;

  /// Maximum file size for avatar images (5 MB)
  static const int maxAvatarSize = 5 * 1024 * 1024;

  /// Allowed image MIME types
  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp',
  };

  /// Magic bytes for image format detection
  static const List<int> _jpegMagic = [0xFF, 0xD8, 0xFF];
  static const List<int> _pngMagic = [0x89, 0x50, 0x4E, 0x47];
  static const List<int> _webpRiff = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
  static const List<int> _webpWebp = [0x57, 0x45, 0x42, 0x50]; // "WEBP" at offset 8

  /// Validate an image file for report upload.
  static ImageValidationResult validateReportImage(File imageFile) {
    return _validateImage(imageFile, maxReportImageSize, 'report image');
  }

  /// Validate an image file for avatar upload.
  static ImageValidationResult validateAvatarImage(File imageFile) {
    return _validateImage(imageFile, maxAvatarSize, 'avatar');
  }

  static ImageValidationResult _validateImage(
    File imageFile,
    int maxSize,
    String imageType,
  ) {
    // Check file exists
    if (!imageFile.existsSync()) {
      return const ImageValidationResult.invalid('Image file not found');
    }

    // Check file size
    final fileSize = imageFile.lengthSync();
    if (fileSize == 0) {
      return const ImageValidationResult.invalid('Image file is empty');
    }
    if (fileSize > maxSize) {
      final maxMB = maxSize ~/ (1024 * 1024);
      final fileMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      return ImageValidationResult.invalid(
        'Image too large ($fileMB MB). Maximum size for $imageType is $maxMB MB.',
      );
    }

    // Read first 12 bytes to check magic bytes
    final RandomAccessFile raf = imageFile.openSync();
    try {
      final Uint8List header = Uint8List(12);
      raf.readIntoSync(header);

      final mimeType = _detectMimeType(header);
      if (mimeType == null) {
        return const ImageValidationResult.invalid(
          'Invalid image format. Please use JPEG, PNG, HEIC, or WebP.',
        );
      }

      if (!allowedMimeTypes.contains(mimeType)) {
        return ImageValidationResult.invalid(
          'Unsupported image format: $mimeType',
        );
      }
    } finally {
      raf.closeSync();
    }

    return const ImageValidationResult.valid();
  }

  /// Detect MIME type from file header magic bytes.
  static String? _detectMimeType(Uint8List header) {
    if (header.length < 4) return null;

    // JPEG: FF D8 FF
    if (_matchesMagic(header, _jpegMagic)) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 (‰PNG)
    if (_matchesMagic(header, _pngMagic)) {
      return 'image/png';
    }

    // WebP: RIFF....WEBP
    if (header.length >= 12 &&
        _matchesMagic(header, _webpRiff) &&
        _matchesMagicAt(header, _webpWebp, 8)) {
      return 'image/webp';
    }

    // HEIC/HEIF: Check for ftyp box with heic/heif/mif1 brand
    // Simplified check - ftyp at offset 4
    if (header.length >= 12) {
      final ftypCheck = String.fromCharCodes(header.sublist(4, 8));
      if (ftypCheck == 'ftyp') {
        final brand = String.fromCharCodes(header.sublist(8, 12));
        if (brand == 'heic' || brand == 'heix' || brand == 'mif1') {
          return 'image/heic';
        }
        if (brand == 'heif' || brand == 'heim') {
          return 'image/heif';
        }
      }
    }

    return null;
  }

  static bool _matchesMagic(Uint8List data, List<int> magic) {
    if (data.length < magic.length) return false;
    for (int i = 0; i < magic.length; i++) {
      if (data[i] != magic[i]) return false;
    }
    return true;
  }

  static bool _matchesMagicAt(Uint8List data, List<int> magic, int offset) {
    if (data.length < offset + magic.length) return false;
    for (int i = 0; i < magic.length; i++) {
      if (data[offset + i] != magic[i]) return false;
    }
    return true;
  }
}
