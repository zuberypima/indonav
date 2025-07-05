// import 'package:flutter/widgets.dart';

// class AppConstants extends InheritedWidget {
//   static AppConstants? of(BuildContext context) =>
//       context.dependOnInheritedWidgetOfExactType<AppConstants>();
//   const AppConstants({required super.child, super.key});
//   // final String privateKeyiOS =
//   //     "<<Your private iOS woosmap key>>"; // Replace with your key
//   final String privateKeyAndroid =
//       "woos-271fa195-1819-37d1-a1d1-b7544e53a1e2"; // Replace with your key
//   @override
//   bool updateShouldNotify(AppConstants oldWidget) => false;
// }

import 'package:flutter/widgets.dart';

class AppConstants extends InheritedWidget {
  static AppConstants? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppConstants>();
  const AppConstants({required super.child, super.key});
  final String mapboxAccessToken =
      "<<Your Mapbox public access token>>"; // Replace with your token
  @override
  bool updateShouldNotify(AppConstants oldWidget) => false;
}
