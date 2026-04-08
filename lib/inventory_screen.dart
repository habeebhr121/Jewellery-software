import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jwells_report/add_new_item.dart';

class InventoryTableScreen extends StatefulWidget {
  final bool showDialog;
  const InventoryTableScreen({super.key, this.showDialog = false});

  @override
  State<InventoryTableScreen> createState() => _InventoryTableScreenState();
}

class _InventoryTableScreenState extends State<InventoryTableScreen> {
  List<InventoryItem> items = [];
  int? selectedIndex;

  @override
  void initState() {
    super.initState();
    _loadItems();

    if (widget.showDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addNewItem();
      });
    }
  }

  double get totalWeight {
    return items.fold(0.0, (sum, item) => sum + item.weight);
  }

  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('inventory_items');

    if (itemsJson != null && itemsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedJson = jsonDecode(itemsJson);
        setState(() {
          items = decodedJson
              .map((json) => InventoryItem.fromJson(json))
              .toList();
        });
      } catch (e) {
        print('Error loading items: $e');
        _initializeDefaultItems();
      }
    } else {
      _initializeDefaultItems();
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString('inventory_items', itemsJson);
  }

  bool _isDuplicateName(String name, {int? excludeIndex}) {
    final upperName = name.toUpperCase().trim();
    return items.asMap().entries.any((entry) {
      if (excludeIndex != null && entry.key == excludeIndex) {
        return false; // Skip the item being edited
      }
      return entry.value.name.toUpperCase() == upperName;
    });
  }

  void _initializeDefaultItems() {
    items = [
      InventoryItem(name: 'GOLD NECKLACE SET', quantity: 25, weight: 125.50),
      InventoryItem(name: 'DIAMOND EARRINGS', quantity: 15, weight: 85.25),
      InventoryItem(name: 'SILVER BANGLES', quantity: 50, weight: 275.75),
      InventoryItem(
        name: 'GOLD CHAINS',
        quantity: 30,
        weight: 180.00,
        isHighlighted: true,
      ),
      InventoryItem(name: 'PLATINUM RINGS', quantity: 8, weight: 45.25),
      InventoryItem(name: 'PEARL NECKLACE', quantity: 12, weight: 95.50),
      InventoryItem(name: 'RUBY PENDANTS', quantity: 18, weight: 65.75),
      InventoryItem(name: 'EMERALD BRACELETS', quantity: 22, weight: 110.25),
      InventoryItem(name: 'SAPPHIRE RINGS', quantity: 14, weight: 78.50),
      InventoryItem(name: 'WEDDING SETS', quantity: 6, weight: 350.00),
    ];
    _saveItems();
    setState(() {});
  }

  Future<void> _deleteItem(int index) async {
    final item = items[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Item'),
          content: Text('Are you sure you want to delete "${item.name}"?'),
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
        items.removeAt(index);
        selectedIndex = null;
      });
      await _saveItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.white),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text('Item "${item.name}" deleted successfully!'),
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

  // NEW: Edit item function
  Future<void> _editItem(int index) async {
    final item = items[index];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return EditItemDialog(
          itemName: item.name,
          currentQuantity: item.quantity,
          currentWeight: item.weight,
          onItemUpdated: (quantity, weight) async {
            setState(() {
              items[index] = InventoryItem(
                name: item.name,
                quantity: quantity,
                weight: weight,
                isHighlighted: item.isHighlighted,
              );
            });

            await _saveItems();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Item "${item.name}" updated successfully!',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.blue[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              );
            }
          },
        );
      },
    );
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
            _buildTableHeader(),
            Expanded(child: _buildTableContent()),
            _buildTotalFooter(),
          ],
        ),
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 80.0, right: 20),
        child: FloatingActionButton(
          onPressed: _addNewItem,
          backgroundColor: Colors.orange[600],
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
          Icon(Icons.inventory_2, color: Colors.orange[700], size: 28),
          SizedBox(width: 12.w),
          Text(
            'Inventory Items',
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
              '${items.length} Items',
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
              'Item Name',
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
              'Total Quantity',
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
              'Total Weight',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
          SizedBox(width: 80.w), // Space for edit and delete buttons
        ],
      ),
    );
  }

  Widget _buildTableContent() {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'No Items Found',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Add your first item to get started',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIndex == index;
        return _buildTableRow(item, index, isSelected);
      },
    );
  }

  Widget _buildTableRow(InventoryItem item, int index, bool isSelected) {
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
              ? Colors.orange[50]
              : (item.isHighlighted
                    ? Colors.green[50]
                    : (index % 2 == 0 ? Colors.white : Colors.grey[25])),
          border: Border(
            left: isSelected
                ? BorderSide(color: Colors.orange[600]!, width: 4.w)
                : (item.isHighlighted
                      ? BorderSide(color: Colors.green, width: 4.w)
                      : BorderSide.none),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: (isSelected || item.isHighlighted)
                        ? FontWeight.bold
                        : FontWeight.w600,
                    fontSize: 14.sp,
                    color: isSelected
                        ? Colors.orange[800]
                        : (item.isHighlighted
                              ? Colors.green[800]
                              : Colors.grey[800]),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange[100] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${item.quantity} pcs',
                      style: TextStyle(
                        color: isSelected ? Colors.orange[900] : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${item.weight.toStringAsFixed(2)} gms',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              // Edit and Delete buttons
              SizedBox(
                width: 80.w,
                child: isSelected
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 18),
                            color: Colors.blue[600],
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            tooltip: 'Edit',
                            onPressed: () => _editItem(index),
                          ),
                          SizedBox(width: 8.w),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18),
                            color: Colors.red[400],
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            tooltip: 'Delete',
                            onPressed: () => _deleteItem(index),
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
                  'Totals',
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
                  '$totalQuantity pcs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${totalWeight.toStringAsFixed(2)} gms',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 80.w), // Space for button columns
        ],
      ),
    );
  }

  void _addNewItem() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AddItemDialog(
          onItemAdded: (itemName, quantity, weight) async {
            try {
              final upperName = itemName.toUpperCase().trim();

              // Check for duplicate names
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
                            child: Text('Item "$upperName" already exists!'),
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
                items.add(
                  InventoryItem(
                    name: upperName,
                    quantity: quantity,
                    weight: weight,
                  ),
                );
              });

              await _saveItems();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text('Item "$upperName" added successfully!'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange[600],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.white),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text('Error saving item: ${e.toString()}'),
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
}

