import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constant/event_color.dart';

/// UI kit 아이콘 위젯.
/// - SVG(asset) 또는 머티리얼 IconData(icon) 중 하나를 지정해 사용.
/// - 로그인 버튼 등 인라인 용도에서는 배경/테두리를 투명으로 둬서 장식 아이콘처럼 사용.
/// - urlString 또는 onPressed 중 하나가 있으면 탭 가능, 둘 다 없으면 단순 표시.
class EventCommonIconScreen extends StatelessWidget {
  final String? asset;               // SVG 경로
  final IconData? icon;              // 머티리얼 아이콘
  final double size;                 // 아이콘 크기 (기본 20)
  final Color? color;                // 아이콘 색
  final Color? bgColor;              // 배경색(미지정 시 투명)
  final Color? borderColor;          // 테두리색(미지정 시 투명)
  final EdgeInsetsGeometry margin;   // 바깥 여백(인라인 기본 0)
  final String? urlString;           // 탭 시 열 URL
  final VoidCallback? onPressed;     // 탭 핸들러

  const EventCommonIconScreen({
    Key? key,
    this.asset,
    this.icon,
    this.size = 20,
    this.color,
    this.bgColor,
    this.borderColor,
    this.margin = EdgeInsets.zero,
    this.urlString,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isDarkMode;
    final bg = bgColor ?? Colors.transparent;
    final border = borderColor ?? Colors.transparent;

    final Widget iconWidget = asset != null
        ? SvgPicture.asset(
            asset!,
            width: size,
            height: size,
            // SVG 색 강제 적용이 필요하면 ColorFilter 사용
            colorFilter: color != null
                ? ColorFilter.mode(color!, BlendMode.srcIn)
                : null,
          )
        : Icon(icon ?? Icons.help_outline, size: size, color: color);

    // 탭 액션(우선순위: onPressed > urlString > null)
    VoidCallback? tap;
    if (onPressed != null) {
      tap = onPressed;
    } else if (urlString != null) {
      tap = () async {
        final Uri url = Uri.parse(urlString!);
        if (!await launchUrl(url)) {
          throw Exception('Could not launch $url');
        }
      };
    }

    final decorated = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg == Colors.transparent
            ? (isDark ? Colors.transparent : Colors.transparent)
            : bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: border == Colors.transparent
              ? Colors.transparent
              : (isDark ? greyColor : border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6), // 아이콘 주변 여백
        child: iconWidget,
      ),
    );

    if (tap == null) return decorated; // 단순 장식

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: tap,
      child: decorated,
    );
  }
}

/// ✅ 하위 호환: 기존 함수 API 유지.
/// 내부적으로 EventCommonIconScreen을 사용합니다.
Widget buildIconButton(
  String imagePath,
  Color bgColor,
  Color borderColor,
  String urlString,
) {
  return EventCommonIconScreen(
    asset: imagePath,
    size: 17,
    bgColor: Get.isDarkMode ? eventOnBodingTitle : bgColor,
    borderColor: Get.isDarkMode ? greyColor : borderColor,
    margin: const EdgeInsets.all(10),
    urlString: urlString,
  );
}
