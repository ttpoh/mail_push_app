// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:get/get.dart';
// // import '../app/controller/event_bottom_bar_controller.dart';
// // import '../app/view/event_favourite.dart';
// // import '../app/view/event_home_screen.dart';
// // import '../app/view/event_profile.dart';
// // import '../app/view/event_search_screen.dart';
// // import '../app/view/event_upcoming_screen.dart';
// import '../constant/event_color.dart';
// import '../constant/event_image.dart';
// import '../constant/event_text.dart';

// class EventBottomScreen extends StatelessWidget {
//   const EventBottomScreen({super.key});

//   Widget buildBottomNavigationMenu(BuildContext context, BottomBarController landingPageController) {
//     return Obx(() {
//       // Obx will rebuild the BottomNavigationBar whenever the currentIndex changes in the controller
//       return MediaQuery(
//         data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
//         child: BottomNavigationBar(
//           backgroundColor: Get.isDarkMode ? eventOnBodingTitle : eventLightBackgroundColor,
//           type: BottomNavigationBarType.fixed,
//           showUnselectedLabels: true,
//           showSelectedLabels: true,
//           elevation: 12,
//           onTap: landingPageController.changeTabIndex,
//           currentIndex: landingPageController.currentIndex.value,
//           unselectedItemColor: eventVersion.withOpacity(0.7),
//           selectedItemColor: skipColor,
//           selectedFontSize: 11,
//           unselectedFontSize: 10,
//           selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
//           unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
//           items: [
//             _bottomNavbarItem(homeIconEvent, homeIconEventActive, homeText),
//             _bottomNavbarItem(searchIconEvent, searchIconEventActive, searchText),
//             _bottomNavbarItem(heartIconEvent, heartIconEventActive, favoritesText),
//             _bottomNavbarItem(ticketIconEvent, ticketIconEventActive, ticketText),
//             _bottomNavbarItem(profileIconEvent, profileIconEventActive, profileText),
//           ],
//         ),
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ThemeData theme = Theme.of(context);
//     final BottomBarController controller = Get.put(BottomBarController());

//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       bottomNavigationBar: buildBottomNavigationMenu(context, controller),
//       body: Obx(() {

//         return IndexedStack(
//           index: controller.currentIndex.value,
//           children: const [
//             EventHomeScreen(),
//             EventSearchScreen(),
//             EventFavouriteScreen(),
//             EventUpcomingScreen(),
//             EventProfileScreen(),
//           ],
//         );
//       }),
//     );
//   }

//   // Helper method to create a BottomNavigationBarItem
//   BottomNavigationBarItem _bottomNavbarItem(String assetName, String activeAsset, String label) {
//     return BottomNavigationBarItem(
//       icon: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 4.0),
//         child: SvgPicture.asset(
//           assetName,
//           width: 26,
//           height: 26,
//           colorFilter: ColorFilter.mode(Colors.grey.shade600, BlendMode.srcIn),
//         ),
//       ),
//       activeIcon: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 4.0),
//         child: SvgPicture.asset(
//           activeAsset,
//           width: 28,
//           height: 28,
//           colorFilter: const ColorFilter.mode(skipColor, BlendMode.srcIn),
//         ),
//       ),
//       label: label,
//     );
//   }
// }
