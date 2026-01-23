import 'package:flutter/material.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/screens/dashboard/admin_dashboard.dart';
import 'package:pos_machine/screens/dashboard/company_admin.dart';
import 'package:pos_machine/screens/dashboard/sales_exicutive_dahsboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userRole = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
    if (mounted) {
      setState(() {
        userRole = role;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    // Route to appropriate dashboard based on role
    switch (userRole) {
      case 'sales_executive':
      case 'restaurant_sales':
        return const SalesExecutiveDashboard();
      case 'supplier':
        return const AdminDashboard(); // Supplier Dashboard
      case 'company_admin':
      default:
        // Default to Company Admin Dashboard for admin and other roles
        return const CompanyAdminDashboard();
    }
  }
}
