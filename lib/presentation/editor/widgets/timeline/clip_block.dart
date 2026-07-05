import 'package:flutter/material.dart';

class ClipBlock extends StatelessWidget {
  final Color color;
  const ClipBlock({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Center(
        child: Text('clip_01', style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w500,
        )),
      ),
    );
  }
}
