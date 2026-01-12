/// App SVG Icons - Centralized icon path management
///
/// This class provides a type-safe way to reference SVG icons throughout the app.
/// All icon paths are validated at compile time.
library;

class AppIcons {
  AppIcons._();

  static const String _basePath = 'assets/icons';

  // ─── Navigation ─────────────────────────────────────────────────────────────
  static const String home = '$_basePath/home.svg';
  static const String map = '$_basePath/map.svg';
  static const String profile = '$_basePath/profile.svg';
  static const String settings = '$_basePath/settings.svg';

  // ─── Actions ────────────────────────────────────────────────────────────────
  static const String camera = '$_basePath/camera.svg';
  static const String report = '$_basePath/report.svg';
  static const String upload = '$_basePath/upload.svg';
  static const String search = '$_basePath/search.svg';

  // ─── Pollution Types ────────────────────────────────────────────────────────
  static const String pollutionPlastic = '$_basePath/pollution_plastic.svg';
  static const String pollutionOil = '$_basePath/pollution_oil.svg';
  static const String pollutionDebris = '$_basePath/pollution_debris.svg';
  static const String pollutionSewage = '$_basePath/pollution_sewage.svg';
  static const String pollutionFishingGear =
      '$_basePath/pollution_fishing_gear.svg';
  static const String pollutionOther = '$_basePath/pollution_other.svg';

  // ─── Status ─────────────────────────────────────────────────────────────────
  static const String success = '$_basePath/success.svg';
  static const String warning = '$_basePath/warning.svg';
  static const String error = '$_basePath/error.svg';
  static const String info = '$_basePath/info.svg';

  // ─── Permissions ────────────────────────────────────────────────────────────
  static const String permissionCamera = '$_basePath/permission_camera.svg';
  static const String permissionLocation = '$_basePath/permission_location.svg';
  static const String permissionPhotos = '$_basePath/permission_photos.svg';

  // ─── Branding ───────────────────────────────────────────────────────────────
  static const String logo = '$_basePath/logo.svg';
  static const String logoIcon = '$_basePath/logo_icon.svg';

  // ─── Empty States ───────────────────────────────────────────────────────────
  static const String emptyReports = '$_basePath/empty_reports.svg';
  static const String emptyEvents = '$_basePath/empty_events.svg';
  static const String noConnection = '$_basePath/no_connection.svg';

  // ─── Marine/Ocean Themed ────────────────────────────────────────────────────
  static const String wave = '$_basePath/wave.svg';
  static const String fish = '$_basePath/fish.svg';
  static const String anchor = '$_basePath/anchor.svg';
  static const String ship = '$_basePath/ship.svg';
  static const String ocean = '$_basePath/ocean.svg';
  static const String container = '$_basePath/container.svg';
}
