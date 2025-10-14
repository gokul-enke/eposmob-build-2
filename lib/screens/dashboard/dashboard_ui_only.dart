import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/shared_preferences.dart';

// Import the different dashboard widgets
import 'admin_dashboard.dart';
import 'company_admin.dart';
import 'sales_exicutive_dahsboard.dart';

class DashboardUIScreen extends StatefulWidget {
  const DashboardUIScreen({super.key});

  @override
  State<DashboardUIScreen> createState() => _DashboardUiScreenState();
}

class _DashboardUiScreenState extends State<DashboardUIScreen> {
  String userRole = ''; // Added to store user role

  @override
  void initState() {
    super.initState();
    _loadUserRole(); // Load user role on init
  }

  // Method to load user role
  void _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
    setState(() {
      userRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show appropriate dashboard based on user role
    if (userRole == 'sales_executive') {
      return const SalesExecutiveDashboard();
    } else if (userRole == 'company_admin') {
      return const CompanyAdminDashboard();
    } else if (userRole == 'admin') {
      // For admin role, show admin dashboard
      return const AdminDashboard();
    }

    // Default to company admin dashboard if no role is matched
    return const CompanyAdminDashboard();
  }
}

class GraphData {
  final DateTime date;
  final int count;

  GraphData({required this.date, required this.count});
}

class QuickAccessCard extends StatelessWidget {
  final Function onTap;
  final String title;
  final Gradient gradient;
  final Size size;
  final IconData? icon;

  const QuickAccessCard({
    Key? key,
    required this.onTap,
    required this.title,
    required this.gradient,
    required this.size,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        height: 140,
        margin: const EdgeInsets.only(top: 10, left: 10),
        width: size.width * .18,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
