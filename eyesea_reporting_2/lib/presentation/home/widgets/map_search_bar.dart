import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/logger.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Floating search bar with user avatar for Google Maps-like UX.
/// Contains a location search field and navigates to profile on avatar tap.
class MapSearchBar extends StatefulWidget {
  /// Callback when a location is selected from search results.
  /// Returns [latitude, longitude] coordinates.
  final void Function(double latitude, double longitude)? onLocationSelected;

  const MapSearchBar({
    super.key,
    this.onLocationSelected,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  List<GeocodingResult> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Use Mapbox Geocoding API
      // For now, we'll use a simple implementation
      // In production, you'd want to use the Mapbox Search SDK or REST API
      final results = await _searchLocations(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      AppLogger.error('Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  /// Search locations using Mapbox Geocoding API
  Future<List<GeocodingResult>> _searchLocations(String query) async {
    return GeocodingService.search(query, limit: 5);
  }

  void _onResultSelected(GeocodingResult result) {
    _searchController.text = result.placeName;
    _focusNode.unfocus();
    setState(() => _searchResults = []);
    widget.onLocationSelected?.call(result.latitude, result.longitude);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchResults = []);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main search bar container
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[900]!.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                children: [
                  // Search icon
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(
                      LucideIcons.search,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                  ),

                  // Search text field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (value) {
                        // Debounce search
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_searchController.text == value) {
                            _performSearch(value);
                          }
                        });
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search cities, countries...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // Clear button (when text is present)
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          LucideIcons.x,
                          color: Colors.grey[500],
                          size: 18,
                        ),
                      ),
                    ),

                  // Loading indicator
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),

                  // Divider
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),

                  // User avatar button
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildAvatar(user?.avatarUrl, user?.displayName),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Search results dropdown
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[900]!.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(
                      LucideIcons.mapPin,
                      color: AppColors.oceanBlue,
                      size: 20,
                    ),
                    title: Text(
                      result.placeName,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: result.context != null
                        ? Text(
                            result.context!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    dense: true,
                    onTap: () => _onResultSelected(result),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(String? avatarUrl, String? displayName) {
    const double size = 32;

    Widget letterPlaceholder() => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.oceanBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              displayName?.isNotEmpty == true
                  ? displayName![0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

    if (avatarUrl == null) {
      return letterPlaceholder();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.oceanBlue.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => letterPlaceholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              color: Colors.grey[300],
              child: const Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
