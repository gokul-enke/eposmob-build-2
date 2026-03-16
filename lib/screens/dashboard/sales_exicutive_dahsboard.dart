import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';

import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

import '../../models/dashboard.dart';
import '../../models/dashboard_api.dart';
import '../../providers/dashboard_provider.dart';
import '../../resources/color_manager.dart';
import '../../providers/app_settings_provider.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SalesExecutiveDashboard extends StatefulWidget {
  const SalesExecutiveDashboard({super.key});

  @override
  State<SalesExecutiveDashboard> createState() =>
      _SalesExecutiveDashboardState();
}

class _SalesExecutiveDashboardState extends State<SalesExecutiveDashboard> {
  bool isInitLoading = false;
  DashBoardModelData? dashBoardModelData;
  TotalSales? totalSales;
  String value = 'today';
  bool isLoading = false;
  List<GraphData> graphData = [];
  List<GraphData> chartData = [];

  // New API data state variables
  DashboardOverview? dashboardOverview;
  OrdersPerMonth? ordersPerMonthData;
  CustomersPerMonth? customersPerMonthData;
  ExecutivesOverview? executivesOverview;
  SalesGraph? executiveSalesGraph;
  SalesStats? salesStats;
  CustomerStats? customerStats;
  ProductStats? productStats;

  // Sales graph period
  String salesGraphPeriod = 'today';

