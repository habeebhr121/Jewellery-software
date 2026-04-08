import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jwells_report/jwellery_details.dart';

class SearchableListPopup extends StatefulWidget {
  const SearchableListPopup({super.key});

  @override
  State<SearchableListPopup> createState() => _SearchableListPopupState();
}

class _SearchableListPopupState extends State<SearchableListPopup> {
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> filteredItems = [];
  List<InventoryItem> allItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventoryItems();
    _searchController.addListener(_filterItems);
  }

  // Load inventory items from SharedPreferences
  Future<void> _loadInventoryItems() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('inventory_items');

    if (itemsJson != null && itemsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedJson = jsonDecode(itemsJson);
        setState(() {
          allItems = decodedJson
              .map((json) => InventoryItem.fromJson(json))
              .toList();
          filteredItems = allItems;
          isLoading = false;
        });
      } catch (e) {
        print('Error loading items: $e');
        setState(() {
          allItems = [];
          filteredItems = [];
          isLoading = false;
        });
      }
    } else {
      setState(() {
        allItems = [];
        filteredItems = [];
        isLoading = false;
      });
    }
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        filteredItems = allItems;
      } else {
        filteredItems = allItems.where((item) {
          return item.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Search
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[700]!, Colors.orange[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2, color: Colors.white, size: 28),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'Search Inventory Items',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 15.sp),
                    decoration: InputDecoration(
                      hintText: 'Search by item name...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterItems();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Results Count
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Icon(Icons.list_alt, size: 18, color: Colors.grey[700]),
                  SizedBox(width: 8.w),
                  Text(
                    'Found ${filteredItems.length} items',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Filtered Items List
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.orange[600]),
                          SizedBox(height: 16.h),
                          Text(
                            'Loading items...',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isEmpty
                                ? Icons.inventory_outlined
                                : Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No items available'
                                : 'No items found',
                            style: TextStyle(
                              fontSize: 18.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Add items to your inventory first'
                                : 'Try adjusting your search terms',
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
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildSearchResultTile(context, item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(BuildContext context, InventoryItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          // Push JewelryDescriptionForm and wait for result
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JewelryDescriptionForm(
                item: {
                  'name': item.name,
                  'quantity': item.quantity,
                  'weight': item.weight,
                  'isHighlighted': item.isHighlighted,
                },
              ),
            ),
          );

          // Once JewelryDescriptionForm pops with result, pass it back
          if (result != null && mounted) {
            Navigator.of(context).pop(result);
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Item Icon
              Container(
                width: 56.w,
                height: 56.h,
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.orange[700],
                  size: 28,
                ),
              ),
              SizedBox(width: 16.w),

              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Name
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Quantity and Weight
                    Row(
                      children: [
                        // Quantity
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory,
                                size: 14,
                                color: Colors.blue[700],
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${item.quantity} pcs',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),

                        // Weight
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.scale,
                                size: 14,
                                color: Colors.amber[800],
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${item.weight.toStringAsFixed(2)} gm',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// InventoryItem Model Class
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

  // Convert InventoryItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'weight': weight,
      'isHighlighted': isHighlighted,
    };
  }

  // Create InventoryItem from JSON
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      weight: (json['weight'] ?? 0.0).toDouble(),
      isHighlighted: json['isHighlighted'] ?? false,
    );
  }
}
