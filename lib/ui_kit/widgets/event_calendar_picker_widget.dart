// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:get/get.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:intl/intl.dart';

// import '../theme/theme_controller.dart';
// import '../app/controller/event_caledar.dart';
// import '../constant/event_color.dart';
// import '../constant/event_image.dart';
// import '../theme/event_theme.dart';


// class HorizontalCalendarWidget extends StatefulWidget {
//   const HorizontalCalendarWidget({super.key});


//   @override
//   State<HorizontalCalendarWidget> createState() => _HorizontalCalendarWidgetState();
// }

// class _HorizontalCalendarWidgetState extends State<HorizontalCalendarWidget> {
//   final CalendarController calendarController = Get.put(CalendarController());
//   late ThemeData theme;
//   final ThemeController themeController = Get.put(ThemeController());
//   @override
//   void initState() {
//     super.initState();
//     theme = Get.isDarkMode ? EventTheme.eventDarkTheme : EventTheme.eventLightTheme;
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           color:  themeController.isDarkMode ? blackModeBorder : eventLightBackgroundColor,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Obx(() => Text(
//                   DateFormat('MMMM yyyy').format(calendarController.focusedDay.value),
//                   style: theme.textTheme.bodyLarge?.copyWith(
//                     fontWeight: FontWeight.w500,
//                     color: themeController.isDarkMode ? eventLightBackgroundColor : eventOnBodingTitle,
//                   ),
//                 )),
//                 Row(
//                   children: [
//                     IconButton(
//                       icon:SvgPicture.asset(
//                         leftCreate,width: 11.67,height: 11.67,colorFilter: ColorFilter.mode(
//        themeController.isDarkMode ? eventLightBackgroundColor : eventOnBodingTitle,
//           BlendMode.srcIn,
//           ),
//                       ),
//                       onPressed: () {
//                         calendarController.goToPreviousMonth();
//                       },
//                     ),
//                     IconButton(
//                       icon:SvgPicture.asset(
//                         rightCreate,width: 11.67,height: 11.67,colorFilter: ColorFilter.mode(
//                       themeController.isDarkMode ? eventLightBackgroundColor : eventOnBodingTitle,
//                         BlendMode.srcIn,
//                       ),

//                       ),
//                       onPressed: () {
//                         calendarController.goToNextMonth();
//                       },
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.only(top: 15,bottom: 20),
//           decoration: BoxDecoration(
// color:  themeController.isDarkMode ? blackModeBorder : eventLightBackgroundColor,
//             borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24),bottomRight: Radius.circular(24)),
//           ),
//           child: Obx(() => TableCalendar(
//             firstDay: DateTime.utc(2020, 1, 1),
//             lastDay: DateTime.utc(2030, 12, 31),
//             focusedDay: calendarController.focusedDay.value,
//             selectedDayPredicate: (day) {
//               return isSameDay(calendarController.selectedDay.value, day);
//             },
//             onDaySelected: (selectedDay, focusedDay) {
//               calendarController.onDaySelected(selectedDay, focusedDay);
//             },
//             calendarFormat: CalendarFormat.week,
//             headerVisible: false,
//             enabledDayPredicate: (day) {
//               return day.isAfter(DateTime.now()) || isSameDay(day, DateTime.now());
//             },
//             daysOfWeekStyle: const DaysOfWeekStyle(
//               weekdayStyle: TextStyle(color: eventVersion),
//               weekendStyle: TextStyle(color: eventVersion),
//             ),
//             calendarStyle: const CalendarStyle(
//               isTodayHighlighted: false,
//               selectedDecoration: BoxDecoration(
//                 color: policyText,
//                 shape: BoxShape.circle,
//               ),
//               rangeEndTextStyle: TextStyle(color: eventVersion),
//               rangeStartTextStyle:TextStyle(color: eventVersion),
//               outsideDaysVisible: false,
//               disabledTextStyle: TextStyle(color: eventVersion),
//             ),
//           )),
//         ),
//       ],
//     );
//   }
// }
