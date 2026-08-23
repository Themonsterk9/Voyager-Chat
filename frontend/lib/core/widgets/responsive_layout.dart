import 'package:flutter/material.dart';

enum FormFactor { mobile, tablet, desktop }

class ResponsiveBreakpoints {
  static const double mobileMax = 600.0;
  static const double tabletMax = 1000.0;

  static FormFactor getFormFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileMax) {
      return FormFactor.mobile;
    } else if (width < tabletMax) {
      return FormFactor.tablet;
    } else {
      return FormFactor.desktop;
    }
  }

  static bool isMobile(BuildContext context) =>
      getFormFactor(context) == FormFactor.mobile;

  static bool isTablet(BuildContext context) =>
      getFormFactor(context) == FormFactor.tablet;

  static bool isDesktop(BuildContext context) =>
      getFormFactor(context) == FormFactor.desktop;

  static bool isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMax;
}

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.tabletMax) {
          if (desktop != null) return desktop!(context);
          if (tablet != null) return tablet!(context);
          return mobile(context);
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.mobileMax) {
          if (tablet != null) return tablet!(context);
          return mobile(context);
        } else {
          return mobile(context);
        }
      },
    );
  }
}
