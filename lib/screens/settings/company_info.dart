import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart'; // Add sales executive provider
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';

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
  String? _timeZone;
  int? _customerId;
  String? _userRole;
  String? _tokenType;
  String? _appVersion;
  int? _companyId;
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

      // Get other login details
      _timeZone = await sharedPrefsProvider.getTimeZone();
      _customerId = await sharedPrefsProvider.getCustomerId();
      _userRole = await sharedPrefsProvider.getUserRole();
      _tokenType = await sharedPrefsProvider.getTokenType();
      _companyId = await sharedPrefsProvider.getCompanyId();

      // Fetch logged in user info from SalesExecutive
      await _fetchLoggedInUserInfo();

      // Fetch company name from store API
      await _fetchCompanyName();

      // Read app version from installed package metadata
      await _loadAppVersion();

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

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}.${packageInfo.buildNumber}';
    } catch (e) {
      debugPrint('Error loading app version: $e');
      _appVersion = 'company_info.not_available'.tr;
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
          _companyName = 'company_info.name_not_available'.tr;
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

    return SettingsPageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSubPageHeader(
            backLabel: 'company_info.back'.tr,
            onBack: () {
              sideBarController.index.value =
                  62; // Navigate back to Settings
            },
            onClose: () {
              sideBarController.index.value =
                  62; // Navigate back to Settings
            },
            title: 'company_info.title'.tr,
            subtitle: 'company_info.subtitle'.tr,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : SingleChildScrollView(
                    child: SettingsInfoList(
                      entries: [
                        MapEntry('company_info.label_admin_user'.tr, _userName ?? 'company_info.loading'.tr),
                        MapEntry('company_info.label_company_name'.tr, _companyName ?? 'company_info.loading'.tr),
                        MapEntry(
                          'company_info.label_username'.tr,
                          _loggedInUserName ?? 'company_info.loading'.tr,
                        ),
                        MapEntry(
                          'company_info.label_email'.tr,
                          _loggedInUserEmail ?? 'company_info.loading'.tr,
                        ),
                        MapEntry('company_info.label_user_role'.tr, _userRole ?? 'company_info.loading'.tr),
                        MapEntry(
                          'company_info.label_customer_id'.tr,
                          _customerId?.toString() ?? 'company_info.loading'.tr,
                        ),
                        MapEntry(
                          'company_info.label_company_id'.tr,
                          _companyId?.toString() ?? 'company_info.loading'.tr,
                        ),
                        MapEntry('company_info.label_token_type'.tr, _tokenType ?? 'company_info.loading'.tr),
                        MapEntry('company_info.label_timezone'.tr, _timeZone ?? 'company_info.not_available'.tr),
                        MapEntry('company_info.label_base_url'.tr, APPUrl.baseURL),
                        MapEntry('company_info.label_app_version'.tr, _appVersion ?? 'company_info.loading'.tr),
                        MapEntry('company_info.label_api_key'.tr, _apiKey ?? 'company_info.not_available'.tr),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          SettingsActionRow(
            children: [
              CustomRoundButton(
                title: 'company_info.back'.tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                fct: () {
                  sideBarController.index.value =
                      62; // Navigate back to Settings
                },
                height: 48,
                width: 180,
                fontSize: FontSize.s12,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
