import 'package:flutter/material.dart';

class VirtualNumpad extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEnterPressed;
  final Function(String) onValueChanged;
  final bool compactMode;

  VirtualNumpad({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onEnterPressed,
    required this.onValueChanged,
    this.compactMode = false,
  });

  final List<String> _keypadValues = [
    '7',
    '8',
    '9',
    '*',
    '4',
    '5',
    '6',
    '-',
    '1',
    '2',
    '3',
    '',
    '0',
    '00',
    '.',
    'Enter'
  ];

  @override
  Widget build(BuildContext context) {
    final padding = compactMode ? 4.0 : 6.0;
    final spacing = compactMode ? 6.0 : 8.0;
    final buttonFontSize = compactMode ? 18.0 : 22.0;
    final buttonVerticalPadding = compactMode ? 4.0 : 6.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E1219),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF070A10),
          width: 1.1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              (constraints.maxWidth - (padding * 2) - (spacing * 3))
                  .clamp(1.0, double.infinity)
                  .toDouble();
          final availableHeight =
              (constraints.maxHeight - (padding * 2) - (spacing * 3))
                  .clamp(1.0, double.infinity)
                  .toDouble();

          final cellWidth = availableWidth / 4;
          final cellHeight = availableHeight / 4;
          final dynamicAspectRatio =
              (cellWidth / cellHeight).clamp(1.1, 2.8).toDouble();

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: dynamicAspectRatio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: _keypadValues.length,
            itemBuilder: (context, index) {
              final value = _keypadValues[index];
              if (value.isEmpty) {
                return const SizedBox.shrink();
              }

              final isEnter = value == 'Enter';
              final isOperator = value == '*' || value == '-' || value == '.';

              final backgroundColor = isEnter
                  ? const Color(0xFF2AAE8A)
                  : (isOperator
                      ? const Color(0xFF263142)
                      : const Color(0xFF202734));
              final borderColor =
                  isEnter ? const Color(0xFF1F6D59) : const Color(0xFF0B1018);
              final textColor =
                  isEnter ? Colors.white : const Color(0xFFE3E8F2);

              return ElevatedButton(
                onPressed:
                    isEnter ? onEnterPressed : () => onValueChanged(value),
                style: ElevatedButton.styleFrom(
                  foregroundColor: textColor,
                  backgroundColor: backgroundColor,
                  shadowColor: Colors.black87,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: borderColor,
                      width: 1.2,
                    ),
                  ),
                  padding:
                      EdgeInsets.symmetric(vertical: buttonVerticalPadding),
                ),
                child: isEnter
                    ? const Icon(Icons.keyboard_return_outlined)
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
