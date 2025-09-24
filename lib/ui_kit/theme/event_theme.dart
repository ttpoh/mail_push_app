import '../constant/event_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nb_utils/nb_utils.dart';

abstract class EventTheme {
  static const double letterSpacing = 0.3;
  static const double letterHeight = 1.5;
  static var fontFamily = GoogleFonts.notoSansJp().fontFamily;

  static final ThemeData eventLightTheme = ThemeData(
    scaffoldBackgroundColor: eventLightBackgroundColor,
    primaryColor: eventDarkButtonColor,
    primaryColorDark: eventPrimaryColor,
    hintColor: eventAccentColor,
    hoverColor: Colors.white54,
    dividerColor: eventLightDividerColor,
    fontFamily: fontFamily,
    inputDecorationTheme:
        const InputDecorationTheme(border: OutlineInputBorder()),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: eventLightBackgroundColor),
    appBarTheme: const AppBarTheme(
      actionsIconTheme: IconThemeData(color: Colors.black),
      iconTheme: IconThemeData(color: Colors.black),
      backgroundColor: whiteColor,
      titleTextStyle: TextStyle(color: Colors.black),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.black),
    colorScheme: const ColorScheme.light(primary: eventPrimaryColor),
    cardTheme: const CardThemeData(color: eventLightCardColor),
    cardColor: eventLightCardColor,
    iconTheme: const IconThemeData(color: Colors.black),
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: eventLightBackgroundColor),
    primaryTextTheme: TextTheme(
      titleLarge: TextStyle(
        color: eventLightPrimaryTextColor,
        letterSpacing: letterSpacing,
        height: letterHeight,
        fontFamily: fontFamily,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        color: eventLightPrimaryTextColor,
        letterSpacing: letterSpacing,
        height: letterHeight,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 48.0,
        fontFamily: fontFamily,
        color: eventLightPrimaryTextColor,
      ),
      displayMedium: TextStyle(
        fontSize: 40.0,
        color: eventLightPrimaryTextColor,
        fontFamily: fontFamily,
      ),
      displaySmall: TextStyle(
        fontSize: 32.0,
        color: eventLightPrimaryTextColor,
        fontFamily: fontFamily,
      ),
      headlineMedium: TextStyle(
        fontSize: 24.0,
        fontFamily: fontFamily,
        color: eventLightPrimaryTextColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 20.0,
        color: eventLightPrimaryTextColor,
        fontFamily: fontFamily,
      ),
      titleLarge: TextStyle(
        fontSize: 18.0,
        color: eventLightPrimaryTextColor,
        fontFamily: fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: 16.0,
        color: eventLightPrimaryTextColor,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0,
        color: eventLightPrimaryTextColor,
        fontFamily: fontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: 12.0,
        fontFamily: fontFamily,
        color: eventLightPrimaryTextColor,
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    popupMenuTheme: const PopupMenuThemeData(color: eventLightBackgroundColor),
  ).copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: OpenUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  static final ThemeData eventDarkTheme = ThemeData(
    scaffoldBackgroundColor: eventDarkBackgroundColor,
    highlightColor: eventPrimaryColor,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: eventDarkBackgroundColor),
    appBarTheme: const AppBarTheme(
      actionsIconTheme: IconThemeData(color: whiteColor),
      titleTextStyle: TextStyle(color: Colors.white),
      backgroundColor: eventDarkBackgroundColor,
      iconTheme: IconThemeData(color: whiteColor),
    ),
    primaryColor: eventPrimaryColor,
    dividerColor: eventDarkDividerColor.withOpacity(0.3),
    primaryColorDark: eventPrimaryColor,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: eventLightBackgroundColor,
      selectionColor: eventLightBackgroundColor,
    ),
    hoverColor: Colors.black12,
    fontFamily: fontFamily,
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: eventDarkBackgroundColor),
    primaryTextTheme: TextTheme(
      titleLarge: TextStyle(
        color: eventLightBackgroundColor,
        letterSpacing: letterSpacing,
        fontFamily: fontFamily,
        height: letterHeight,
      ),
      labelSmall: TextStyle(
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        height: letterHeight,
      ),
    ),
    cardTheme: const CardThemeData(color: eventDarkCardColor),
    cardColor: eventDarkCardColor,
    iconTheme: const IconThemeData(color: eventLightBackgroundColor),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 48.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
      displayMedium: TextStyle(
        fontSize: 40.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
      displaySmall: TextStyle(
        fontSize: 32.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        fontSize: 24.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
      headlineSmall: TextStyle(
        fontSize: 20.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
      titleLarge: TextStyle(
        fontSize: 18.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: 16.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: 12.0,
        color: eventLightBackgroundColor,
        fontFamily: fontFamily,
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(color: eventDarkBackgroundColor),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    colorScheme: const ColorScheme.dark(
      primary: eventPrimaryColor,
      onPrimary: eventLightBackgroundColor,
    ).copyWith(secondary: eventAccentColor),
  ).copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: OpenUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
