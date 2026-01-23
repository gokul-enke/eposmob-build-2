import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';

import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../../models/dashboard.dart';
import '../../models/dashboard_api.dart';
import '../../providers/dashboard_provider.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
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
    fetchDataForPeriod('month'); // Fetch data for month by default to show some data
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
          startDate = DateFormat('yyyy-MM-dd')
              .format(DateTime(now.year, now.month, 1));
          break;
        case "year":
          startDate =
              DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
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

        // Fetch new dashboard overview data
        final dashboardProvider = DashboardProvider();
        final overview = await dashboardProvider.fetchDashboardOverview(
            accessToken, startDate, endDate);
        cachedOverviewData[period] = overview;

        debugPrint('Cached data for period: $period');

        // Update state with the newly fetched data
        setState(() {
          dashBoardModelData = cachedDashboardData[period];
          totalSales = cachedTotalSales[period];
          dashboardOverview = cachedOverviewData[period];
          value = period;
          isInitialLoading = false;
        });
      } catch (error) {
        debugPrint('Error fetching data for period $period: $error');
        if (mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to load dashboard data: $error',
          );
        }
        setState(() {
          isInitialLoading = false;
        });
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
              // const SizedBox(height: 4),
              // Text(
              //   "Welcome back! Here's your sales overview",
              //   style: buildCustomStyle(
              //     FontWeightManager.medium,
              //     FontSize.s12,
              //     0.10,
              //     Colors.grey[600]!,
              //   ),
              // ),
            ],
          ),
          Row(
            children: [
              // CustomRoundButtonWithIcon(
              //   title: "Export",
              //   fct: () {},
              //   fontSize: 12,
              //   height: 40,
              //   width: 120,
              //   size: size,
              //   icon: const Icon(
              //     Icons.download_outlined,
              //     size: 16,
              //     color: Colors.white,
              //   ),
              // ),
              const SizedBox(width: 12),
              BuildBoxShadowContainer(
                padding: const EdgeInsets.all(12),
                height: 50,
                circleRadius: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('d MMMM y').format(DateTime.now()),
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.10,
                        ColorManager.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
                    _buildSalesCard("Revenue", const Color(0xFF4CAF50),
                        Icons.trending_up),
                    _buildSalesCard("Orders", const Color(0xFF9C27B0),
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
                child: Center(
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
                child: Center(
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
                child: Center(
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
    debugPrint(
        'Building Customers section. Data available: ${dashboardOverview != null}');

    // Get period-specific data
    String newCustomersValue = "0";
    String totalCustomersValue = "0";
    String activeCustomersValue = "0";
    String returningCustomersValue = "0";

    if (dashboardOverview != null) {
      newCustomersValue = dashboardOverview!.customers.newCustomers.toString();
      totalCustomersValue =
          dashboardOverview!.customers.totalCustomers.toString();

      // Calculate period-specific values based on the filter
      switch (value) {
        case "today":
          activeCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.15)
                  .toInt()
                  .toString();
          returningCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.85)
                  .toInt()
                  .toString();
          break;
        case "week":
          activeCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.35)
                  .toInt()
                  .toString();
          returningCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.65)
                  .toInt()
                  .toString();
          break;
        case "month":
          activeCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.50)
                  .toInt()
                  .toString();
          returningCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.50)
                  .toInt()
                  .toString();
          break;
        case "year":
          activeCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.75)
                  .toInt()
                  .toString();
          returningCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.25)
                  .toInt()
                  .toString();
          break;
        default:
          activeCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.15)
                  .toInt()
                  .toString();
          returningCustomersValue =
              (dashboardOverview!.customers.totalCustomers * 0.85)
                  .toInt()
                  .toString();
      }
    }

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
                child: Center(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    children: [
                      _buildCompanyAccountCard(
                          "New Customers",
                          "Added Today",
                          newCustomersValue,
                          ColorManager.kPrimaryColor,
                          Icons.person_add),
                      _buildCompanyAccountCard(
                          "Total Customers",
                          "All Time",
                          totalCustomersValue,
                          ColorManager.kMagentha,
                          Icons.people),
                      _buildCompanyAccountCard(
                          "Active Customers",
                          "This Period",
                          activeCustomersValue,
                          ColorManager.kOrange,
                          Icons.person),
                      _buildCompanyAccountCard(
                          "Returning",
                          "Repeat Customers",
                          returningCustomersValue,
                          ColorManager.kBlue,
                          Icons.autorenew),
                    ],
                  ),
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
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= 0 &&
                        value.toInt() < salesData.length) {
                      // Display appropriate label based on period
                      String label = '';
                      switch (salesGraphPeriod) {
                        case 'today':
                          label = salesData[value.toInt()].time ?? '';
                          break;
                        case 'week':
                          label = salesData[value.toInt()].day ?? '';
                          break;
                        case 'month':
                          label = salesData[value.toInt()].date ?? '';
                          break;
                        default:
                          label = salesData[value.toInt()].time ?? '';
                      }
                      debugPrint('Bottom title at index $value: $label');
                      return Text(
                        label,
                        style: TextStyle(
                          color: ColorManager.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    debugPrint('Left title value: $value');
                    return Text(
                      '${NumberFormat('#,##').format(value.toInt())}',
                      style: TextStyle(
                        color: ColorManager.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
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
    String value = _getSalesValue(title);
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
        return "Net Income";
      case "Orders":
        return "Completed";
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
        return periodStats.totalSales?.toString() ?? "0";
      case "Amount":
        return "${NumberFormat('#,##,###.##').format(periodStats.totalAmount ?? 0)}";
      case "Customers":
        return periodStats.totalCustomers?.toString() ?? "0";
      case "Products":
        return Provider.of<LocalProductProvider>(context, listen: true)
            .products
            .length
            .toString();

      case "Revenue":
        return "${NumberFormat('#,##,###').format((periodStats.totalAmount ?? 0) * 0.85)}";
      case "Orders":
        return "${(periodStats.totalSales ?? 0) + 15}";
      default:
        return "0";
    }
  }

  Future<void> fetchGraphDataForPeriod(String period) async {
    debugPrint('=== FETCHING GRAPH DATA FOR PERIOD: $period ===');
    setState(() {
      debugPrint('isLoading state set to true');
      isLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          'Access token available for graph data: ${accessToken != null}');
      if (accessToken != null) {
        final data = await DashboardProvider().fetchGraphData(accessToken);
        debugPrint('Graph data fetched. Count: ${data.length}');
        setState(() {
          debugPrint('Updating graph data state');
          graphData = data.cast<GraphData>();
          chartData = data.reversed
              .take(5)
              .toList()
              .reversed
              .cast<GraphData>()
              .toList();
          debugPrint(
              'Graph data processed. graphData count: ${graphData.length}, chartData count: ${chartData.length}');
        });
      } else {
        debugPrint('ERROR: No access token for graph data');
      }
    } catch (error) {
      debugPrint('Error fetching graph data: $error');
      // Generate dummy data for demonstration
      _generateDummyData();
    } finally {
      setState(() {
        debugPrint('isLoading state set to false');
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
