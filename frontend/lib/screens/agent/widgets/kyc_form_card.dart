import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

class KycFormCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const KycFormCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.wp(5.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: R.sp(5.5),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: R.hp(0.8)),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: R.sp(3.8),
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: R.hp(3.0)),
          ...children,
        ],
      ),
    );
  }
}
