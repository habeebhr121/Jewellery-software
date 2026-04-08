import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ShopCashMonitorScreen extends StatefulWidget {
  const ShopCashMonitorScreen({super.key});

  @override
  State<ShopCashMonitorScreen> createState() => _ShopCashMonitorScreenState();
}

class _ShopCashMonitorScreenState extends State<ShopCashMonitorScreen> {
  List<CashTransaction> allTransactions = [];
  bool isLoading = true;

  double totalCashIn = 0.0;
  double totalCashOut = 0.0;
  double currentBalance = 0.0;

  int totalReceipts = 0;
  int totalPayments = 0;
  int totalBills = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    List<CashTransaction> transactions = [];

    // Reset totals
    totalCashIn = 0.0;
    totalCashOut = 0.0;
    totalReceipts = 0;
    totalPayments = 0;
    totalBills = 0;

    // Load Cash Receipts (CASH IN - INCLUDE Cash for Gold by amount)
    final receiptsJson = prefs.getStringList('cash_receipts') ?? [];
    for (var receiptStr in receiptsJson) {
      try {
        final data = jsonDecode(receiptStr);
        double amount = (data['amount'] ?? 0).toDouble();
        bool isCashForGold = data['isCashForGold'] == true;

        // INCLUDE all receipts (including Cash for Gold) by amount
        transactions.add(
          CashTransaction(
            type: CashTransactionType.receipt,
            customerName: data['name'] ?? 'Unknown',
            amount: amount,
            date: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            description: isCashForGold ? 'Cash Receipt (Gold)' : 'Cash Receipt',
            isCashForGold: isCashForGold,
            goldGrams: isCashForGold ? data['goldGrams']?.toDouble() : null,
          ),
        );
        totalCashIn += amount;
        totalReceipts++;
      } catch (e) {
        print('Error loading receipt: $e');
      }
    }

    // Load Cash Payments (CASH OUT - INCLUDE Cash for Gold by amount)
    final paymentsJson = prefs.getStringList('cash_payments') ?? [];
    for (var paymentStr in paymentsJson) {
      try {
        final data = jsonDecode(paymentStr);
        double amount = (data['amount'] ?? 0).toDouble();
        bool isCashForGold = data['isCashForGold'] == true;

        // INCLUDE all payments (including Cash for Gold) by amount
        transactions.add(
          CashTransaction(
            type: CashTransactionType.payment,
            customerName: data['name'] ?? 'Unknown',
            amount: amount,
            date: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            description: isCashForGold ? 'Cash Payment (Gold)' : 'Cash Payment',
            isCashForGold: isCashForGold,
            goldGrams: isCashForGold ? data['goldGrams']?.toDouble() : null,
          ),
        );
        totalCashOut += amount;
        totalPayments++;
      } catch (e) {
        print('Error loading payment: $e');
      }
    }

