import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/theme/app_colors.dart';
import '../providers/events_provider.dart';

/// Screen for creating a new cleanup event.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxAttendeesController = TextEditingController();
  final _locationFocusNode = FocusNode();
  final _imagePicker = ImagePicker();

  DateTime _startTime = DateTime.now().add(const Duration(days: 1));
  DateTime _endTime = DateTime.now().add(const Duration(days: 1, hours: 2));

  bool _isSubmitting = false;
  bool _isSearchingLocation = false;
  List<GeocodingResult> _locationResults = [];
  GeocodingResult? _selectedLocation;
  
  // Cover image state
  File? _coverImage;

  @override
  void initState() {
    super.initState();
    _locationController.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxAttendeesController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    final query = _locationController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _locationResults = [];
        _selectedLocation = null;
      });
      return;
    }

    // Debounced search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_locationController.text.trim() == query && query.isNotEmpty) {
        _searchLocation(query);
      }
    });
  }

  Future<void> _searchLocation(String query) async {
    setState(() => _isSearchingLocation = true);
    try {
      final results = await GeocodingService.search(query, limit: 5);
      if (mounted) {
        setState(() {
          _locationResults = results;
          _isSearchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationResults = [];
          _isSearchingLocation = false;
        });
      }
    }
  }

  void _selectLocation(GeocodingResult result) {
    setState(() {
      _selectedLocation = result;
      _locationController.text = result.placeName;
      _locationResults = [];
      _locationFocusNode.unfocus();
    });
  }

  /// Show image source picker (camera or gallery)
  Future<void> _pickImage() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.camera, color: AppColors.oceanBlue),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppColors.oceanBlue),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
              if (_coverImage != null)
                ListTile(
                  leading: const Icon(LucideIcons.trash2, color: AppColors.punchRed),
                  title: const Text('Remove Image'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _coverImage = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _coverImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateTime(bool isStart) async {
    final initialDate = isStart ? _startTime : _endTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          if (isStart) {
            _startTime = newDateTime;
            if (_endTime.isBefore(_startTime)) {
              _endTime = _startTime.add(const Duration(hours: 2));
            }
          } else {
            _endTime = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<EventsProvider>();
      final maxAttendeesText = _maxAttendeesController.text.trim();

      await provider.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        location: _locationController.text.trim(),
        lat: _selectedLocation?.latitude,
        lon: _selectedLocation?.longitude,
        maxAttendees:
            maxAttendeesText.isNotEmpty ? int.tryParse(maxAttendeesText) : null,
        coverImagePath: _coverImage?.path,
      );

      if (!mounted) return;

      // Refresh events list
      await provider.fetchUpcomingEvents();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event created successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      if (!mounted) return;
      context.pop(); // Go back
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create event: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month ${dt.day}, ${dt.year} at $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.inkBlack : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.inkBlack : Colors.white,
        title: const Text('Create Event'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image Picker
              _buildCoverImagePicker(isDark),
              const SizedBox(height: 24),

              // Event Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'Beach Cleanup, Park Cleanup, etc.',
                  prefixIcon: const Icon(LucideIcons.calendar),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Title is required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Tell people what to expect...',
                  prefixIcon: const Icon(LucideIcons.fileText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (val) => val == null || val.isEmpty
                    ? 'Description is required'
                    : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Location with search
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _locationController,
                    focusNode: _locationFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      hintText: 'Search for a place...',
                      prefixIcon: const Icon(LucideIcons.mapPin),
                      suffixIcon: _isSearchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _locationController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18),
                                  onPressed: () {
                                    _locationController.clear();
                                    setState(() {
                                      _selectedLocation = null;
                                      _locationResults = [];
                                    });
                                  },
                                )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.02),
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Location is required'
                        : null,
                  ),
                  // Location search results
                  if (_locationResults.isNotEmpty && _locationFocusNode.hasFocus)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.inkBlack : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _locationResults.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                        ),
                        itemBuilder: (context, index) {
                          final result = _locationResults[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              LucideIcons.mapPin,
                              size: 18,
                              color: AppColors.oceanBlue,
                            ),
                            title: Text(
                              result.placeName,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: result.context != null
                                ? Text(
                                    result.context!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : Colors.black.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                            onTap: () => _selectLocation(result),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Date & Time Section Header
              Row(
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Date & Time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.black.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Start Time
              _buildDateTimeButton(
                label: 'Start',
                dateTime: _startTime,
                icon: LucideIcons.playCircle,
                onTap: () => _selectDateTime(true),
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              // End Time
              _buildDateTimeButton(
                label: 'End',
                dateTime: _endTime,
                icon: LucideIcons.stopCircle,
                onTap: () => _selectDateTime(false),
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Max Attendees (Optional)
              TextFormField(
                controller: _maxAttendeesController,
                decoration: InputDecoration(
                  labelText: 'Max Attendees (Optional)',
                  hintText: 'Leave empty for unlimited',
                  prefixIcon: const Icon(LucideIcons.users),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (val) {
                  if (val == null || val.isEmpty) return null;
                  final num = int.tryParse(val);
                  if (num == null || num <= 0) {
                    return 'Must be a positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Create Button
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.oceanBlue,
                  disabledBackgroundColor:
                      AppColors.oceanBlue.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.plus, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Create Event',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeButton({
    required String label,
    required DateTime dateTime,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.oceanBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppColors.oceanBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(dateTime),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImagePicker(bool isDark) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 2,
            style: _coverImage == null ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _coverImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _coverImage!,
                    fit: BoxFit.cover,
                  ),
                  // Overlay gradient for better text visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  // Edit button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.pencil,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.oceanBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.imagePlus,
                      size: 32,
                      color: AppColors.oceanBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add Cover Image',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.darkGunmetal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to upload a photo',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
