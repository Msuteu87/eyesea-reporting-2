import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../core/services/connectivity_service.dart';
import '../../domain/entities/unified_feed_item.dart';
import '../../domain/repositories/social_feed_repository.dart';

/// Filter options for the social feed
enum FeedFilter { nearby, country, city, world }

/// Provider for managing social feed state with automatic proximity-first filtering.
///
/// Uses offset-based pagination. For cursor-based pagination (better for large
/// datasets), the repository would need to support cursor parameters.
class SocialFeedProvider extends ChangeNotifier {
  final SocialFeedRepository _repository;
  final ConnectivityService _connectivityService;

  List<UnifiedFeedItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  FeedFilter _currentFilter = FeedFilter.nearby; // Default to nearby
  String? _filterCountry;
  String? _filterCity;
  String? _currentUserId;
  StreamSubscription<bool>? _connectivitySubscription;

  // Location tracking for proximity filtering
  double? _userLatitude;
  double? _userLongitude;
  int _currentRadiusKm = 50; // Start with 50km
  bool _locationAvailable = false;

  // Auto-expand radius thresholds
  static const List<int> _radiusSteps = [50, 100, 250, 500, 1000];
  static const int _minItemsBeforeExpand = 5;

  static const int _pageSize = 20;
  int _currentOffset = 0;

  /// Maximum items to keep in memory to prevent unbounded growth.
  /// When exceeded, older items are discarded.
  static const int _maxItemsInMemory = 200;