    // Load Cash Bills (CASH IN)
    final billsJson = prefs.getStringList('saved_bills') ?? [];
    for (var billStr in billsJson) {
      try {
        final data = jsonDecode(billStr);

        // Calculate total from items if totalAmount doesn't exist
        double calculatedTotal = 0.0;
        if (data['items'] != null) {
          for (var item in data['items']) {
            calculatedTotal +=
                double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          }
        }

        // Use totalAmount if exists, otherwise use calculated
        double amount = (data['totalAmount'] != null)
            ? (data['totalAmount'] as num).toDouble()
            : calculatedTotal;

        transactions.add(
          CashTransaction(
            type: CashTransactionType.bill,
            customerName: data['customerName'] ?? 'Unknown',
            amount: amount,
            date: DateTime.parse(
              data['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
            description: 'Cash Bill - SL No: ${data['slNo'] ?? 'N/A'}',
            isCashForGold: false,
          ),
        );
        totalCashIn += amount;
        totalBills++;
      } catch (e) {
        print('Error loading bill: $e');
      }
    }

    // Sort by date (newest first)
    transactions.sort((a, b) => b.date.compareTo(a.date));

    currentBalance = totalCashIn - totalCashOut;

    setState(() {
      allTransactions = transactions;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 20.h),
                    _buildBalanceCard(),
                    SizedBox(height: 20.h),
                    _buildStatisticsCards(),
                    SizedBox(height: 20.h),
                    _buildPieChart(),
                    SizedBox(height: 20.h),
                    _buildRecentTransactions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 40,
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop Cash Monitor',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Real-time cash flow tracking',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              DateFormat('MMM dd, yyyy').format(DateTime.now()),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    Color balanceColor = currentBalance >= 0
        ? Colors.green[700]!
        : Colors.red[700]!;
    IconData balanceIcon = currentBalance >= 0
        ? Icons.trending_up
        : Icons.trending_down;

    return Container(
      padding: EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [balanceColor, balanceColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: balanceColor.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Cash Balance',
                style: TextStyle(
                  fontSize: 18.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(balanceIcon, color: Colors.white, size: 32),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹',
                style: TextStyle(
                  fontSize: 32.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                currentBalance.abs().toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 48.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (currentBalance < 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'Cash Deficit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Cash In',
            '₹${totalCashIn.toStringAsFixed(2)}',
            Icons.arrow_downward,
            Colors.green,
            '$totalReceipts Receipts\n$totalBills Bills',
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: _buildStatCard(
            'Cash Out',
            '₹${totalCashOut.toStringAsFixed(2)}',
            Icons.arrow_upward,
            Colors.red,
            '$totalPayments Payments',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String amount,
    IconData icon,
    Color color,
    String details,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            amount,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            details,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[500],
              height: 1.4.h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (totalCashIn == 0 && totalCashOut == 0) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cash Flow Overview',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 200.h,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          value: totalCashIn,
                          title:
                              '${((totalCashIn / (totalCashIn + totalCashOut)) * 100).toStringAsFixed(1)}%',
                          color: Colors.green[400],
                          radius: 60,
                          titleStyle: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: totalCashOut,
                          title:
                              '${((totalCashOut / (totalCashIn + totalCashOut)) * 100).toStringAsFixed(1)}%',
                          color: Colors.red[400],
                          radius: 60,
                          titleStyle: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24.w),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      'Cash In',
                      Colors.green[400]!,
                      totalCashIn,
                    ),
                    SizedBox(height: 16.h),
                    _buildLegendItem(
                      'Cash Out',
                      Colors.red[400]!,
                      totalCashOut,
                    ),
                    SizedBox(height: 16.h),
                    Divider(color: Colors.grey[300]),
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Net:',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '₹${currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: currentBalance >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double value) {
    return Row(
      children: [
        Container(
          width: 16.w,
          height: 16.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${value.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    // Get last 50 transactions
    List<CashTransaction> recentTransactions = allTransactions
        .take(50)
        .toList();

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'Last ${recentTransactions.length}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '${allTransactions.length} Total',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (recentTransactions.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16.h),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: recentTransactions.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1.h, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final transaction = recentTransactions[index];
                return _buildTransactionItem(transaction);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(CashTransaction transaction) {
    Color typeColor;
    IconData typeIcon;
    bool isInflow =
        transaction.type == CashTransactionType.receipt ||
        transaction.type == CashTransactionType.bill;

    switch (transaction.type) {
      case CashTransactionType.receipt:
        typeColor = transaction.isCashForGold
            ? Colors.amber[600]!
            : Colors.green[600]!;
        typeIcon = transaction.isCashForGold
            ? Icons.balance
            : Icons.arrow_downward;
        break;
      case CashTransactionType.payment:
        typeColor = transaction.isCashForGold
            ? Colors.orange[600]!
            : Colors.red[600]!;
        typeIcon = transaction.isCashForGold
            ? Icons.balance
            : Icons.arrow_upward;
        break;
      case CashTransactionType.bill:
        typeColor = Colors.blue[600]!;
        typeIcon = Icons.receipt_long;
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.customerName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  transaction.description,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 4.h),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(transaction.date),
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isInflow ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isInflow ? Colors.green[700] : Colors.red[700],
                ),
              ),
              SizedBox(height: 4.h),
              if (transaction.isCashForGold && transaction.goldGrams != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${transaction.goldGrams!.toStringAsFixed(3)} gm',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[800],
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    transaction.type.displayName,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Models
enum CashTransactionType { receipt, payment, bill }

extension CashTransactionTypeExtension on CashTransactionType {
  String get displayName {
    switch (this) {
      case CashTransactionType.receipt:
        return 'Receipt';
      case CashTransactionType.payment:
        return 'Payment';
      case CashTransactionType.bill:
        return 'Bill';
    }
  }
}

class CashTransaction {
  final CashTransactionType type;
  final String customerName;
  final double amount;
  final DateTime date;
  final String description;
  final bool isCashForGold;
  final double? goldGrams;

  CashTransaction({
    required this.type,
    required this.customerName,
    required this.amount,
    required this.date,
    required this.description,
    this.isCashForGold = false,
    this.goldGrams,
  });
}
