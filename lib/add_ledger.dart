import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AddCustomerDialog extends StatefulWidget {
  final Function(
    String name,
    double balance,
    bool isDebit,
    double weight,
    bool isWeightEntry,
  )
  onCustomerAdded;

  const AddCustomerDialog({super.key, required this.onCustomerAdded});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isDebit = true;
  bool _isWeightEntry = false; // false = Cash, true = Weight

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        padding: EdgeInsets.all(24),
        constraints: BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.person_add, color: Colors.blue[700]),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Add New Customer',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20.h),

                // Toggle Switch between Cash and Weight
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleButton(
                          label: 'Cash',
                          icon: Icons.currency_rupee,
                          isSelected: !_isWeightEntry,
                          onTap: () {
                            setState(() {
                              _isWeightEntry = false;
                            });
                          },
                        ),
                        _buildToggleButton(
                          label: 'Weight',
                          icon: Icons.scale,
                          isSelected: _isWeightEntry,
                          onTap: () {
                            setState(() {
                              _isWeightEntry = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                // Conditional Fields based on toggle
                if (!_isWeightEntry) ...[
                  // Cash Amount Field
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Debit/Credit Selection
                  Row(
                    children: [
                      Expanded(
                        child: _buildSelectionCard(
                          title: 'Debit',
                          subtitle: 'Money to receive',
                          icon: Icons.arrow_upward,
                          color: Colors.red,
                          isSelected: _isDebit,
                          onTap: () {
                            setState(() {
                              _isDebit = true;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildSelectionCard(
                          title: 'Credit',
                          subtitle: 'Money to pay',
                          icon: Icons.arrow_downward,
                          color: Colors.green,
                          isSelected: !_isDebit,
                          onTap: () {
                            setState(() {
                              _isDebit = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Weight Field
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Weight (grams)',
                      prefixIcon: Icon(Icons.scale),
                      suffixText: 'gm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter weight';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],

                SizedBox(height: 24.h),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final name = _nameController.text.trim();
                            final balance = _isWeightEntry
                                ? 0.0
                                : double.parse(_amountController.text.trim());
                            final weight = _isWeightEntry
                                ? double.parse(_weightController.text.trim())
                                : 0.0;

                            widget.onCustomerAdded(
                              name,
                              balance,
                              _isDebit,
                              weight,
                              _isWeightEntry,
                            );
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text('Add Customer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2.w,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 32),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Customer class (keep your existing implementation)
class Customer {
  final String name;
  final double balance;
  final bool isDebit;

  Customer({required this.name, required this.balance, required this.isDebit});
}
