import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jwells_report/shop_cash_monitor.dart';
import 'package:window_manager/window_manager.dart';
import 'package:jwells_report/all_transactions_screen.dart';
import 'package:jwells_report/cash_bill.dart';
import 'package:jwells_report/dashboard.dart';
import 'package:jwells_report/inventory_screen.dart';
import 'package:jwells_report/issue_jwellery.dart';
import 'package:jwells_report/ledger.dart';
import 'package:jwells_report/payment_cash_screen.dart';
import 'package:jwells_report/purchase_jwellery.dart';
import 'package:jwells_report/receipt_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure window manager is initialized
  await windowManager.ensureInitialized();

  // Define window options with comprehensive settings
  WindowOptions windowOptions = WindowOptions(
    // Initial window size (comfortable for desktop)
    size: Size(1400, 900),

    // Center window on screen
    center: true,

    // Minimum size - prevents window from being too small
    minimumSize: Size(1200, 800),

    // Maximum size (optional) - can be set to screen size
    // maximumSize: Size(1920, 1080),

    // Window appearance
    backgroundColor: Colors.transparent,
    skipTaskbar: false,

    // Window title
    title: 'Star Jewellery Management System',

    // Title bar style
    titleBarStyle: TitleBarStyle.normal,

    // Full screen settings
    fullScreen: false,

    // Always on top (set to false for normal behavior)
    alwaysOnTop: false,
  );

  // Wait until window is ready and then show it
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Show the window
    await windowManager.show();

    // Focus on the window
    await windowManager.focus();

    // Optionally set to maximized state on startup
    // await windowManager.maximize();

    // Prevent window from being resized below minimum
    await windowManager.setMinimumSize(Size(1200, 800));

    // Set window title
    await windowManager.setTitle('Star Jewellery Management System');

    // Enable resizing
    await windowManager.setResizable(true);

    // Prevent window from being closed accidentally (optional)
    await windowManager.setPreventClose(false);
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(1728, 1117),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Star Jewellery',
          theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Inter'),
          home: RefrensHomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class RefrensHomePage extends StatefulWidget {
  RefrensHomePage({super.key});

  @override
  _RefrensHomePageState createState() => _RefrensHomePageState();
}

int selectedMenuIndex = 0;

class _RefrensHomePageState extends State<RefrensHomePage> with WindowListener {
  String selectedMenuItem = 'Quotation';
  bool addLedgerState = false;
  bool addItemState = false;

  List sidePanelItems = [
    'Dashboard',
    'Cash Bill',
    'Issue to Jwellery',
    'Purchase from Jwellery',
    'Payment Cash',
    'Receipt',
    'Ledger Account',
    'Sales Report',
    'Shop Cash',
    'Current Stock',
  ];