// NEW: Edit Item Dialog
class EditItemDialog extends StatefulWidget {
  final String itemName;
  final int currentQuantity;
  final double currentWeight;
  final Function(int quantity, double weight) onItemUpdated;

  const EditItemDialog({
    super.key,
    required this.itemName,
    required this.currentQuantity,
    required this.currentWeight,
    required this.onItemUpdated,
  });

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  late TextEditingController quantityController;
  late TextEditingController weightController;

  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController(
      text: widget.currentQuantity.toString(),
    );
    weightController = TextEditingController(
      text: widget.currentWeight.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.edit, color: Colors.blue[600], size: 24),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Item',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        widget.itemName,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                labelText: 'Quantity (pieces)',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                final text = value;
                quantityController.value = quantityController.value.copyWith(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
              },
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                labelText: 'Weight (grams)',
                prefixIcon: Icon(Icons.scale),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                final text = value;
                weightController.value = weightController.value.copyWith(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
              },
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                SizedBox(width: 12.w),
                ElevatedButton(
                  onPressed: () {
                    // Allow 0 values - no validation
                    int quantity = int.tryParse(quantityController.text) ?? 0;
                    double weight =
                        double.tryParse(weightController.text) ?? 0.0;

                    widget.onItemUpdated(quantity, weight);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text('Update', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryItem {
  final String name;
  final int quantity;
  final double weight;
  final bool isHighlighted;

  InventoryItem({
    required this.name,
    required this.quantity,
    required this.weight,
    this.isHighlighted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'weight': weight,
      'isHighlighted': isHighlighted,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      weight: (json['weight'] ?? 0.0).toDouble(),
      isHighlighted: json['isHighlighted'] ?? false,
    );
  }
}
