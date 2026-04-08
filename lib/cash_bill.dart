import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jwells_report/add_item_sale.dart';
import 'package:jwells_report/jwellery_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class CashBill extends StatefulWidget {
  const CashBill({super.key});

  @override
  State<CashBill> createState() => _CashBillState();
}

class _CashBillState extends State<CashBill> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phController = TextEditingController();

  String selectedName = '';
  String slNo = 'SG0001';
  String currentDate = '';
  List<Map<String, dynamic>> goldItems = [];
  int? selectedRowIndex;

  @override
  void initState() {
    super.initState();
    _initializeBill();
  }

  Future<void> _initializeBill() async {
    await _generateSlNo();
    _getCurrentDate();
    setState(() {
      goldItems = [];
    });
  }

  Future<void> _generateSlNo() async {
    final prefs = await SharedPreferences.getInstance();
    int lastNo = prefs.getInt('last_sl_no') ?? 0;
    lastNo++;
    setState(() {
      slNo = 'SG${lastNo.toString().padLeft(4, '0')}';
    });
  }

  void _getCurrentDate() {
    setState(() {
      currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    });
  }

  Future<void> _saveBill() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter customer name', Colors.red);
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
      await prefs.setInt('last_sl_no', currentNo);

      // Calculate total amount
      double totalAmount = 0.0;
      for (var item in goldItems) {
        totalAmount +=
            double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      }

      // Create bill object with transaction info
      final bill = {
        'id': 'CB${DateTime.now().millisecondsSinceEpoch}',
        'slNo': slNo,
        'date': currentDate,
        'customerName': _nameController.text.trim().toUpperCase(),
        'phone': _phController.text.trim(),
        'items': goldItems,
        'totalAmount': totalAmount,
        'type': 'CASH_BILL',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Load existing bills
      List<String> bills = prefs.getStringList('saved_bills') ?? [];
      bills.add(jsonEncode(bill));
      await prefs.setStringList('saved_bills', bills);

      print('Cash bill saved: ${bill['id']}');

      // Reduce inventory quantities
      await _updateInventoryQuantities();

      _showSnackBar('Bill saved successfully!', Colors.green);

      // Reset for new bill
      await Future.delayed(Duration(seconds: 1));
      _resetBill();
    } catch (e) {
      _showSnackBar('Error saving bill: $e', Colors.red);
      print('Error in _saveBill: $e');
    }
  }

  Future<void> _updateInventoryQuantities() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('inventory_items');

    if (itemsJson != null && itemsJson.isNotEmpty) {
      try {
        List<dynamic> inventoryItems = jsonDecode(itemsJson);

        for (var soldItem in goldItems) {
          String itemName = soldItem['description'];
          int soldQuantity = int.tryParse(soldItem['set']) ?? 1;
          double soldWeight = double.tryParse(soldItem['gross']) ?? 0.0;

          int index = inventoryItems.indexWhere(
            (item) =>
                item['name'].toString().toUpperCase() == itemName.toUpperCase(),
          );

          if (index != -1) {
            int currentQty = inventoryItems[index]['quantity'] ?? 0;
            int newQty = currentQty - soldQuantity;

            if (newQty < 0) newQty = 0;

            inventoryItems[index]['quantity'] = newQty;

            double currentWeight = (inventoryItems[index]['weight'] ?? 0.0)
                .toDouble();
            double newWeight = currentWeight - soldWeight;

            if (newWeight < 0) newWeight = 0.0;

            inventoryItems[index]['weight'] = newWeight;
          }
        }

        await prefs.setString('inventory_items', jsonEncode(inventoryItems));

        print('Inventory updated successfully');
      } catch (e) {
        print('Error updating inventory: $e');
      }
    }
  }

  void _resetBill() {
    setState(() {
      _nameController.clear();
      _phController.clear();
      goldItems = [];
      selectedRowIndex = null;
    });
    _initializeBill();
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
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                              Expanded(
                                child: TextField(
                                  cursorColor: Colors.white,
                                  autofocus: true,
                                  controller: _nameController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: "Enter Customer Name",
                                    hintStyle: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Phone : ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  cursorColor: Colors.white,
                                  controller: _phController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Ph Number",
                                    hintStyle: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
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
                    Expanded(
                      child: Row(
                        children: [
                          Spacer(),
                          _buildInfoItem('Date', currentDate),
                          SizedBox(width: 35.w),
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
                                  Icons.receipt_long_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'No Items Added',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Click "Add" button to add items to this bill',
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
              ? Colors.blue[50]
              : (isEven ? Colors.grey[50] : Colors.white),
          border: Border(
            left: isSelected
                ? BorderSide(color: Colors.blue[600]!, width: 4.w)
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
                  color: isSelected ? Colors.blue[800] : Colors.grey[800],
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

  @override
  void dispose() {
    _nameController.dispose();
    _phController.dispose();
    super.dispose();
  }
}
