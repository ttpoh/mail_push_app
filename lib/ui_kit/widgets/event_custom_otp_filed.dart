import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:eventup/theme/event_theme.dart';
import 'package:get/get.dart';
import '../constant/event_color.dart';


class EventOtpInputField extends StatefulWidget {
  final int otpInputFieldCount;
  final double width;
  final Function(String) onOtpEntered;
  final List<TextInputFormatter>? inputFormatters;
  final RxList<String> initialOtpValues;
  const EventOtpInputField({
    Key? key,
    required this.otpInputFieldCount,
    required this.width,
    required this.onOtpEntered,
    required this.inputFormatters, required this.initialOtpValues,s,
  }) : super(key: key);

  @override
  EventOtpInputFieldState createState() => EventOtpInputFieldState();
}

class EventOtpInputFieldState extends State<EventOtpInputField> {
  late List<String> otpNumbers;
  late List<FocusNode> focusNodes;
  late ThemeData theme;

  @override
  void initState() {
    super.initState();
    otpNumbers = List.filled(widget.otpInputFieldCount, '');
    focusNodes = List.generate(widget.otpInputFieldCount, (_) => FocusNode());
    // theme = Get.isDarkMode ? EventTheme.eventDarkTheme : EventTheme.eventLightTheme;
  }

  @override
  void dispose() {
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        widget.otpInputFieldCount,
            (index) {
          return SizedBox(
            height: 56,
            width: 56,
            child: Focus(
              onFocusChange: (hasFocus) {
                setState(() {});
              },
              child: Center(
                child: TextFormField(
                  key: Key('otpField_$index'),
                  autofocus: false,
                  focusNode: focusNodes[index],
                  onChanged: (value) {
                    otpNumbers[index] = value;
                    if (value.isNotEmpty) {
                      if (index < widget.otpInputFieldCount - 1) {
                        focusNodes[index + 1].requestFocus();
                      } else {

                        focusNodes[index].unfocus();
                      }
                    }
                    widget.onOtpEntered(otpNumbers.join());
                  },
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: widget.inputFormatters,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 30, horizontal: 19),
                    hintText: '',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    fillColor: Get.isDarkMode ? blackModeBorder : backgroundTextFiled,
                    filled: true,
                    counterText: "",
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: skipNightColor, width: 1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Get.isDarkMode ? blackModeBorder : backgroundTextFiled, width: 1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Get.isDarkMode ? backgroundTextFiled : eventOnBodingTitle,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
