import 'package:flutter/material.dart'
    show AlertDialog, Alignment, AppBar, Axis, BlendMode, Border, BorderRadius, BoxDecoration, BoxShape, BuildContext, Color, ColorFilter, Colors, Column, Container, CrossAxisAlignment, Divider, EdgeInsets, FontWeight, GestureDetector, IconButton, Image, Key, MainAxisAlignment, MainAxisSize, Navigator, Padding, Positioned, PreferredSizeWidget, Row, SingleChildScrollView, Size, SizedBox, Spacer, Stack, State, StatefulWidget, Text, ThemeData, VoidCallback, Widget, kToolbarHeight, showDialog, Theme;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
// import '../../../route/my_route.dart';
import './../theme/theme_controller.dart';

// import '../app/controller/event_appbar_controller.dart';
import '../constant/event_color.dart';
import '../constant/event_image.dart';
import '../constant/event_text.dart';
// import '../theme/event_theme.dart';

class EventCustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String locationTitle;
  final bool eventTitle;
  final bool leadIcon;
  final bool showSearchIcon;
  final bool showFilterIcon;
  final bool showNotificationIcon;
  final bool showShareIcon;
  final bool showFavoriteIcon;
  final bool hasNotificationDot;
  final bool searchClick;
  final double height;
  final Color? backColor;
  final Color? fontColor;
  final bool centerText;
  final bool dotIcon;
  final bool settingIcon;
  final bool skipIcon;
  final String? skipPath;
  final bool noIcon;

  const EventCustomAppBar(
      {Key? key,
      required this.locationTitle,
      this.eventTitle = false,
      this.leadIcon = false,
      this.height = kToolbarHeight,
      this.showSearchIcon = false,
      this.showNotificationIcon = false,
      this.showShareIcon = false,
      this.showFavoriteIcon = false,
      this.hasNotificationDot = false,
      this.centerText = true,
      this.showFilterIcon = false,
      this.dotIcon = false,
      this.settingIcon = false,
      this.backColor,
      this.fontColor,
      this.skipIcon = false,
      this.skipPath,
      this.noIcon = false,
      this.searchClick = false})
      : super(key: key);

  @override
  State<EventCustomAppBar> createState() => _EventCustomAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(height);
}

class _EventCustomAppBarState extends State<EventCustomAppBar> {
  final ThemeController controller = Get.put(ThemeController());
  // final EventAppbarController eventAppbarController = Get.put(EventAppbarController());
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    // 기존 late theme 초기화 코드는 제거했습니다.
  }

  @override
  Widget build(BuildContext context) {
    // ✅ build 시점에 Theme를 안전하게 가져옵니다.
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: true,
      backgroundColor: widget.backColor ??
          (controller.isDarkMode
              ? eventOnBodingTitle
              : eventLightBackgroundColor),
      centerTitle: widget.centerText,
      elevation: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 0, top: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            widget.eventTitle
                ? Text(
                    appBarText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: eventVersion,
                    ),
                  )
                : const SizedBox.shrink(),
            Text(
              widget.locationTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.fontColor ??
                    (controller.isDarkMode
                        ? eventLightBackgroundColor
                        : eventOnBodingTitle),
              ),
            ),
          ],
        ),
      ),
      leading: widget.leadIcon
          ? GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 0),
                child: Image.asset(
                  controller.isDarkMode ? arrowBackDark : arrowBack,
                ),
              ),
            )
          : widget.noIcon == true
              ? Padding(
                  padding: const EdgeInsets.only(top: 15, bottom: 5, left: 20),
                  child: SvgPicture.asset(
                    logoSub,
                  ),
                )
              : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 5, top: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildIcon(widget.showSearchIcon, searchWhite, () {
                  // Get.toNamed(MyRoute.eventSearchFind);
                }),
                widget.showNotificationIcon
                    ? _buildNotificationIcon()
                    : const SizedBox.shrink(),
                _buildIcon(widget.showShareIcon, shareIcon, () {
                  _showShareDialog(context, theme); // ✅ theme 전달
                }),
                widget.showFavoriteIcon
                    ? _buildFavoriteIcon()
                    : const SizedBox.shrink(),
                _buildIcon(widget.showFilterIcon, filterImage, () {
                  // Get.toNamed(MyRoute.eventFilterScreen);
                }),
                _buildIcon(widget.dotIcon, verticalDot, () {
                  // Get.toNamed(MyRoute.eventGetHelpScreen);
                }),
                _buildIcon(widget.settingIcon, settingIcons, () {
                  // Get.toNamed(MyRoute.eventSettingScreen);
                }),
                widget.skipIcon
                    ? Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: GestureDetector(
                          onTap: () {
                            // widget.skipPath == null
                            //     ? Get.toNamed(MyRoute.eventStartScreen)
                            //     : Get.toNamed(MyRoute.eventBottomScreen);
                          },
                          child: Text(
                            skipText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: controller.isDarkMode
                                  ? skipNightColor
                                  : skipColor,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(bool showIcon, String assetPath, VoidCallback onPressed) {
    return showIcon
        ? Padding(
            padding: const EdgeInsets.only(right: 15),
            child: GestureDetector(
              onTap: onPressed,
              child: Container(
                decoration: BoxDecoration(
                  color: controller.isDarkMode
                      ? blackModeBorder
                      : backgroundTextFiled,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SvgPicture.asset(
                    assetPath,
                    colorFilter: ColorFilter.mode(
                      controller.isDarkMode
                          ? eventLightBackgroundColor
                          : eventOnBodingTitle,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        _buildIcon(true, notifyIcon, () {
          // Get.toNamed(MyRoute.eventNotificationScreen);
        }),
        widget.hasNotificationDot
            ? Positioned(
                right: 25,
                top: 10,
                child: Container(
                  height: 8,
                  width: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }

  void _showShareDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          alignment: Alignment.bottomCenter,
          content: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      shareTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: controller.isDarkMode
                            ? eventLightBackgroundColor
                            : liveLocation,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 24,
                      width: 24,
                      decoration: const BoxDecoration(
                        color: crossBack,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: SvgPicture.asset(
                          crossSign,
                          height: 6,
                          width: 6,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 1, color: dividerColor),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareIcon(facebookShare, facebookTitle, 30, 30, theme),
                    _buildShareIcon(instagramShare, instagram, 30, 30, theme),
                    _buildShareIcon(
                        Get.isDarkMode ? twitterDarkShare : twitterShare,
                        twitter,
                        20,
                        20,
                        theme),
                    _buildShareIcon(gmailShare, gmail, 20, 20, theme),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoriteIcon() {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: GestureDetector(
        onTap: () {
          setState(() {
            isFavorite = !isFavorite;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color:
                controller.isDarkMode ? blackModeBorder : backgroundTextFiled,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SvgPicture.asset(
              isFavorite ? heartIconRed : heartIconEvent,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ theme을 파라미터로 전달받아 사용하도록 변경
  Widget _buildShareIcon(
      String iconPath, String label, double width, double height, ThemeData theme) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: eventLightBackgroundColor,
            borderRadius: BorderRadius.circular(90),
            border: Border.all(color: unselectList, width: 1),
          ),
          child: IconButton(
            icon: SvgPicture.asset(
              iconPath,
              height: height,
              width: width,
            ),
            onPressed: () {
              // Handle share action
            },
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: controller.isDarkMode
                ? eventLightBackgroundColor
                : liveLocation,
          ),
        ),
      ],
    );
  }
}
