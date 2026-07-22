import 'package:flutter/widgets.dart';

/// Local layout breakpoints for the Rhapsody screens. Mirrors the app shell's
/// desktop threshold (>= 768px) so the reading column matches the rest of the
/// app. Kept here because Rhapsody was ported from a project with a different
/// core layout module.
bool useDesktopLayoutForContext(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 768;

/// Within the desktop range, tablets get a slightly narrower reading column.
bool isTabletLayout(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= 768 && width < 1024;
}
