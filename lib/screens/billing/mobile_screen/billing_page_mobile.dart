import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/screens/billing/mobile_screen/widgets/billing_widget.dart';
import 'package:pos_machine/screens/billing/mobile_screen/widgets/home_widget.dart';
import 'package:pos_machine/screens/billing/mobile_screen/widgets/order_list_widget.dart';
import 'package:provider/provider.dart';

class BillingPageMobile extends StatefulWidget {
  const BillingPageMobile({super.key});

  @override
  State<BillingPageMobile> createState() => _BillingPageMobileState();
}

class _BillingPageMobileState extends State<BillingPageMobile> {
  int _currentIndex = 0;
  String? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    // Initialize the billing provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final billingProvider = Provider.of<BillingProvider>(context, listen: false);
      
      // Initialize connectivity listener with UI feedback
      billingProvider.initConnectivityListener(
        onConnectivityChanged: (message) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 2),
                backgroundColor: message.contains('No internet') ? Colors.red : Colors.green,
              ),
            );
          }
        },
      );
      
      // Initialize delivery method
      billingProvider.initializeDeliveryMethod();
      
      // Register keyboard shortcuts
      billingProvider.registerDefaultKeyboardShortcuts(
        onClearCart: () => _clearCart(),
        onSaveOrder: () => _saveOrder(),
        onCreateOrderAndPrint: () => _createOrderAndPrint(),
        onConfirmOrder: () => _confirmOrder(),
      );
    });
  }

  void _clearCart() {
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final localProvider = Provider.of<LocalProductProvider>(context, listen: false);
    
    billingProvider.clearCart();
    localProvider.clearCart();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('mobile_billing.msg_cart_cleared'.tr)),
    );
  }

  void _saveOrder() {
    // Implement save order logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('mobile_billing.msg_order_saved'.tr)),
    );
  }

  void _createOrderAndPrint() {
    // Implement create and print logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('mobile_billing.msg_order_created_print'.tr)),
    );
  }

  void _confirmOrder() {
    // Implement confirm order logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('mobile_billing.msg_order_confirmed'.tr)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: _getAppBarTitle(),
      //   centerTitle: true, // This centers the title
      //   backgroundColor: Colors.blue[800],
      //   foregroundColor: Colors.white,
      //   elevation: 4,
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.person),
      //       onPressed: () => _navigateToProfile(context),
      //     ),
      //   ],
      // ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue[800],
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.1,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale),
              label: 'Billing',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'Orders',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    return Consumer2<BillingProvider, LocalProductProvider>(
      builder: (context, billingProvider, localProvider, child) {
        switch (_currentIndex) {
          case 0:
            return HomeWidget(
              selectedOrderId: _selectedOrderId,
            );
          case 1:
            return const BillingWidget();
          case 2:
            return ViewOrders(
              onOrderSelected: (orderId) {
                setState(() {
                  _selectedOrderId = orderId;
                  _currentIndex = 0; // Switch to home tab
                });
                localProvider.loadOrderForEditing(orderId);
                
                // Update billing provider state
                billingProvider.setLastRehydratedOrderId(orderId);
              },
            );
          default:
            return Container();
        }
      },
    );
  }

  // Widget _getAppBarTitle() {
  //   final String title;
  //   switch (_currentIndex) {
  //     case 0:
  //       title = 'New Order';
  //       break;
  //     case 1:
  //       title = 'Billing';
  //       break;
  //     case 2:
  //       title = 'Saved Orders';
  //       break;
  //     default:
  //       title = 'POS System';
  //       break;
  //   }

  //   return Text(
  //     title,
  //     style: const TextStyle(
  //       fontSize: 20,
  //       fontWeight: FontWeight.w700,
  //       letterSpacing: 0.5,
  //     ),
  //   );
  // }

  // void _navigateToProfile(BuildContext context) {
  //   // Implement profile navigation
  // }
}
