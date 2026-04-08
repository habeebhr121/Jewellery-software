import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  List<Transaction> allTransactions = [];
  List<Transaction> filteredTransactions = [];
  int? selectedTransactionIndex;

  String filterPeriod = 'All Time';
  String filterType = 'All';
  String sortBy = 'Date (Newest)';

  DateTime? customStartDate;
  DateTime? customEndDate;

  bool isLoading = true;

  final TextEditingController _slNoSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllTransactions();
  }

  @override
  void dispose() {
    _slNoSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTransactions() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    List<Transaction> transactions = [];

    // Load Cash Receipts
    final receiptsJson = prefs.getStringList('cash_receipts') ?? [];
    for (int i = 0; i < receiptsJson.length; i++) {
      try {
        final data = jsonDecode(receiptsJson[i]);
        transactions.add(
          Transaction(
            id: data['id'] ?? '',
            type: TransactionType.cashReceipt,
            customerName: data['name'] ?? '',
            amount: (data['amount'] ?? 0).toDouble(),
            date: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            isCashForGold: data['isCashForGold'] ?? false,
            goldGrams: data['goldGrams']?.toDouble(),
            goldPrice: data['goldPrice']?.toDouble(),
            rawData: data,
            sourceType: 'cash_receipts',
            sourceIndex: i,
          ),
        );
      } catch (e) {
        print('Error loading receipt: $e');
      }
    }

    // Load Cash Payments
    final paymentsJson = prefs.getStringList('cash_payments') ?? [];
    for (int i = 0; i < paymentsJson.length; i++) {
      try {
        final data = jsonDecode(paymentsJson[i]);
        transactions.add(
          Transaction(
            id: data['id'] ?? '',
            type: TransactionType.cashPayment,
            customerName: data['name'] ?? '',
            amount: (data['amount'] ?? 0).toDouble(),
            date: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            isCashForGold: data['isCashForGold'] ?? false,
            goldGrams: data['goldGrams']?.toDouble(),
            goldPrice: data['goldPrice']?.toDouble(),
            rawData: data,
            sourceType: 'cash_payments',
            sourceIndex: i,
          ),
        );
      } catch (e) {
        print('Error loading payment: $e');
      }
    }

    // Load Cash Bills
    final cashBillsJson = prefs.getStringList('saved_bills') ?? [];
    for (int i = 0; i < cashBillsJson.length; i++) {
      try {
        final data = jsonDecode(cashBillsJson[i]);
        double totalAmount = 0.0;
        int itemCount = 0;

        if (data['items'] != null) {
          itemCount = (data['items'] as List).length;
          for (var item in data['items']) {
            totalAmount +=
                double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          }
        }

        transactions.add(
          Transaction(
            id: data['id'] ?? data['slNo'] ?? '',
            type: TransactionType.cashBill,
            customerName: data['customerName'] ?? '',
            amount: data['totalAmount']?.toDouble() ?? totalAmount,
            date: DateTime.parse(
              data['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
            itemCount: itemCount,
            slNo: data['slNo'],
            phone: data['phone'],
            rawData: data,
            sourceType: 'saved_bills',
            sourceIndex: i,
          ),
        );
      } catch (e) {
        print('Error loading cash bill: $e');
      }
    }

    // Load Issue Jewellery
    final alterationsJson = prefs.getStringList('alteration_bills') ?? [];
    for (int i = 0; i < alterationsJson.length; i++) {
      try {
        final data = jsonDecode(alterationsJson[i]);
        double totalPureWeight = 0.0;
        if (data['items'] != null) {
          for (var item in data['items']) {
            totalPureWeight +=
                double.tryParse(item['pure']?.toString() ?? '0') ?? 0.0;
          }
        }
        transactions.add(
          Transaction(
            id: data['slNo'] ?? '',
            type: TransactionType.issueJewellery,
            customerName: data['accountName'] ?? '',
            amount: 0.0,
            pureWeight: totalPureWeight,
            date: DateTime.parse(
              data['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
            goldGrams: totalPureWeight,
            itemCount: (data['items'] as List?)?.length ?? 0,
            slNo: data['slNo'],
            phone: data['phone'],
            rawData: data,
            sourceType: 'alteration_bills',
            sourceIndex: i,
          ),
        );
      } catch (e) {
        print('Error loading issue jewellery: $e');
      }
    }

    // Load Purchase Jewellery
    final purchasesJson = prefs.getStringList('purchase_bills') ?? [];
    for (int i = 0; i < purchasesJson.length; i++) {
      try {
        final data = jsonDecode(purchasesJson[i]);
        double totalPureWeight = 0.0;
        double totalAmount = 0.0;

        if (data['items'] != null) {
          for (var item in data['items']) {
            totalPureWeight +=
                double.tryParse(item['pure']?.toString() ?? '0') ?? 0.0;
            totalAmount +=
                double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          }
        }

        transactions.add(
          Transaction(
            id: data['id'] ?? data['slNo'] ?? '',
            type: TransactionType.purchaseJewellery,
            customerName: data['accountName'] ?? '',
            amount: data['totalAmount']?.toDouble() ?? totalAmount,
            pureWeight: totalPureWeight,
            date: DateTime.parse(
              data['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
            goldGrams: totalPureWeight,
            itemCount: (data['items'] as List?)?.length ?? 0,
            slNo: data['slNo'],
            phone: data['phone'],
            rawData: data,
            sourceType: 'purchase_bills',
            sourceIndex: i,
          ),
        );
      } catch (e) {
        print('Error loading purchase: $e');
      }
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      allTransactions = transactions;
      filteredTransactions = transactions;
      isLoading = false;
    });

    _applyFiltersAndSort();
  }

  void _searchBySLNo(String slNo) {
    if (slNo.trim().isEmpty) {
      _applyFiltersAndSort();
      return;
    }

    setState(() {
      filteredTransactions = allTransactions.where((t) {
        return t.slNo != null &&
            t.slNo!.toLowerCase().contains(slNo.toLowerCase());
      }).toList();
      selectedTransactionIndex = null;
    });
  }

  void _applyFiltersAndSort() {
    List<Transaction> result = List.from(allTransactions);

    if (filterPeriod == 'Custom Range' &&
        customStartDate != null &&
        customEndDate != null) {
      DateTime startOfDay = DateTime(
        customStartDate!.year,
        customStartDate!.month,
        customStartDate!.day,
      );
      DateTime endOfDay = DateTime(
        customEndDate!.year,
        customEndDate!.month,
        customEndDate!.day,
        23,
        59,
        59,
      );

      result = result.where((t) {
        return t.date.isAfter(startOfDay.subtract(Duration(seconds: 1))) &&
            t.date.isBefore(endOfDay.add(Duration(seconds: 1)));
      }).toList();
    } else if (filterPeriod != 'All Time') {
      DateTime now = DateTime.now();
      DateTime filterDate;
      DateTime? endFilterDate;

      switch (filterPeriod) {
        case 'Today':
          filterDate = DateTime(now.year, now.month, now.day);
          endFilterDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          result = result.where((t) {
            return t.date.isAfter(filterDate.subtract(Duration(seconds: 1))) &&
                t.date.isBefore(endFilterDate!.add(Duration(seconds: 1)));
          }).toList();
          break;

        case 'Yesterday':
          filterDate = DateTime(now.year, now.month, now.day - 1);
          endFilterDate = DateTime(
            now.year,
            now.month,
            now.day - 1,
            23,
            59,
            59,
          );
          result = result.where((t) {
            return t.date.isAfter(filterDate.subtract(Duration(seconds: 1))) &&
                t.date.isBefore(endFilterDate!.add(Duration(seconds: 1)));
          }).toList();
          break;

        case 'This Week':
          int currentWeekday = now.weekday;
          filterDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: currentWeekday - 1));
          filterDate = DateTime(
            filterDate.year,
            filterDate.month,
            filterDate.day,
          );
          result = result
              .where(
                (t) =>
                    t.date.isAfter(filterDate.subtract(Duration(seconds: 1))),
              )
              .toList();
          break;

        case 'This Month':
          filterDate = DateTime(now.year, now.month, 1);
          result = result
              .where(
                (t) =>
                    t.date.isAfter(filterDate.subtract(Duration(seconds: 1))),
              )
              .toList();
          break;

        case 'This Year':
          filterDate = DateTime(now.year, 1, 1);
          result = result
              .where(
                (t) =>
                    t.date.isAfter(filterDate.subtract(Duration(seconds: 1))),
              )
              .toList();
          break;

        case 'Last 7 Days':
          filterDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: 6));
          filterDate = DateTime(
            filterDate.year,
            filterDate.month,
            filterDate.day,
          );
          result = result
              .where(
                (t) =>
                    t.date.isAfter(filterDate.subtract(Duration(seconds: 1))),
              )
              .toList();
          break;

        case 'Last 30 Days':
          filterDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: 29));
          filterDate = DateTime(
            filterDate.year,
            filterDate.month,
            filterDate.day,
          );
          result = result
              .where(
                (t) =>
                    t.date.isAfter(filterDate.subtract(Duration(seconds: 1))),
              )
              .toList();
          break;

        case 'Last 90 Days':
          filterDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: 89));
          filterDate = DateTime(
            filterDate.year,
            filterDate.month,
            filterDate.day,
          );
          result = result
              .where(
                (t) =>
                    t.date.isAfter(filterDate.subtract(Duration(seconds: 1))),
              )
              .toList();
          break;

        default:
          filterDate = DateTime(2020);
          result = result.where((t) => t.date.isAfter(filterDate)).toList();
      }
    }

    if (filterType != 'All') {
      TransactionType? type;
      switch (filterType) {
        case 'Cash Receipts':
          type = TransactionType.cashReceipt;
          break;
        case 'Cash Payments':
          type = TransactionType.cashPayment;
          break;
        case 'Cash Bills':
          type = TransactionType.cashBill;
          break;
        case 'Issue Jewellery':
          type = TransactionType.issueJewellery;
          break;
        case 'Purchase Jewellery':
          type = TransactionType.purchaseJewellery;
          break;
      }
      if (type != null) {
        result = result.where((t) => t.type == type).toList();
      }
    }

    switch (sortBy) {
      case 'Date (Newest)':
        result.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'Date (Oldest)':
        result.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'Amount (High to Low)':
        result.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Amount (Low to High)':
        result.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'Customer Name':
        result.sort((a, b) => a.customerName.compareTo(b.customerName));
        break;
    }

    setState(() {
      filteredTransactions = result;
      selectedTransactionIndex = null;
    });
  }

  Future<void> _showCustomDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: customStartDate != null && customEndDate != null
          ? DateTimeRange(start: customStartDate!, end: customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.purple[600]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customStartDate = picked.start;
        customEndDate = picked.end;
        filterPeriod = 'Custom Range';
      });
      _applyFiltersAndSort();
    }
  }

  Future<void> _editTransaction(Transaction transaction) async {
    if (transaction.type == TransactionType.cashBill ||
        transaction.type == TransactionType.issueJewellery ||
        transaction.type == TransactionType.purchaseJewellery) {
      await _showEditJewelryDialog(transaction);
    } else {
      await _showEditCashDialog(transaction);
    }
  }

  Future<void> _showEditCashDialog(Transaction transaction) async {
    final TextEditingController amountController = TextEditingController(
      text: transaction.amount.toStringAsFixed(2),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${transaction.type.displayName}'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                double? newAmount = double.tryParse(amountController.text);
                if (newAmount != null && newAmount > 0) {
                  await _updateTransaction(transaction, {'amount': newAmount});
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
              child: Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditJewelryDialog(Transaction transaction) async {
    if (transaction.rawData == null || transaction.rawData!['items'] == null) {
      _showSnackBar('Cannot edit: No item data found', Colors.red);
      return;
    }

    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
      (transaction.rawData!['items'] as List).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return _EditJewelryDialog(
          transaction: transaction,
          items: items,
          onSave: (updatedItems) async {
            double totalAmount = 0.0;
            double totalPure = 0.0;

            for (var item in updatedItems) {
              totalAmount +=
                  double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
              totalPure +=
                  double.tryParse(item['pure']?.toString() ?? '0') ?? 0.0;
            }

            await _updateTransaction(transaction, {
              'items': updatedItems,
              'totalAmount': totalAmount,
              'totalPure': totalPure,
            });
          },
        );
      },
    );
  }

  Future<void> _updateTransaction(
    Transaction transaction,
    Map<String, dynamic> updates,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      List<String> sourceList =
          prefs.getStringList(transaction.sourceType) ?? [];

      if (transaction.sourceIndex < sourceList.length) {
        var data = jsonDecode(sourceList[transaction.sourceIndex]);

        updates.forEach((key, value) {
          data[key] = value;
        });

        sourceList[transaction.sourceIndex] = jsonEncode(data);
        await prefs.setStringList(transaction.sourceType, sourceList);

        await _loadAllTransactions();
        _showSnackBar('Transaction updated successfully!', Colors.green);
      }
    } catch (e) {
      print('Error updating transaction: $e');
      _showSnackBar('Error updating transaction', Colors.red);
    }
  }

  // UPDATED: Custom print format for each transaction type
  Future<void> _printTransaction(Transaction transaction) async {
    try {
      final pdf = pw.Document();

      // Build different PDF layouts based on transaction type
      if (transaction.type == TransactionType.issueJewellery ||
          transaction.type == TransactionType.purchaseJewellery) {
        pdf.addPage(_buildIssueOrPurchasePDF(transaction));
      } else if (transaction.type == TransactionType.cashBill) {
        pdf.addPage(_buildCashBillPDF(transaction));
      } else {
        pdf.addPage(_buildGenericPDF(transaction));
      }

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            '${transaction.type.displayName}_${transaction.slNo ?? transaction.id}.pdf',
      );

      _showSnackBar('PDF generated successfully', Colors.green);
    } catch (e) {
      print('Error printing: $e');
      _showSnackBar('Error generating PDF: ${e.toString()}', Colors.red);
    }
  }

  // Issue/Purchase Jewellery PDF with Shop Details
  pw.Page _buildIssueOrPurchasePDF(Transaction transaction) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Shop Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2.w),
                color: PdfColors.blue50,
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'STAR GOLD',
                    style: pw.TextStyle(
                      fontSize: 28.sp,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 5.h),
                  pw.Text(
                    'Sky Line Center, Near REG. Office',
                    style: pw.TextStyle(fontSize: 11.sp),
                  ),
                  pw.Text(
                    'Kallachi Road, Nadapuram',
                    style: pw.TextStyle(fontSize: 11.sp),
                  ),
                  pw.SizedBox(height: 10.h),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 10.h),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            transaction.type.displayName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 20.sp,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3.h),
                          pw.Text(
                            'SL No: ${transaction.slNo ?? 'N/A'}',
                            style: pw.TextStyle(
                              fontSize: 14.sp,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(transaction.date)}',
                            style: pw.TextStyle(fontSize: 11.sp),
                          ),
                          pw.Text(
                            'Time: ${DateFormat('hh:mm a').format(transaction.date)}',
                            style: pw.TextStyle(fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15.h),

            // Customer Details
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CUSTOMER DETAILS',
                    style: pw.TextStyle(
                      fontSize: 14.sp,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Name: ${transaction.customerName}',
                        style: pw.TextStyle(fontSize: 12.sp),
                      ),
                      if (transaction.phone != null)
                        pw.Text(
                          'Phone: ${transaction.phone}',
                          style: pw.TextStyle(fontSize: 12.sp),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15.h),

            // Items Table
            if (transaction.rawData != null &&
                transaction.rawData!['items'] != null) ...[
              pw.Text(
                'ITEMS DETAILS',
                style: pw.TextStyle(
                  fontSize: 16.sp,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10.h),
              pw.Table.fromTextArray(
                headers: [
                  'SL',
                  'Item Name',
                  'Qty',
                  'Net Wt (gm)',
                  'Purity (%)',
                  'Pure Wt (gm)',
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10.sp,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey400,
                ),
                cellAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(fontSize: 9.sp),
                data: List<List<dynamic>>.generate(
                  (transaction.rawData!['items'] as List).length,
                  (index) {
                    var item = transaction.rawData!['items'][index];
                    double netWeight =
                        (double.tryParse(item['gross']?.toString() ?? '0') ??
                            0.0) -
                        (double.tryParse(item['stone']?.toString() ?? '0') ??
                            0.0);
                    if (item['netWeight'] != null) {
                      netWeight =
                          double.tryParse(
                            item['netWeight']?.toString() ?? '0',
                          ) ??
                          netWeight;
                    }

                    return [
                      '${index + 1}',
                      item['itemName'] ??
                          item['description'] ??
                          'Item ${index + 1}',
                      item['sets']?.toString() ??
                          item['set']?.toString() ??
                          '1',
                      netWeight.toStringAsFixed(3),
                      item['pure%']?.toString() ??
                          item['touchValue']?.toString() ??
                          '91.6',
                      item['pure']?.toString() ?? '0.000',
                    ];
                  },
                ),
                border: pw.TableBorder.all(),
                cellHeight: 25,
              ),

              pw.SizedBox(height: 15.h),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2.w),
                  color: PdfColors.grey200,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL PURE WEIGHT:',
                      style: pw.TextStyle(
                        fontSize: 14.sp,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${transaction.pureWeight?.toStringAsFixed(3) ?? '0.000'} gm',
                      style: pw.TextStyle(
                        fontSize: 16.sp,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 8.sp),
                    ),
                    pw.SizedBox(height: 3.h),
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 9.sp,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Authorized Signature',
                      style: pw.TextStyle(fontSize: 9.sp),
                    ),
                    pw.SizedBox(height: 15.h),
                    pw.Container(
                      width: 120.w,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Cash Bill PDF with Shop Details
  pw.Page _buildCashBillPDF(Transaction transaction) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Shop Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2.w),
                color: PdfColors.purple50,
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'STAR GOLD',
                    style: pw.TextStyle(
                      fontSize: 28.sp,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepPurple900,
                    ),
                  ),
                  pw.SizedBox(height: 5.h),
                  pw.Text(
                    'Sky Line Center, Near REG. Office',
                    style: pw.TextStyle(fontSize: 11.sp),
                  ),
                  pw.Text(
                    'Kallachi Road, Nadapuram',
                    style: pw.TextStyle(fontSize: 11.sp),
                  ),
                  pw.SizedBox(height: 10.h),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 10.h),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CASH BILL',
                            style: pw.TextStyle(
                              fontSize: 20.sp,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3.h),
                          pw.Text(
                            'SL No: ${transaction.slNo ?? 'N/A'}',
                            style: pw.TextStyle(
                              fontSize: 14.sp,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(transaction.date)}',
                            style: pw.TextStyle(fontSize: 11.sp),
                          ),
                          pw.Text(
                            'Time: ${DateFormat('hh:mm a').format(transaction.date)}',
                            style: pw.TextStyle(fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15.h),

            // Customer Details
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CUSTOMER DETAILS',
                    style: pw.TextStyle(
                      fontSize: 14.sp,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Name: ${transaction.customerName}',
                        style: pw.TextStyle(fontSize: 12.sp),
                      ),
                      if (transaction.phone != null)
                        pw.Text(
                          'Phone: ${transaction.phone}',
                          style: pw.TextStyle(fontSize: 12.sp),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15.h),

            // Items Table
            if (transaction.rawData != null &&
                transaction.rawData!['items'] != null) ...[
              pw.Text(
                'ITEMS DETAILS',
                style: pw.TextStyle(
                  fontSize: 16.sp,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10.h),
              pw.Table.fromTextArray(
                headers: [
                  'SL',
                  'Item',
                  'Qty',
                  'Wt(gm)',
                  'Stone',
                  'Purity',
                  'Rate',
                  'Making',
                  'Amount',
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8.sp,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey400,
                ),
                cellAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(fontSize: 7.sp),
                data: List<List<dynamic>>.generate(
                  (transaction.rawData!['items'] as List).length,
                  (index) {
                    var item = transaction.rawData!['items'][index];
                    String makingUnit = item['makingUnit']?.toString() ?? '%';
                    String makingValue = item['making']?.toString() ?? '0';
                    String makingDisplay = '$makingValue $makingUnit';

                    return [
                      '${index + 1}',
                      item['itemName'] ?? item['description'] ?? 'Item',
                      item['sets']?.toString() ??
                          item['set']?.toString() ??
                          '1',
                      item['gross']?.toString() ?? '0',
                      item['stone']?.toString() ?? '0',
                      item['pure%']?.toString() ?? '91.6',
                      item['rate']?.toString() ?? '0',
                      makingDisplay,
                      item['amount']?.toString() ?? '0.00',
                    ];
                  },
                ),
                border: pw.TableBorder.all(),
                cellHeight: 20,
              ),

              pw.SizedBox(height: 15.h),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2.w),
                  color: PdfColors.grey200,
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Subtotal:',
                          style: pw.TextStyle(fontSize: 12.sp),
                        ),
                        pw.Text(
                          transaction.amount.toStringAsFixed(2),
                          style: pw.TextStyle(fontSize: 12.sp),
                        ),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL AMOUNT:',
                          style: pw.TextStyle(
                            fontSize: 14.sp,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          transaction.amount.toStringAsFixed(2),
                          style: pw.TextStyle(
                            fontSize: 16.sp,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 8.sp),
                    ),
                    pw.SizedBox(height: 3.h),
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 9.sp,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Authorized Signature',
                      style: pw.TextStyle(fontSize: 9.sp),
                    ),
                    pw.SizedBox(height: 15.h),
                    pw.Container(
                      width: 120.w,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Generic PDF for Cash Receipts/Payments with Shop Details
  pw.Page _buildGenericPDF(Transaction transaction) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Shop Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2.w),
                color: transaction.type == TransactionType.cashReceipt
                    ? PdfColors.green50
                    : PdfColors.red50,
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'STAR GOLD',
                    style: pw.TextStyle(
                      fontSize: 28.sp,
                      fontWeight: pw.FontWeight.bold,
                      color: transaction.type == TransactionType.cashReceipt
                          ? PdfColors.green900
                          : PdfColors.red900,
                    ),
                  ),
                  pw.SizedBox(height: 5.h),
                  pw.Text(
                    'Sky Line Center, Near REG. Office',
                    style: pw.TextStyle(fontSize: 11.sp),
                  ),
                  pw.Text(
                    'Kallachi Road, Nadapuram',
                    style: pw.TextStyle(fontSize: 11.sp),
                  ),
                  pw.SizedBox(height: 10.h),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 10.h),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        transaction.type.displayName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 22.sp,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(transaction.date)}',
                            style: pw.TextStyle(fontSize: 11.sp),
                          ),
                          pw.Text(
                            'Time: ${DateFormat('hh:mm a').format(transaction.date)}',
                            style: pw.TextStyle(fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20.h),

            // Customer Details
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CUSTOMER DETAILS',
                    style: pw.TextStyle(
                      fontSize: 14.sp,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8.h),
                  pw.Text('Name: ${transaction.customerName}'),
                  if (transaction.phone != null)
                    pw.Text('Phone: ${transaction.phone}'),
                ],
              ),
            ),

            pw.SizedBox(height: 20.h),

            // Amount Details
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2.w),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Amount:',
                        style: pw.TextStyle(
                          fontSize: 16.sp,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '₹${transaction.amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 20.sp,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (transaction.isCashForGold &&
                      transaction.goldGrams != null) ...[
                    pw.SizedBox(height: 10.h),
                    pw.Divider(),
                    pw.SizedBox(height: 10.h),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Gold Weight:',
                          style: pw.TextStyle(fontSize: 12.sp),
                        ),
                        pw.Text(
                          '${transaction.goldGrams!.toStringAsFixed(3)} gm',
                          style: pw.TextStyle(
                            fontSize: 12.sp,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (transaction.goldPrice != null)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Gold Price/gm:',
                            style: pw.TextStyle(fontSize: 12.sp),
                          ),
                          pw.Text(
                            '₹${transaction.goldPrice!.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 12.sp,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 8.sp),
                    ),
                    pw.SizedBox(height: 3.h),
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 9.sp,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Authorized Signature',
                      style: pw.TextStyle(fontSize: 9.sp),
                    ),
                    pw.SizedBox(height: 15.h),
                    pw.Container(
                      width: 120.w,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _viewTransactionDetails(Transaction transaction) async {
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
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        transaction.type.color,
                        transaction.type.color.withOpacity(0.7),
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
                      Icon(
                        transaction.type.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.type.displayName,
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
                                color: Colors.white70,
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

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard('Basic Information', [
                          _buildInfoRow(
                            'Customer Name',
                            transaction.customerName,
                          ),
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

                        _buildInfoCard('Transaction Summary', [
                          if (transaction.type ==
                                  TransactionType.issueJewellery ||
                              transaction.type ==
                                  TransactionType.purchaseJewellery)
                            _buildInfoRow(
                              'Total Pure Weight',
                              '${transaction.pureWeight?.toStringAsFixed(3) ?? '0.000'} gm',
                              valueColor: Colors.amber[800],
                            )
                          else
                            _buildInfoRow(
                              'Amount',
                              '₹${transaction.amount.toStringAsFixed(2)}',
                              valueColor:
                                  transaction.type ==
                                      TransactionType.cashReceipt
                                  ? Colors.green[700]
                                  : Colors.red[700],
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

                        if (transaction.rawData != null &&
                            transaction.rawData!['items'] != null)
                          _buildItemsCard(transaction.rawData!),
                      ],
                    ),
                  ),
                ),

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${index + 1}. ${item['itemName'] ?? item['description'] ?? 'Item ${index + 1}'}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (item['amount'] != null)
                        Text(
                          '₹${item['amount']}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                    ],
                  ),
                  Divider(height: 16.h),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (item['sets'] != null || item['set'] != null)
                        _buildItemDetail(
                          'Sets',
                          (item['sets'] ?? item['set']).toString(),
                        ),
                      if (item['gross'] != null)
                        _buildItemDetail('Gross', '${item['gross']} gm'),
                      if (item['stone'] != null)
                        _buildItemDetail('Stone', '${item['stone']} gm'),
                      if (item['weight'] != null)
                        _buildItemDetail('Weight', '${item['weight']} gm'),
                      if (item['waste'] != null)
                        _buildItemDetail('Waste', '${item['waste']} gm'),
                      if (item['touchValue'] != null || item['pure%'] != null)
                        _buildItemDetail(
                          'Touch',
                          (item['touchValue'] ?? item['pure%']).toString(),
                        ),
                      if (item['pure'] != null)
                        _buildItemDetail(
                          'Pure',
                          '${item['pure']} gm',
                          Colors.amber[700],
                        ),
                      if (item['rate'] != null && item['rate'] != '0.00')
                        _buildItemDetail('Rate', '₹${item['rate']}'),
                      if (item['categoryName'] != null)
                        _buildItemDetail(
                          'Category',
                          item['categoryName'].toString(),
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

  Future<void> _deleteTransaction(Transaction transaction) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Transaction'),
          content: Text(
            'Are you sure you want to delete this ${transaction.type.displayName} transaction?\n\nThis action cannot be undone and will also remove it from the database.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(backgroundColor: Colors.red[50]),
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      final prefs = await SharedPreferences.getInstance();

      try {
        List<String> sourceList =
            prefs.getStringList(transaction.sourceType) ?? [];

        if (transaction.sourceIndex < sourceList.length) {
          sourceList.removeAt(transaction.sourceIndex);
          await prefs.setStringList(transaction.sourceType, sourceList);

          await _loadAllTransactions();
          _showSnackBar('Transaction deleted successfully!', Colors.red);
        }
      } catch (e) {
        print('Error deleting transaction: $e');
        _showSnackBar('Error deleting transaction', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }

  double get totalAmount {
    return filteredTransactions.fold(0.0, (sum, transaction) {
      if (transaction.type == TransactionType.cashReceipt) {
        return sum + transaction.amount;
      } else if (transaction.type == TransactionType.cashPayment) {
        return sum - transaction.amount;
      } else if (transaction.type == TransactionType.cashBill) {
        return sum + transaction.amount;
      } else if (transaction.type == TransactionType.purchaseJewellery) {
        return sum - transaction.amount;
      }
      return sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBySlNo(),
          _buildFilters(),
          _buildTableHeader(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildTransactionsList(),
          ),
          _buildSummaryFooter(),
        ],
      ),
    );
  }

  Widget _buildSearchBySlNo() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      constraints: BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey, size: 20),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: _slNoSearchController,
              decoration: InputDecoration(
                hintText: 'Search by SL No...',
                hintStyle: TextStyle(fontSize: 14.sp),
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(fontSize: 14.sp),
              onChanged: _searchBySLNo,
            ),
          ),
          if (_slNoSearchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, size: 18),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () {
                _slNoSearchController.clear();
                _applyFiltersAndSort();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[700]!, Colors.purple[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.receipt_long, color: Colors.white, size: 24),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Transactions',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  filterPeriod == 'Custom Range' && customStartDate != null
                      ? '${DateFormat('MMM dd').format(customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(customEndDate!)}'
                      : 'Complete transaction history',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              '${filteredTransactions.length} Records',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: Colors.grey[700]),
              SizedBox(width: 6.w),
              Text(
                'Filters & Sort',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Period',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildFilterChip('All Time', filterPeriod, (value) {
                          setState(() {
                            filterPeriod = value;
                            customStartDate = null;
                            customEndDate = null;
                          });
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Today', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Yesterday', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('This Week', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Last 7 Days', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Last 30 Days', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('This Month', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Last 90 Days', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('This Year', filterPeriod, (value) {
                          setState(() => filterPeriod = value);
                          _applyFiltersAndSort();
                        }),
                        InkWell(
                          onTap: _showCustomDatePicker,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: filterPeriod == 'Custom Range'
                                  ? Colors.purple[600]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: filterPeriod == 'Custom Range'
                                    ? Colors.purple[600]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.date_range,
                                  size: 13,
                                  color: filterPeriod == 'Custom Range'
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Custom Range',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: filterPeriod == 'Custom Range'
                                        ? Colors.white
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildFilterChip('All', filterType, (value) {
                          setState(() => filterType = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Cash Receipts', filterType, (value) {
                          setState(() => filterType = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Cash Payments', filterType, (value) {
                          setState(() => filterType = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Cash Bills', filterType, (value) {
                          setState(() => filterType = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Issue Jewellery', filterType, (
                          value,
                        ) {
                          setState(() => filterType = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Purchase Jewellery', filterType, (
                          value,
                        ) {
                          setState(() => filterType = value);
                          _applyFiltersAndSort();
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildFilterChip('Date (Newest)', sortBy, (value) {
                          setState(() => sortBy = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Date (Oldest)', sortBy, (value) {
                          setState(() => sortBy = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Amount (High to Low)', sortBy, (
                          value,
                        ) {
                          setState(() => sortBy = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Amount (Low to High)', sortBy, (
                          value,
                        ) {
                          setState(() => sortBy = value);
                          _applyFiltersAndSort();
                        }),
                        _buildFilterChip('Customer Name', sortBy, (value) {
                          setState(() => sortBy = value);
                          _applyFiltersAndSort();
                        }),
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

  Widget _buildFilterChip(
    String label,
    String currentValue,
    Function(String) onTap,
  ) {
    bool isSelected = currentValue == label;
    return InkWell(
      onTap: () => onTap(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? Colors.purple[600]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF6B7280),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.r),
          topRight: Radius.circular(12.r),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Date & Time',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Type',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Customer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Amount/Pure',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
          SizedBox(width: 160.w),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'No transactions found',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Try adjusting your filters',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12.r),
          bottomRight: Radius.circular(12.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: filteredTransactions.length,
        itemBuilder: (context, index) {
          final transaction = filteredTransactions[index];
          final isSelected = selectedTransactionIndex == index;
          return _buildTransactionRow(transaction, index, isSelected);
        },
      ),
    );
  }

  Widget _buildTransactionRow(
    Transaction transaction,
    int index,
    bool isSelected,
  ) {
    String displayValue;
    Color displayColor;

    if (transaction.type == TransactionType.issueJewellery ||
        transaction.type == TransactionType.purchaseJewellery) {
      displayValue =
          '${transaction.pureWeight?.toStringAsFixed(3) ?? '0.000'} gm';
      displayColor = Colors.amber[700]!;
    } else {
      displayValue = transaction.amount > 0
          ? '₹${transaction.amount.toStringAsFixed(2)}'
          : '—';
      displayColor = transaction.type == TransactionType.cashReceipt
          ? Colors.green[700]!
          : transaction.type == TransactionType.cashPayment
          ? Colors.red[700]!
          : Colors.deepPurple[700]!;
    }

    return InkWell(
      onTap: () {
        setState(() {
          selectedTransactionIndex = isSelected ? null : index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.purple[50]
              : (index % 2 == 0 ? Colors.white : Colors.grey[50]),
          border: Border(
            left: isSelected
                ? BorderSide(color: Colors.purple[600]!, width: 4.w)
                : BorderSide.none,
            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5.w),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(transaction.date),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    DateFormat('hh:mm a').format(transaction.date),
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: transaction.type.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      transaction.type.icon,
                      size: 13,
                      color: transaction.type.color,
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        transaction.type.displayName,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: transaction.type.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                transaction.customerName,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                displayValue,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: displayColor,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  children: [
                    if (transaction.isCashForGold &&
                        transaction.goldGrams != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '${transaction.goldGrams!.toStringAsFixed(3)}gm',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                      ),
                    if (transaction.itemCount != null &&
                        transaction.itemCount! > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: transaction.type.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '${transaction.itemCount} items',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                            color: transaction.type.color,
                          ),
                        ),
                      ),
                    if (!transaction.isCashForGold &&
                        (transaction.itemCount == null ||
                            transaction.itemCount == 0))
                      Text(
                        'Cash',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 160.w,
              child: isSelected
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.visibility, size: 17),
                          color: Colors.blue[600],
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          tooltip: 'View',
                          onPressed: () => _viewTransactionDetails(transaction),
                        ),
                        SizedBox(width: 6.w),
                        IconButton(
                          icon: Icon(Icons.edit, size: 17),
                          color: Colors.orange[600],
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          tooltip: 'Edit',
                          onPressed: () => _editTransaction(transaction),
                        ),
                        SizedBox(width: 6.w),
                        IconButton(
                          icon: Icon(Icons.print, size: 17),
                          color: Colors.green[600],
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          tooltip: 'Print',
                          onPressed: () => _printTransaction(transaction),
                        ),
                        SizedBox(width: 6.w),
                        IconButton(
                          icon: Icon(Icons.delete, size: 17),
                          color: Colors.red[600],
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          tooltip: 'Delete',
                          onPressed: () => _deleteTransaction(transaction),
                        ),
                      ],
                    )
                  : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryFooter() {
    int receiptsCount = filteredTransactions
        .where((t) => t.type == TransactionType.cashReceipt)
        .length;
    int paymentsCount = filteredTransactions
        .where((t) => t.type == TransactionType.cashPayment)
        .length;
    int cashBillsCount = filteredTransactions
        .where((t) => t.type == TransactionType.cashBill)
        .length;
    int issueCount = filteredTransactions
        .where((t) => t.type == TransactionType.issueJewellery)
        .length;
    int purchaseCount = filteredTransactions
        .where((t) => t.type == TransactionType.purchaseJewellery)
        .length;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total',
              '${filteredTransactions.length}',
              Icons.receipt_long,
              Colors.purple,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildSummaryCard(
              'Receipts',
              '$receiptsCount',
              Icons.arrow_downward,
              Colors.green,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildSummaryCard(
              'Payments',
              '$paymentsCount',
              Icons.arrow_upward,
              Colors.red,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildSummaryCard(
              'Cash Bills',
              '$cashBillsCount',
              Icons.receipt,
              Colors.deepPurple,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildSummaryCard(
              'Issue',
              '$issueCount',
              Icons.output,
              Colors.orange,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildSummaryCard(
              'Purchase',
              '$purchaseCount',
              Icons.shopping_cart,
              Colors.blue,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildSummaryCard(
              'Net Amount',
              '₹${totalAmount.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              totalAmount >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// FIXED: Edit Dialog with proper TextField cursor handling
class _EditJewelryDialog extends StatefulWidget {
  final Transaction transaction;
  final List<Map<String, dynamic>> items;
  final Function(List<Map<String, dynamic>>) onSave;

  const _EditJewelryDialog({
    required this.transaction,
    required this.items,
    required this.onSave,
  });

  @override
  State<_EditJewelryDialog> createState() => _EditJewelryDialogState();
}

class _EditJewelryDialogState extends State<_EditJewelryDialog> {
  late List<Map<String, dynamic>> items;
  late List<Map<String, TextEditingController>> controllers;

  @override
  void initState() {
    super.initState();
    items = widget.items;

    // Initialize controllers for each item
    controllers = items.map((item) {
      return {
        'set': TextEditingController(text: item['set']?.toString() ?? '0'),
        'gross': TextEditingController(text: item['gross']?.toString() ?? '0'),
        'stone': TextEditingController(text: item['stone']?.toString() ?? '0'),
        'pure%': TextEditingController(
          text: item['pure%']?.toString() ?? '91.6',
        ),
        'rate': TextEditingController(text: item['rate']?.toString() ?? '0'),
        'making': TextEditingController(
          text: item['making']?.toString() ?? '0',
        ),
        'discount': TextEditingController(
          text: item['discount']?.toString() ?? '0',
        ),
      };
    }).toList();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controllerMap in controllers) {
      controllerMap.forEach((key, controller) {
        controller.dispose();
      });
    }
    super.dispose();
  }

  void _calculateItemAmount(int index) {
    final item = items[index];
    final controllerMap = controllers[index];

    double gross = double.tryParse(controllerMap['gross']!.text) ?? 0.0;
    double stone = double.tryParse(controllerMap['stone']!.text) ?? 0.0;
    double purity = double.tryParse(controllerMap['pure%']!.text) ?? 91.6;
    double rate = double.tryParse(controllerMap['rate']!.text) ?? 0.0;
    double making = double.tryParse(controllerMap['making']!.text) ?? 0.0;
    double discount = double.tryParse(controllerMap['discount']!.text) ?? 0.0;
    int sets = int.tryParse(controllerMap['set']!.text) ?? 0;
    String makingUnit = item['makingUnit']?.toString() ?? '%';

    double netWeight = gross - stone;
    double pureWeight = (netWeight * purity) / 100;
    double baseAmount = netWeight * rate;

    double makingAmount = 0.0;
    if (makingUnit == '%') {
      makingAmount = (baseAmount * making) / 100;
    } else if (makingUnit == 'gm') {
      makingAmount = netWeight * making;
    } else if (makingUnit == 'pcs') {
      makingAmount = sets * making;
    }

    double totalAmount = baseAmount + makingAmount - discount;

    setState(() {
      // Update the item values
      item['set'] = controllerMap['set']!.text;
      item['gross'] = controllerMap['gross']!.text;
      item['stone'] = controllerMap['stone']!.text;
      item['pure%'] = controllerMap['pure%']!.text;
      item['rate'] = controllerMap['rate']!.text;
      item['making'] = controllerMap['making']!.text;
      item['discount'] = controllerMap['discount']!.text;

      item['netWeight'] = netWeight.toStringAsFixed(3);
      item['pure'] = pureWeight.toStringAsFixed(3);
      item['amount'] = totalAmount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Edit ${widget.transaction.type.displayName}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(20),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildEditableItemCard(index);
                },
              ),
            ),

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
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSave(items);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableItemCard(int index) {
    final item = items[index];
    final controllerMap = controllers[index];

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${index + 1}. ${item['itemName'] ?? item['description'] ?? 'Item'}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${item['amount'] ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            Divider(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: _buildEditField(
                    'Sets/Pcs',
                    controllerMap['set']!,
                    index,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildEditField(
                    'Gross (gm)',
                    controllerMap['gross']!,
                    index,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildEditField(
                    'Stone (gm)',
                    controllerMap['stone']!,
                    index,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildEditField(
                    'Purity (%)',
                    controllerMap['pure%']!,
                    index,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildEditField('Rate', controllerMap['rate']!, index),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildEditField(
                          'Making',
                          controllerMap['making']!,
                          index,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      DropdownButton<String>(
                        value: item['makingUnit']?.toString() ?? '%',
                        items: ['%', 'gm', 'pcs'].map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            item['makingUnit'] = value;
                            _calculateItemAmount(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildEditField('Discount', controllerMap['discount']!, index),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Net: ${item['netWeight'] ?? '0.000'} gm'),
                  Text(
                    'Pure: ${item['pure'] ?? '0.000'} gm',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: TextField with proper cursor positioning
  Widget _buildEditField(
    String label,
    TextEditingController controller,
    int index,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.left, // FIXED: Ensure left alignment
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: TextStyle(fontSize: 14.sp),
      onChanged: (value) {
        // FIXED: Set selection to end of text after change
        final text = value;
        controller.value = controller.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(
            offset: text.length,
          ), // Cursor at end
        );
        _calculateItemAmount(index);
      },
    );
  }
}

// Transaction Model
class Transaction {
  final String id;
  final TransactionType type;
  final String customerName;
  final double amount;
  final double? pureWeight;
  final DateTime date;
  final bool isCashForGold;
  final double? goldGrams;
  final double? goldPrice;
  final int? itemCount;
  final String? slNo;
  final String? phone;
  final Map<String, dynamic>? rawData;
  final String sourceType;
  final int sourceIndex;

  Transaction({
    required this.id,
    required this.type,
    required this.customerName,
    required this.amount,
    this.pureWeight,
    required this.date,
    this.isCashForGold = false,
    this.goldGrams,
    this.goldPrice,
    this.itemCount,
    this.slNo,
    this.phone,
    this.rawData,
    required this.sourceType,
    required this.sourceIndex,
  });
}

enum TransactionType {
  cashReceipt,
  cashPayment,
  cashBill,
  issueJewellery,
  purchaseJewellery,
}

extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.cashReceipt:
        return 'Cash Receipt';
      case TransactionType.cashPayment:
        return 'Cash Payment';
      case TransactionType.cashBill:
        return 'Cash Bill';
      case TransactionType.issueJewellery:
        return 'Issue Jewellery';
      case TransactionType.purchaseJewellery:
        return 'Purchase Jewellery';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionType.cashReceipt:
        return Icons.arrow_downward;
      case TransactionType.cashPayment:
        return Icons.arrow_upward;
      case TransactionType.cashBill:
        return Icons.receipt;
      case TransactionType.issueJewellery:
        return Icons.output;
      case TransactionType.purchaseJewellery:
        return Icons.shopping_cart;
    }
  }

  Color get color {
    switch (this) {
      case TransactionType.cashReceipt:
        return Colors.green;
      case TransactionType.cashPayment:
        return Colors.red;
      case TransactionType.cashBill:
        return Colors.deepPurple;
      case TransactionType.issueJewellery:
        return Colors.orange;
      case TransactionType.purchaseJewellery:
        return Colors.blue;
    }
  }
}
