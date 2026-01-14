import 'package:flutter/foundation.dart';
import '../../core/utils/logger.dart';

/// A mixin that provides common async state management functionality.
///
/// Use this mixin to reduce boilerplate for loading/error states in providers.
///
/// Example usage:
/// ```dart
/// class MyProvider extends ChangeNotifier with AsyncStateMixin {
///   Future<void> fetchData() async {
///     await executeAsync(
///       action: () async {
///         // Your async operation
///       },
///       operationName: 'fetchData',
///     );
///   }
/// }
/// ```
mixin AsyncStateMixin on ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  /// Whether an async operation is in progress
  bool get isLoading => _isLoading;

  /// The last error message, or null if no error
  String? get error => _error;

  /// Whether there's currently an error
  bool get hasError => _error != null;

  /// Clears the current error
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Sets the loading state
  @protected
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Sets the error state
  @protected
  void setError(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  /// Executes an async action with automatic loading/error state management.
  ///
  /// [action] - The async function to execute
  /// [operationName] - Name used for logging errors
  /// [onError] - Optional callback when error occurs (receives the exception)
  /// [rethrowError] - Whether to rethrow the error after handling (default: false)
  ///
  /// Returns true if the operation succeeded, false if it failed.
  @protected
  Future<bool> executeAsync({
    required Future<void> Function() action,
    required String operationName,
    void Function(Object error)? onError,
    bool rethrowError = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('$operationName failed: $e');
      onError?.call(e);
      if (rethrowError) rethrow;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Executes an async action that returns a value with automatic state management.
  ///
  /// [action] - The async function to execute
  /// [operationName] - Name used for logging errors
  /// [fallback] - Value to return if the operation fails
  /// [onError] - Optional callback when error occurs
  ///
  /// Returns the result of the action, or [fallback] if it fails.
  @protected
  Future<T> executeAsyncWithResult<T>({
    required Future<T> Function() action,
    required String operationName,
    required T fallback,
    void Function(Object error)? onError,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await action();
      return result;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('$operationName failed: $e');
      onError?.call(e);
      return fallback;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// A provider that manages a single list of items with loading/error states.
///
/// Useful for simple list-based providers. Extend this class and implement
/// [fetchItems] to load your data.
///
/// Example:
/// ```dart
/// class BadgesProvider extends ListProvider<BadgeEntity> {
///   final BadgeDataSource _dataSource;
///
///   BadgesProvider(this._dataSource);
///
///   @override
///   Future<List<BadgeEntity>> fetchItems() async {
///     return await _dataSource.fetchBadges();
///   }
/// }
/// ```
abstract class ListProvider<T> extends ChangeNotifier with AsyncStateMixin {
  List<T> _items = [];

  /// The current list of items
  List<T> get items => _items;

  /// Whether the list is empty
  bool get isEmpty => _items.isEmpty;

  /// The number of items
  int get itemCount => _items.length;

  /// Override this method to fetch items from your data source
  @protected
  Future<List<T>> fetchItems();

  /// Loads items from the data source
  Future<void> load() async {
    await executeAsync(
      action: () async {
        _items = await fetchItems();
      },
      operationName: 'load${T.toString()}s',
    );
  }

  /// Refreshes the list by clearing and reloading
  Future<void> refresh() async {
    _items = [];
    notifyListeners();
    await load();
  }

  /// Clears all items
  void clear() {
    _items = [];
    notifyListeners();
  }
}
