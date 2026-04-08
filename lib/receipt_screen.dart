import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CashReceiptScreen extends StatefulWidget {
  final bool showDialog;
  const CashReceiptScreen({super.key, this.showDialog = true});

  @override
  State<CashReceiptScreen> createState() => _CashReceiptScreenState();
}

class _CashReceiptScreenState extends State<CashReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _goldPriceController = TextEditingController(text: '0.00');
  final _customerSearchController = TextEditingController(); // NEW
  bool _isLoading = false;
  DateTime _receiptDate = DateTime.now();
  String? _selectedCustomer;
  List<CashReceipt> receipts = [];
  List<String> customerList = [];
  List<String> filteredCustomerList = []; // NEW
  int? selectedReceiptIndex;

  String filterPeriod = 'All Time';
  bool isCashForGold = false;
  double calculatedGrams = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();

    if (widget.showDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddReceiptDialog();
      });
    }
  }

  Future<void> _loadData() async {
    await _loadCustomers();
    await _loadReceipts();
  }

  Future<void> _loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedJson = jsonDecode(accountsJson);
        setState(() {
          customerList = decodedJson
              .map((json) => json['name'].toString())
              .toList();
          customerList.sort();
          filteredCustomerList = List.from(customerList); // NEW
        });
        print('Loaded ${customerList.length} customers');
      } catch (e) {
        print('Error loading customers: $e');
      }
    }
  }

  Future<void> _loadReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    final receiptsJson = prefs.getStringList('cash_receipts') ?? [];

    try {
      setState(() {
        receipts = receiptsJson
            .map((json) => CashReceipt.fromJson(jsonDecode(json)))
            .toList();
        receipts.sort((a, b) => b.date.compareTo(a.date));
      });
      print('Loaded ${receipts.length} receipts');
    } catch (e) {
      print('Error loading receipts: $e');
    }
  }

  List<CashReceipt> get filteredReceipts {
    if (filterPeriod == 'All Time') return receipts;

    DateTime now = DateTime.now();
    DateTime filterDate;

    switch (filterPeriod) {
      case 'Today':
        filterDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        filterDate = now.subtract(Duration(days: 7));
        break;
      case 'This Month':
        filterDate = DateTime(now.year, now.month, 1);
        break;
      default:
        return receipts;
    }

    return receipts
        .where((receipt) => receipt.date.isAfter(filterDate))
        .toList();
  }

  Future<void> _saveReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    final receiptsJson = receipts
        .map((receipt) => jsonEncode(receipt.toJson()))
        .toList();
    await prefs.setStringList('cash_receipts', receiptsJson);
    print('Saved ${receipts.length} receipts to database');
  }

  Future<void> _updateAccountBalance(
    String customerName,
    double receiptAmount,
  ) async {
    print('\n========== PROCESSING CASH RECEIPT ==========');
    print('Customer: $customerName');
    print('Receipt Amount: ₹${receiptAmount.toStringAsFixed(2)}');

    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson == null || accountsJson.isEmpty) {
      print('ERROR: No accounts found in database');
      return;
    }

    try {
      List<dynamic> accounts = jsonDecode(accountsJson);

      int accountIndex = accounts.indexWhere(
        (account) =>
            account['name'].toString().toUpperCase() ==
            customerName.toUpperCase(),
      );

      if (accountIndex == -1) {
        print('ERROR: Account not found for customer: $customerName');
        return;
      }

      String debitStr = accounts[accountIndex]['debit']?.toString() ?? '0.00';
      String creditStr = accounts[accountIndex]['credit']?.toString() ?? '0.00';

      double currentDebit = double.tryParse(debitStr) ?? 0.0;
      double currentCredit = double.tryParse(creditStr) ?? 0.0;

      print('Current Debit: ₹${currentDebit.toStringAsFixed(2)}');
      print('Current Credit: ₹${currentCredit.toStringAsFixed(2)}');

      double remainingAmount = receiptAmount;
      double newDebit = currentDebit;
      double newCredit = currentCredit;

      if (currentDebit > 0) {
        print('\n--- Customer has debt, processing debt reduction ---');

        if (remainingAmount >= currentDebit) {
          print('Receipt covers full debt');
          remainingAmount = remainingAmount - currentDebit;
          newDebit = 0.0;
        } else {
          print('Receipt only partially covers debt');
          newDebit = currentDebit - remainingAmount;
          remainingAmount = 0.0;
        }
      }

      if (remainingAmount > 0) {
        print('\n--- Adding remaining amount to credit ---');
        newCredit = currentCredit + remainingAmount;
      }

      accounts[accountIndex]['debit'] = newDebit.toStringAsFixed(2);
      accounts[accountIndex]['credit'] = newCredit.toStringAsFixed(2);

      print('Final Debit: ₹${newDebit.toStringAsFixed(2)}');
      print('Final Credit: ₹${newCredit.toStringAsFixed(2)}');

      await prefs.setString('accounts', jsonEncode(accounts));
      print('========== CASH RECEIPT PROCESSED ==========\n');
    } catch (e) {
      print('ERROR updating account balance: $e');
    }
  }

  Future<void> _updateAccountWeight(String customerName, double grams) async {
    print('\n========== PROCESSING GOLD RECEIPT ==========');
    print('Customer: $customerName');
    print('Gold Weight to Add: ${grams.toStringAsFixed(3)} gm');

    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson == null || accountsJson.isEmpty) {
      print('ERROR: No accounts found in database');
      return;
    }

    try {
      List<dynamic> accounts = jsonDecode(accountsJson);

      int accountIndex = accounts.indexWhere(
        (account) =>
            account['name'].toString().toUpperCase() ==
            customerName.toUpperCase(),
      );

      if (accountIndex == -1) {
        print('ERROR: Account not found for customer: $customerName');
        return;
      }

      String weightStr =
          accounts[accountIndex]['weight']?.toString() ?? '0.000';
      double currentWeight = double.tryParse(weightStr) ?? 0.0;

      print('Current Weight: ${currentWeight.toStringAsFixed(3)} gm');

      double newWeight = currentWeight + grams;

      print('New Weight: ${newWeight.toStringAsFixed(3)} gm');

      accounts[accountIndex]['weight'] = newWeight.toStringAsFixed(3);

      await prefs.setString('accounts', jsonEncode(accounts));
      print('========== GOLD RECEIPT PROCESSED ==========\n');
    } catch (e) {
      print('ERROR updating account weight: $e');
    }
  }

  Future<void> _deleteReceipt(int index) async {
    final receipt = receipts[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Receipt'),
          content: Text(
            receipt.isCashForGold
                ? 'Are you sure you want to delete this gold receipt from "${receipt.name}"?\n\nThis will revert ${receipt.goldGrams?.toStringAsFixed(3)} grams from weight.'
                : 'Are you sure you want to delete this receipt from "${receipt.name}"?\n\nThis will revert the balance changes.',
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
      if (receipt.isCashForGold) {
        await _revertAccountWeight(receipt.name, receipt.goldGrams ?? 0.0);
      } else {
        await _revertAccountBalance(receipt.name, receipt.amount);
      }

      setState(() {
        receipts.removeAt(index);
        selectedReceiptIndex = null;
      });

      await _saveReceipts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt deleted and ${receipt.isCashForGold ? "weight" : "balance"} reverted successfully!',
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _revertAccountBalance(
    String customerName,
    double receiptAmount,
  ) async {
    print('\n========== REVERTING CASH RECEIPT ==========');

    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson == null || accountsJson.isEmpty) return;

    try {
      List<dynamic> accounts = jsonDecode(accountsJson);

      int accountIndex = accounts.indexWhere(
        (account) =>
            account['name'].toString().toUpperCase() ==
            customerName.toUpperCase(),
      );

      if (accountIndex == -1) return;

      String debitStr = accounts[accountIndex]['debit']?.toString() ?? '0.00';
      String creditStr = accounts[accountIndex]['credit']?.toString() ?? '0.00';

      double currentDebit = double.tryParse(debitStr) ?? 0.0;
      double currentCredit = double.tryParse(creditStr) ?? 0.0;

      double amountToRevert = receiptAmount;
      double newDebit = currentDebit;
      double newCredit = currentCredit;

      if (currentCredit > 0) {
        if (currentCredit >= amountToRevert) {
          newCredit = currentCredit - amountToRevert;
          amountToRevert = 0.0;
        } else {
          amountToRevert = amountToRevert - currentCredit;
          newCredit = 0.0;
        }
      }

      if (amountToRevert > 0) {
        newDebit = currentDebit + amountToRevert;
      }

      accounts[accountIndex]['debit'] = newDebit.toStringAsFixed(2);
      accounts[accountIndex]['credit'] = newCredit.toStringAsFixed(2);

      await prefs.setString('accounts', jsonEncode(accounts));
      print('========== CASH RECEIPT REVERTED ==========\n');
    } catch (e) {
      print('ERROR reverting account balance: $e');
    }
  }

  Future<void> _revertAccountWeight(String customerName, double grams) async {
    print('\n========== REVERTING GOLD RECEIPT ==========');
    print('Customer: $customerName');
    print('Gold Weight to Remove: ${grams.toStringAsFixed(3)} gm');

    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson == null || accountsJson.isEmpty) return;

    try {
      List<dynamic> accounts = jsonDecode(accountsJson);

      int accountIndex = accounts.indexWhere(
        (account) =>
            account['name'].toString().toUpperCase() ==
            customerName.toUpperCase(),
      );

      if (accountIndex == -1) return;

      String weightStr =
          accounts[accountIndex]['weight']?.toString() ?? '0.000';
      double currentWeight = double.tryParse(weightStr) ?? 0.0;

      print('Current Weight: ${currentWeight.toStringAsFixed(3)} gm');

      double newWeight = currentWeight - grams;

      print('New Weight: ${newWeight.toStringAsFixed(3)} gm');

      accounts[accountIndex]['weight'] = newWeight.toStringAsFixed(3);

      await prefs.setString('accounts', jsonEncode(accounts));
      print('========== GOLD RECEIPT REVERTED ==========\n');
    } catch (e) {
      print('ERROR reverting account weight: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _goldPriceController.dispose();
    _customerSearchController.dispose(); // NEW
    super.dispose();
  }

  double get totalReceipts {
    return filteredReceipts.fold(0.0, (sum, receipt) => sum + receipt.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterToggle(),
            _buildTableHeader(),
            Expanded(child: _buildReceiptsList()),
            _buildTotalFooter(),
          ],
        ),
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 80.0, right: 20),
        child: FloatingActionButton(
          onPressed: _showAddReceiptDialog,
          backgroundColor: Colors.blue[600],
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.r),
          topRight: Radius.circular(12.r),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long, color: Colors.blue[700], size: 28),
          SizedBox(width: 12.w),
          Text(
            'Cash Receipts',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '${filteredReceipts.length} Receipts',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1.w),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 20, color: Colors.grey[700]),
          SizedBox(width: 8.w),
          Text(
            'Filter:',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 12.w),
          _buildFilterChip('All Time'),
          SizedBox(width: 8.w),
          _buildFilterChip('Today'),
          SizedBox(width: 8.w),
          _buildFilterChip('This Week'),
          SizedBox(width: 8.w),
          _buildFilterChip('This Month'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = filterPeriod == label;
    return InkWell(
      onTap: () {
        setState(() {
          filterPeriod = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[400]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFF6B7280),
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1.w),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Customer Name',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Amount / Grams',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Type / Date',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
          SizedBox(width: 40.w),
        ],
      ),
    );
  }

  Widget _buildReceiptsList() {
    if (filteredReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              filterPeriod == 'All Time'
                  ? 'No receipts recorded yet'
                  : 'No receipts found for $filterPeriod',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap + to add a new receipt',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredReceipts.length,
      itemBuilder: (context, index) {
        final receipt = filteredReceipts[index];
        final actualIndex = receipts.indexOf(receipt);
        final isSelected = selectedReceiptIndex == actualIndex;
        return _buildReceiptRow(receipt, actualIndex, isSelected);
      },
    );
  }

  Widget _buildReceiptRow(CashReceipt receipt, int index, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          if (selectedReceiptIndex == index) {
            selectedReceiptIndex = null;
          } else {
            selectedReceiptIndex = index;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue[50]
              : (index % 2 == 0 ? Colors.white : Colors.grey[25]),
          border: Border(
            left: isSelected
                ? BorderSide(color: Colors.blue[600]!, width: 4.w)
                : BorderSide.none,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: receipt.isCashForGold
                            ? Colors.amber[100]
                            : Colors.blue[100],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        receipt.isCashForGold ? Icons.balance : Icons.person,
                        color: receipt.isCashForGold
                            ? Colors.amber[700]
                            : Colors.blue[700],
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        receipt.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: isSelected
                              ? Colors.blue[800]
                              : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: receipt.isCashForGold
                              ? Colors.amber[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '₹${receipt.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: receipt.isCashForGold
                                ? Colors.amber[700]
                                : Colors.blue[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                      if (receipt.isCashForGold && receipt.goldGrams != null)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '${receipt.goldGrams!.toStringAsFixed(3)} gm',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.amber[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: receipt.isCashForGold
                            ? Colors.amber[100]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        receipt.isCashForGold ? 'GOLD' : 'CASH',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: receipt.isCashForGold
                              ? Colors.amber[800]
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      DateFormat('MMM dd, yyyy').format(receipt.date),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40.w,
                child: isSelected
                    ? IconButton(
                        icon: Icon(Icons.delete_outline, size: 20),
                        color: Colors.red[400],
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () => _deleteReceipt(index),
                      )
                    : SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFF6B7280),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12.r),
          bottomRight: Radius.circular(12.r),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1.w),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.calculate, color: Colors.white, size: 18),
                SizedBox(width: 8.w),
                Text(
                  'Total ($filterPeriod)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${filteredReceipts.length} Records',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '₹${totalReceipts.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 40.w),
        ],
      ),
    );
  }

  void _showAddReceiptDialog() {
    _amountController.clear();
    _goldPriceController.text = '0.00';
    _customerSearchController.clear(); // NEW
    _receiptDate = DateTime.now();
    _selectedCustomer = null;
    isCashForGold = false;
    calculatedGrams = 0.0;
    filteredCustomerList = List.from(customerList); // NEW

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateGrams() {
              final amount =
                  double.tryParse(_amountController.text.trim()) ?? 0.0;
              final goldPrice =
                  double.tryParse(_goldPriceController.text.trim()) ?? 1.0;

              setModalState(() {
                if (goldPrice > 0) {
                  calculatedGrams = amount / goldPrice;
                } else {
                  calculatedGrams = 0.0;
                }
              });
            }

            // NEW: Filter customers
            void filterCustomers(String query) {
              setModalState(() {
                if (query.isEmpty) {
                  filteredCustomerList = List.from(customerList);
                } else {
                  filteredCustomerList = customerList
                      .where(
                        (customer) => customer.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.45,
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDialogHeader(),
                      SizedBox(height: 24.h),
                      _buildToggleSwitch(setModalState),
                      SizedBox(height: 20.h),
                      _buildSearchableCustomerField(
                        setModalState,
                        filterCustomers,
                      ), // NEW
                      SizedBox(height: 20.h),
                      _buildAmountField(updateGrams),
                      SizedBox(height: 20.h),
                      if (isCashForGold) ...[
                        _buildGoldPriceField(updateGrams),
                        SizedBox(height: 16.h),
                        _buildGramDisplay(),
                        SizedBox(height: 20.h),
                      ],
                      _buildDateField(setModalState),
                      SizedBox(height: 32.h),
                      _buildDialogButtons(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(Icons.receipt, color: Colors.blue[700], size: 28),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Receipt',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Record a new transaction',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, color: Colors.grey[600]),
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildToggleSwitch(StateSetter setModalState) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setModalState(() {
                  isCashForGold = false;
                  calculatedGrams = 0.0;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isCashForGold ? Colors.blue[600] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.money,
                      size: 20,
                      color: !isCashForGold ? Colors.white : Colors.grey[700],
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Cash Only',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: !isCashForGold ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: InkWell(
              onTap: () {
                setModalState(() {
                  isCashForGold = true;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isCashForGold ? Colors.amber[600] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.balance,
                      size: 20,
                      color: isCashForGold ? Colors.white : Colors.grey[700],
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Cash for Gold',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isCashForGold ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Searchable customer field
  Widget _buildSearchableCustomerField(
    StateSetter setModalState,
    Function(String) onSearch,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Name *',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _customerSearchController,
          decoration: InputDecoration(
            hintText: 'Search and select customer',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon: _selectedCustomer != null
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setModalState(() {
                        _customerSearchController.clear();
                        _selectedCustomer = null;
                        filteredCustomerList = List.from(customerList);
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2.w),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.red[400]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            onSearch(value);
          },
          validator: (value) {
            if (_selectedCustomer == null || _selectedCustomer!.isEmpty) {
              return 'Please select a customer';
            }
            return null;
          },
          readOnly: _selectedCustomer != null,
        ),
        if (_customerSearchController.text.isNotEmpty &&
            _selectedCustomer == null)
          Container(
            margin: EdgeInsets.only(top: 8),
            constraints: BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: filteredCustomerList.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredCustomerList.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomerList[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        title: Text(
                          customer,
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        onTap: () {
                          setModalState(() {
                            _selectedCustomer = customer;
                            _customerSearchController.text = customer;
                          });
                        },
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _buildAmountField(VoidCallback onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Received Amount *',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (value) => onChanged(),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: Icon(Icons.currency_rupee, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2.w),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.red[400]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Receipt amount is required';
            }
            final amount = double.tryParse(value.trim());
            if (amount == null) {
              return 'Please enter a valid amount';
            }
            if (amount <= 0) {
              return 'Amount must be greater than 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGoldPriceField(VoidCallback onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gold Price per Gram *',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _goldPriceController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (value) => onChanged(),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: Icon(Icons.currency_rupee, color: Colors.amber[700]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.amber[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.amber[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.amber[600]!, width: 2.w),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.red[400]!),
            ),
            filled: true,
            fillColor: Colors.amber[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Gold price is required';
            }
            final price = double.tryParse(value.trim());
            if (price == null) {
              return 'Please enter a valid price';
            }
            if (price <= 0) {
              return 'Price must be greater than 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGramDisplay() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[50]!, Colors.amber[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.amber[400]!, width: 2.w),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[200],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.balance, color: Colors.amber[900], size: 24),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gold Weight',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.amber[900],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${calculatedGrams.toStringAsFixed(3)} grams',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt Date',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _receiptDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.blue[600]!,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null && picked != _receiptDate) {
              setModalState(() {
                _receiptDate = picked;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(_receiptDate),
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey[800]),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              side: BorderSide(color: Colors.grey[400]!),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitReceipt,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCashForGold
                  ? Colors.amber[600]
                  : Colors.blue[600],
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Add Receipt',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _submitReceipt() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await Future.delayed(Duration(milliseconds: 500));

      final amount = double.parse(_amountController.text.trim());
      final receiptId = 'RCP${DateTime.now().millisecondsSinceEpoch}';

      final newReceipt = CashReceipt(
        id: receiptId,
        name: _selectedCustomer!,
        amount: amount,
        date: _receiptDate,
        isCashForGold: isCashForGold,
        goldGrams: isCashForGold ? calculatedGrams : null,
        goldPrice: isCashForGold
            ? double.parse(_goldPriceController.text.trim())
            : null,
      );

      setState(() {
        receipts.insert(0, newReceipt);
        _isLoading = false;
      });

      await _saveReceipts();

      if (isCashForGold) {
        await _updateAccountWeight(_selectedCustomer!, calculatedGrams);
      } else {
        await _updateAccountBalance(_selectedCustomer!, amount);
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCashForGold
                ? 'Gold receipt (${calculatedGrams.toStringAsFixed(3)}gm) from "$_selectedCustomer" recorded!'
                : 'Cash receipt from "$_selectedCustomer" recorded successfully!',
          ),
          backgroundColor: isCashForGold ? Colors.amber[600] : Colors.blue[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }
}

class CashReceipt {
  final String id;
  final String name;
  final double amount;
  final DateTime date;
  final bool isCashForGold;
  final double? goldGrams;
  final double? goldPrice;

  CashReceipt({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    this.isCashForGold = false,
    this.goldGrams,
    this.goldPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
      'isCashForGold': isCashForGold,
      'goldGrams': goldGrams,
      'goldPrice': goldPrice,
    };
  }

  factory CashReceipt.fromJson(Map<String, dynamic> json) {
    return CashReceipt(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      isCashForGold: json['isCashForGold'] ?? false,
      goldGrams: json['goldGrams']?.toDouble(),
      goldPrice: json['goldPrice']?.toDouble(),
    );
  }
}
