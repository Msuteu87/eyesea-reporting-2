import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
import 'package:ultralytics_yolo/widgets/yolo_overlay.dart';
import '../../core/services/image_compression_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/logger.dart';

/// Full-screen camera capture with gallery carousel and Object Detection.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  late final YOLOViewController _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  File? _capturedImage;
  bool _showThumbnailAnimation = false;

  // Expert mode (bounding boxes visibility)
  bool _showBoundingBoxes = false;
  static const String _expertModeKey = 'expert_mode_enabled';

  // Gallery carousel
  List<AssetEntity> _recentPhotos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = YOLOViewController();
    _loadRecentPhotos();
    _loadExpertModePreference();
    // Simulate initialization delay for smooth UI
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isInitialized = true);
    });
  }

  Future<void> _loadExpertModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final expertMode = prefs.getBool(_expertModeKey) ?? false;
    if (mounted) {
      setState(() => _showBoundingBoxes = expertMode);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // controller.dispose() is managed by YOLOView usually, but we can stop it if needed.
    // _controller.stop();
    super.dispose();
  }

  // Lifecycle handling is managed by YOLOView's platform view usually,
  // but if we need explicit restart:
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // _controller.restartCamera();
    }
  }

  Future<void> _loadRecentPhotos() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) return;

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (albums.isNotEmpty) {
        final recentAlbum = albums.first;
        final photos = await recentAlbum.getAssetListPaged(
          page: 0,
          size: 20,
        );

        if (mounted) {
          setState(() => _recentPhotos = photos);
        }
      }
    } catch (e) {
      AppLogger.error('Gallery load error: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      AppLogger.debug('Capturing frame from YOLOView...');
      final Uint8List? imageBytes = await _controller.captureFrame();

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception('Captured empty frame');
      }

      // Write to temp file
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'yolo_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      setState(() {
        _capturedImage = file;
        _showThumbnailAnimation = true;
      });

      // Compress and navigate
      await _compressAndNavigate(file);
    } catch (e) {
      AppLogger.error('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _selectFromGallery(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return;

    setState(() {
      _capturedImage = file;
      _showThumbnailAnimation = true;
    });

    await _compressAndNavigate(file);
  }

  Future<void> _compressAndNavigate(File originalFile) async {
    try {
      AppLogger.debug('Compressing image...');
      final compressedFile = await ImageCompressionService.compressImage(
        originalFile,
        quality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      final originalSize = await originalFile.length();
      final compressedSize = await compressedFile.length();
      final reduction =
          ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);
      AppLogger.info(
          'Compressed: ${originalSize ~/ 1024}KB -> ${compressedSize ~/ 1024}KB ($reduction% reduction)');

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        context.push(
            '/report-details?imagePath=${Uri.encodeComponent(compressedFile.path)}');
      }
    } catch (e) {
      AppLogger.error('Compression error: $e');
      if (mounted) {
        context.push(
            '/report-details?imagePath=${Uri.encodeComponent(originalFile.path)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Model path logic needs to be robust.
    // Android: 'yolo11n.tflite' if in assets folder natively?
    // iOS: 'yolo11n' (implicitly .mlmodel from bundle).
    // Let's rely on the plugin's asset loading if possible or fallback.
    // Based on docs, just the name might work if in bundle.
    final modelPath = Platform.isAndroid ? 'yolo11n.tflite' : 'yolo11n';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // YOLO View (Camera + Detection)
          if (_isInitialized)
            YOLOView(
              controller: _controller,
              modelPath: modelPath,
              task: YOLOTask.detect,
              cameraResolution: '1080p', // Try high res
              lensFacing: LensFacing.back,
              showOverlays: _showBoundingBoxes, // Expert mode: show bounding boxes
              confidenceThreshold: 0.4,
              overlayTheme: const YOLOOverlayTheme(
                boundingBoxColor: AppColors.primary,
                labelBackgroundColor: AppColors.primary,
                textColor: Colors.white,
                textSize: 12.0,
              ),
              onResult: (results) {
                // We can log or use results if needed,
                // but overlays handle the visual part.
              },
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Overlay for when not initialized or loading
          if (!_isInitialized) Container(color: Colors.black),

          // Thumbnail Animation Overlay
          if (_showThumbnailAnimation && _capturedImage != null)
            _buildThumbnailAnimation(),

          // Top Bar (Close button)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailAnimation() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _capturedImage!,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(2, 2),
              end: const Offset(0.5, 0.5),
              duration: 600.ms,
              curve: Curves.easeOutBack,
            )
            .fadeOut(delay: 500.ms, duration: 300.ms),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gallery Carousel
          if (_recentPhotos.isNotEmpty) _buildGalleryCarousel(),

          const SizedBox(height: 24),

          // Capture Button
          GestureDetector(
            onTap: _isCapturing ? null : _capturePhoto,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isCapturing ? 60 : 64,
                  height: _isCapturing ? 60 : 64,
                  decoration: BoxDecoration(
                    color: _isCapturing ? AppColors.punchRed : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryCarousel() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentPhotos.length,
        itemBuilder: (context, index) {
          final asset = _recentPhotos[index];
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
            ),
            child: GestureDetector(
              onTap: () => _selectFromGallery(asset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _GalleryThumbnail(asset: asset),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget to load and display gallery thumbnail
class _GalleryThumbnail extends StatefulWidget {
  final AssetEntity asset;

  const _GalleryThumbnail({required this.asset});

  @override
  State<_GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<_GalleryThumbnail> {
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(140, 140),
    );
    if (mounted && data != null) {
      setState(() => _thumbnailData = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailData == null) {
      return Container(
        width: 70,
        height: 70,
        color: Colors.grey[800],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    return Image.memory(
      _thumbnailData!,
      width: 70,
      height: 70,
      fit: BoxFit.cover,
    );
  }
}
