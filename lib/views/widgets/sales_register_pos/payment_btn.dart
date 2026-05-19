import 'package:flutter/material.dart';

class PaymentButton extends StatelessWidget {
  final String buttonText;
  final IconData iconData;
  final Color buttonColor;
  final VoidCallback action;

  const PaymentButton({
    super.key,
    required this.buttonText,
    this.iconData = Icons.check,
    required this.buttonColor,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      padding: const EdgeInsets.all(2.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(86, 52),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          backgroundColor: buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        onPressed: action,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              buttonText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            const SizedBox(width: 2),
            Icon(
              iconData,
              size: 0,
            ),
          ],
        ),
      ),
    );
  }
}
