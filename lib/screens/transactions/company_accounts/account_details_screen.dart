import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/company_accounts.dart';
import 'package:pos_machine/providers/company_account_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/responsive.dart';
import 'package:provider/provider.dart';

class AccountDetailsScreen extends StatefulWidget {
  static CompanyAccountsData? accountData;

  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final SideBarController sideBarController = Get.find<SideBarController>();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetailedAccountData();
  }

  Future<void> _loadDetailedAccountData() async {
    final account = AccountDetailsScreen.accountData;
    if (account == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get providers
      final companyAccountProvider =
          Provider.of<CompanyAccountProvider>(context, listen: false);
      final sharedPrefProvider =
          Provider.of<SharedPreferenceProvider>(context, listen: false);

      // Get access token
      final token = await sharedPrefProvider.getToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      // Fetch detailed account data with transactions
      final detailedAccount =
          await companyAccountProvider.getAccountDetailsWithTransactions(
        accessToken: token,
        accountName: account.name ?? '',
      );

      if (detailedAccount != null) {
        // Update the static account data with the detailed version
        AccountDetailsScreen.accountData = detailedAccount;
      } else {
        _error = 'Could not load detailed account information';
      }
    } catch (e) {
      debugPrint('Error loading detailed account data: $e');
      _error = 'Error loading account details: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountDetailsScreen.accountData;

    if (account == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account Details'),
          backgroundColor: ColorManager.kPrimaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No account data available'),
        ),
      );
    }

    return SafeArea(
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(10.0),
              padding: const EdgeInsets.all(8.0),
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
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    Text(
                      'Account Details - ${account.name ?? "N/A"}',
                      style: ResponsiveWidget.isMobile(context)
                          ? buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s12, 0.30, ColorManager.textColor)
                          : buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s20, 0.30, ColorManager.textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // Loading indicator or error message
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      )
                    else if (_error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else
                      // Body: scrollable content with 3 sections
                      Column(
                        children: [
                          // 1) Account Information
                          _buildAccountInformation(account),
                          const SizedBox(height: 12),

                          // 2) Financial Summary
                          _buildFinancialSummary(account),
                          const SizedBox(height: 12),

                          // 3) Company Account Transactions
                          _buildTransactionsSection(account),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Footer actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomRoundButton(
                          title: 'Close',
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          borderColor: ColorManager.kPrimaryColor,
                          fct: () => sideBarController.index.value =
                              59, // Navigate back to company accounts
                          height: 45,
                          width: 120,
                          fontSize: FontSize.s12,
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomBackButton(
          onPressed: () {
            sideBarController.index.value =
                59; // Navigate back to company accounts
          },
          text: 'Company Accounts',
        ),
        Row(
          children: [
            // Refresh button
            IconButton(
              icon:
                  const Icon(Icons.refresh, color: ColorManager.kPrimaryColor),
              onPressed: _loadDetailedAccountData,
            ),
            const SizedBox(width: 8),
            BuildBoxShadowContainer(
              width: 15,
              height: 15,
              circleRadius: 10,
              color: ColorManager.kPrimaryColor,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  sideBarController.index.value =
                      59; // Navigate back to company accounts
                },
                icon: const Icon(Icons.close_rounded,
                    size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 1) Account Information
  Widget _buildAccountInformation(CompanyAccountsData account) {
    return _buildSectionCard(
      title: 'Account Information',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Account Name', account.name ?? 'N/A'),
                  const SizedBox(height: 16),
                  _buildDetailRow('Status', account.accountStatus),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        account.accountStatus.toLowerCase() == 'credit'
                            ? Icons.check_circle
                            : account.accountStatus.toLowerCase() == 'debit'
                                ? Icons.remove_circle
                                : Icons.radio_button_checked,
                        color: account.accountStatus.toLowerCase() == 'credit'
                            ? Colors.green
                            : account.accountStatus.toLowerCase() == 'debit'
                                ? Colors.red
                                : Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        account.accountStatus,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          Colors.black87,
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          'Type',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s14,
                            0.21,
                            Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildPill(account.type ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          'Payment Methods',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s14,
                            0.21,
                            Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (account.paymentMethod ?? [])
                              .map((m) => _buildPill(m))
                              .toList(),
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
    );
  }

  // 2) Financial Summary
  Widget _buildFinancialSummary(CompanyAccountsData account) {
    return _buildSectionCard(
      title: 'Financial Summary',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Received Amount',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        Colors.black87,
                      )),
                  const SizedBox(height: 6),
                  _amountText('₹${account.formattedReceived}', Colors.green),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sent Amount',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        Colors.black87,
                      )),
                  const SizedBox(height: 6),
                  _amountText('₹${account.formattedSent}', Colors.red),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        Colors.black87,
                      )),
                  const SizedBox(height: 6),
                  _amountText('₹${account.formattedBalance}', Colors.blueGrey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3) Company Account Transactions - FINAL CLEAN IMPLEMENTATION
  Widget _buildTransactionsSection(CompanyAccountsData account) {
    // Get transaction data - this is where the issue likely is
    final transactions = account.accountTransaction ?? [];

    debugPrint(
        'Building transactions section with ${transactions.length} transactions');

    return _buildSectionCard(
      title: 'Company Account Transactions',
      showDivider: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Table header with exact field mappings as per your requirements
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(
              children: [
                Expanded(
                  child: Text('FROM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  child: Text('TO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  child: Text('TYPE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  child: Text('STATUS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  child: Text('AMOUNT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  child: Text('DATE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Display transactions or "No transactions found" message
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No transactions found',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  debugPrint(
                      'Displaying transaction: ${tx.transferFrom}, ${tx.transferTo}, ${tx.amount}');
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 6.0),
                    child: Row(
                      children: [
                        // FROM - transferFrom
                        Expanded(
                          child: Text(tx.transferFrom ?? '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        // TO - transferTo
                        Expanded(
                          child: Text(tx.transferTo ?? '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        // TYPE - transactionType
                        Expanded(
                          child: Text(
                              (tx.transactionType ?? '').isNotEmpty
                                  ? tx.transactionType!.toUpperCase()
                                  : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        // STATUS - status with chip
                        Expanded(
                          child: _buildStatusChip(tx.status ?? '-'),
                        ),
                        // AMOUNT - formattedAmount
                        Expanded(
                          child: Text('₹${tx.formattedAmount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        // DATE - date
                        Expanded(
                          child: Text(tx.date ?? '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Section card with title
  Widget _buildSectionCard(
      {required String title, required Widget child, bool showDivider = true}) {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.21,
                Colors.black87,
              ),
            ),
          ),
          if (showDivider) const Divider(height: 1, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  // Small rounded pill chip
  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _amountText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            title,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s14,
              0.21,
              Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'N/A',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.21,
              Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Status chip widget
  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    // Normalize status for comparison
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus == 'completed') {
      backgroundColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
    } else if (normalizedStatus == 'pending') {
      backgroundColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange;
    } else if (normalizedStatus == 'failed' ||
        normalizedStatus == 'cancelled') {
      backgroundColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red;
    } else {
      backgroundColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