  List sidePanelIcons = [
    Icons.dashboard_outlined,
    Icons.receipt,
    Icons.person_outline,
    Icons.people_outline,
    Icons.menu_book_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.settings_outlined,
    Icons.trending_up_outlined,
    Icons.monetization_on,
    Icons.shopping_cart_checkout_rounded,
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _init() async {
    // Additional window setup after widget is initialized
    await windowManager.setPreventClose(false);
  }

  // Handle window close event
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text('Are you sure you want to close?'),
            actions: [
              TextButton(
                child: Text('No'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Yes'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // Handle window resize event
  @override
  void onWindowResize() {
    // You can add custom logic here when window is resized
    setState(() {});
  }

  // Handle window minimize event
  @override
  void onWindowMinimize() {
    // Custom logic when minimized
  }

  // Handle window maximize event
  @override
  void onWindowMaximize() {
    // Custom logic when maximized
  }

  // Handle window restore event
  @override
  void onWindowRestore() {
    // Custom logic when restored
  }

  Widget _getCurrentWidget() {
    switch (selectedMenuIndex) {
      case 0:
        return DashboardScreen(
          onMenuSelected: (index) {
            setState(() {
              selectedMenuIndex = index;
            });
          },
        );
      case 1:
        return CashBill();
      case 2:
        return IssueAlterationScreen();
      case 3:
        return PurcahseJwellery();
      case 4:
        return CashPaymentScreen();
      case 5:
        return CashReceiptScreen();
      case 6:
        return AccountLedgerScreen(showDialog: addLedgerState);
      case 7:
        return AllTransactionsScreen();
      case 8:
        return ShopCashMonitorScreen();
      case 9:
        return InventoryTableScreen(showDialog: addItemState);
      default:
        return DashboardScreen(
          onMenuSelected: (index) {
            setState(() {
              selectedMenuIndex = index;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 280.w,
            color: Colors.white,
            child: Column(
              children: [
                // Logo Header
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.menu, color: Colors.grey[600], size: 20),
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Star Jewellery',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Company Selector
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Center(
                          child: Text(
                            'S',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Star Jewellers Pro',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.orange,
                                  size: 12,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'coming soon',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // Navigation Menu Items
                Expanded(
                  child: ListView.separated(
                    itemBuilder: (context, index) {
                      return _buildMenuItemWithDropdown(
                        sidePanelIcons[index],
                        "${sidePanelItems[index]}",
                        selectedMenuIndex == index,
                        () {
                          setState(() {
                            selectedMenuIndex = index;
                            print("selected index $index");
                          });
                        },
                      );
                    },
                    separatorBuilder: (context, index) {
                      return SizedBox(height: 8.h);
                    },
                    itemCount: sidePanelItems.length,
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Container(
              child: Column(
                children: [
                  // Top Header Bar
                  Container(
                    height: 70.h,
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Quotations',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.star_border,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                        SizedBox(width: 16.w),
                        Icon(
                          Icons.help_outline,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                        SizedBox(width: 16.w),
                        Icon(
                          Icons.notifications_outlined,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                        SizedBox(width: 16.w),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  // Tab Navigation and Create Button
                  selectedMenuIndex == 0
                      ? Container(
                          color: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              selectedMenuIndex == 0
                                  ? _buildTab('Overview', true)
                                  : Container(),
                              SizedBox(width: 32.w),
                              Spacer(),
                              SizedBox(width: 12.w),
                              PopupMenuButton<String>(
                                onSelected: (String value) {
                                  switch (value) {
                                    case 'Create ledger':
                                      setState(() {
                                        selectedMenuIndex = 6;
                                        addLedgerState = true;
                                      });
                                      Future.delayed(
                                        Duration(milliseconds: 100),
                                        () {
                                          setState(() {
                                            addLedgerState = false;
                                          });
                                        },
                                      );
                                      break;
                                    case 'Add item':
                                      setState(() {
                                        selectedMenuIndex = 9;
                                        addItemState = true;
                                      });
                                      Future.delayed(
                                        Duration(milliseconds: 100),
                                        () {
                                          setState(() {
                                            addItemState = false;
                                          });
                                        },
                                      );
                                      break;
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: 5,
                                    bottom: 5,
                                  ),
                                  height: 35.h,
                                  width: 35.w,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE91E63),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                itemBuilder: (BuildContext context) => [
                                  PopupMenuItem<String>(
                                    value: 'Create ledger',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.list,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 12.w),
                                        Text('Create ledger'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'Add item',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 12.w),
                                        Text('Add item'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : Container(),

                  Divider(height: 1.h, color: Color(0xFFE5E7EB)),

                  Expanded(
                    child: Container(
                      color: Color(0xFFF8F9FA),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 30,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 900.h,
                          child: _getCurrentWidget(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemWithDropdown(
    IconData icon,
    String title,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Color(0xFF6C63FF) : Colors.grey[600],
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Color(0xFF6C63FF) : Colors.grey[700],
          ),
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          color: isSelected ? Color(0xFF6C63FF) : Colors.grey[400],
          size: isSelected ? 18 : 16,
        ),
        selected: isSelected,
        selectedTileColor: Color(0xFF6C63FF).withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  Widget _buildTab(String title, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Color(0xFF6C63FF) : Colors.grey[600],
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 3.h,
          width: title.length * 8.0,
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ],
    );
  }
}
