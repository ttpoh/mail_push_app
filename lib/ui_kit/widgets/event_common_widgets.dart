// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:get/get.dart';
// import 'package:nb_utils/nb_utils.dart';

// import '../constant/event_color.dart';
// import '../constant/event_image.dart';
// import '../constant/event_text.dart';
// import '../theme/event_theme.dart';

// InputDecoration eventInputDecoration(
//     BuildContext context, {
//       String? prefixIcon,
//       String? suffixIcon,
//       Widget? suffixWidget,
//       String? labelText,
//       double? borderRadius,
//       String? hintText,
//       bool? isSvg,
//       Color? fillColor,
//       Color? hintColor,
//       Color? prefixIconColor,
//       double? leftContentPadding,
//       double? rightContentPadding,
//       double? topContentPadding,
//       double? bottomContentPadding,
//       double? borderWidth,
//       VoidCallback? onSuffixPressed,
//       TextStyle? hintStyle,
//     })
// {
//   return InputDecoration(
//     counterText: "",
//     border: InputBorder.none,
//     enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(16),
//       borderSide: BorderSide(color: Get.isDarkMode ? blackModeBorder : backgroundTextFiled, width: borderWidth ?? 1.0),
//        ),
//     contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
//     labelText: labelText,
//     labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
//         color: hintColor ?? (Get.isDarkMode ? white : eventVersion),
//         fontWeight: FontWeight.w400,
//         fontFamily: EventTheme.fontFamily),
//     alignLabelWithHint: true,
//     hintText: hintText.validate(),
//     hintStyle: hintStyle ??
//         Theme.of(context).textTheme.bodyLarge?.copyWith(
//             color: hintColor ?? eventVersion,
//             fontWeight: FontWeight.w400,
//             fontFamily: EventTheme.fontFamily),
//     isDense: true,
//     prefixIcon: Padding(
//       padding: const EdgeInsets.only(left: 15, right: 10),
//       child: SvgPicture.asset(
//         prefixIcon!, // SVG image
//         width: 18,
//         height: 18,
//         colorFilter: ColorFilter.mode(
//           prefixIconColor ?? (Get.isDarkMode ? eventVersion : eventVersion),
//           BlendMode.srcIn,
//         ),
//       ),
//     ),
//     prefixIconConstraints: const BoxConstraints(
//       minWidth: 20,
//       minHeight: 20,
//     ),
//     suffixIcon: suffixWidget ?? (suffixIcon != null
//         ? IconButton(

//       icon: SvgPicture.asset(
//         suffixIcon == "visible"
//             ? eyeOpen
//             : eyeClose,
//         color: eventVersion,
//         width: 24,
//         height: 24,
//       ),
//       onPressed: onSuffixPressed,
//     )
//         : null),

//     suffixIconConstraints: const BoxConstraints(
//       minWidth: 20,
//       minHeight: 20,
//     ),
//     focusedErrorBorder: OutlineInputBorder(
//       borderRadius: const BorderRadius.all(Radius.circular(16)),
//       borderSide: BorderSide(color: Colors.red, width: borderWidth ?? 1.0),
//     ),
//     errorBorder: OutlineInputBorder(
//       borderRadius: const BorderRadius.all(Radius.circular(16)),
//       borderSide: BorderSide(color: Colors.red, width: borderWidth ?? 1.0),
//     ),
//     focusedBorder: OutlineInputBorder(
//       borderRadius: const BorderRadius.all(Radius.circular(16)),
//       borderSide: BorderSide(color: skipNightColor, width: borderWidth ?? 1),
//     ),

//     errorStyle: primaryTextStyle(
//         color: Colors.red, size: 13, fontFamily: EventTheme.fontFamily),
//     filled: true,
//     fillColor: Get.isDarkMode ? blackModeBorder : backgroundTextFiled,
//   );
// }
// Widget searchTextField(){
//   return  Padding(
//     padding: const EdgeInsets.only(left: 12,right: 12),
//     child: TextFormField(

//       decoration: InputDecoration(
//         prefixIcon: Padding(
//           padding: const EdgeInsets.all(18.0),
//           child: SvgPicture.asset(
//             searchWhite,
//             colorFilter: ColorFilter.mode(
//               Get.isDarkMode ? eventLightBackgroundColor : eventLightBackgroundColor,
//               BlendMode.srcIn,
//             ),
//           ),
//         ),
//         suffixIcon: Padding(
//           padding: const EdgeInsets.all(18.0),
//           child: Image.asset(
//             Get.isDarkMode ? searchCloseBlack : searchCloseWhite,
//           ),
//         ),
//         hintText: searchLocation,
//         contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
//         filled: true,
//         fillColor: Get.isDarkMode ? blackModeBorder : eventLightBackgroundColor,
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(1000),
//           borderSide: const BorderSide(color: Colors.transparent),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(1000),
//           borderSide: const BorderSide(color: Colors.transparent),
//         ),
//       ),
//     )

//   );
// }
// Widget buildTextRow({
//   required String headingText,
//   required String actionText,
//   TextStyle? headingStyle,
//   TextStyle? actionStyle,
//   VoidCallback? onTapAction,
// }) {
//   return Row(
//     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//     children: [
//       Text(headingText, style: headingStyle),
//       Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: onTapAction,
//           child: Text(actionText, style: actionStyle),
//         ),
//       ),
//     ],
//   );
// }
