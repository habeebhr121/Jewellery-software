import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget buildSummaryCard({
  required IconData icon,
  required String title,
  required String value,
  required Color color,
}) {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(color: Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Spacer(),
            Icon(Icons.help_outline, color: Colors.grey[400], size: 16),
          ],
        ),
        SizedBox(height: 12.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}