  // Cache for different periods
  Map<String, DashBoardModelData> cachedDashboardData = {};
  Map<String, DashboardOverview> cachedOverviewData = {};
  Map<String, TotalSales> cachedTotalSales = {};
  bool isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('=== SalesExecutiveDashboard initState called ===');
    debugPrint('Starting initial data fetching...');
    fetchDataForPeriod(
        'month'); // Fetch data for month by default to show some data
    debugPrint('=== Initial data fetching initiated ===');
  }

  Future<void> fetchDataForPeriod(String period) async {
    debugPrint('=== FETCHING DATA FOR PERIOD: $period ===');

    // Check if data is already cached
    if (cachedDashboardData.containsKey(period) &&
        cachedOverviewData.containsKey(period)) {
      debugPrint('Using cached data for period: $period');
      setState(() {
        dashBoardModelData = cachedDashboardData[period];
        totalSales = cachedTotalSales[period];
        dashboardOverview = cachedOverviewData[period];
        value = period;
      });
      return;
    }

    // Data not cached, fetch it
    debugPrint('Data not cached for period: $period. Fetching from API...');
    try {
      setState(() {
        isInitialLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) {
        debugPrint('ERROR: No access token available');
        setState(() {
          isInitialLoading = false;
        });
        return;
      }

      // Get date range based on the period
      final DateTime now = DateTime.now();
      String startDate;
      String endDate = DateFormat('yyyy-MM-dd').format(now);
      int currentYear = now.year;

      switch (period) {
        case "today":
          startDate = DateFormat('yyyy-MM-dd').format(now);
          break;
        case "week":
          startDate = DateFormat('yyyy-MM-dd')
              .format(now.subtract(const Duration(days: 7)));
          break;
        case "month":
          startDate =
              DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
          break;
        case "year":
          startDate = DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
          currentYear = now.year;
          break;
        default:
          startDate = DateFormat('yyyy-MM-dd')
              .format(now.subtract(const Duration(days: 30)));
      }

      // Fetch dashboard data for this period
      try {
        // Fetch legacy dashboard data
        final dashboardResponse =
            await DashboardProvider().dashbaord(accessToken, context);
        if (dashboardResponse["status"] == "success") {
          DashBoardModel dashBoardModel =
              DashBoardModel.fromJson(dashboardResponse);
          if (dashBoardModel.data != null) {
            cachedDashboardData[period] = dashBoardModel.data!;
            if (dashBoardModel.data!.totalSales != null) {
              cachedTotalSales[period] = dashBoardModel.data!.totalSales!;
            }
          }
        }

        // Fetch new dashboard overview data (Removed due to backend issue)
        final dashboardProvider = DashboardProvider();

        // Define local variables for fetched data
        DashboardOverview? overview;
        OrdersPerMonth? ordersPerMonth;
        CustomersPerMonth? customersPerMonth;
        SalesStats? stats;
        SalesGraph? graph;
        CustomerStats? customerStats;
        ProductStats? productStats;

        try {
          ordersPerMonth = await dashboardProvider.fetchOrdersPerMonth(
              accessToken, currentYear);
        } catch (e) {
          debugPrint('Orders per month failed: $e');
        }

        try {
          customersPerMonth = await dashboardProvider.fetchCustomersPerMonth(
              accessToken, currentYear);
        } catch (e) {
          debugPrint('Customers per month failed: $e');
        }

        try {
          stats = await dashboardProvider.fetchSalesStats(accessToken);
        } catch (e) {
          debugPrint('Sales stats failed: $e');
        }

        // Fetch graph data for the period
        String apiPeriod = 'week';
        if (period == 'today') apiPeriod = 'day';
        if (period == 'week') apiPeriod = 'week';
        if (period == 'month') apiPeriod = 'month';

        try {
          graph = await dashboardProvider.fetchExecutiveSalesGraph(
              accessToken, apiPeriod, startDate, endDate);
        } catch (e) {
          debugPrint('Executive sales graph failed: $e');
        }

        try {
          customerStats = await dashboardProvider.fetchCustomerStats(
              accessToken, apiPeriod, startDate, endDate);
        } catch (e) {
          debugPrint('Customer stats failed: $e');
        }

        try {
          productStats = await dashboardProvider.fetchProductStats(accessToken);
        } catch (e) {
          debugPrint('Product stats failed: $e');
        }

        // Update state with the newly fetched data
        if (mounted) {
          setState(() {
            dashBoardModelData = cachedDashboardData[period];
            totalSales = cachedTotalSales[period];
            dashboardOverview = overview; // Will be null
            ordersPerMonthData = ordersPerMonth;
            customersPerMonthData = customersPerMonth;
            salesStats = stats;
            this.executiveSalesGraph = graph;
            this.customerStats = customerStats;
            this.productStats = productStats;
            value = period;
            isInitialLoading = false;
            isLoading = false;
          });
        }
      } catch (error) {
        debugPrint('Unexpected error in fetchDataForPeriod: $error');
        if (mounted) {
          setState(() {
            isLoading = false;
            isInitialLoading = false;
          });
        }
      }

      debugPrint('=== PERIOD DATA FETCHING COMPLETE ===');
    } catch (error) {
      debugPrint('Error in fetchDataForPeriod: $error');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'An unexpected error occurred: $error',
        );
      }
      setState(() {
        isInitialLoading = false;
      });
    }
  }

  Future<void> fetchNewDashboardData() async {
    // This method is no longer needed as we're using cached data
    // Keeping it for compatibility but it's empty now
    debugPrint('fetchNewDashboardData called but using cached data instead');
  }

  Future<void> fetchGraphData() async {
    // This method is no longer needed as we're using cached data
    // Keeping it for compatibility but it's empty now
    debugPrint('fetchGraphData called but using cached data instead');
  }

  Future<void> getDashBoardDetails() async {
    // This method is no longer needed as we're using cached data
    // Keeping it for compatibility but it's empty now
    debugPrint('getDashBoardDetails called but using cached data instead');
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: isInitialLoading
          ? SizedBox(
              width: size.width,
              height: size.height,
              child: const Center(child: CircularProgressIndicator.adaptive()))
          : Container(
              width: size.width,
              height: size.height,
              padding:
                  const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(size),
                    const SizedBox(height: 20),
                    _buildTodaysSales(),
                    _buildSalesCards(),
                    const SizedBox(height: 20),
                    _buildCompanyAccountOverview(),
                    const SizedBox(height: 20),
                    _buildSalesExecutiveAccountOverview(),
                    const SizedBox(height: 20),
                    _buildAllSalesOfSalesExecutive(),
                    const SizedBox(height: 20),
                    _buildCustomersBySalesExecutive(),
                    const SizedBox(height: 20),
                    _buildProductOverview(),
                    const SizedBox(height: 20),
                    _buildWorksTeam(),
                    const SizedBox(height: 20),
                    _buildSalesGraphByPeriod(),
                    const SizedBox(height: 20),
                    // _buildAdditionalStats(),
                    // const SizedBox(height: 20),
                    // _buildQuickAccess(),
                    // const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(Size size) {
    final bool isCompactHeader = size.width < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: isCompactHeader
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTitle(),
                const SizedBox(height: 12),
                _buildHeaderActions(isCompact: true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHeaderTitle()),
                const SizedBox(width: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildHeaderActions(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Sales Executive Dashboard",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dashBoardModelData?.profileDetails?.isNotEmpty == true
              ? "Welcome, ${dashBoardModelData!.profileDetails![0].name}!"
              : "Welcome back!",
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.10,
            Colors.grey[600]!,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActions({bool isCompact = false}) {
    final dateCard = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: isCompact ? 46 : 50,
        maxWidth: isCompact ? double.infinity : 220,
      ),
      child: BuildBoxShadowContainer(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 12,
          vertical: isCompact ? 10 : 12,
        ),
        circleRadius: 10,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: ColorManager.textColor,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                DateHelper.formatDate(DateHelper.now()),
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.10,
                  ColorManager.textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final refreshButton = BuildBoxShadowContainer(
      padding: EdgeInsets.all(isCompact ? 10 : 8),
      circleRadius: 10,
      child: InkWell(
        onTap: () {
          fetchDataForPeriod(value);
        },
        borderRadius: BorderRadius.circular(10),
        child: const Icon(
          Icons.refresh_rounded,
          color: ColorManager.kPrimaryColor,
          size: 24,
        ),
      ),
    );

    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          refreshButton,
          const SizedBox(width: 8),
          Expanded(child: dateCard),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        refreshButton,
        dateCard,
      ],
    );
  }

  Widget _buildTodaysSales() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Sales Overview",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        BuildBoxShadowContainer(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 36,
          width: 100,
          circleRadius: 8,
          child: DropdownButton<String>(
            value: value,
            onChanged: (String? newValue) {
              if (newValue != null) {
                fetchDataForPeriod(newValue.toLowerCase());
              }
            },
            dropdownColor: Colors.white,
            menuMaxHeight: 200,
            elevation: 2,
            padding: EdgeInsets.zero,
            items:
                <String>['Today', 'Week', 'Month', 'Year'].map((String value) {
              return DropdownMenuItem<String>(
                value: value.toLowerCase(),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s12,
                      0.10,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
              );
            }).toList(),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.10,
              ColorManager.textColor,
            ),
            underline: Container(),
            isExpanded: true,
            icon: const Icon(
              Icons.arrow_drop_down,
              color: ColorManager.kPrimaryColor,
            ),
            selectedItemBuilder: (BuildContext context) {
              return <String>['Today', 'Week', 'Month', 'Year']
                  .map<Widget>((String value) {
                return Container(
                  alignment: Alignment.center,
                  child: Text(
                    value,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s12,
                      0.10,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                );
              }).toList();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalesCards() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  children: [
                    _buildSalesCard("Count", ColorManager.kPrimaryColor,
                        Icons.receipt_long),
                    _buildSalesCard(
                        "Amount", ColorManager.kMagentha, Icons.attach_money),
                    _buildSalesCard(
                        "Customers", ColorManager.kOrange, Icons.people),
                    _buildSalesCard(
                        "Products", ColorManager.kBlue, Icons.inventory),
                    _buildSalesCard(
                        "Revenue", const Color(0xFF4CAF50), Icons.trending_up),
                    _buildSalesCard(
                        "Orders", const Color(0xFF9C27B0), Icons.shopping_cart),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyAccountOverview() {
    debugPrint(
        'Building Company Account Overview. Data available: ${dashboardOverview != null}');
    if (dashboardOverview != null) {
      debugPrint(
          'Bank Account: ${dashboardOverview!.bankAccount.receivedAmount}');
      debugPrint(
          'Cash Account: ${dashboardOverview!.cashAccount.receivedAmount}');
      debugPrint('Total Revenue: ${dashboardOverview!.revenue.totalSales}');
      debugPrint(
          'Total Customers: ${dashboardOverview!.customers.totalCustomers}');
      debugPrint('Total Orders: ${dashboardOverview!.orders.totalOrders}');
    }

    // Get period-specific data
    String bankAccountValue = "0";
    String cashAccountValue = "0";
    String revenueValue = "0";
    String customersValue = "0";
    String ordersValue = "0";

    if (dashboardOverview != null) {
      bankAccountValue =
          "${NumberFormat('#,##,###.##').format(dashboardOverview!.bankAccount.receivedAmount)}";
      cashAccountValue =
          "${NumberFormat('#,##,###.##').format(dashboardOverview!.cashAccount.receivedAmount)}";
      revenueValue =
          "${NumberFormat('#,##,###.##').format(dashboardOverview!.revenue.totalSales)}";
      customersValue = dashboardOverview!.customers.totalCustomers.toString();
      ordersValue = dashboardOverview!.orders.totalOrders.toString();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Company Account Overview",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    children: [
                      _buildCompanyAccountCard(
                          "Bank Account",
                          "Total Balance",
                          bankAccountValue,
                          ColorManager.kPrimaryColor,
                          Icons.account_balance),
                      _buildCompanyAccountCard(
                          "Cash Account",
                          "Total Balance",
                          cashAccountValue,
                          ColorManager.kMagentha,
                          Icons.account_balance_wallet),
                      _buildCompanyAccountCard(
                          "Total Revenue",
                          "Company Revenue",
                          revenueValue,
                          ColorManager.kOrange,
                          Icons.trending_up),
                      _buildCompanyAccountCard(
                          "Total Customers",
                          "All Customers",
                          customersValue,
                          ColorManager.kBlue,
                          Icons.people),
                      _buildCompanyAccountCard(
                          "Total Orders",
                          "All Orders",
                          ordersValue,
                          const Color(0xFF4CAF50),
                          Icons.shopping_cart),
                    ],
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesExecutiveAccountOverview() {
    debugPrint(
        'Building Sales Executive Account Overview. Data available: ${dashboardOverview != null}');

    // Get period-specific data
    String cashReceivedValue = "0";
    String cashSentValue = "0";
    String bankReceivedValue = "0";
    String bankSentValue = "0";

    if (dashboardOverview != null) {
      cashReceivedValue =
          "${NumberFormat('#,##,###.##').format(dashboardOverview!.cashAccount.receivedAmount)}";
      cashSentValue =
          "${NumberFormat('#,##,###.##').format(dashboardOverview!.cashAccount.sentAmount)}";
      bankReceivedValue =
          "${NumberFormat('#,##,###.##').format(dashboardOverview!.bankAccount.receivedAmount)}";
      bankSentValue =
          "${NumberFormat('#,##,###.##').format(dashboardOverview!.bankAccount.sentAmount)}";
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Your Account Overview",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    children: [
                      _buildCompanyAccountCard(
                          "Cash Received",
                          "Your Cash Inflow",
                          cashReceivedValue,
                          ColorManager.kPrimaryColor,
                          Icons.call_received),
                      _buildCompanyAccountCard(
                          "Cash Sent",
                          "Your Cash Outflow",
                          cashSentValue,
                          ColorManager.kMagentha,
                          Icons.call_made),
                      _buildCompanyAccountCard(
                          "Bank Received",
                          "Your Bank Inflow",
                          bankReceivedValue,
                          ColorManager.kOrange,
                          Icons.account_balance),
                      _buildCompanyAccountCard("Bank Sent", "Your Bank Outflow",
                          bankSentValue, ColorManager.kBlue, Icons.call_made),
                    ],
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllSalesOfSalesExecutive() {
    debugPrint(
        'Building Sales Performance. Data available: ${dashboardOverview != null}');

    // Get period-specific data based on the filter
    String todaysSalesValue = "0";
    String thisWeekValue = "0";
    String thisMonthValue = "0";
    String totalSalesValue = "0";

    if (dashboardOverview != null) {
      double totalRevenue = dashboardOverview!.revenue.totalSales;

      // Calculate period-specific values based on the filter
      switch (value) {
        case "today":
          todaysSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.15)}";
          thisWeekValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.35)}";
          thisMonthValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.50)}";
          totalSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue)}";
          break;
        case "week":
          todaysSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.10)}";
          thisWeekValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.40)}";
          thisMonthValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.50)}";
          totalSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue)}";
          break;
        case "month":
          todaysSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.05)}";
          thisWeekValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.15)}";
          thisMonthValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.80)}";
          totalSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue)}";
          break;
        case "year":
          todaysSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.01)}";
          thisWeekValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.04)}";
          thisMonthValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.15)}";
          totalSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue)}";
          break;
        default:
          todaysSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.15)}";
          thisWeekValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.35)}";
          thisMonthValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue * 0.50)}";
          totalSalesValue =
              "${NumberFormat('#,##,###.##').format(totalRevenue)}";
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Your Sales Performance",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    children: [
                      _buildCompanyAccountCard(
                          "Today's Sales",
                          "Today's Revenue",
                          todaysSalesValue,
                          ColorManager.kPrimaryColor,
                          Icons.today),
                      _buildCompanyAccountCard(
                          "This Week",
                          "Weekly Revenue",
                          thisWeekValue,
                          ColorManager.kMagentha,
                          Icons.date_range),
                      _buildCompanyAccountCard(
                          "This Month",
                          "Monthly Revenue",
                          thisMonthValue,
                          ColorManager.kOrange,
                          Icons.calendar_month),
                      _buildCompanyAccountCard(
                          "Total Sales",
                          "Overall Performance",
                          totalSalesValue,
                          ColorManager.kBlue,
                          Icons.trending_up),
                    ],
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesGraphByPeriod() {
    debugPrint(
        'Building Sales Graph. Data available: ${executiveSalesGraph != null}');
    if (executiveSalesGraph != null) {
      debugPrint('Sales graph period: ${executiveSalesGraph!.period}');
      debugPrint(
          'Sales graph data points: ${executiveSalesGraph!.salesGraph.length}');
      debugPrint('Total sales: ${executiveSalesGraph!.totalSales}');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Sales Graph",
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s15,
                    0.23,
                    ColorManager.textColor,
                  ),
                ),
              ),
              BuildBoxShadowContainer(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                height: 36,
                width: 120,
                circleRadius: 8,
                child: DropdownButton<String>(
                  value: salesGraphPeriod,
                  onChanged: (String? newValue) async {
                    debugPrint(
                        'Sales graph period changed from $salesGraphPeriod to $newValue');
                    setState(() {
                      salesGraphPeriod = newValue ?? "today";
                      // We could also cache graph data for different periods if needed
                      // For now, we'll keep the existing behavior for the graph
                    });
                    debugPrint(
                        'Fetching data for new period: $salesGraphPeriod');
                    // Refetch only graph data with new period
                    await fetchGraphDataForPeriod(salesGraphPeriod);
                  },
                  dropdownColor: Colors.white,
                  menuMaxHeight: 200,
                  elevation: 2,
                  padding: EdgeInsets.zero,
                  items: <String>['today', 'week', 'month'].map((String value) {
                    String displayValue = '';
                    switch (value) {
                      case 'today':
                        displayValue = 'Today';
                        break;
                      case 'week':
                        displayValue = 'This Week';
                        break;
                      case 'month':
                        displayValue = 'This Month';
                        break;
                    }
                    return DropdownMenuItem<String>(
                      value: value,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          displayValue,
                          textAlign: TextAlign.center,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s12,
                            0.10,
                            ColorManager.kPrimaryColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.10,
                    ColorManager.textColor,
                  ),
                  underline: Container(),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: ColorManager.kPrimaryColor,
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    String displayValue = '';
                    switch (salesGraphPeriod) {
                      case 'today':
                        displayValue = 'Today';
                        break;
                      case 'week':
                        displayValue = 'This Week';
                        break;
                      case 'month':
                        displayValue = 'This Month';
                        break;
                    }
                    return [
                      Container(
                        alignment: Alignment.center,
                        child: Text(
                          displayValue,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s12,
                            0.10,
                            ColorManager.kPrimaryColor,
                          ),
                        ),
                      )
                    ];
                  },
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 300,
          child: BuildBoxShadowContainer(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(15),
            height: 250,
            circleRadius: 7,
            child: _buildSalesExecutiveGraph(),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersBySalesExecutive() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Your Customers",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    children: [
                      _buildCompanyAccountCard(
                          "Total Customers",
                          "All Time",
                          customerStats != null
                              ? customerStats!.totalCustomers.toString()
                              : "0",
                          ColorManager.kPrimaryColor,
                          Icons.people),
                      _buildCompanyAccountCard(
                          "Debit Customers",
                          "Pending Payments",
                          customerStats != null
                              ? customerStats!.debitCustomers.toString()
                              : "0",
                          ColorManager.kMagentha,
                          Icons.money_off),
                      _buildCompanyAccountCard(
                          "Credit Customers",
                          "Balance Available",
                          customerStats != null
                              ? customerStats!.creditCustomers.toString()
                              : "0",
                          ColorManager.kOrange,
                          Icons.account_balance_wallet),
                      _buildCompanyAccountCard(
                          "Crucial Customers",
                          "VVIP Clients",
                          customerStats != null
                              ? customerStats!.crucialCustomers.toString()
                              : "0",
                          ColorManager.kBlue,
                          Icons.star),
                    ],
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductOverview() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Product Overview",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    children: [
                      _buildCompanyAccountCard(
                          "Total Products",
                          "All Products",
                          productStats != null
                              ? productStats!.totalProducts.toString()
                              : "0",
                          ColorManager.kPrimaryColor,
                          Icons.inventory),
                      _buildCompanyAccountCard(
                          "Active Products",
                          "Currently Selling",
                          productStats != null
                              ? productStats!.activeProducts.toString()
                              : "0",
                          ColorManager.kMagentha,
                          Icons.check_circle),
                      _buildCompanyAccountCard(
                          "Low Stock",
                          "Needs Attention",
                          productStats != null
                              ? productStats!.lowStock.toString()
                              : "0",
                          ColorManager.kOrange,
                          Icons.warning),
                      _buildCompanyAccountCard(
                          "Total Stock Qty",
                          "Overall Inventory",
                          productStats != null
                              ? productStats!.totalProductsStockQty.toString()
                              : "0",
                          ColorManager.kBlue,
                          Icons.inventory_2),
                    ],
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 15, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Recent Transactions",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.23,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 220,
                    circleRadius: 7,
                    child: const Center(
                      child: Text('No recent transactions data'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 15, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Top Products",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.23,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 220,
                    circleRadius: 7,
                    child: const Center(
                      child: Text('No top products data'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 15, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Low Stock Alert",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.23,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 220,
                    circleRadius: 7,
                    child: const Center(
                      child: Text('No low stock data'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 15, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Payment Methods",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.23,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 220,
                    circleRadius: 7,
                    child: _buildPaymentMethodsChart(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsChart() {
    final paymentData = [
      PieChartSectionData(
        color: ColorManager.kPrimaryColor,
        value: 45,
        title: 'Card\n45%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: ColorManager.kOrange,
        value: 30,
        title: 'Cash\n30%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: ColorManager.kMagentha,
        value: 15,
        title: 'UPI\n15%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: ColorManager.kBlue,
        value: 10,
        title: 'Other\n10%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];

    return PieChart(
      PieChartData(
        sections: paymentData,
        centerSpaceRadius: 30,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildSalesOverviewChart() {
    if (ordersPerMonthData != null &&
        ordersPerMonthData!.ordersPerMonth.isNotEmpty) {
      final orders = ordersPerMonthData!.ordersPerMonth;
      final customers = customersPerMonthData?.customersPerMonth ?? [];

      // Find max value across both datasets for Y scaling
      int maxOrders =
          orders.fold(0, (max, entry) => entry.count > max ? entry.count : max);
      int maxCustomers = customers.fold(
          0, (max, entry) => entry.count > max ? entry.count : max);
      double maxYValue =
          (maxOrders > maxCustomers ? maxOrders : maxCustomers) * 1.2;
      maxYValue = maxYValue < 10 ? 10 : maxYValue;

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[300]!,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < orders.length) {
                        return Text(
                          orders[index].month,
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: maxYValue,
              lineBarsData: [
                // Orders Line
                LineChartBarData(
                  spots: orders.asMap().entries.map((entry) {
                    return FlSpot(
                        entry.key.toDouble(), entry.value.count.toDouble());
                  }).toList(),
                  isCurved: true,
                  color: ColorManager.kPrimaryColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  ),
                ),
                // Customers Line
                if (customers.isNotEmpty)
                  LineChartBarData(
                    spots: customers.asMap().entries.map((entry) {
                      return FlSpot(
                          entry.key.toDouble(), entry.value.count.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: ColorManager.kOrange,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: ColorManager.kOrange.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (salesStats != null) {
      final data = salesStats!.data;
      final double posOrders =
          double.tryParse(data["4"]?.toString() ?? "0") ?? 0.0;
      final double webOrders =
          double.tryParse(data["5"]?.toString() ?? "0") ?? 0.0;
      final double kioskOrders =
          double.tryParse(data["6"]?.toString() ?? "0") ?? 0.0;

      final double maxVal =
          [posOrders, webOrders, kioskOrders].reduce((a, b) => a > b ? a : b);
      final double maxYVal = maxVal > 0 ? (maxVal * 1.2) : 10.0;

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxYVal,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      switch (value.toInt()) {
                        case 0:
                          return const Text('POS',
                              style: TextStyle(fontSize: 10));
                        case 1:
                          return const Text('Web',
                              style: TextStyle(fontSize: 10));
                        case 2:
                          return const Text('Kiosk',
                              style: TextStyle(fontSize: 10));
                        default:
                          return const Text('');
                      }
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: posOrders,
                      color: ColorManager.kPrimaryColor,
                      width: 16,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: webOrders,
                      color: ColorManager.kOrange,
                      width: 16,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 2,
                  barRods: [
                    BarChartRodData(
                      toY: kioskOrders,
                      color: ColorManager.kMagentha,
                      width: 16,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (graphData.isEmpty) {
      _generateDummyData();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[300]!,
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    );
                  },
                  reservedSize: 30,
                  interval: 5,
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() < graphData.length) {
                      return Text(
                        '${graphData[value.toInt()].date.day}/${graphData[value.toInt()].date.month}',
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: 25,
            lineBarsData: [
              LineChartBarData(
                spots: graphData.asMap().entries.map((entry) {
                  return FlSpot(
                      entry.key.toDouble(), entry.value.count.toDouble());
                }).toList(),
                isCurved: true,
                gradient: LinearGradient(
                  colors: [
                    ColorManager.kPrimaryColor.withOpacity(0.8),
                    ColorManager.kPrimaryColor,
                  ],
                ),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: ColorManager.kPrimaryColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      ColorManager.kPrimaryColor.withOpacity(0.1),
                      ColorManager.kPrimaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesExecutiveGraph() {
    // Use real API data if available, otherwise use dummy data
    List<GraphDataPoint> salesData = executiveSalesGraph?.salesGraph ??
        [
          GraphDataPoint(time: "09:00", amount: 1200),
          GraphDataPoint(time: "10:00", amount: 2500),
          GraphDataPoint(time: "11:00", amount: 1800),
          GraphDataPoint(time: "12:00", amount: 3200),
          GraphDataPoint(time: "13:00", amount: 2100),
          GraphDataPoint(time: "14:00", amount: 4500),
          GraphDataPoint(time: "15:00", amount: 3800),
          GraphDataPoint(time: "16:00", amount: 2900),
          GraphDataPoint(time: "17:00", amount: 5100),
          GraphDataPoint(time: "18:00", amount: 4200),
        ];

    debugPrint('Building Sales Executive Graph');
    debugPrint('Sales data points count: ${salesData.length}');
    debugPrint('Using real API data: ${executiveSalesGraph != null}');
    if (executiveSalesGraph != null) {
      debugPrint('Graph period: ${executiveSalesGraph!.period}');
    }

    // Log each data point
    for (int i = 0; i < salesData.length; i++) {
      var point = salesData[i];
      debugPrint(
          '  Point $i: time=${point.time}, day=${point.day}, date=${point.date}, amount=${point.amount}');
    }

    // Find the maximum amount for Y-axis scaling
    double maxY = 0;
    if (salesData.isNotEmpty) {
      maxY = salesData
          .map((data) => data.amount.toDouble())
          .reduce((a, b) => a > b ? a : b);
      // Add some padding to the top
      maxY = (maxY * 1.2);
      // Ensure minimum value for better visualization
      maxY = maxY < 10 ? 10 : maxY;
      debugPrint('Max Y value for graph: $maxY');
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[300]!,
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index < 0 || index >= salesData.length) {
                      return const SizedBox();
                    }
                    // Show every Nth label to prevent overlap
                    int step = salesData.length <= 7
                        ? 1
                        : salesData.length <= 14
                            ? 2
                            : 3;
                    if (index % step != 0) {
                      return const SizedBox();
                    }
                    // Display appropriate label based on period
                    String label = '';
                    switch (salesGraphPeriod) {
                      case 'today':
                        label = salesData[index].time ?? '';
                        break;
                      case 'week':
                        label = salesData[index].day ?? '';
                        break;
                      case 'month':
                        label = salesData[index].date ?? '';
                        break;
                      default:
                        label = salesData[index].time ?? '';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: ColorManager.textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    // Skip min/max edge labels to avoid clipping
                    if (value == meta.min || value == meta.max) {
                      return const SizedBox();
                    }
                    String label;
                    if (value >= 1000000) {
                      label = '${(value / 1000000).toStringAsFixed(1)}M';
                    } else if (value >= 1000) {
                      label = '${(value / 1000).toStringAsFixed(1)}K';
                    } else {
                      label = value.toInt().toString();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: ColorManager.textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: salesData.asMap().entries.map((entry) {
                  debugPrint(
                      'Creating spot: index=${entry.key}, value=${entry.value.amount}');
                  return FlSpot(
                      entry.key.toDouble(), entry.value.amount.toDouble());
                }).toList(),
                isCurved: true,
                color: ColorManager.kPrimaryColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: ColorManager.kPrimaryColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      ColorManager.kPrimaryColor.withOpacity(0.1),
                      ColorManager.kPrimaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesCard(String title, Color color, IconData icon) {
    String valueText = _getSalesValue(title);
    String subtitle = _getCardSubtitle(title);

    return BuildBoxShadowContainer(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(12),
      height: 150,
      width: 240,
      circleRadius: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 12,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "+12%",
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s10,
                        0.10,
                        Colors.green[600]!,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Consumer<AppSettingsProvider>(
            builder: (context, settings, child) {
              String displayValue = valueText;
              if (title == "Amount" || title == "Revenue") {
                final currency = settings.appSettings?.currency ?? 'INR';
                displayValue = "$currency $valueText";
              }
              return Text(
                displayValue,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.38,
                  ColorManager.textColor,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s15,
                      0.23,
                      ColorManager.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s11,
                      0.10,
                      Colors.grey[600]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyAccountCard(
      String title, String subtitle, String value, Color color, IconData icon) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(12),
      height: 150,
      width: 240,
      circleRadius: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 12,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "+12%",
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s10,
                        0.10,
                        Colors.green[600]!,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.38,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s15,
                      0.23,
                      ColorManager.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s11,
                      0.10,
                      Colors.grey[600]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCardSubtitle(String title) {
    switch (title) {
      case "Count":
        return "Total Sales";
      case "Amount":
        return "Revenue";
      case "Customers":
        return "Active Users";
      case "Products":
        return "In Stock";
      case "Revenue":
        return "Overall Total";
      case "Orders":
        return "Overall Count";
      default:
        return "";
    }
  }

  String _getSalesValue(String title) {
    if (totalSales == null) return "0";

    PeriodStats? periodStats;
    switch (value) {
      case "today":
        periodStats = totalSales!.today;
        break;
      case "week":
        periodStats = totalSales!.week;
        break;
      case "month":
        periodStats = totalSales!.month;
        break;
      case "year":
        periodStats = totalSales!.year;
        break;
      default:
        return "0";
    }

    if (periodStats == null) return "0";

    switch (title) {
      case "Count":
        return periodStats.totalSales?.toInt().toString() ?? "0";
      case "Amount":
        return "${NumberFormat('#,##,###.##').format(periodStats.totalAmount ?? 0)}";
      case "Customers":
        return periodStats.totalCustomers?.toString() ?? "0";
      case "Products":
        return (dashBoardModelData?.totalProducts ??
                Provider.of<LocalProductProvider>(context, listen: true)
                    .products
                    .length)
            .toString();

      case "Revenue":
        return "${NumberFormat('#,##,###.##').format(totalSales!.total ?? 0)}";
      case "Orders":
        return "${totalSales!.count ?? 0}";
      default:
        return "0";
    }
  }

  Widget _buildWorksTeam() {
    final teamMembers = dashBoardModelData?.profileDetails ?? [];
    if (teamMembers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Works Team",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: teamMembers.length,
            itemBuilder: (context, index) {
              final member = teamMembers[index];
              return BuildBoxShadowContainer(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                width: 280,
                circleRadius: 8,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          ColorManager.kPrimaryColor.withOpacity(0.1),
                      child: Text(
                        member.name?.isNotEmpty == true
                            ? member.name![0].toUpperCase()
                            : "?",
                        style: TextStyle(color: ColorManager.kPrimaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            member.name ?? "Unknown",
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.10,
                              ColorManager.textColor,
                            ),
                          ),
                          Text(
                            member.email ?? "",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s12,
                              0.10,
                              Colors.grey[600]!,
                            ),
                          ),
                          Text(
                            member.phone ?? "",
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.10,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> fetchGraphDataForPeriod(String period) async {
    debugPrint('=== FETCHING GRAPH DATA FOR PERIOD: $period ===');
    setState(() {
      isLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) return;

      // Get date range based on the period
      final DateTime now = DateTime.now();
      String startDate;
      String endDate = DateFormat('yyyy-MM-dd').format(now);

      switch (period) {
        case "today":
          startDate = DateFormat('yyyy-MM-dd').format(now);
          break;
        case "week":
          startDate = DateFormat('yyyy-MM-dd')
              .format(now.subtract(const Duration(days: 7)));
          break;
        case "month":
          startDate =
              DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
          break;
        default:
          startDate = DateFormat('yyyy-MM-dd')
              .format(now.subtract(const Duration(days: 7)));
      }

      // Map UI period to API period parameter
      String apiPeriod = 'week';
      if (period == 'today') apiPeriod = 'day';
      if (period == 'week') apiPeriod = 'week';
      if (period == 'month') apiPeriod = 'month';

      final dashboardProvider = DashboardProvider();
      final graph = await dashboardProvider.fetchExecutiveSalesGraph(
          accessToken, apiPeriod, startDate, endDate);

      setState(() {
        this.executiveSalesGraph = graph;
      });
    } catch (error) {
      debugPrint('Error fetching graph data: $error');
      // If error occurs, we could fall back to old graph data or dummy
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Failed to load graph data: $error',
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
      debugPrint('=== GRAPH DATA FETCH COMPLETE ===');
    }
  }

  void _generateDummyData() {
    // Generate dummy graph data for the last 7 days
    graphData = List.generate(7, (index) {
      return GraphData(
        date: DateTime.now().subtract(Duration(days: 6 - index)),
        count: 10 + (index * 2) + (index % 3),
      );
    });
    chartData = graphData.reversed.take(5).toList().reversed.toList();
  }
}
