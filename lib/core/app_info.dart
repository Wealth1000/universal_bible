/// Central app metadata. Single source of truth for the version shown in
/// the UI (settings, welcome). Bump here on release.
///
/// TODO: read from pubspec at build time (e.g. package_info_plus) once pub
/// dependencies can be changed again.
class AppInfo {
  AppInfo._();

  static const String appName = 'Universal Bible';
  static const String version = '1.0.9';
}
