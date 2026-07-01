import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/add_customer_mobile_page.dart';

/// Full-screen "Select Customer" page matching the Figma design.
/// Displays a search bar, a scrollable customer list with radio selection,
/// a floating "add customer" button, and bottom Close / Done actions.
class SelectCustomerPage extends StatefulWidget {
  const SelectCustomerPage({super.key});

  @override
  State<SelectCustomerPage> createState() => _SelectCustomerPageState();
}

class _SelectCustomerPageState extends State<SelectCustomerPage> {
  static const _controller = BillingMobileCustomerController();
  final TextEditingController _searchController = TextEditingController();
  List<CustomerListModelData> _allCustomers = [];
  List<CustomerListModelData> _filteredCustomers = [];
  CustomerListModelData? _selectedCustomer;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-select current customer if one is already chosen
    final currentSelection =
        Provider.of<CustomerSelectionProvider>(context, listen: false)
            .selectedCustomer;
    _selectedCustomer = currentSelection;
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accessToken =
          Provider.of<AuthModel>(context, listen: false).token ?? '';
      final customerProvider = CustomerProvider();
      final response = await customerProvider.listCustomer(
        accessToken: accessToken,
        loadAll: true,
      );

      if (!mounted) return;

      // The provider populates its internal list. We also read from the
      // response to get our local list.
      if (response != null && response['status'] == 'success') {
        final model = CustomerListModel.fromJson(response);
        setState(() {
          _allCustomers = model.data ?? [];
          _filteredCustomers = List.from(_allCustomers);
          _isLoading = false;
        });
      } else {
        setState(() {
          _allCustomers = [];
          _filteredCustomers = [];
          _isLoading = false;
          _errorMessage = BillingMobileErrorMessages.customersUnavailable;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = BillingMobileErrorMessages.loadCustomersFailed;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredCustomers = _controller.filterCustomers(_allCustomers, query);
    });
  }

  void _applyCustomerSelection(CustomerListModelData customer) {
    _controller.applySelection(
      customer: customer,
      customerSelectionProvider: Provider.of<CustomerSelectionProvider>(
        context,
        listen: false,
      ),
      billingProvider: Provider.of<BillingProvider>(context, listen: false),
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );
  }

