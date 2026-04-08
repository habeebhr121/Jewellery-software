import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onMenuSelected;

  const DashboardScreen({super.key, required this.onMenuSelected});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isLoading = true;

  // Overview Data (Current Month Only)
  double totalReceipts = 0;
  double totalPayments = 0;
  double totalCashBills = 0;
  double totalPurchases = 0;
  int totalTransactions = 0;
  int totalInventoryItems = 0;
  double totalInventoryWeight = 0;
  int totalAccounts = 0;

  // Recent Transactions with full data
  List<TransactionData> recentTransactions = [];

  // Chart Data
  Map<String, double> transactionTypeDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    // Get current month date range
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    print('\n========== LOADING DASHBOARD DATA ==========');
    print(
      'Date Range: ${DateFormat('MMM dd, yyyy').format(startOfMonth)} to ${DateFormat('MMM dd, yyyy').format(endOfMonth)}',
    );

    // Load Cash Receipts (Current Month) - INCLUDE Cash for Gold (amount only)
    final receiptsJson = prefs.getStringList('cash_receipts') ?? [];
    double receipts = 0;
    int receiptsCount = 0;

    for (var json in receiptsJson) {
      try {
        final data = jsonDecode(json);
        DateTime transDate = DateTime.parse(
          data['date'] ?? DateTime.now().toIso8601String(),
        );

        if (transDate.isAfter(startOfMonth.subtract(Duration(seconds: 1))) &&
            transDate.isBefore(endOfMonth.add(Duration(seconds: 1)))) {
          // INCLUDE all receipts (including Cash for Gold) by amount
          double amount = (data['amount'] ?? 0).toDouble();
          receipts += amount;
          receiptsCount++;

          if (data['isCashForGold'] == true) {
            print(
              'Receipt (Cash for Gold): ₹${amount.toStringAsFixed(2)} from ${data['name']}',
            );
          } else {
            print(
              'Receipt: ₹${amount.toStringAsFixed(2)} from ${data['name']}',
            );
          }
        }
      } catch (e) {
        print('Error loading receipt: $e');
      }
    }

    print(
      'Total Receipts: ₹${receipts.toStringAsFixed(2)} ($receiptsCount receipts)',
    );

    // Load Cash Payments (Current Month) - INCLUDE Cash for Gold (amount only)
    final paymentsJson = prefs.getStringList('cash_payments') ?? [];
    double payments = 0;
    int paymentsCount = 0;

    for (var json in paymentsJson) {
      try {
        final data = jsonDecode(json);
        DateTime transDate = DateTime.parse(
          data['date'] ?? DateTime.now().toIso8601String(),
        );

        if (transDate.isAfter(startOfMonth.subtract(Duration(seconds: 1))) &&
            transDate.isBefore(endOfMonth.add(Duration(seconds: 1)))) {
          // INCLUDE all payments (including Cash for Gold) by amount
          double amount = (data['amount'] ?? 0).toDouble();
          payments += amount;
          paymentsCount++;

          if (data['isCashForGold'] == true) {
            print(
              'Payment (Cash for Gold): ₹${amount.toStringAsFixed(2)} to ${data['name']}',
            );
          } else {
            print('Payment: ₹${amount.toStringAsFixed(2)} to ${data['name']}');
          }
        }
      } catch (e) {
        print('Error loading payment: $e');
      }
    }

    print(
      'Total Payments: ₹${payments.toStringAsFixed(2)} ($paymentsCount payments)',
    );

    // Load Cash Bills (Current Month) - ACCURATE CALCULATION
    final billsJson = prefs.getStringList('saved_bills') ?? [];
    double billsAmount = 0;
    int billsCount = 0;

    print('\n--- Loading Cash Bills ---');
    for (var json in billsJson) {
      try {
        final data = jsonDecode(json);
        DateTime transDate = DateTime.parse(
          data['timestamp'] ?? DateTime.now().toIso8601String(),
        );

        if (transDate.isAfter(startOfMonth.subtract(Duration(seconds: 1))) &&
            transDate.isBefore(endOfMonth.add(Duration(seconds: 1)))) {
          // Calculate total from items
          double calculatedTotal = 0.0;

          if (data['items'] != null) {
            for (var item in data['items']) {
              double itemAmount =
                  double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
              calculatedTotal += itemAmount;
            }
          }

          // Use totalAmount if exists, otherwise use calculated
          double billTotal = (data['totalAmount'] != null)
              ? (data['totalAmount'] as num).toDouble()
              : calculatedTotal;

          billsAmount += billTotal;
          billsCount++;

          print(
            'Bill ${data['slNo']}: ₹${billTotal.toStringAsFixed(2)} (${data['customerName']})',
          );
        }
      } catch (e) {
        print('Error loading bill: $e');
      }
    }

    print(
      'Total Cash Bills: ₹${billsAmount.toStringAsFixed(2)} ($billsCount bills)',
    );

    // Load Purchase Bills (Current Month) - ACCURATE CALCULATION
    final purchasesJson = prefs.getStringList('purchase_bills') ?? [];
    double purchasesAmount = 0;
    int purchasesCount = 0;

    print('\n--- Loading Purchase Bills ---');
    for (var json in purchasesJson) {
      try {
        final data = jsonDecode(json);
        DateTime transDate = DateTime.parse(
          data['timestamp'] ?? DateTime.now().toIso8601String(),
        );

        if (transDate.isAfter(startOfMonth.subtract(Duration(seconds: 1))) &&
            transDate.isBefore(endOfMonth.add(Duration(seconds: 1)))) {
          // Calculate total from items
          double calculatedTotal = 0.0;

          if (data['items'] != null) {
            for (var item in data['items']) {
              double itemAmount =
                  double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
              calculatedTotal += itemAmount;
            }
          }

          // Use totalAmount if exists, otherwise use calculated
          double purchaseTotal = (data['totalAmount'] != null)
              ? (data['totalAmount'] as num).toDouble()
              : calculatedTotal;

          purchasesAmount += purchaseTotal;
          purchasesCount++;

          print(
            'Purchase ${data['slNo']}: ₹${purchaseTotal.toStringAsFixed(2)} (${data['accountName']})',
          );
        }
      } catch (e) {
        print('Error loading purchase: $e');
      }
    }

    print(
      'Total Purchases: ₹${purchasesAmount.toStringAsFixed(2)} ($purchasesCount purchases)',
    );

    // Load Inventory (Total, not month-specific)
    final inventoryJson = prefs.getString('inventory_items');
    int itemsCount = 0;
    double inventoryWeight = 0;
    if (inventoryJson != null && inventoryJson.isNotEmpty) {
      try {
        final items = jsonDecode(inventoryJson) as List;
        itemsCount = items.length;
        for (var item in items) {
          inventoryWeight += (item['weight'] ?? 0).toDouble();
        }
      } catch (e) {
        print('Error loading inventory: $e');
      }
    }

    // Load Accounts (Total, not month-specific)
    final accountsJson = prefs.getString('accounts');
    int accountsCount = 0;
    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        final accounts = jsonDecode(accountsJson) as List;
        accountsCount = accounts.length;
      } catch (e) {
        print('Error loading accounts: $e');
      }
    }

    // Calculate total transactions (Current Month)
    int totalTrans =
        receiptsCount + paymentsCount + billsCount + purchasesCount;

    print('\nTotal Transactions This Month: $totalTrans');
    print('  - Receipts: $receiptsCount');
    print('  - Payments: $paymentsCount');
    print('  - Bills: $billsCount');
    print('  - Purchases: $purchasesCount');

    // Load Recent Transactions (last 10, with full data) - INCLUDE CASH FOR GOLD
    List<TransactionData> recent = [];

    // Add recent bills
    for (var json in billsJson.reversed.take(3)) {
      try {
        final data = jsonDecode(json);
        double totalAmount = 0.0;
        int itemCount = 0;

        if (data['items'] != null) {
          itemCount = (data['items'] as List).length;
          for (var item in data['items']) {
            totalAmount +=
                double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          }
        }

        // Use totalAmount if exists, otherwise calculated
        double billAmount = (data['totalAmount'] != null)
            ? (data['totalAmount'] as num).toDouble()
            : totalAmount;

        recent.add(
          TransactionData(
            id: data['id'] ?? data['slNo'] ?? '',
            type: 'Cash Bill',
            customer: data['customerName'] ?? 'Unknown',
            amount: billAmount,
            date: DateTime.parse(
              data['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
            color: Colors.deepPurple,
            icon: Icons.receipt,
            slNo: data['slNo'],
            phone: data['phone'],
            itemCount: itemCount,
            rawData: data,
          ),
        );
      } catch (e) {
        print('Error loading recent bill: $e');
      }
    }

    // Add recent receipts (INCLUDE Cash for Gold)
    for (var json in receiptsJson.reversed.take(3)) {
      try {
        final data = jsonDecode(json);

        // Add ALL receipts including Cash for Gold
        recent.add(
          TransactionData(
            id: data['id'] ?? '',
            type: data['isCashForGold'] == true
                ? 'Cash Receipt (Gold)'
                : 'Cash Receipt',
            customer: data['name'] ?? 'Unknown',
            amount: (data['amount'] ?? 0).toDouble(),
            date: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            color: data['isCashForGold'] == true ? Colors.amber : Colors.green,
            icon: data['isCashForGold'] == true
                ? Icons.balance
                : Icons.arrow_downward,
            isCashForGold: data['isCashForGold'] ?? false,
            goldGrams: data['goldGrams']?.toDouble(),
            goldPrice: data['goldPrice']?.toDouble(),
            rawData: data,
          ),
        );
      } catch (e) {
        print('Error loading recent receipt: $e');
      }
    }

    // Add recent payments (INCLUDE Cash for Gold)
    for (var json in paymentsJson.reversed.take(2)) {
      try {
        final data = jsonDecode(json);

        // Add ALL payments including Cash for Gold
        recent.add(
          TransactionData(
            id: data['id'] ?? '',
            type: data['isCashForGold'] == true
                ? 'Cash Payment (Gold)'
                : 'Cash Payment',
            customer: data['name'] ?? 'Unknown',
            amount: (data['amount'] ?? 0).toDouble(),
            date: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            color: data['isCashForGold'] == true ? Colors.orange : Colors.red,
            icon: data['isCashForGold'] == true
                ? Icons.balance
                : Icons.arrow_upward,
            isCashForGold: data['isCashForGold'] ?? false,
            goldGrams: data['goldGrams']?.toDouble(),
            goldPrice: data['goldPrice']?.toDouble(),
            rawData: data,
          ),
        );
      } catch (e) {
        print('Error loading recent payment: $e');
      }
    }

    // Sort by date and take top 8
    recent.sort((a, b) => b.date.compareTo(a.date));
    recent = recent.take(8).toList();

    // Transaction Type Distribution
    Map<String, double> distribution = {
      'Cash Bills': billsAmount,
      'Receipts': receipts,
      'Payments': payments,
      'Purchases': purchasesAmount,
    };

    print('\n========== DASHBOARD LOADED ==========\n');

    setState(() {
      totalReceipts = receipts;
      totalPayments = payments;
      totalCashBills = billsAmount;
      totalPurchases = purchasesAmount;
      totalTransactions = totalTrans;
      totalInventoryItems = itemsCount;
      totalInventoryWeight = inventoryWeight;
      totalAccounts = accountsCount;
      recentTransactions = recent;
      transactionTypeDistribution = distribution;
      isLoading = false;
    });
  }

  Future<void> _viewTransactionDetails(TransactionData transaction) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        transaction.color,
                        transaction.color.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.r),
                      topRight: Radius.circular(16.r),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(transaction.icon, color: Colors.white, size: 28),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.type,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Transaction Details',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        _buildInfoCard('Basic Information', [
                          _buildInfoRow('Customer Name', transaction.customer),
                          if (transaction.slNo != null)
                            _buildInfoRow('SL No.', transaction.slNo!),
                          if (transaction.phone != null)
                            _buildInfoRow('Phone', transaction.phone!),
                          _buildInfoRow(
                            'Date',
                            DateFormat('MMM dd, yyyy').format(transaction.date),
                          ),
                          _buildInfoRow(
                            'Time',
                            DateFormat('hh:mm a').format(transaction.date),
                          ),
                        ]),

                        SizedBox(height: 16.h),

                        // Amount/Weight Info Card
                        _buildInfoCard('Transaction Summary', [
                          _buildInfoRow(
                            'Amount',
                            '₹${transaction.amount.toStringAsFixed(2)}',
                            valueColor: transaction.color,
                          ),
                          if (transaction.isCashForGold &&
                              transaction.goldGrams != null)
                            _buildInfoRow(
                              'Gold Weight',
                              '${transaction.goldGrams!.toStringAsFixed(3)} gm',
                              valueColor: Colors.amber[700],
                            ),
                          if (transaction.isCashForGold &&
                              transaction.goldPrice != null)
                            _buildInfoRow(
                              'Gold Price/gm',
                              '₹${transaction.goldPrice!.toStringAsFixed(2)}',
                            ),
                          if (transaction.itemCount != null &&
                              transaction.itemCount! > 0)
                            _buildInfoRow(
                              'Total Items',
                              '${transaction.itemCount}',
                            ),
                        ]),

                        SizedBox(height: 16.h),

                        // Items Details (if available)
                        if (transaction.rawData != null &&
                            transaction.rawData!['items'] != null)
                          _buildItemsCard(transaction.rawData!),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.r),
                      bottomRight: Radius.circular(16.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(Map<String, dynamic> rawData) {
    final items = rawData['items'] as List;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${items.length})',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12.h),
          ...items.asMap().entries.map((entry) {
            int index = entry.key;
            var item = entry.value;
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${item['description'] ?? 'Unknown Item'}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildItemDetail('Sets', item['set']?.toString() ?? '0'),
                      _buildItemDetail('Gross', '${item['gross'] ?? '0'} gm'),
                      _buildItemDetail('Stone', '${item['stone'] ?? '0'} gm'),
                      _buildItemDetail('Purity', '${item['pure%'] ?? '0'}%'),
                      _buildItemDetail(
                        'Pure',
                        '${item['pure'] ?? '0'} gm',
                        Colors.amber[700],
                      ),
                      if (item['rate'] != null && item['rate'] != '0.00')
                        _buildItemDetail('Rate', '₹${item['rate']}'),
                      if (item['amount'] != null && item['amount'] != '0.00')
                        _buildItemDetail(
                          'Amount',
                          '₹${item['amount']}',
                          Colors.green[700],
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemDetail(String label, String value, [Color? color]) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 24.h),
              _buildOverviewCards(),
              SizedBox(height: 24.h),
              _buildChartsSection(),
              SizedBox(height: 24.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildRecentTransactions()),
                  SizedBox(width: 16.w),
                  Expanded(child: _buildQuickActions()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    DateTime now = DateTime.now();
    String currentMonth = DateFormat('MMMM yyyy').format(now);

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[700]!, Colors.purple[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
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
            child: Icon(Icons.dashboard, color: Colors.white, size: 32),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Current Month: $currentMonth',
                  style: TextStyle(
                    fontSize: 14.sp,
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
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: 16),
                SizedBox(width: 8.w),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    // Net Cash Flow = (Cash Bills + Total Receipts) - Total Payments
    double netCashFlow = (totalCashBills + totalReceipts) - totalPayments;

    return Column(
      children: [
        // ROW 1: Cash Bills, Total Receipts, Total Payments, Net Cash Flow
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Cash Bills',
                '₹${totalCashBills.toStringAsFixed(2)}',
                Icons.receipt,
                Colors.deepPurple,
                'This Month',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildMetricCard(
                'Total Receipts',
                '₹${totalReceipts.toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.green,
                'This Month',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildMetricCard(
                'Total Payments',
                '₹${totalPayments.toStringAsFixed(2)}',
                Icons.trending_down,
                Colors.red,
                'This Month',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildMetricCard(
                'Net Cash Flow',
                '₹${netCashFlow.toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                netCashFlow >= 0 ? Colors.blue : Colors.orange,
                netCashFlow >= 0 ? 'Positive' : 'Negative',
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        // ROW 2: Total Transactions, Purchases, Inventory Items, Total Accounts
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Transactions',
                '$totalTransactions',
                Icons.receipt_long,
                Colors.purple,
                'This Month',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildMetricCard(
                'Purchases',
                '₹${totalPurchases.toStringAsFixed(2)}',
                Icons.shopping_cart,
                Colors.blue,
                'This Month',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildMetricCard(
                'Inventory Items',
                '$totalInventoryItems',
                Icons.inventory_2,
                Colors.teal,
                '${totalInventoryWeight.toStringAsFixed(2)} gm',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildMetricCard(
                'Total Accounts',
                '$totalAccounts',
                Icons.people,
                Colors.amber,
                'Active',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
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
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildTransactionDistributionChart()),
      ],
    );
  }

  Widget _buildTransactionDistributionChart() {
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
            children: [
              Icon(Icons.pie_chart, color: Colors.purple[600], size: 24),
              SizedBox(width: 12.w),
              Text(
                'Transaction Distribution (This Month)',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 250.h,
            child: Row(
              children: [
                Expanded(child: _buildPieChart()),
                SizedBox(width: 24.w),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      'Cash Bills',
                      Colors.deepPurple,
                      totalCashBills,
                    ),
                    SizedBox(height: 12.h),
                    _buildLegendItem('Receipts', Colors.green, totalReceipts),
                    SizedBox(height: 12.h),
                    _buildLegendItem('Payments', Colors.red, totalPayments),
                    SizedBox(height: 12.h),
                    _buildLegendItem('Purchases', Colors.blue, totalPurchases),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    double total =
        totalCashBills + totalReceipts + totalPayments + totalPurchases;

    if (total == 0) {
      return Center(
        child: Text(
          'No data for this month',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: totalCashBills,
            title: '${((totalCashBills / total) * 100).toStringAsFixed(1)}%',
            color: Colors.deepPurple,
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: totalReceipts,
            title: '${((totalReceipts / total) * 100).toStringAsFixed(1)}%',
            color: Colors.green,
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: totalPayments,
            title: '${((totalPayments / total) * 100).toStringAsFixed(1)}%',
            color: Colors.red,
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: totalPurchases,
            title: '${((totalPurchases / total) * 100).toStringAsFixed(1)}%',
            color: Colors.blue,
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
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
              Row(
                children: [
                  Icon(Icons.history, color: Colors.purple[600], size: 24),
                  SizedBox(width: 12.w),
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  widget.onMenuSelected(7); // Sales Report index
                },
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (recentTransactions.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                    SizedBox(height: 16.h),
                    Text(
                      'No recent transactions',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentTransactions.map((transaction) {
              return InkWell(
                onTap: () => _viewTransactionDetails(transaction),
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: transaction.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          transaction.icon,
                          color: transaction.color,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.customer,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Text(
                                  transaction.type,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  '•',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  DateFormat(
                                    'MMM dd, hh:mm a',
                                  ).format(transaction.date),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: transaction.color,
                            ),
                          ),
                          if (transaction.isCashForGold &&
                              transaction.goldGrams != null)
                            Container(
                              margin: EdgeInsets.only(top: 4),
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                '${transaction.goldGrams!.toStringAsFixed(3)} gm',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800],
                                ),
                              ),
                            )
                          else if (transaction.itemCount != null &&
                              transaction.itemCount! > 0)
                            Container(
                              margin: EdgeInsets.only(top: 4),
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: transaction.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                '${transaction.itemCount} items',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: transaction.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
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
            children: [
              Icon(Icons.flash_on, color: Colors.amber[700], size: 24),
              SizedBox(width: 12.w),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildQuickActionButton(
            'New Cash Bill',
            Icons.receipt,
            Colors.deepPurple,
            () => widget.onMenuSelected(1),
          ),
          SizedBox(height: 12.h),
          _buildQuickActionButton(
            'Cash Receipt',
            Icons.arrow_downward,
            Colors.green,
            () => widget.onMenuSelected(5),
          ),
          SizedBox(height: 12.h),
          _buildQuickActionButton(
            'Cash Payment',
            Icons.arrow_upward,
            Colors.red,
            () => widget.onMenuSelected(4),
          ),
          SizedBox(height: 12.h),
          _buildQuickActionButton(
            'Purchase Jewellery',
            Icons.shopping_cart,
            Colors.blue,
            () => widget.onMenuSelected(3),
          ),
          SizedBox(height: 12.h),
          _buildQuickActionButton(
            'Issue Jewellery',
            Icons.output,
            Colors.orange,
            () => widget.onMenuSelected(2),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// Transaction Data Model
class TransactionData {
  final String id;
  final String type;
  final String customer;
  final double amount;
  final DateTime date;
  final Color color;
  final IconData icon;
  final String? slNo;
  final String? phone;
  final bool isCashForGold;
  final double? goldGrams;
  final double? goldPrice;
  final int? itemCount;
  final Map<String, dynamic>? rawData;

  TransactionData({
    required this.id,
    required this.type,
    required this.customer,
    required this.amount,
    required this.date,
    required this.color,
    required this.icon,
    this.slNo,
    this.phone,
    this.isCashForGold = false,
    this.goldGrams,
    this.goldPrice,
    this.itemCount,
    this.rawData,
  });
}
