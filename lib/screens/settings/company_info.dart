import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart'; // Add sales executive provider
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/get_store.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  String? _userName; // Admin user info
  String? _loggedInUserName; // Logged in username from SalesExecutive
  String? _loggedInUserEmail; // Logged in email from SalesExecutive
  String? _apiKey;
  String? _companyName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      // Get user info from shared preferences
      final sharedPrefsProvider = Provider.of<SharedPreferenceProvider>(
        context,
        listen: false,
      );

      // Get admin user name (from shared preferences)
      _userName = await sharedPrefsProvider.getCustomerName();

      // Get API key
      _apiKey = await sharedPrefsProvider.getApiKey();

      // Fetch logged in user info from SalesExecutive
      await _fetchLoggedInUserInfo();

      // Fetch company name from store API
      await _fetchCompanyName();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading user info: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchLoggedInUserInfo() async {
    try {
      // Use SalesExecutiveProvider to fetch sales executive data
      final salesExecutiveProvider = Provider.of<SalesExecutiveProvider>(
        context,
        listen: false,
      );

      // Fetch sales executives
      await salesExecutiveProvider.fetchSalesExecutives(context);

      // Get current user from sales executives
      final currentUser = salesExecutiveProvider.getCurrentUser(context);

      if (currentUser != null) {
        // Set logged in username and email from SalesExecutive model
        _loggedInUserName = currentUser.name;
        _loggedInUserEmail = currentUser.email;
        debugPrint(
            'Logged in user info set from SalesExecutive: $_loggedInUserName, $_loggedInUserEmail');
      } else {
        // Fallback to user role from shared preferences if sales executive data isn't available
        final sharedPrefsProvider = Provider.of<SharedPreferenceProvider>(
          context,
          listen: false,
        );

        String userRole = await sharedPrefsProvider.getUserRole();
        _loggedInUserEmail =
            userRole.contains('@') ? userRole : 'admin@company.com';
        _loggedInUserName = _userName; // Use admin user name as fallback
      }
    } catch (e) {
      debugPrint('Error fetching logged in user info: $e');

      // Fallback to user role from shared preferences if sales executive fetch fails
      try {
        final sharedPrefsProvider = Provider.of<SharedPreferenceProvider>(
          context,
          listen: false,
        );

        String userRole = await sharedPrefsProvider.getUserRole();
        _loggedInUserEmail =
            userRole.contains('@') ? userRole : 'admin@company.com';
        _loggedInUserName = _userName; // Use admin user name as fallback
      } catch (settingsError) {
        debugPrint('Error fetching from shared preferences: $settingsError');
        _loggedInUserEmail = 'admin@company.com';
        _loggedInUserName = _userName; // Use admin user name as fallback
      }
    }
  }

  Future<void> _fetchCompanyName() async {
    try {
      // Use PurchaseProvider to fetch store data
      final purchaseProvider = Provider.of<PurchaseProvider>(
        context,
        listen: false,
      );

      // Get access token from shared preferences
      final sharedPrefsProvider = Provider.of<SharedPreferenceProvider>(
        context,
        listen: false,
      );

      String? accessToken = await sharedPrefsProvider.getToken();

      if (accessToken == null) {
        throw Exception('Access token not found');
      }

      // Fetch stores
      await purchaseProvider.listAllStores(accessToken, null);

      // Get store list
      List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;

      if (storeList != null && storeList.isNotEmpty) {
        // Use the first store's name as the company name
        _companyName = storeList.first.name;
        debugPrint('Company name set from store: $_companyName');
      } else {
        // If no stores found, try to get it from app settings
        final appSettingsProvider = Provider.of<AppSettingsProvider>(
          context,
          listen: false,
        );

        // Try to get company name from print title or other settings
        if (appSettingsProvider.appSettings != null) {
          _companyName = appSettingsProvider.appSettings!.printTitle;
        }

        // If still no company name, use a default
        if (_companyName == null || _companyName!.isEmpty) {
          _companyName = 'Company Name Not Available';
        }
      }
    } catch (e) {
      debugPrint('Error fetching company name: $e');

      // Fallback to app settings if store fetch fails
      try {
        final appSettingsProvider = Provider.of<AppSettingsProvider>(
          context,
          listen: false,
        );

        // Try to get company name from print title or other settings
        if (appSettingsProvider.appSettings != null) {
          _companyName = appSettingsProvider.appSettings!.printTitle;
        }
      } catch (settingsError) {
        debugPrint('Error fetching from app settings: $settingsError');
      }

      // If still no company name, use a default
      if (_companyName == null || _companyName!.isEmpty) {
        _companyName = 'Company Name Not Available';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sideBarController = Get.find<SideBarController>();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomBackButton(
                    onPressed: () {
                      sideBarController.index.value =
                          62; // Navigate back to Settings
                    },
                    text: 'Settings',
                  ),
                  BuildBoxShadowContainer(
                    width: 15,
                    height: 15,
                    circleRadius: 10,
                    color: ColorManager.kPrimaryColor,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        sideBarController.index.value =
                            62; // Navigate back to Settings
                      },
                      icon: const Icon(Icons.close_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Company Information',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BuildBoxShadowContainer(
                  circleRadius: 12,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoTable(),
                          const SizedBox(height: 20),
                          _buildNoteSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: 'Back to Settings',
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () {
                      sideBarController.index.value =
                          62; // Navigate back to Settings
                    },
                    height: 45,
                    width: 150,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTable() {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
      },
      children: [
        _buildTableRow('Admin User Info', _userName ?? 'Loading...'),
        _buildTableRow('Company Name', _companyName ?? 'Loading...'),
        _buildTableRow('Logged In Username', _loggedInUserName ?? 'Loading...'),
        _buildTableRow('Logged In Email', _loggedInUserEmail ?? 'Loading...'),
        _buildTableRow('Base URL', APPUrl.baseURL),
        _buildTableRow('API Key', _apiKey ?? 'Not available'),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.8),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        border: Border.all(color: Colors.yellow.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Note:',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• API Key is sensitive information and should be kept secure\n'
            '• User information is fetched from local storage\n'
            '• Company Name is fetched from the first store in the store list',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
