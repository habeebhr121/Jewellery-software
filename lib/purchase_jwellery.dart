import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jwells_report/add_item_sale.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:jwells_report/jwellery_details.dart';

class PurcahseJwellery extends StatefulWidget {
  const PurcahseJwellery({super.key});

  @override
  State<PurcahseJwellery> createState() => _PurcahseJwelleryState();
}

class _PurcahseJwelleryState extends State<PurcahseJwellery> {
  String selectedName = '';
  String slNo = 'PC0001';
  String currentDate = '';
  List<Map<String, dynamic>> goldItems = [];
  int? selectedRowIndex;
  List<String> accountNames = [];

  @override
  void initState() {
    super.initState();
    _initializeBill();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSearchablePopup(context);
    });
  }

  Future<void> _initializeBill() async {
    await _loadAccountNames();
    await _generateSlNo();
    _getCurrentDate();
    setState(() {
      goldItems = [];
      selectedName = '';
    });
  }

  Future<void> _loadAccountNames() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedJson = jsonDecode(accountsJson);
        setState(() {
          accountNames = decodedJson
              .map((json) => json['name'].toString())
              .toList();
        });
      } catch (e) {
        print('Error loading account names: $e');
        setState(() {
          accountNames = [];
        });
      }
    } else {
      setState(() {
        accountNames = [];
      });
    }
  }

  Future<void> _generateSlNo() async {
    final prefs = await SharedPreferences.getInstance();
    int lastNo = prefs.getInt('last_purchase_sl_no') ?? 0;
    lastNo++;
    setState(() {
      slNo = 'PC${lastNo.toString().padLeft(4, '0')}';
    });
  }

  void _getCurrentDate() {
    setState(() {
      currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    });
  }

  Future<void> _saveBill() async {
    if (selectedName.isEmpty) {
      _showSnackBar('Please select an account name', Colors.red);
      return;
    }

    if (goldItems.isEmpty) {
      _showSnackBar('Please add at least one item', Colors.red);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Update SL No counter
      int currentNo = int.parse(slNo.substring(2));
      await prefs.setInt('last_purchase_sl_no', currentNo);

      // Calculate total amount
      double totalAmount = 0.0;
      for (var item in goldItems) {
        totalAmount +=
            double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      }

      // Create purchase bill object with complete transaction info
      final bill = {
        'id': 'PCH${DateTime.now().millisecondsSinceEpoch}',
        'slNo': slNo,
        'date': currentDate,
        'accountName': selectedName,
        'items': goldItems,
        'totalAmount': totalAmount,
        'type': 'PURCHASE',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Load existing purchase bills
      List<String> bills = prefs.getStringList('purchase_bills') ?? [];
      bills.add(jsonEncode(bill));
      await prefs.setStringList('purchase_bills', bills);

      print('Purchase bill saved: ${bill['id']}');

      // Add to inventory quantities and weights
      await _updateInventoryQuantities();

      // Update account weight (add pure weight)
      await _updateAccountWeight();

      _showSnackBar('Purchase bill saved successfully!', Colors.green);

      // Reset for new bill
      await Future.delayed(Duration(seconds: 1));
      _resetBill();
    } catch (e) {
      _showSnackBar('Error saving bill: $e', Colors.red);
      print('Error in _saveBill: $e');
    }
  }

  Future<void> _updateAccountWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('accounts');

    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        List<dynamic> accounts = jsonDecode(accountsJson);

        // Calculate total pure weight from all items
        double totalPureWeight = 0.0;
        for (var item in goldItems) {
          double pureWeight =
              double.tryParse(item['pure']?.toString() ?? '0') ?? 0.0;
          totalPureWeight += pureWeight;
        }

        // Find matching account by name
        int accountIndex = accounts.indexWhere(
          (account) =>
              account['name'].toString().toUpperCase() ==
              selectedName.toUpperCase(),
        );

        if (accountIndex != -1) {
          // Get current weight from account
          double currentWeight =
              double.tryParse(
                accounts[accountIndex]['weight']?.toString() ?? '0',
              ) ??
              0.0;

          // Add pure weight (Purchase adds to account)
          double newWeight = currentWeight + totalPureWeight;

          // Update account weight
          accounts[accountIndex]['weight'] = newWeight.toStringAsFixed(3);

          // Save updated accounts
          await prefs.setString('accounts', jsonEncode(accounts));

          print(
            'Account weight updated: $selectedName + Total Pure Weight: $totalPureWeight, New Weight: $newWeight',
          );
        } else {
          print('Account not found: $selectedName');
        }
      } catch (e) {
        print('Error updating account weight: $e');
      }
    }
  }

  Future<void> _updateInventoryQuantities() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('inventory_items');

    if (itemsJson != null && itemsJson.isNotEmpty) {
      try {
        List<dynamic> inventoryItems = jsonDecode(itemsJson);

        for (var purchasedItem in goldItems) {
          String itemName = purchasedItem['description'];
          int purchasedQuantity = int.tryParse(purchasedItem['set']) ?? 1;
          double purchasedWeight =
              double.tryParse(purchasedItem['gross']) ?? 0.0;

          int index = inventoryItems.indexWhere(
            (item) =>
                item['name'].toString().toUpperCase() == itemName.toUpperCase(),
          );

          if (index != -1) {
            int currentQty = inventoryItems[index]['quantity'] ?? 0;
            int newQty = currentQty + purchasedQuantity;

            inventoryItems[index]['quantity'] = newQty;

            double currentWeight = (inventoryItems[index]['weight'] ?? 0.0)
                .toDouble();
            double newWeight = currentWeight + purchasedWeight;

            inventoryItems[index]['weight'] = newWeight;
          }
        }

        await prefs.setString('inventory_items', jsonEncode(inventoryItems));

        print('Inventory updated successfully (Purchase)');
      } catch (e) {
        print('Error updating inventory: $e');
      }
    }
  }

  void _resetBill() {
    setState(() {
      selectedName = '';
      goldItems = [];
      selectedRowIndex = null;
    });
    _initializeBill();

    Future.delayed(Duration(milliseconds: 500), () {
      _showSearchablePopup(context);
    });
  }

  void _deleteItem(int index) {
    setState(() {
      goldItems.removeAt(index);
      selectedRowIndex = null;
    });
    _showSnackBar('Item deleted', Colors.orange);
  }

  Future<void> _editItem(int index) async {
    final item = goldItems[index];

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => JewelryDescriptionForm(
          item: {'name': item['description'], 'isEdit': true, 'editData': item},
        ),
      ),
    );

    if (result != null) {
      setState(() {
        goldItems[index] = {
          'description': result['item'],
          'set': result['sets'],
          'stone': result['stoneWeight'],
          'gross': result['grossWeight'],
          'pure%': result['purity'],
          'pure': result['pureWeight'] ?? '',
          'rate': result['rate'],
          'amount': result['totalAmount'],
          'making': result['making'] ?? '0.00', // NEW
          'makingUnit': result['makingUnit'] ?? '%', // NEW
          'discount': result['discount'] ?? '0.00', // NEW
          'netWeight': result['netWeight'] ?? '0.000', // NEW
        };
        selectedRowIndex = null;
      });
      _showSnackBar('Item updated', Colors.blue);
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
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple[700]!, Colors.deepPurple[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      color: Colors.amber[300],
                      size: 28,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Name : ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.sp,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showSearchablePopup(context),
                                child: Row(
                                  children: [
                                    Text(
                                      selectedName.isEmpty
                                          ? "Select Name"
                                          : selectedName,
                                      style: TextStyle(
                                        color: selectedName.isNotEmpty
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                              Spacer(),
                              _buildInfoItem('Date', currentDate),
                              SizedBox(width: 35.w),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Text(
                                'SL No. : ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Text(
                                slNo,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
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
          ),

          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
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
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.r),
                        topRight: Radius.circular(16.r),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('DESCRIPTION', 2),
                        _buildHeaderCell('SET', 1),
                        _buildHeaderCell('STONE', 1),
                        _buildHeaderCell('GROSS', 1),
                        _buildHeaderCell('PURE%', 1),
                        _buildHeaderCell('PURE', 1),
                        _buildHeaderCell('RATE', 1),
                        _buildHeaderCell('AMOUNT', 1),
                        SizedBox(width: 80.w),
                      ],
                    ),
                  ),

                  Expanded(
                    child: goldItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'No Items Purchased',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Click "Add" button to add purchase items',
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
                            itemCount: goldItems.length,
                            itemBuilder: (context, index) {
                              final isSelected = selectedRowIndex == index;
                              return _buildDataRow(
                                goldItems[index],
                                index,
                                index % 2 == 0,
                                isSelected,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            margin: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  'Save',
                  Icons.save,
                  Colors.green[600]!,
                  true,
                  _saveBill,
                ),
                SizedBox(width: 16.w),
                _buildActionButton(
                  'Add',
                  Icons.add,
                  Colors.deepPurple[600]!,
                  false,
                  _addNewItem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label :',
          style: TextStyle(color: Colors.white70, fontSize: 12.sp),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
      ),
    );
  }

  Widget _buildDataRow(
    Map<String, dynamic> item,
    int index,
    bool isEven,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          if (selectedRowIndex == index) {
            selectedRowIndex = null;
          } else {
            selectedRowIndex = index;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple[50]
              : (isEven ? Colors.grey[50] : Colors.white),
          border: Border(
            left: isSelected
                ? BorderSide(color: Colors.deepPurple[600]!, width: 4.w)
                : BorderSide.none,
            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5.w),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                item['description'],
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.deepPurple[800] : Colors.grey[800],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item['set'],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item['stone'],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item['gross'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item['pure%'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item['pure'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber[700],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item['rate'],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item['amount'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[700],
                ),
              ),
            ),
            SizedBox(
              width: 80.w,
              child: isSelected
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, size: 18),
                          color: Colors.blue[600],
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () => _editItem(index),
                        ),
                        SizedBox(width: 8.w),
                        IconButton(
                          icon: Icon(Icons.delete, size: 18),
                          color: Colors.red[600],
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () => _deleteItem(index),
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

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color, width: isSelected ? 0 : 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: isSelected ? Colors.white : color),
                SizedBox(width: 10.w),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSearchablePopup(BuildContext context) async {
    await _loadAccountNames();

    if (accountNames.isEmpty) {
      _showSnackBar(
        'No accounts found. Please add accounts first.',
        Colors.orange,
      );
      return;
    }

    List<String> filtered = List.from(accountNames);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Row(
                children: [
                  Icon(Icons.person_search, color: Colors.deepPurple[600]),
                  SizedBox(width: 12.w),
                  Text("Select Account"),
                ],
              ),
              content: SizedBox(
                width: 400.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search account...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (query) {
                        setState(() {
                          filtered = accountNames
                              .where(
                                (name) => name.toLowerCase().contains(
                                  query.toLowerCase(),
                                ),
                              )
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Found ${filtered.length} accounts',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 10.h),
                    SizedBox(
                      height: 300.h,
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No accounts found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepPurple[100],
                                    child: Text(
                                      filtered[index][0],
                                      style: TextStyle(
                                        color: Colors.deepPurple[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    filtered[index],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context, filtered[index]);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    ).then((value) async {
      if (value != null) {
        setState(() {
          selectedName = value;
        });

        final result = await showDialog(
          context: context,
          builder: (context) => SearchableListPopup(),
        );

        if (result != null) {
          setState(() {
            goldItems.add({
              'description': result['item'] ?? '',
              'set': result['sets'] ?? '1',
              'stone': result['stoneWeight'] ?? '0.00',
              'gross': result['grossWeight'] ?? '0.00',
              'pure%': result['purity'] ?? '0.00',
              'pure': result['pureWeight'] ?? '0.00',
              'rate': result['rate'] ?? '0.00',
              'amount': result['totalAmount'] ?? '0.00',
              'making': result['making'] ?? '0.00', // NEW
              'makingUnit': result['makingUnit'] ?? '%', // NEW
              'discount': result['discount'] ?? '0.00', // NEW
              'netWeight': result['netWeight'] ?? '0.000', // NEW
            });
          });

          debugPrint("Selected Item: $result");
        }
      }
    });
  }

  Future<void> _addNewItem() async {
    final result = await showDialog(
      context: context,
      builder: (context) => SearchableListPopup(),
    );

    if (result != null) {
      setState(() {
        goldItems.add({
          'description': result['item'] ?? '',
          'set': result['sets'] ?? '1',
          'stone': result['stoneWeight'] ?? '0.00',
          'gross': result['grossWeight'] ?? '0.00',
          'pure%': result['purity'] ?? '0.00',
          'pure': result['pureWeight'] ?? '0.00',
          'rate': result['rate'] ?? '0.00',
          'amount': result['totalAmount'] ?? '0.00',
          'making': result['making'] ?? '0.00', // NEW
          'makingUnit': result['makingUnit'] ?? '%', // NEW
          'discount': result['discount'] ?? '0.00', // NEW
          'netWeight': result['netWeight'] ?? '0.000', // NEW
        });
      });
      _showSnackBar('Item added successfully', Colors.green);
    }
  }
}
