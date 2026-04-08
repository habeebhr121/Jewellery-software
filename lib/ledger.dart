import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jwells_report/add_ledger.dart';
import 'package:intl/intl.dart';

class AccountLedgerScreen extends StatefulWidget {
  final bool showDialog;

  const AccountLedgerScreen({super.key, this.showDialog = false});

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen>
    with AutomaticKeepAliveClientMixin {
  List<Customer> customers = [];
  List<Account> accounts = [];
  int? selectedIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();

    if (widget.showDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddCustomerDialog();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAccounts();
  }

  double _calculateNetBalance(Account account) {
    double debit = double.tryParse(account.debit) ?? 0.0;
    double credit = double.tryParse(account.credit) ?? 0.0;
    return credit - debit;
  }

  double get totalDebit {
    return accounts.fold(0.0, (sum, account) {
      double netBalance = _calculateNetBalance(account);
      return sum + (netBalance < 0 ? netBalance.abs() : 0.0);
    });
  }

  double get totalCredit {
    return accounts.fold(0.0, (sum, account) {
      double netBalance = _calculateNetBalance(account);
      return sum + (netBalance > 0 ? netBalance : 0.0);
    });
  }

  double get totalWeight {
    return accounts.fold(0.0, (sum, account) {
      double weight = double.tryParse(account.weight.toString()) ?? 0.0;
      return sum + weight;
    });
  }

  Future<void> _reloadAccounts() async {
    await _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedJson = jsonDecode(accountsJson);
        List<Account> loadedAccounts = decodedJson
            .map((json) => Account.fromJson(json))
            .toList();

        for (int i = 0; i < loadedAccounts.length; i++) {
          loadedAccounts[i] = await _syncAccountWithTransactions(
            loadedAccounts[i],
          );
        }

        setState(() {
          accounts = loadedAccounts;
        });

        print('Loaded and synced ${accounts.length} accounts');
      } catch (e) {
        print('Error loading accounts: $e');
        _initializeDefaultAccounts();
      }
    } else {
      _initializeDefaultAccounts();
    }
  }

  // UPDATED: Modified to handle Cash for Gold transactions
  Future<Account> _syncAccountWithTransactions(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    List<TransactionWithSource> syncedTransactions = [];

    String accountNameUpper = account.name.toUpperCase();

    // Load Cash Receipts
    final receiptsJson = prefs.getStringList('cash_receipts') ?? [];
    for (int i = 0; i < receiptsJson.length; i++) {
      try {
        final data = jsonDecode(receiptsJson[i]);
        String customerName = (data['name'] ?? '').toString().toUpperCase();

        if (customerName == accountNameUpper) {
          bool isCashForGold = data['isCashForGold'] == true;

          if (isCashForGold && data['goldGrams'] != null) {
            // MODIFIED: For Cash for Gold - add gold grams to weight
            double goldGrams = (data['goldGrams'] ?? 0).toDouble();
            syncedTransactions.add(
              TransactionWithSource(
                transaction: Transaction(
                  date: DateTime.parse(
                    data['date'] ?? DateTime.now().toIso8601String(),
                  ),
                  type: TransactionType.weight,
                  amount: goldGrams, // Add grams to weight
                  description:
                      'Cash Receipt - Cash for Gold (${goldGrams.toStringAsFixed(3)} gm)',
                ),
                sourceType: 'cash_receipts',
                sourceIndex: i,
                originalData: data,
              ),
            );
          } else {
            // Normal cash receipt - add to credit
            syncedTransactions.add(
              TransactionWithSource(
                transaction: Transaction(
                  date: DateTime.parse(
                    data['date'] ?? DateTime.now().toIso8601String(),
                  ),
                  type: TransactionType.credit,
                  amount: (data['amount'] ?? 0).toDouble(),
                  description: 'Cash Receipt',
                ),
                sourceType: 'cash_receipts',
                sourceIndex: i,
                originalData: data,
              ),
            );
          }
        }
      } catch (e) {
        print('Error syncing receipt: $e');
      }
    }

    // Load Cash Payments
    final paymentsJson = prefs.getStringList('cash_payments') ?? [];
    for (int i = 0; i < paymentsJson.length; i++) {
      try {
        final data = jsonDecode(paymentsJson[i]);
        String customerName = (data['name'] ?? '').toString().toUpperCase();

        if (customerName == accountNameUpper) {
          bool isCashForGold = data['isCashForGold'] == true;

          if (isCashForGold && data['goldGrams'] != null) {
            // MODIFIED: For Cash for Gold - subtract gold grams from weight
            double goldGrams = (data['goldGrams'] ?? 0).toDouble();
            syncedTransactions.add(
              TransactionWithSource(
                transaction: Transaction(
                  date: DateTime.parse(
                    data['date'] ?? DateTime.now().toIso8601String(),
                  ),
                  type: TransactionType.weight,
                  amount: -goldGrams, // Subtract grams from weight
                  description:
                      'Cash Payment - Cash for Gold (${goldGrams.toStringAsFixed(3)} gm)',
                ),
                sourceType: 'cash_payments',
                sourceIndex: i,
                originalData: data,
              ),
            );
          } else {
            // Normal cash payment - add to debit
            syncedTransactions.add(
              TransactionWithSource(
                transaction: Transaction(
                  date: DateTime.parse(
                    data['date'] ?? DateTime.now().toIso8601String(),
                  ),
                  type: TransactionType.debit,
                  amount: (data['amount'] ?? 0).toDouble(),
                  description: 'Cash Payment',
                ),
                sourceType: 'cash_payments',
                sourceIndex: i,
                originalData: data,
              ),
            );
          }
        }
      } catch (e) {
        print('Error syncing payment: $e');
      }
    }

    // Load Issue Jewellery
    final alterationsJson = prefs.getStringList('alteration_bills') ?? [];
    for (int i = 0; i < alterationsJson.length; i++) {
      try {
        final data = jsonDecode(alterationsJson[i]);
        String customerName = (data['accountName'] ?? '')
            .toString()
            .toUpperCase();

        if (customerName == accountNameUpper) {
          double totalPureWeight = 0.0;
          if (data['items'] != null) {
            for (var item in data['items']) {
              totalPureWeight +=
                  double.tryParse(item['pure']?.toString() ?? '0') ?? 0.0;
            }
          }

          syncedTransactions.add(
            TransactionWithSource(
              transaction: Transaction(
                date: DateTime.parse(
                  data['timestamp'] ?? DateTime.now().toIso8601String(),
                ),
                type: TransactionType.weight,
                amount: -totalPureWeight,
                description:
                    'Issue Jewellery - SL No: ${data['slNo'] ?? 'N/A'}',
              ),
              sourceType: 'alteration_bills',
              sourceIndex: i,
              originalData: data,
            ),
          );
        }
      } catch (e) {
        print('Error syncing issue jewellery: $e');
      }
    }

    // Load Purchase Jewellery
    final purchasesJson = prefs.getStringList('purchase_bills') ?? [];
    for (int i = 0; i < purchasesJson.length; i++) {
      try {
        final data = jsonDecode(purchasesJson[i]);
        String customerName = (data['accountName'] ?? '')
            .toString()
            .toUpperCase();

        if (customerName == accountNameUpper) {
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

          if (totalPureWeight > 0) {
            syncedTransactions.add(
              TransactionWithSource(
                transaction: Transaction(
                  date: DateTime.parse(
                    data['timestamp'] ?? DateTime.now().toIso8601String(),
                  ),
                  type: TransactionType.weight,
                  amount: totalPureWeight,
                  description:
                      'Purchase Jewellery - Weight - SL No: ${data['slNo'] ?? 'N/A'}',
                ),
                sourceType: 'purchase_bills',
                sourceIndex: i,
                originalData: data,
              ),
            );
          }

          if (totalAmount > 0) {
            syncedTransactions.add(
              TransactionWithSource(
                transaction: Transaction(
                  date: DateTime.parse(
                    data['timestamp'] ?? DateTime.now().toIso8601String(),
                  ),
                  type: TransactionType.credit,
                  amount: totalAmount,
                  description:
                      'Purchase Jewellery - Amount - SL No: ${data['slNo'] ?? 'N/A'}',
                ),
                sourceType: 'purchase_bills',
                sourceIndex: i,
                originalData: data,
              ),
            );
          }
        }
      } catch (e) {
        print('Error syncing purchase: $e');
      }
    }

    syncedTransactions.sort(
      (a, b) => a.transaction.date.compareTo(b.transaction.date),
    );

    double totalDebit = 0.0;
    double totalCredit = 0.0;
    double totalWeight = 0.0;

    for (var txWithSource in syncedTransactions) {
      if (txWithSource.transaction.type == TransactionType.debit) {
        totalDebit += txWithSource.transaction.amount;
      } else if (txWithSource.transaction.type == TransactionType.credit) {
        totalCredit += txWithSource.transaction.amount;
      } else if (txWithSource.transaction.type == TransactionType.weight) {
        totalWeight += txWithSource.transaction.amount;
      }
    }

    return Account(
      name: account.name,
      debit: totalDebit.toStringAsFixed(2),
      credit: totalCredit.toStringAsFixed(2),
      weight: totalWeight.toStringAsFixed(3),
      isHighlighted: account.isHighlighted,
      transactions: syncedTransactions,
    );
  }

  Future<void> _deleteTransaction(TransactionWithSource txWithSource) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      List<String> sourceList =
          prefs.getStringList(txWithSource.sourceType) ?? [];

      if (txWithSource.sourceIndex < sourceList.length) {
        sourceList.removeAt(txWithSource.sourceIndex);
        await prefs.setStringList(txWithSource.sourceType, sourceList);

        await _reloadAccounts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8.w),
                  Expanded(child: Text('Transaction deleted successfully!')),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting transaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transaction: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _showTransactionDetailDialog(TransactionWithSource txWithSource) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (txWithSource.transaction.type) {
      case TransactionType.debit:
        typeColor = Colors.red[600]!;
        typeIcon = Icons.remove_circle_outline;
        typeLabel = 'DEBIT';
        break;
      case TransactionType.credit:
        typeColor = Colors.green[600]!;
        typeIcon = Icons.add_circle_outline;
        typeLabel = 'CREDIT';
        break;
      case TransactionType.weight:
        typeColor = Colors.amber[600]!;
        typeIcon = Icons.scale;
        typeLabel = 'WEIGHT';
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [typeColor, typeColor.withOpacity(0.7)],
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
                      Icon(typeIcon, color: Colors.white, size: 28),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
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

                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard('Basic Information', [
                          _buildInfoRow(
                            'Customer Name',
                            txWithSource.originalData['name']?.toString() ??
                                txWithSource.originalData['customerName']
                                    ?.toString() ??
                                txWithSource.originalData['accountName']
                                    ?.toString() ??
                                'N/A',
                          ),
                          if (txWithSource.originalData['slNo'] != null)
                            _buildInfoRow(
                              'SL No.',
                              txWithSource.originalData['slNo']!.toString(),
                            ),
                          if (txWithSource.originalData['phone'] != null)
                            _buildInfoRow(
                              'Phone',
                              txWithSource.originalData['phone']!.toString(),
                            ),
                          _buildInfoRow(
                            'Date',
                            DateFormat(
                              'MMM dd, yyyy',
                            ).format(txWithSource.transaction.date),
                          ),
                          _buildInfoRow(
                            'Time',
                            DateFormat(
                              'hh:mm a',
                            ).format(txWithSource.transaction.date),
                          ),
                        ]),

                        SizedBox(height: 16.h),

                        _buildInfoCard('Transaction Summary', [
                          if (txWithSource.transaction.type ==
                              TransactionType.weight)
                            _buildInfoRow(
                              'Total Pure Weight',
                              '${txWithSource.transaction.amount.toStringAsFixed(3)} gm',
                              valueColor: Colors.amber[800],
                            )
                          else
                            _buildInfoRow(
                              'Amount',
                              '₹${txWithSource.transaction.amount.toStringAsFixed(2)}',
                              valueColor:
                                  txWithSource.transaction.type ==
                                      TransactionType.credit
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          if (txWithSource.originalData['isCashForGold'] ==
                                  true &&
                              txWithSource.originalData['goldGrams'] != null)
                            _buildInfoRow(
                              'Gold Weight',
                              '${txWithSource.originalData['goldGrams']!.toStringAsFixed(3)} gm',
                              valueColor: Colors.amber[700],
                            ),
                          if (txWithSource.originalData['isCashForGold'] ==
                                  true &&
                              txWithSource.originalData['goldPrice'] != null)
                            _buildInfoRow(
                              'Gold Price/gm',
                              '₹${txWithSource.originalData['goldPrice']!.toStringAsFixed(2)}',
                            ),
                          if (txWithSource.originalData['items'] != null &&
                              (txWithSource.originalData['items'] as List)
                                  .isNotEmpty)
                            _buildInfoRow(
                              'Total Items',
                              '${(txWithSource.originalData['items'] as List).length}',
                            ),
                        ]),

                        SizedBox(height: 16.h),

                        if (txWithSource.originalData['items'] != null &&
                            (txWithSource.originalData['items'] as List)
                                .isNotEmpty)
                          _buildItemsCard(txWithSource.originalData, typeColor),
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

  Widget _buildItemsCard(Map<String, dynamic> rawData, Color typeColor) {
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
                          '₹${item['amount']?.toString() ?? '0.00'}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                    ],
                  ),
                  Divider(height: 16.h),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (item['sets'] != null)
                        _buildItemDetail(
                          'Sets',
                          item['sets']?.toString() ?? '0',
                        ),
                      if (item['gross'] != null)
                        _buildItemDetail('Gross', '${item['gross'] ?? '0'} gm'),
                      if (item['stone'] != null)
                        _buildItemDetail('Stone', '${item['stone'] ?? '0'} gm'),
                      if (item['weight'] != null)
                        _buildItemDetail(
                          'Weight',
                          '${item['weight'] ?? '0'} gm',
                        ),
                      if (item['waste'] != null)
                        _buildItemDetail('Waste', '${item['waste'] ?? '0'} gm'),
                      if (item['touchValue'] != null)
                        _buildItemDetail(
                          'Touch',
                          item['touchValue']?.toString() ?? '0',
                        ),
                      if (item['pure'] != null)
                        _buildItemDetail(
                          'Pure',
                          '${item['pure'] ?? '0'} gm',
                          Colors.amber[700],
                        ),
                      if (item['rate'] != null && item['rate'] != '0.00')
                        _buildItemDetail('Rate', '₹${item['rate']}'),
                      if (item['categoryName'] != null)
                        _buildItemDetail(
                          'Category',
                          item['categoryName']?.toString() ?? '',
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

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = jsonEncode(
      accounts.map((account) => account.toJson()).toList(),
    );
    await prefs.setString('accounts', accountsJson);
  }

  bool _isDuplicateName(String name) {
    final upperName = name.toUpperCase().trim();
    return accounts.any((account) => account.name.toUpperCase() == upperName);
  }

  void _initializeDefaultAccounts() {
    accounts = [];
    _saveAccounts();
    setState(() {});
  }

  Future<void> _deleteAccount(int index) async {
    final account = accounts[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Text(
            'Are you sure you want to delete "${account.name}"?\n\nNote: This will not delete the associated transactions from the database, only the account entry.',
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
      setState(() {
        accounts.removeAt(index);
        selectedIndex = null;
      });
      await _saveAccounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.white),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Account "${account.name}" deleted successfully!',
                  ),
                ),
              ],
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

  Future<void> _showTransactionHistory(int index) async {
    await _reloadAccounts();

    if (!mounted || index >= accounts.length) return;

    final account = accounts[index];
    int? selectedTxIndex;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[700]!, Colors.blue[500]!],
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
                          Icon(Icons.history, color: Colors.white, size: 28),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transaction History',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  account.name,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
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

                    // Summary Cards
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.grey[100],
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total Debit',
                                  '₹${account.debit}',
                                  Colors.red[400]!,
                                  Icons.arrow_upward,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total Credit',
                                  '₹${account.credit}',
                                  Colors.green[400]!,
                                  Icons.arrow_downward,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Gold Weight',
                                  '${account.weight} gm',
                                  Colors.amber[600]!,
                                  Icons.scale,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _reloadAccounts();
                              Navigator.of(context).pop();
                              _showTransactionHistory(index);
                            },
                            icon: Icon(
                              Icons.refresh,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Refresh',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Transaction List
                    Expanded(
                      child: account.transactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'No Transactions Yet',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Transactions from other screens will appear here',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: account.transactions.length,
                              itemBuilder: (context, txIndex) {
                                final reversedIndex =
                                    account.transactions.length - 1 - txIndex;
                                final txWithSource =
                                    account.transactions[reversedIndex];
                                final isSelected =
                                    selectedTxIndex == reversedIndex;

                                return _buildTransactionCardWithActions(
                                  txWithSource,
                                  isSelected,
                                  () {
                                    setDialogState(() {
                                      if (selectedTxIndex == reversedIndex) {
                                        selectedTxIndex = null;
                                      } else {
                                        selectedTxIndex = reversedIndex;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    await _reloadAccounts();
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCardWithActions(
    TransactionWithSource txWithSource,
    bool isSelected,
    VoidCallback onTap,
  ) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (txWithSource.transaction.type) {
      case TransactionType.debit:
        typeColor = Colors.red[600]!;
        typeIcon = Icons.remove_circle_outline;
        typeLabel = 'DEBIT';
        break;
      case TransactionType.credit:
        typeColor = Colors.green[600]!;
        typeIcon = Icons.add_circle_outline;
        typeLabel = 'CREDIT';
        break;
      case TransactionType.weight:
        typeColor = Colors.amber[600]!;
        typeIcon = Icons.scale;
        typeLabel = 'WEIGHT';
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.only(bottom: 12),
        elevation: isSelected ? 4 : 2,
        color: isSelected ? Colors.blue[50] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(
            color: isSelected ? Colors.blue[300]! : Colors.transparent,
            width: 2.w,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.h,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy hh:mm a',
                              ).format(txWithSource.transaction.date),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          txWithSource.transaction.type ==
                                  TransactionType.weight
                              ? '${txWithSource.transaction.amount >= 0 ? '+' : ''}${txWithSource.transaction.amount.toStringAsFixed(3)} gm'
                              : '₹${txWithSource.transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (txWithSource
                            .transaction
                            .description
                            .isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            txWithSource.transaction.description,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (isSelected) ...[
                SizedBox(height: 12.h),
                Divider(height: 1.h),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showTransactionDetailDialog(txWithSource),
                        icon: Icon(Icons.visibility, size: 18),
                        label: Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete Transaction'),
                              content: Text(
                                'Are you sure you want to delete this transaction? This action cannot be undone.',
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.red[50],
                                  ),
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (shouldDelete == true) {
                            await _deleteTransaction(txWithSource);
                            Navigator.of(context).pop();
                          }
                        },
                        icon: Icon(Icons.delete, size: 18),
                        label: Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AddCustomerDialog(
          onCustomerAdded:
              (name, balance, isDebit, weight, isWeightEntry) async {
                try {
                  final upperName = name.toUpperCase().trim();

                  if (_isDuplicateName(upperName)) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'Customer "$upperName" already exists!',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.orange[700],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                    return;
                  }

                  setState(() {
                    customers.add(
                      Customer(
                        name: upperName,
                        balance: balance,
                        isDebit: isDebit,
                      ),
                    );
                  });

                  final newAccount = Account(
                    name: upperName,
                    debit: '0.00',
                    credit: '0.00',
                    weight: '0.000',
                    isHighlighted: false,
                    transactions: [],
                  );

                  setState(() {
                    accounts.add(newAccount);
                  });

                  await _saveAccounts();
                  await _reloadAccounts();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'Customer "$upperName" added successfully!',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error saving customer: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'Error saving customer: ${e.toString()}',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[700]!, Colors.purple[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, color: Colors.white, size: 28),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Ledger Account',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: _reloadAccounts,
                      tooltip: 'Refresh accounts',
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBalanceCard(
                      'Total Debit',
                      '₹${totalDebit.toStringAsFixed(2)}',
                      Colors.red[400]!,
                    ),
                    _buildBalanceCard(
                      'Total Credit',
                      '₹${totalCredit.toStringAsFixed(2)}',
                      Colors.green[400]!,
                    ),
                    _buildBalanceCard(
                      'Total Gold Weight',
                      '${totalWeight >= 0 ? '+' : ''}${totalWeight.toStringAsFixed(3)} gm',
                      totalWeight >= 0 ? Colors.amber[600]! : Colors.red[600]!,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Account Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Debit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Credit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Weight (gm)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                SizedBox(width: 80.w),
              ],
            ),
          ),

          // Account List
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12.r),
                  bottomRight: Radius.circular(12.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: accounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'No Accounts Found',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Add your first customer to get started',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(0),
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final isSelected = selectedIndex == index;
                        return _buildAccountRow(
                          context,
                          index,
                          account.name,
                          account.debit,
                          account.credit,
                          account.weight,
                          account.isHighlighted,
                          isSelected,
                        );
                      },
                    ),
            ),
          ),

          // Footer
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'As of: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Type: UNREGISTERED',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, String amount, Color color) {
    return SizedBox(
      width: 200.w,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              amount,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(
    BuildContext context,
    int index,
    String accountName,
    String debit,
    String credit,
    String weight,
    bool isHighlighted,
    bool isSelected,
  ) {
    double debitAmount = double.tryParse(debit) ?? 0.0;
    double creditAmount = double.tryParse(credit) ?? 0.0;
    double netBalance = creditAmount - debitAmount;

    String weightStr = weight.toString().trim();
    double weightValue = double.tryParse(weightStr) ?? 0.0;

    bool isZeroWeight = weightValue == 0.0;
    bool isNegativeWeight = weightValue < 0.0;

    return InkWell(
      onTap: () {
        setState(() {
          if (selectedIndex == index) {
            selectedIndex = null;
          } else {
            selectedIndex = index;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue[50]
              : (isHighlighted ? Colors.green[50] : Colors.transparent),
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1.w),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (isHighlighted && !isSelected)
                      Container(
                        width: 4.w,
                        height: 20.h,
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                        margin: EdgeInsets.only(right: 8),
                      ),
                    if (isSelected)
                      Container(
                        width: 4.w,
                        height: 20.h,
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                        margin: EdgeInsets.only(right: 8),
                      ),
                    Expanded(
                      child: Text(
                        accountName,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: (isHighlighted || isSelected)
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.blue[800]
                              : (isHighlighted
                                    ? Colors.green[800]
                                    : Colors.grey[800]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  netBalance < 0
                      ? '₹${netBalance.abs().toStringAsFixed(2)}'
                      : '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: netBalance < 0 ? Colors.red[600] : Colors.grey[400],
                    fontWeight: netBalance < 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  netBalance > 0 ? '₹${netBalance.toStringAsFixed(2)}' : '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: netBalance > 0
                        ? Colors.green[600]
                        : Colors.grey[400],
                    fontWeight: netBalance > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isZeroWeight
                      ? '—'
                      : isNegativeWeight
                      ? weightValue.toStringAsFixed(3)
                      : '+${weightValue.toStringAsFixed(3)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isZeroWeight
                        ? Colors.grey[400]
                        : (isNegativeWeight
                              ? Colors.red[600]
                              : Colors.blue[600]),
                    fontWeight: isZeroWeight
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 80.w,
                child: isSelected
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.visibility_outlined, size: 20),
                            color: Colors.blue[600],
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () => _showTransactionHistory(index),
                            tooltip: 'View History',
                          ),
                          SizedBox(width: 12.w),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20),
                            color: Colors.red[400],
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () => _deleteAccount(index),
                            tooltip: 'Delete',
                          ),
                        ],
                      )
                    : SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Models
enum TransactionType { debit, credit, weight }

class Transaction {
  final DateTime date;
  final TransactionType type;
  final double amount;
  final String description;

  Transaction({
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.toString().split('.').last,
      'amount': amount,
      'description': description,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      date: DateTime.parse(json['date']),
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] ?? '',
    );
  }
}

class TransactionWithSource {
  final Transaction transaction;
  final String sourceType;
  final int sourceIndex;
  final Map<String, dynamic> originalData;

  TransactionWithSource({
    required this.transaction,
    required this.sourceType,
    required this.sourceIndex,
    required this.originalData,
  });
}

class Account {
  final String name;
  final String debit;
  final String credit;
  final String weight;
  final bool isHighlighted;
  final List<TransactionWithSource> transactions;

  Account({
    required this.name,
    required this.debit,
    required this.credit,
    required this.weight,
    required this.isHighlighted,
    List<TransactionWithSource>? transactions,
  }) : transactions = transactions ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'debit': debit,
      'credit': credit,
      'weight': weight,
      'isHighlighted': isHighlighted,
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    var weightValue = json['weight'];
    String weightString;

    if (weightValue is num) {
      weightString = weightValue.toStringAsFixed(3);
    } else if (weightValue is String) {
      weightString = weightValue;
    } else {
      weightString = '0.000';
    }

    return Account(
      name: json['name'] ?? '',
      debit: json['debit'] ?? '0.00',
      credit: json['credit'] ?? '0.00',
      weight: weightString,
      isHighlighted: json['isHighlighted'] ?? false,
      transactions: [],
    );
  }
}

class Customer {
  final String name;
  final double balance;
  final bool isDebit;

  Customer({required this.name, required this.balance, required this.isDebit});
}
