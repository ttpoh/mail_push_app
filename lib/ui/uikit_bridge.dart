import 'package:flutter/material.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

/// UI-Kit 토큰을 읽어와 머티리얼과 브릿지
class UiKit {
  static Color primary(BuildContext c) => ec.eventPrimaryColor;
  static Color success(BuildContext c) => ec.greenRight;         // 초록 점
  static Color danger(BuildContext c)  => ec.eventErrorColor;    // 빨강 점
  static Color cardBg(BuildContext c)  => Theme.of(c).cardColor; // eventLight/DarkCardColor
  static Color subtleText(BuildContext c) =>
      Theme.of(c).textTheme.bodySmall?.color?.withOpacity(0.70) ??
      const Color(0x99000000);

  static double radiusLg(BuildContext c) => 18.0;

  static List<BoxShadow> softShadow(Brightness b) => [
        BoxShadow(
          blurRadius: 10,
          offset: const Offset(0, 4),
          color: (b == Brightness.dark
              ? Colors.black.withOpacity(0.35)
              : Colors.black.withOpacity(0.06)),
        ),
      ];
}
