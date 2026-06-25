import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/screens/customers/add_customer_modal.dart';

/// Full-screen "Select Customer" page matching the Figma design.
/// Displays a search bar, frequent-customer horizontal cards, a scrollable
/// customer list with radio selection, a floating "add customer" button,
/// and bottom Close / Done actions.
class SelectCustomerPage extends StatefulWidget {
  const SelectCustomerPage({super.key});

  @override
  State<SelectCustomerPage> createState() => _SelectCustomerPageState();
}

class _SelectCustomerPageState extends State<SelectCustomerPage> {
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
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load customers';
      });
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _filteredCustomers = List.from(_allCustomers));
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        final name = (c.name ?? '').toLowerCase();
        final phone = (c.phone ?? '').toLowerCase();
        return name.contains(lowerQuery) || phone.contains(lowerQuery);
      }).toList();
    });
  }

  /// First 10 customers act as "Frequent Customers" for the horizontal cards.
  List<CustomerListModelData> get _frequentCustomers {
    return _allCustomers.length > 10
        ? _allCustomers.sublist(0, 10)
        : _allCustomers;
  }

  void _selectAndDone(CustomerListModelData customer) {
    _applyCustomerSelection(customer);
    Navigator.of(context).pop(customer);
  }

  void _applyCustomerSelection(CustomerListModelData customer) {
    final customerSelectionProv =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    customerSelectionProv.setSelectedCustomer(customer);

    final bp = Provider.of<BillingProvider>(context, listen: false);
    bp.setMobileNumberText('${customer.name} ${customer.phone}');
    bp.setSelectedCustomer(customer, isManual: true);
    bp.mobileNumberTextController.text =
        '${customer.name} ${customer.phone}';

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    Provider.of<CartProvider>(context, listen: false)
        .fetchCartDataFromApi(
      customerId: customer.id ?? 0,
      accessToken: accessToken,
    );
  }

  Future<void> _onAddCustomer() async {
    final size = MediaQuery.of(context).size;
    final result = await showAddCustomerModal(
      context,
      size,
      mobileNumber: '',
    );

    if (result != null && result is Map && result['status'] == 'success') {
      // Reload the list after adding a new customer
      await _loadCustomers();
    }
  }

  // Build avatar initial for the customer
  String _avatarInitial(CustomerListModelData customer) {
    final name = customer.name ?? '';
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // Get a color for the avatar based on the initial
  Color _avatarColor(String initial) {
    const colors = [
      Color(0xFF1D4ED8), // Blue
      Color(0xFF059669), // Green
      Color(0xFFD97706), // Amber
      Color(0xFFDC2626), // Red
      Color(0xFF7C3AED), // Purple
      Color(0xFF0891B2), // Cyan
      Color(0xFFDB2777), // Pink
      Color(0xFF4F46E5), // Indigo
    ];
    final index = initial.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                          padding: EdgeInsets.only(
                              bottom: 80 + bottomPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Frequent Customers horizontal carousel
                              if (_frequentCustomers.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                                  child: Text(
                                    'Frequent Customers',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                _buildFrequentCustomerCards(),
                                const SizedBox(height: 8),
                              ],

                              // Full customer list
                              ..._buildCustomerList(),
                            ],
                          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            hintText:
                'Search ${_allCustomers.length.toString()} customers....',
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
  // FREQUENT CUSTOMER CARDS (HORIZONTAL)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildFrequentCustomerCards() {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _frequentCustomers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final customer = _frequentCustomers[index];
          final initial = _avatarInitial(customer);
          final isSelected = _selectedCustomer?.id == customer.id;
          final hasVip = customer.membershipName != null &&
              customer.membershipName!.isNotEmpty;

          return GestureDetector(
            onTap: () => _selectAndDone(customer),
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1D4ED8)
                      : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + VIP badge row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            _avatarColor(initial).withOpacity(0.12),
                        child: Icon(
                          Icons.person,
                          size: 22,
                          color: _avatarColor(initial),
                        ),
                      ),
                      if (hasVip)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            customer.membershipName!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Name
                  Text(
                    customer.name ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Phone
                  Row(
                    children: [
                      Icon(Icons.phone,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customer.phone ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Select button
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => _selectAndDone(customer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Select customer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CUSTOMER LIST
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  List<Widget> _buildCustomerList() {
    if (_filteredCustomers.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.person_search,
                    size: 48, color: Colors.grey.shade300),
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
        ),
      ];
    }

    return _filteredCustomers.map((customer) {
      final initial = _avatarInitial(customer);
      final isSelected = _selectedCustomer?.id == customer.id;

      return InkWell(
        onTap: () {
          setState(() => _selectedCustomer = customer);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Avatar circle with initial
              CircleAvatar(
                radius: 20,
                backgroundColor: _avatarColor(initial).withOpacity(0.12),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _avatarColor(initial),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name + Phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer.phone ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              isSelected
                  ? Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  : Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
    }).toList();
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
            color: Colors.black.withOpacity(0.06),
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
