import 'package:flutter/material.dart';

import 'colors.dart';

class RxGuadianLogo extends StatelessWidget {
  final double size;
  const RxGuadianLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: kInputBorderColor, width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.local_pharmacy_outlined,
          color: kPrimaryColor,
          size: size * 0.5,
        ),
      ),
    );
  }
}