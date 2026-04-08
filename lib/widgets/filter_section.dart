import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jwells_report/widgets/build_filter_chips.dart';

Widget buildFiltersSection() {
  return Container(
    color: Colors.white,
    padding: EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters Header
        Row(
          children: [
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
            SizedBox(width: 8.w),
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFFE91E63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                '7 Applied',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Color(0xFFE91E63),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Spacer(),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.close, color: Colors.grey[400], size: 16),
              label: Text(
                'Clear All Filters',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Filter Tags Row 1
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            buildFilterChip('Status: All', true),
            buildFilterChip('Date: FY 23-24', true),
            buildFilterChip('Amount: 10,000 - Max', true),
            buildFilterChip('Created By: Sandeep Maurya', true),
          ],
        ),

        SizedBox(height: 12.h),

        // Filter Tags Row 2
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [buildFilterChip('Currency: INR, USD, CAD', true)],
        ),
      ],
    ),
  );
}
