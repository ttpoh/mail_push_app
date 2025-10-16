// // import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:nb_utils/nb_utils.dart';

// import '../theme/event_theme.dart';

// enum DateCategory { today, yesterday, other }

// Widget eventCommonCacheImageWidget(String? url, double height,
//     {double? width, BoxFit? fit, Color? color}) {
//   if (url.validate().startsWith('http')) {
//     if (isMobile) {
//       // return CachedNetworkImage(
//         placeholder:
//             placeholderWidgetFn() as Widget Function(BuildContext, String)?,
//         imageUrl: '$url',
//         height: height,
//         width: width,
//         color: color,
//         fit: fit ?? BoxFit.cover,
//         errorWidget: (_, __, ___) {
//           return SizedBox(height: height, width: width);
//         },
//       );
//     } else {
//       return Image.network(url!,
//           height: height, width: width, fit: fit ?? BoxFit.cover);
//     }
//   } else {
//     return Image.asset(url!,
//         height: height, width: width, fit: fit ?? BoxFit.cover);
//   }
// }

// Widget? Function(BuildContext, String) placeholderWidgetFn() =>
//     (_, s) => placeholderWidget();

// Widget placeholderWidget() =>
//     Image.asset('assets/placeholder.jpg', fit: BoxFit.cover);

// PreferredSizeWidget homelyCommonAppBarWidget(
//   BuildContext context, {
//   String? titleText,
//   Widget? actionWidget,
//   Widget? actionWidget2,
//   Widget? actionWidget3,
//   Widget? leadingWidget,
//   Color? backgroundColor,
//   bool? isTitleCenter,
//   bool isback = true,
// }) {
//   ThemeData theme =
//       Get.isDarkMode ? EventTheme.eventDarkTheme : EventTheme.eventLightTheme;
//   return AppBar(
//     centerTitle: isTitleCenter ?? true,
//     backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
//     leading: isback
//         ? IconButton(
//             padding: EdgeInsets.zero,
//             icon: const Icon(Icons.arrow_back),
//             onPressed: () {
//               Navigator.pop(context);
//             },
//           )
//         : leadingWidget,
//     actions: [
//       actionWidget ?? const SizedBox(),
//       actionWidget2 ?? const SizedBox(),
//       actionWidget3 ?? const SizedBox()
//     ],
//     title: Text(
//       titleText ?? "",
//       textAlign: TextAlign.center,
//       style: TextStyle(
//           fontSize: 18,
//           fontWeight: FontWeight.w600,
//           fontFamily: EventTheme.fontFamily),
//     ),
//     elevation: 0.0,
//   );
// }
