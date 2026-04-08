import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class JewelryDescriptionForm extends StatefulWidget {
  final Map<String, dynamic> item;

  const JewelryDescriptionForm({super.key, required this.item});

  @override
  _JewelryDescriptionFormState createState() => _JewelryDescriptionFormState();
}

class _JewelryDescriptionFormState extends State<JewelryDescriptionForm> {
  late TextEditingController _nameController;

  // Form Controllers
  final TextEditingController setsController = TextEditingController(text: '0');
  final TextEditingController grossWeightController = TextEditingController(
    text: '0',
  );
  final TextEditingController stoneWeightController = TextEditingController(
    text: '0.000',
  );
  final TextEditingController makingController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController netWeightController = TextEditingController(
    text: '0.000',
  );
  final TextEditingController pureWeightController = TextEditingController(
    text: '0.000',
  );
  final TextEditingController rateController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController purityController = TextEditingController(
    text: '91.6',
  );
  final TextEditingController discountController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController totalAmountController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController descriptionController = TextEditingController();

  // Focus node for auto-selection
  final FocusNode setsFocusNode = FocusNode();

  // Dropdown values
  String selectedMakingUnit = '%';

  @override
  void initState() {
    super.initState();

    // Initialize name controller
    _nameController = TextEditingController(text: widget.item['name']);

    // Check if editing existing item
    if (widget.item['isEdit'] == true && widget.item['editData'] != null) {
      _loadEditData(widget.item['editData']);
    }

    // Add listeners for auto-calculation
    grossWeightController.addListener(_calculateNetWeight);
    stoneWeightController.addListener(_calculateNetWeight);
    netWeightController.addListener(_calculatePureWeight);
    purityController.addListener(_calculatePureWeight);

    // Add listeners for amount calculation
    netWeightController.addListener(_calculateAmount);
    rateController.addListener(_calculateAmount);
    makingController.addListener(_calculateAmount);
    setsController.addListener(_calculateAmount);
    discountController.addListener(_calculateAmount);

    // Auto-focus and select Sets/Pcs field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setsFocusNode.requestFocus();
      setsController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: setsController.text.length,
      );
    });
  }

  // Load existing data when editing
  void _loadEditData(Map<String, dynamic> editData) {
    setState(() {
      // Load all existing values
      setsController.text = editData['set']?.toString() ?? '0';
      stoneWeightController.text = editData['stone']?.toString() ?? '0.000';
      grossWeightController.text = editData['gross']?.toString() ?? '0.000';
      purityController.text = editData['pure%']?.toString() ?? '91.6';
      pureWeightController.text = editData['pure']?.toString() ?? '0.000';
      rateController.text = editData['rate']?.toString() ?? '0.00';
      totalAmountController.text = editData['amount']?.toString() ?? '0.00';

      // Load making, discount, and makingUnit - NEW
      makingController.text = editData['making']?.toString() ?? '0.00';
      discountController.text = editData['discount']?.toString() ?? '0.00';
      selectedMakingUnit = editData['makingUnit']?.toString() ?? '%';

      // Calculate or load net weight
      if (editData['netWeight'] != null) {
        netWeightController.text = editData['netWeight'].toString();
      } else {
        double gross = double.tryParse(grossWeightController.text) ?? 0.0;
        double stone = double.tryParse(stoneWeightController.text) ?? 0.0;
        netWeightController.text = (gross - stone).toStringAsFixed(3);
      }

      // Set description if available
      if (editData['description'] != null) {
        descriptionController.text = editData['description'].toString();
      }
    });

    print(
      'Loaded edit data with making: ${editData['making']}, discount: ${editData['discount']}, makingUnit: ${editData['makingUnit']}',
    );
  }

  // Calculate Net Weight = Gross Weight - Stone
  void _calculateNetWeight() {
    double gross = double.tryParse(grossWeightController.text) ?? 0.0;
    double stone = double.tryParse(stoneWeightController.text) ?? 0.0;
    double netWeight = gross - stone;

    setState(() {
      netWeightController.text = netWeight.toStringAsFixed(3);
    });
  }

  // Calculate Pure Weight = Net Weight * Purity / 100
  void _calculatePureWeight() {
    double netWeight = double.tryParse(netWeightController.text) ?? 0.0;
    double purity = double.tryParse(purityController.text) ?? 0.0;
    double pureWeight = (netWeight * purity) / 100;

    setState(() {
      pureWeightController.text = pureWeight.toStringAsFixed(3);
    });
  }

  // Calculate Amount based on Making unit
  void _calculateAmount() {
    double netWeight = double.tryParse(netWeightController.text) ?? 0.0;
    double rate = double.tryParse(rateController.text) ?? 0.0;
    double making = double.tryParse(makingController.text) ?? 0.0;
    int sets = int.tryParse(setsController.text) ?? 0;
    double discount = double.tryParse(discountController.text) ?? 0.0;

    double baseAmount = netWeight * rate;
    double makingAmount = 0.0;

    if (selectedMakingUnit == '%') {
      // Making in percentage
      makingAmount = (baseAmount * making) / 100;
    } else if (selectedMakingUnit == 'gm') {
      // Making in grams
      makingAmount = netWeight * making;
    } else if (selectedMakingUnit == 'pcs') {
      // Making in pieces
      makingAmount = sets * making;
    }

    double totalAmount = baseAmount + makingAmount - discount;

    setState(() {
      totalAmountController.text = totalAmount.toStringAsFixed(2);
    });
  }

  // Clear all fields to default
  void _clearFields() {
    setState(() {
      setsController.text = '0';
      grossWeightController.text = '0';
      stoneWeightController.text = '0.000';
      makingController.text = '0.00';
      rateController.text = '0.00';
      purityController.text = '91.6';
      discountController.text = '0.00';
      descriptionController.text = '';
      selectedMakingUnit = '%';

      // Auto-calculated fields will update automatically
      netWeightController.text = '0.000';
      pureWeightController.text = '0.000';
      totalAmountController.text = '0.00';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    setsController.dispose();
    grossWeightController.dispose();
    stoneWeightController.dispose();
    makingController.dispose();
    netWeightController.dispose();
    pureWeightController.dispose();
    rateController.dispose();
    purityController.dispose();
    discountController.dispose();
    totalAmountController.dispose();
    descriptionController.dispose();
    setsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditMode = widget.item['isEdit'] == true;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isEditMode ? 'EDIT ITEM' : 'ADD ITEM',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
            color: Colors.white,
          ),
        ),
        backgroundColor: isEditMode ? Colors.blue[800] : Colors.teal[800],
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Main Form Card
            Container(
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
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isEditMode
                            ? [Colors.blue[700]!, Colors.blue[500]!]
                            : [Colors.teal[700]!, Colors.teal[500]!],
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
                          isEditMode ? Icons.edit : Icons.diamond,
                          color: Colors.amber[300],
                          size: 28,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          isEditMode
                              ? 'Edit Jewelry Item'
                              : 'Jewelry Item Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form Content
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Row 1: Item Name and Sets/Pcs with Rate
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildFormField(
                                    'Item Name',
                                    _nameController,
                                    isHighlighted: false,
                                    enabled: false,
                                  ),
                                  SizedBox(height: 12.h),
                                  _buildFormField(
                                    'Sets/Pcs',
                                    setsController,
                                    isHighlighted: true,
                                    focusNode: setsFocusNode,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                children: [
                                  SizedBox(height: 73.h),
                                  _buildFormField('Rate', rateController),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16.h),

                        // Row 2: Gross Weight and Purity
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildFormFieldWithUnit(
                                    'Gross Weight',
                                    grossWeightController,
                                    'gm',
                                  ),
                                  SizedBox(height: 12.h),
                                  _buildFormFieldWithUnit(
                                    'Stone',
                                    stoneWeightController,
                                    'gm',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildFormFieldWithUnit(
                                    'Purity',
                                    purityController,
                                    '%',
                                  ),
                                  SizedBox(height: 12.h),
                                  _buildFormFieldWithDropdown(
                                    'Making',
                                    makingController,
                                    selectedMakingUnit,
                                    ['%', 'pcs', 'gm'],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        // Summary Section
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryField(
                                      'Net Weight',
                                      netWeightController,
                                      Colors.blue[700]!,
                                      isReadOnly: true,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: _buildSummaryField(
                                      'Discount',
                                      discountController,
                                      Colors.blue[700]!,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryField(
                                      'Pure Weight',
                                      pureWeightController,
                                      Colors.blue[700]!,
                                      isReadOnly: true,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: _buildSummaryField(
                                      'Amount',
                                      totalAmountController,
                                      Colors.green[700]!,
                                      isBold: true,
                                      isReadOnly: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // Description
                        _buildLargeTextField(
                          'Description',
                          descriptionController,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  isEditMode ? 'Update' : 'Save',
                  Icons.save,
                  Colors.green[600]!,
                  () {
                    // Collect all values into a Map
                    final result = {
                      'item': _nameController.text,
                      'sets': setsController.text,
                      'grossWeight': grossWeightController.text,
                      'stoneWeight': stoneWeightController.text,
                      'making': makingController.text,
                      'makingUnit': selectedMakingUnit,
                      'netWeight': netWeightController.text,
                      'pureWeight': pureWeightController.text,
                      'rate': rateController.text,
                      'purity': purityController.text,
                      'discount': discountController.text,
                      'totalAmount': totalAmountController.text,
                      'description': descriptionController.text,
                    };

                    // Pop and send result back
                    Navigator.pop(context, result);
                  },
                ),
                SizedBox(width: 16.w),
                _buildActionButton(
                  'Clear',
                  Icons.refresh,
                  Colors.orange[600]!,
                  _clearFields,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build standard form field
  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    bool isHighlighted = false,
    FocusNode? focusNode,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isHighlighted ? Colors.blue[700] : Colors.grey[700],
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: enabled ? Colors.grey[800] : Colors.grey[500],
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? (isHighlighted ? Colors.blue[50] : Colors.grey[50])
                : Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // Build form field with unit
  Widget _buildFormFieldWithUnit(
    String label,
    TextEditingController controller,
    String unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 16.sp, color: Colors.grey[800]),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
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
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build form field with dropdown
  Widget _buildFormFieldWithDropdown(
    String label,
    TextEditingController controller,
    String currentValue,
    List<String> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 16.sp, color: Colors.grey[800]),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
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
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: DropdownButton<String>(
                value: currentValue,
                underline: SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                items: options.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(value),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedMakingUnit = newValue;
                    });
                    _calculateAmount();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build summary field
  Widget _buildSummaryField(
    String label,
    TextEditingController controller,
    Color color, {
    bool isBold = false,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: color),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: color.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: color, width: 2.w),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Build large text field for description
  Widget _buildLargeTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(fontSize: 16.sp, color: Colors.grey[800]),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(16),
            hintText: 'Enter additional details...',
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  // Build action button
  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        text,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 2,
      ),
    );
  }
}
