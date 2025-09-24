import 'package:flutter/material.dart';

class SwipeButton extends StatefulWidget {
  final String text;
  final String imagePath;
  final VoidCallback onSwipe;

  const SwipeButton({
    Key? key,
    required this.text,
    required this.imagePath,
    required this.onSwipe,
  }) : super(key: key);

  @override
  swipeButtonState createState() => swipeButtonState();
}

class swipeButtonState extends State<SwipeButton> {
  Color _buttonColor = Colors.blue;

  void _handleSwipe() {
    setState(() {
      _buttonColor = Colors.red; // Change to red when swiped
    });
    widget.onSwipe();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dx > 0) {

          _handleSwipe();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: _buttonColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(widget.imagePath, width: 24, height: 24),
            const SizedBox(width: 8),
            Text(
              widget.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
