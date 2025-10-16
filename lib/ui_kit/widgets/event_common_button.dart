// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import '../constant/event_color.dart';
// import '../theme/event_theme.dart';
// class EventCommonButton extends StatefulWidget {
//   final VoidCallback onPressed;
//   final String text;
//   final String? imagePath;
//   final double? width;
//   final double? height;
//   final double? size;
//   final double? padding;
//   final double? fontSize;
//   final double? borderRadius;
//   final Color? bgColor;
//   final Color? borderColor;
//   final Color? textColor;
//   final BoxBorder? boxBorder;
//   final TextStyle? textStyle;
//   const EventCommonButton({
//     super.key,
//     required this.onPressed,
//     required this.text,
//     this.imagePath,
//     this.width,
//     this.size,
//     this.padding,
//     this.height,
//     this.fontSize,
//     this.bgColor,
//     this.textColor,
//     this.borderRadius,
//     this.borderColor,
//     this.boxBorder,
//     this.textStyle,
//   });
//   @override
//   State<EventCommonButton> createState() => _EventCommonButtonState();
// }
// class _EventCommonButtonState extends State<EventCommonButton> {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: widget.width ?? double.infinity,
//       height: widget.height ?? 60.0,
//       padding:  EdgeInsets.all(widget.padding ?? 0),
//       decoration: BoxDecoration(
//         border: Border.all(color: widget.borderColor ?? Colors.transparent),
//         borderRadius: BorderRadius.circular(widget.borderRadius ?? 12.0),
//         color: widget.bgColor ?? eventDarkButtonColor,
//       ),
//       child: ElevatedButton(
//         style: ElevatedButton.styleFrom(
//           padding: const EdgeInsets.all(5),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           elevation: 4,
//           backgroundColor: Colors.transparent,
//           foregroundColor: Colors.white,
//           shadowColor: Colors.transparent,
//         ),
//         onPressed: widget.onPressed,
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             if (widget.imagePath != null)
//               Padding(
//                 padding: const EdgeInsets.only(right: 8.0),
//                 child: SvgPicture.asset(
//                   widget.imagePath!,

//                 ),
//               ),
//             Text(
//               widget.text,
//               style:
//               TextStyle(
//                     fontSize: widget.size ?? 16,
//                     color:widget.textColor ?? eventLightBackgroundColor,
//                     fontWeight: FontWeight.w700,
//                     fontFamily: EventTheme.fontFamily,
//                   ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
