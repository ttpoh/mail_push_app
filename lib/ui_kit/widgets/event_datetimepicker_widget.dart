// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'package:nb_utils/nb_utils.dart';
// import '../constant/event_color.dart';
// import '../constant/event_image.dart';
// import '../theme/event_theme.dart';

// class CustomDateTimePicker extends StatefulWidget {
//   final DateTime selectedDateTime;
//   final VoidCallback onTap;
//   const CustomDateTimePicker({
//     Key? key,
//     required this.selectedDateTime,
//     required this.onTap,
//   }) : super(key: key);

//   @override
//   State<CustomDateTimePicker> createState() => CustomDateTimePickerState();
// }

// class CustomDateTimePickerState extends State<CustomDateTimePicker> {
//   late ThemeData theme;
//   @override
//   void initState() {
//     super.initState();
//     theme = Get.isDarkMode ? EventTheme.eventDarkTheme : EventTheme.eventLightTheme;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: widget.onTap,
//       child: Padding(
//         padding: const EdgeInsets.only(left: 10, right: 15),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.start,
//           children: [
//             Container(
//               height: 48,
//               width: 48,
//               decoration: BoxDecoration(
//                 color: Get.isDarkMode ? Colors.white : backgroundTextFiled,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     DateFormat('d').format(widget.selectedDateTime),
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       fontWeight: FontWeight.w700,
//                       color: Get.isDarkMode ? eventOnBodingTitle : eventOnBodingTitle,
//                     ),
//                   ),
//                   Text(
//                     DateFormat('MMM').format(widget.selectedDateTime),
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       fontWeight: FontWeight.w400,
//                       fontSize: 10,
//                       color: eventVersion,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             20.width,
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   DateFormat('EEEE').format(widget.selectedDateTime),
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.w700,
//                     color: Get.isDarkMode ? eventLightBackgroundColor : eventOnBodingTitle,
//                   ),
//                 ),
//                 Text(
//                   '${DateFormat('h:mm a').format(widget.selectedDateTime)} - End',
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontWeight: FontWeight.w400,
//                     color: eventVersion,
//                   ),
//                 ),
//               ],
//             ),
//             const Spacer(),
//             SvgPicture.asset(
//               calendarAddIcon,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
