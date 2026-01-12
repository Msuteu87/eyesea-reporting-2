import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen camera capture with gallery carousel.
/// Returns the captured/selected image file on success.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  File? _capturedImage;
  bool _showThumbnailAnimation = false;

  // Gallery carousel
  List<AssetEntity> _recentPhotos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadRecentPhotos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('🎥 Getting available cameras...');
      _cameras = await availableCameras();
      debugPrint('🎥 Found ${_cameras.length} cameras');

      if (_cameras.isEmpty) {
        debugPrint('🎥 No cameras found!');
        return;
      }

      // Use back camera
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      debugPrint('🎥 Using camera: ${backCamera.name}');

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      debugPrint('🎥 Initializing camera controller...');
      await _controller!.initialize();
      debugPrint('🎥 Camera initialized successfully!');

      if (mounted) {
        setState(() => _isInitialized = true);
        debugPrint('🎥 State updated - isInitialized: true');
      }
    } catch (e) {
      debugPrint('🎥 Camera init error: $e');
    }
  }

  Future<void> _loadRecentPhotos() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        return;
      }

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
      debugPrint('Gallery load error: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);

      setState(() {
        _capturedImage = file;
        _showThumbnailAnimation = true;
      });

      // Wait for animation then return
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.pop(context, file);
      }
    } catch (e) {
      debugPrint('Capture error: $e');
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

    // Wait for animation then return
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pop(context, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_isInitialized && _controller != null)
            CameraPreview(controller: _controller!)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

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

          // Bottom Controls - always show (even during loading)
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

/// Camera preview widget - simplified
class CameraPreview extends StatelessWidget {
  final CameraController controller;

  const CameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 100,
          height: controller.value.previewSize?.width ?? 100,
          child: controller.buildPreview(),
        ),
      ),
    );
  }
}