  Future<void> _onAddCustomer() async {
    final result = await openAddCustomerMobilePage(
      context,
      mobileNumber: '',
    );

    if (result != null && result is Map && result['status'] == 'success') {
      final createdCustomer =
          _controller.parseCreatedCustomerFromAddResponse(result);
      if (createdCustomer != null) {
        setState(() {
          _allCustomers.removeWhere((customer) =>
              customer.id == createdCustomer.id ||
              (customer.phone != null &&
                  customer.phone == createdCustomer.phone));
          _allCustomers.insert(0, createdCustomer);
          _filteredCustomers = _controller.filterCustomers(
            _allCustomers,
            _searchController.text,
          );
          _selectedCustomer = createdCustomer;
        });
        _applyCustomerSelection(createdCustomer);
        if (mounted) {
          Navigator.of(context).pop(createdCustomer);
        }
        return;
      }

      final createdPhone = (result['phone'] ?? '').toString();
      await _loadCustomers();
      final matched =
          _controller.findCustomerByPhone(_allCustomers, createdPhone);
      if (matched != null) {
        setState(() => _selectedCustomer = matched);
        _applyCustomerSelection(matched);
        if (mounted) {
          Navigator.of(context).pop(matched);
        }
      } else if (mounted) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.addCustomerFailed,
        );
      }
    } else if (result != null && result is Map && result['status'] != 'success') {
      if (mounted) {
        final apiMessage = result['message']?.toString();
        showScaffoldError(
          context: context,
          message: apiMessage?.trim().isNotEmpty == true
              ? apiMessage!.trim()
              : BillingMobileErrorMessages.addCustomerFailed,
        );
      }
    }
  }

  // Build avatar initial for the customer
  String _avatarInitial(CustomerListModelData customer) {
    return _controller.avatarInitial(customer);
  }

  MobileCustomerBalanceDisplay? _balanceDisplayForCustomer(
    CustomerListModelData customer,
  ) {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final customerSelection =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final isQuotationDraft = Provider.of<LocalProductProvider>(context,
            listen: false)
        .currentOrder
        ?.quotationId !=
        null;
    final shouldShow = _controller.shouldShowCustomerBalance(
      customer: customer,
      customerSelectionProvider: customerSelection,
      defaultCustomerPhone:
          appSettings?.autoAssignDefaultCustomerPhone ?? '',
      isQuotationDraft: isQuotationDraft,
    );
    if (!shouldShow) return null;

    return _controller.balanceDisplay(
      balance: customer.balance ?? 0.0,
      currency: appSettings?.currency ?? '',
    );
  }

  Widget _buildBalanceChip(MobileCustomerBalanceDisplay display) {
    return Text(
      '${display.label}: ${display.amountText}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: display.color,
      ),
    );
  }

  /// Mirrors desktop `checkout_modal.dart` customer-type badge styling.
  Widget _buildCustomerTypeBadge(String? customerType) {
    final type = (customerType == null || customerType.trim().isEmpty)
        ? 'B2C'
        : customerType.trim().toUpperCase();
    final isB2B = type == 'B2B';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isB2B ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isB2B ? Colors.green.shade300 : Colors.blue.shade300,
        ),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isB2B ? Colors.green.shade700 : Colors.blue.shade700,
        ),
      ),
    );
  }

  // Get a color for the avatar based on the initial
  Color _avatarColor(String initial) {
    return _controller.avatarColor(initial);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final showCustomerType = Provider.of<AppSettingsProvider>(context)
            .appSettings
            ?.companyB2BEnabled ??
        false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───
            _buildHeader(),

            // ─── Search Bar ───
            _buildSearchBar(),

            // ─── Body ───
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1D4ED8),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(_errorMessage!,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadCustomers,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            if (_filteredCustomers.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_search,
                                          size: 48,
                                          color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No customers found',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: EdgeInsets.only(
                                  bottom: 80 + bottomPadding,
                                ),
                                sliver: SliverList.builder(
                                  itemCount: _filteredCustomers.length,
                                  itemBuilder: (context, index) {
                                    return _buildCustomerRow(
                                      _filteredCustomers[index],
                                      showCustomerType: showCustomerType,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      // ─── FAB ───
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _onAddCustomer,
              backgroundColor: const Color(0xFF1D4ED8),
              elevation: 4,
              child: const Icon(Icons.person_add, color: Colors.white),
            ),
      // ─── Bottom Bar ───
      bottomSheet: _buildBottomBar(bottomPadding),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HEADER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Select Customer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SEARCH BAR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search ${_allCustomers.length.toString()} customers....',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 22,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.grey.shade400, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CUSTOMER LIST
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildCustomerRow(
    CustomerListModelData customer, {
    required bool showCustomerType,
  }) {
    final initial = _avatarInitial(customer);
    final isSelected = _selectedCustomer?.id == customer.id;
    final balanceDisplay = _balanceDisplayForCustomer(customer);

    return InkWell(
      onTap: () {
        setState(() => _selectedCustomer = customer);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1D4ED8).withValues(alpha: 0.04)
              : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _avatarColor(initial).withValues(alpha: 0.12),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _avatarColor(initial),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          customer.name ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showCustomerType) ...[
                        const SizedBox(width: 6),
                        _buildCustomerTypeBadge(customer.customerType),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.phone ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (balanceDisplay != null) ...[
                        const SizedBox(width: 8),
                        _buildBalanceChip(balanceDisplay),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF22C55E) : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BOTTOM BAR (Close / Done)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildBottomBar(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close button
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Done button
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedCustomer != null
                  ? () {
                      _applyCustomerSelection(_selectedCustomer!);
                      Navigator.of(context).pop(_selectedCustomer);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF166534),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
