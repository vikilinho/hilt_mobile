import 'package:flutter/material.dart';
import 'package:hilt_mobile/src/l10n/app_localizations.dart';

Widget buildTestApp(
  Widget child, {
  Locale locale = const Locale('en'),
  bool debugShowCheckedModeBanner = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
