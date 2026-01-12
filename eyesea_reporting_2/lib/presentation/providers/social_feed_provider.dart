import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../../core/services/connectivity_service.dart';
import '../../data/datasources/social_feed_data_source.dart';
import '../../domain/entities/feed_item.dart';

/// Filter options for the social feed
enum FeedFilter { world, country, city }

/// Provider for managing social feed state
class SocialFeedProvider extends ChangeNotifier {
  final SocialFeedDataSource _dataSource;
  final ConnectivityService _connectivityService;

  List<FeedItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  FeedFilter _currentFilter = FeedFilter.world;
  String? _filterCountry;
  String? _filterCity;
  String? _currentUserId;
  StreamSubscription<bool>? _connectivitySubscription;

  static const int _pageSize = 20;
  int _currentOffset = 0;

  SocialFeedProvider(this._dataSource, this._connectivityService) {
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
  List<FeedItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  FeedFilter get currentFilter => _currentFilter;
  bool get isOffline => !_connectivityService.isOnline;
  String? get filterCountry => _filterCountry;
  String? get filterCity => _filterCity;

  /// Set the current user info for thank tracking and location filtering
  void setCurrentUser(String? userId, String? country, String? city) {
    _currentUserId = userId;
    _filterCountry = country;
    _filterCity = city;
    log('Set current user: id=$userId, country=$country, city=$city');
  }

  /// Update the current filter and reload feed
  void setFilter(FeedFilter filter) {
    if (_currentFilter != filter) {
      log('Filter changed from $_currentFilter to $filter');
      _currentFilter = filter;
      loadFeed(refresh: true);
    }
  }

  /// Load or refresh the social feed
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
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    if (refresh) {
      // Don't clear items immediately to avoid flash
      _error = null;
    }
    notifyListeners();

    try {
      String? country;
      String? city;

      switch (_currentFilter) {
        case FeedFilter.world:
          country = null;
          city = null;
          break;
        case FeedFilter.country:
          country = _filterCountry;
          city = null;
          break;
        case FeedFilter.city:
          country = _filterCountry;
          city = _filterCity;
          break;
      }

      log('Loading feed: filter=$_currentFilter, country=$country, city=$city, offset=$_currentOffset');

      final data = await _dataSource.fetchFeed(
        userId: _currentUserId,
        country: country,
        city: city,
        limit: _pageSize,
        offset: _currentOffset,
      );

      final newItems = data.map((json) => FeedItem.fromJson(json)).toList();

      if (refresh) {
        _items = newItems;
      } else {
        _items = [..._items, ...newItems];
      }

      _hasMore = newItems.length >= _pageSize;
      _currentOffset += newItems.length;
      _error = null;

      log('Loaded ${newItems.length} items, total: ${_items.length}, hasMore: $_hasMore');
    } catch (e) {
      log('Error loading feed: $e');
      _error = 'Failed to load feed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
          await _dataSource.toggleThank(reportId, _currentUserId!);

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

  /// Check if current user can thank a specific item
  bool canThank(FeedItem item) {
    return _currentUserId != null && item.userId != _currentUserId;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
