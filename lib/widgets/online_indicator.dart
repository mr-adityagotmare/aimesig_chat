import 'package:flutter/material.dart';

class OnlineIndicator extends StatelessWidget {
  final bool online;

  const OnlineIndicator({
    super.key,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: online ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}