import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget buildFilterChip(String label, bool hasDropdown) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(6.r),
      border: Border.all(color: Color(0xFFE5E7EB)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.close, color: Colors.grey[400], size: 16),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        if (hasDropdown) ...[
          SizedBox(width: 8.w),
          Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 16),
        ],
      ],
    ),
  );
}
