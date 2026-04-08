import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jwells_report/widgets/build_summary_card.dart';

Widget buildSummarySection() {
  return Container(
    color: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
            SizedBox(width: 8.w),
            Text(
              'Summary',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),

        SizedBox(height: 20.h),

        // Summary Cards
        Row(
          children: [
            Expanded(
              child: buildSummaryCard(
                icon: Icons.description_outlined,
                title: 'Total Quotations',
                value: '24',
                color: Color(0xFF3B82F6),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: buildSummaryCard(
                icon: Icons.list,
                title: 'Draft Quotations',
                value: '24',
                color: Color(0xFF10B981),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: buildSummaryCard(
                icon: Icons.currency_rupee,
                title: 'Quotation Amount',
                value: '₹16,985,829.23',
                color: Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