  SocialFeedProvider(this._repository, this._connectivityService) {
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline && _items.isEmpty) {
        log('Back online, loading social feed');
        loadFeed(refresh: true);
      }
      notifyListeners(); // Update offline banner
    });
  }

  // Getters
  List<UnifiedFeedItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  FeedFilter get currentFilter => _currentFilter;
  bool get isOffline => !_connectivityService.isOnline;
  String? get filterCountry => _filterCountry;
  String? get filterCity => _filterCity;
  int get currentRadiusKm => _currentRadiusKm;
  bool get isUsingProximity => _locationAvailable && _currentFilter == FeedFilter.nearby;

  /// Set the current user info for thank tracking and location filtering
  void setCurrentUser(String? userId, String? country, String? city) {
    _currentUserId = userId;
    _filterCountry = country;
    _filterCity = city;
    log('Set current user: id=$userId, country=$country, city=$city');
  }

  /// Set user's current location for proximity filtering
  Future<void> setUserLocation(double latitude, double longitude) async {
    _userLatitude = latitude;
    _userLongitude = longitude;
    _locationAvailable = true;
    _currentRadiusKm = _radiusSteps.first; // Reset to smallest radius
    log('Set user location: lat=$latitude, lng=$longitude');
  }

  /// Initialize location from device GPS
  Future<void> initializeLocation() async {
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        log('Location permission denied, falling back to country filter');
        _locationAvailable = false;
        if (_currentFilter == FeedFilter.nearby) {
          _currentFilter = _filterCountry != null ? FeedFilter.country : FeedFilter.world;
        }
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.low, // Low accuracy is faster and sufficient
          timeLimit: Duration(seconds: 10),
        ),
      );

      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
      _locationAvailable = true;
      _currentRadiusKm = _radiusSteps.first;
      log('Initialized location: lat=${position.latitude}, lng=${position.longitude}');
    } catch (e) {
      log('Failed to get location: $e');
      _locationAvailable = false;
      // Fall back to country filter if location fails
      if (_currentFilter == FeedFilter.nearby) {
        _currentFilter = _filterCountry != null ? FeedFilter.country : FeedFilter.world;
      }
    }
  }

  /// Update the current filter and reload feed
  void setFilter(FeedFilter filter) {
    if (_currentFilter != filter) {
      log('Filter changed from $_currentFilter to $filter');
      _currentFilter = filter;
      _currentRadiusKm = _radiusSteps.first; // Reset radius on filter change
      loadFeed(refresh: true);
    }
  }

  /// Load or refresh the social feed with automatic proximity expansion
  Future<void> loadFeed({bool refresh = false}) async {
    if (!_connectivityService.isOnline) {
      _error = 'You are offline. Connect to the internet to view the feed.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (_isLoading) return;

    if (refresh) {
      _currentOffset = 0;
      _hasMore = true;
      _error = null;
      _currentRadiusKm = _radiusSteps.first; // Reset radius on refresh
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    if (refresh) {
      _error = null;
    }
    notifyListeners();

    try {
      String? country;
      String? city;
      double? latitude;
      double? longitude;
      int? radiusKm;

      switch (_currentFilter) {
        case FeedFilter.nearby:
          if (_locationAvailable && _userLatitude != null && _userLongitude != null) {
            latitude = _userLatitude;
            longitude = _userLongitude;
            radiusKm = _currentRadiusKm;
            country = null;
            city = null;
          } else {
            // Fallback to country if no location
            country = _filterCountry;
            city = null;
          }
          break;
        case FeedFilter.country:
          country = _filterCountry;
          city = null;
          break;
        case FeedFilter.city:
          country = _filterCountry;
          city = _filterCity;
          break;
        case FeedFilter.world:
          country = null;
          city = null;
          break;
      }

      log('Loading feed: filter=$_currentFilter, lat=$latitude, lng=$longitude, radius=${radiusKm}km, country=$country, city=$city, offset=$_currentOffset');

      final data = await _repository.fetchUnifiedFeed(
        userId: _currentUserId,
        country: country,
        city: city,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        limit: _pageSize,
        offset: _currentOffset,
      );

      var newItems = data.map((json) => UnifiedFeedItem.fromJson(json)).toList();

      // Auto-expand radius if using proximity and got too few results
      if (_currentFilter == FeedFilter.nearby &&
          _locationAvailable &&
          refresh &&
          newItems.length < _minItemsBeforeExpand) {
        final expandedItems = await _tryExpandRadius(newItems);
        if (expandedItems != null) {
          newItems = expandedItems;
        }
      }

      if (refresh) {
        _items = newItems;
      } else {
        _items = [..._items, ...newItems];
      }

      // Enforce memory cap: keep only the most recent items
      if (_items.length > _maxItemsInMemory) {
        final overflow = _items.length - _maxItemsInMemory;
        _items = _items.sublist(overflow);
        log('Memory cap enforced: removed $overflow oldest items');
      }

      _hasMore = newItems.length >= _pageSize;
      _currentOffset += newItems.length;
      _error = null;

      log('Loaded ${newItems.length} items, total: ${_items.length}, hasMore: $_hasMore, radius: ${_currentRadiusKm}km');
    } catch (e) {
      log('Error loading feed: $e');
      _error = 'Failed to load feed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Try expanding the search radius to find more results
  /// Returns expanded items if successful, null if no expansion needed/possible
  Future<List<UnifiedFeedItem>?> _tryExpandRadius(List<UnifiedFeedItem> currentItems) async {
    if (_userLatitude == null || _userLongitude == null) return null;

    // Find current radius index
    final currentIndex = _radiusSteps.indexOf(_currentRadiusKm);
    if (currentIndex == -1 || currentIndex >= _radiusSteps.length - 1) {
      // Already at max radius or invalid
      log('Cannot expand radius: already at max or invalid (${_currentRadiusKm}km)');
      return null;
    }

    // Try each larger radius until we get enough items or run out of options
    for (int i = currentIndex + 1; i < _radiusSteps.length; i++) {
      final nextRadius = _radiusSteps[i];

      // Check how many reports exist in this radius
      final count = await _repository.countReportsInRadius(
        latitude: _userLatitude!,
        longitude: _userLongitude!,
        radiusKm: nextRadius,
      );

      log('Checking radius ${nextRadius}km: $count reports available');

      if (count >= _minItemsBeforeExpand) {
        // Found a radius with enough items, fetch them
        _currentRadiusKm = nextRadius;

        final data = await _repository.fetchUnifiedFeed(
          userId: _currentUserId,
          latitude: _userLatitude,
          longitude: _userLongitude,
          radiusKm: nextRadius,
          limit: _pageSize,
          offset: 0,
        );

        log('Expanded to ${nextRadius}km radius, got ${data.length} items');
        return data.map((json) => UnifiedFeedItem.fromJson(json)).toList();
      }
    }

    // No radius had enough items, use the largest one
    final maxRadius = _radiusSteps.last;
    if (_currentRadiusKm != maxRadius) {
      _currentRadiusKm = maxRadius;

      final data = await _repository.fetchUnifiedFeed(
        userId: _currentUserId,
        latitude: _userLatitude,
        longitude: _userLongitude,
        radiusKm: maxRadius,
        limit: _pageSize,
        offset: 0,
      );

      log('Expanded to max radius ${maxRadius}km, got ${data.length} items');
      return data.map((json) => UnifiedFeedItem.fromJson(json)).toList();
    }

    return null;
  }

  /// Toggle thank status for a report (optimistic update)
  Future<void> toggleThank(String reportId) async {
    if (_currentUserId == null) {
      log('Cannot thank: user not authenticated');
      return;
    }

    final index = _items.indexWhere((item) => item.id == reportId);
    if (index == -1) {
      log('Cannot thank: item not found');
      return;
    }

    final item = _items[index];
    
    // Can only thank reports, not events
    if (item is! ReportFeedItem) {
      log('Cannot thank: item is not a report');
      return;
    }

    // Cannot thank own report
    if (item.userId == _currentUserId) {
      log('Cannot thank own report');
      return;
    }

    // Optimistic update
    final newThanked = !item.userHasThanked;
    final newCount = item.thanksCount + (newThanked ? 1 : -1);

    _items[index] = item.copyWith(
      userHasThanked: newThanked,
      thanksCount: newCount,
    );
    notifyListeners();

    log('Optimistic thank update: thanked=$newThanked, count=$newCount');

    try {
      final actuallyThanked =
          await _repository.toggleThank(reportId, _currentUserId!);

      // Verify server state matches optimistic update
      if (actuallyThanked != newThanked) {
        log('Server state differs from optimistic update, correcting');
        _items[index] = item.copyWith(
          userHasThanked: actuallyThanked,
          thanksCount: item.thanksCount + (actuallyThanked ? 1 : -1),
        );
        notifyListeners();
      }
    } catch (e) {
      // Revert on error
      log('Error toggling thank, reverting: $e');
      _items[index] = item;
      notifyListeners();
    }
  }

  /// Toggle join status for an event (optimistic update)
  Future<void> toggleJoinEvent(String eventId) async {
    if (_currentUserId == null) {
      log('Cannot join event: user not authenticated');
      return;
    }

    final index = _items.indexWhere((item) => item.id == eventId);
    if (index == -1) {
      log('Cannot join event: item not found');
      return;
    }

    final item = _items[index];
    
    // Can only join events, not reports
    if (item is! EventFeedItem) {
      log('Cannot join: item is not an event');
      return;
    }

    // Cannot join own event (organizers are already participating)
    if (item.userId == _currentUserId) {
      log('Cannot join own event');
      return;
    }

    // Cannot join if event is full and not already joined
    if (item.isFull && !item.userHasJoined) {
      log('Cannot join: event is full');
      return;
    }

    // Optimistic update
    final newJoined = !item.userHasJoined;
    final newCount = item.attendeeCount + (newJoined ? 1 : -1);

    _items[index] = item.copyWith(
      userHasJoined: newJoined,
      attendeeCount: newCount,
    );
    notifyListeners();

    log('Optimistic join update: joined=$newJoined, count=$newCount');

    try {
      final actuallyJoined =
          await _repository.toggleJoinEvent(eventId, _currentUserId!);

      // Verify server state matches optimistic update
      if (actuallyJoined != newJoined) {
        log('Server state differs from optimistic update, correcting');
        _items[index] = item.copyWith(
          userHasJoined: actuallyJoined,
          attendeeCount: item.attendeeCount + (actuallyJoined ? 1 : -1),
        );
        notifyListeners();
      }
    } catch (e) {
      // Revert on error
      log('Error toggling event join, reverting: $e');
      _items[index] = item;
      notifyListeners();
    }
  }

  /// Check if current user can thank a specific report
  bool canThank(ReportFeedItem item) {
    return _currentUserId != null && item.userId != _currentUserId;
  }

  /// Check if current user can join a specific event
  bool canJoin(EventFeedItem item) {
    if (_currentUserId == null) return false;
    if (item.userId == _currentUserId) return false; // Organizer
    if (item.isFull && !item.userHasJoined) return false;
    if (item.status == 'cancelled' || item.status == 'completed') return false;
    return true;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
