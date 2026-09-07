import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import '../../providers/app_settings_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/dashboard_responsive.dart';
import 'widgets/zatca_failed_alert.dart';

class CompanyAdminDashboard extends StatefulWidget {
  const CompanyAdminDashboard({super.key});

  @override
  State<CompanyAdminDashboard> createState() => _CompanyAdminDashboardState();
}

class _CompanyAdminDashboardState extends State<CompanyAdminDashboard> {
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

  // Dummy data for demonstration
  final List<String> recentTransactions = [
    "Transaction #12345 - 2,450.00",
    "Transaction #12346 - 1,200.50",
    "Transaction #12347 - 890.75",
    "Transaction #12348 - 3,100.00",
    "Transaction #12349 - 567.25",
  ];

  final List<Map<String, dynamic>> topProducts = [
    {"name": "Smartphone", "sales": 245, "revenue": "2,45,000"},
    {"name": "Laptop", "sales": 123, "revenue": "6,15,000"},
    {"name": "Headphones", "sales": 567, "revenue": "1,13,400"},
    {"name": "Tablet", "sales": 89, "revenue": "2,67,000"},
  ];

  final List<Map<String, dynamic>> lowStockItems = [
    {"name": "iPhone 13", "stock": 5, "status": "Critical"},
    {"name": "MacBook Pro", "stock": 12, "status": "Low"},
    {"name": "AirPods", "stock": 8, "status": "Critical"},
    {"name": "iPad", "stock": 15, "status": "Low"},
  ];

  @override
  void initState() {
    super.initState();
    getDashBoardDetails();
    fetchGraphData();
    fetchNewDashboardData(); // Added to fetch new API data
  }

  Future<void> fetchNewDashboardData() async {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) return;

      // Get current date for API calls
      final DateTime now = DateTime.now();
      final String startDate = DateFormat('yyyy-MM-dd')
          .format(now.subtract(const Duration(days: 30)));
      final String endDate = DateFormat('yyyy-MM-dd').format(now);
      final int currentYear = now.year;

      // Fetch all dashboard data
      final dashboardProvider = DashboardProvider();

      // Variables to store fetched data
      DashboardOverview? overview;
      OrdersPerMonth? ordersPerMonth;
      CustomersPerMonth? customersPerMonth;
      ExecutivesOverview? executives;
      SalesGraph? executiveSalesGraph;
      SalesStats? stats;
      CustomerStats? customerStats;
      ProductStats? productStats;

      // Try fetching each endpoint individually so one failure doesn't stop the whole load
      // Note: We are using the main dashboard API for the core overview data.

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
        executives = await dashboardProvider.fetchExecutivesOverview(
            accessToken, startDate, endDate);
      } catch (e) {
        debugPrint('Executives overview failed: $e');
      }

      try {
        executiveSalesGraph = await dashboardProvider.fetchExecutiveSalesGraph(
            accessToken, 'week', startDate, endDate);
      } catch (e) {
        debugPrint('Executive sales graph failed: $e');
      }

      try {
        stats = await dashboardProvider.fetchSalesStats(accessToken);
      } catch (e) {
        debugPrint('Sales stats failed: $e');
      }

      try {
        customerStats = await dashboardProvider.fetchCustomerStats(
            accessToken, 'today', startDate, endDate);
      } catch (e) {
        debugPrint('Customer stats failed: $e');
      }

      try {
        productStats = await dashboardProvider.fetchProductStats(accessToken);
      } catch (e) {
        debugPrint('Product stats failed: $e');
      }

      // Update state with whatever data we successfully fetched
      if (mounted) {
        setState(() {
          // Only set dummy data if no data has been successfully fetched from any endpoint
          if (dashBoardModelData == null &&
              salesStats == null &&
              dashboardOverview == null) {
            _setDummyDashboardData();
          }

          if (ordersPerMonth != null) ordersPerMonthData = ordersPerMonth;
          if (customersPerMonth != null)
            customersPerMonthData = customersPerMonth;
          if (executives != null) executivesOverview = executives;
          if (executiveSalesGraph != null)
            this.executiveSalesGraph = executiveSalesGraph;
          if (stats != null) this.salesStats = stats;
          if (customerStats != null) this.customerStats = customerStats;
          if (productStats != null) this.productStats = productStats;
        });
      }
    } catch (error) {
      // General safety catch
      debugPrint('Unexpected error in fetchNewDashboardData: $error');
    }
  }

  Future<void> fetchGraphDataForPeriod(String period) async {
    debugPrint('=== FETCHING GRAPH DATA FOR PERIOD: $period ===');
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
              .format(now.subtract(const Duration(days: 7))); // Default to week
      }

      // Map UI period to API period parameter
      String apiPeriod = 'week';
      if (period == 'today') apiPeriod = 'day';
      if (period == 'week') apiPeriod = 'week';
      if (period == 'month') apiPeriod = 'month';

      final dashboardProvider = DashboardProvider();
      final executiveSalesGraph = await dashboardProvider
          .fetchExecutiveSalesGraph(accessToken, apiPeriod, startDate, endDate);

      setState(() {
        this.executiveSalesGraph = executiveSalesGraph;
      });
    } catch (error) {
      debugPrint('Error fetching graph data: $error');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'general.failed_to_load_graph_data'
              .trParams({'error': error.toString()}),
        );
      }
    }
  }

  Future<void> fetchGraphData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken != null) {
        final data = await DashboardProvider().fetchGraphData(accessToken);
        setState(() {
          graphData = data.cast<GraphData>();
          chartData = data.reversed
              .take(5)
              .toList()
              .reversed
              .cast<GraphData>()
              .toList();
        });
      }
    } catch (error) {
      // Generate dummy data for demonstration
      _generateDummyData();
    } finally {
      setState(() {
        isLoading = false;
      });
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

  Future<void> getDashBoardDetails() async {
    try {
      setState(() {
        isInitLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null) {
        _setDummyDashboardData();
        return;
      }

      final response =
          await DashboardProvider().dashbaord(accessToken, context);

      if (response != null && response["status"] == "success") {
        setState(() {
          DashBoardModel dashBoardModel = DashBoardModel.fromJson(response);
          dashBoardModelData = dashBoardModel.data;
          totalSales = dashBoardModelData?.totalSales;
        });
      } else {
        _setDummyDashboardData();
      }
    } catch (error) {
      debugPrint('Error in getDashBoardDetails: $error');
      _setDummyDashboardData();
    } finally {
      if (mounted) {
        setState(() {
          isInitLoading = false;
        });
      }
    }
  }

  void _setDummyDashboardData() {
    // Create dummy data for demonstration
    setState(() {
      // 1. Dashboard Overview Dummy
      dashboardOverview = DashboardOverview(
        bankAccount:
            BankAccount(receivedAmount: 1250000.0, sentAmount: 450000.0),
        cashAccount: CashAccount(receivedAmount: 85400.0, sentAmount: 12000.0),
        products: ProductsData(
            total: 450, addedToday: 5, addedWeek: 23, addedMonth: 89),
        revenue: RevenueData(totalSales: 2450000.0),
        customers: CustomersData(newCustomers: 12, totalCustomers: 1250),
        orders: OrdersData(newOrders: 45, totalOrders: 5670),
      );

      // 2. Legacy Total Sales Dummy
      totalSales = TotalSales(
        today: PeriodStats(
            totalSales: 45, totalAmount: 12500.50, totalCustomers: 28),
        week: PeriodStats(
            totalSales: 234, totalAmount: 65780.25, totalCustomers: 156),
        month: PeriodStats(
            totalSales: 1045, totalAmount: 345600.75, totalCustomers: 678),
        year: PeriodStats(
            totalSales: 12450, totalAmount: 4567890.50, totalCustomers: 8234),
      );

      // 3. Orders per Month Dummy
      ordersPerMonthData = OrdersPerMonth(ordersPerMonth: [
        MonthlyData(month: 'Jan', count: 450),
        MonthlyData(month: 'Feb', count: 520),
        MonthlyData(month: 'Mar', count: 610),
        MonthlyData(month: 'Apr', count: 580),
      ]);

      // 4. Product Stats Dummy
      productStats = ProductStats(
        totalProducts: 450,
        activeProducts: 420,
        inactiveProducts: 30,
        sellableProducts: 400,
        purchasableProducts: 350,
        taxableProducts: 450,
        nonTaxableProducts: 0,
        totalCategory: 15,
        sellableCategory: 12,
        purchasableCategory: 10,
        taxableCategory: 15,
        nonTaxableCategory: 0,
        productsInStock: 380,
        totalProductsStockQty: 4500,
        lowStock: 12,
      );

      // 5. Customer Stats Dummy
      customerStats = CustomerStats(
        period: 'today',
        totalCustomers: 1250,
        debitCustomers: 45,
        creditCustomers: 120,
        crucialCustomers: 15,
      );

      // 6. Executive Sales Graph Dummy
      executiveSalesGraph = SalesGraph(
        period: 'week',
        salesGraph: List.generate(7, (index) {
          return GraphDataPoint(
            day: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index],
            amount: 1500 + (index * 200),
          );
        }),
        totalSales: 8500,
      );

      // 7. Executives Overview Dummy
      executivesOverview = ExecutivesOverview(
        totalExecutives: 5,
        salesExecutivesGraph: [
          SalesExecutiveGraph(
            executiveId: 1,
            executiveName: "John Doe",
            sales: [SalesData(date: "2024-03-01", amount: 1500)],
          ),
          SalesExecutiveGraph(
            executiveId: 2,
            executiveName: "Jane Smith",
            sales: [SalesData(date: "2024-03-01", amount: 2400)],
          ),
        ],
      );

      // 8. Sales Stats Dummy
      salesStats = SalesStats(
        data: {
          "total_sales": 5670,
          "total_amount": 2450000.0,
          "daily_average": 81666.0,
        },
        deliveryMethod: [
          {"method": "Pickup", "count": 2450},
          {"method": "Delivery", "count": 3220},
        ],
        payments: [
          {"method": "Cash", "amount": 1250000.0},
          {"method": "Card", "amount": 1000000.0},
          {"method": "Online", "amount": 200000.0},
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final double horizontalPadding = size.width < 600 ? 4.0 : 12.0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: isInitLoading
          ? SizedBox(
              width: size.width,
              height: size.height,
              child: const Center(child: CircularProgressIndicator.adaptive()))
          : SafeArea(
              child: SizedBox(
              width: size.width,
              height: size.height,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(size),
                    const SizedBox(height: 20),
                    const ZatcaFailedAlert(),
                    _buildTodaysSales(),
                    _buildSalesCards(),
                    const SizedBox(height: 20),
                    _buildCompanyAccountOverview(),
                    const SizedBox(height: 20),
                    _buildProductOverview(),
                    const SizedBox(height: 20),
                    _buildCustomerOverview(),
                    const SizedBox(height: 20),
                    _buildSalesExecutiveOverview(),
                    const SizedBox(height: 20),
                    _buildSalesOverview(),
                    const SizedBox(height: 20),
                    _buildWorksTeam(),
                    const SizedBox(height: 20),

                    // _buildAdditionalStats(),
                    // const SizedBox(height: 20),
                    // _buildQuickAccess(),
                    // const SizedBox(height: 20),
                  ],
                ),
              ),
            )),
    );
  }

  Widget _buildHeader(Size size) {
    final bool isCompact = size.width < 700;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'company_admin.title'.tr,
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
              ? 'company_admin.welcome_user'.trParams({'name': dashBoardModelData!.profileDetails![0].name ?? ''})
              : 'company_admin.welcome_back'.tr,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.10,
            Colors.grey[600]!,
          ),
        ),
      ],
    );

    final refreshButton = BuildBoxShadowContainer(
      padding: const EdgeInsets.all(8),
      circleRadius: 10,
      child: InkWell(
        onTap: () {
          getDashBoardDetails();
          fetchNewDashboardData();
          fetchGraphData();
        },
        borderRadius: BorderRadius.circular(10),
        child: const Icon(
          Icons.refresh_rounded,
          color: ColorManager.kPrimaryColor,
          size: 24,
        ),
      ),
    );

    final dateCard = BuildBoxShadowContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      circleRadius: 10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 18, color: ColorManager.textColor),
          const SizedBox(width: 10),
          Text(
            DateHelper.formatDate(DateHelper.now()),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.10,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                Row(
                  children: [
                    refreshButton,
                    const SizedBox(width: 10),
                    Expanded(child: dateCard),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                refreshButton,
                const SizedBox(width: 12),
                dateCard,
              ],
            ),
    );
  }

  Widget _buildTodaysSales() {
    return DashboardSectionHeader(
      title: 'company_admin.section_sales_overview'.tr,
      trailing: BuildBoxShadowContainer(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 38,
        width: 110,
        circleRadius: 10,
        child: DropdownButton<String>(
            value: value,
            onChanged: (String? newValue) {
              setState(() {
                value = newValue?.toLowerCase() ?? "today";
              });
              fetchGraphDataForPeriod(value);
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
                    'company_admin.period_${value.toLowerCase()}'.tr,
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
                    'company_admin.period_${value.toLowerCase()}'.tr,
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
    );
  }

  Widget _buildSalesCards() {
    return ResponsiveStatGrid(
      cards: [
        _buildSalesCard("Count", ColorManager.kPrimaryColor, Icons.receipt_long),
        _buildSalesCard("Amount", ColorManager.kMagentha, Icons.attach_money),
        _buildSalesCard("Customers", ColorManager.kOrange, Icons.people),
        _buildSalesCard("Products", ColorManager.kBlue, Icons.inventory),
        _buildSalesCard("Revenue", const Color(0xFF4CAF50), Icons.trending_up),
        _buildSalesCard("Orders", const Color(0xFF9C27B0), Icons.shopping_cart),
      ],
    );
  }

  Widget _buildCompanyAccountOverview() {
    return Column(
      children: [
        DashboardSectionHeader(title: 'company_admin.section_company_account_overview'.tr),
        ResponsiveStatGrid(
          cards: [
            _buildCompanyAccountCard(
                'company_admin.card_bank_accounts'.tr,
                'company_admin.card_bank_balance'.tr,
                dashboardOverview != null
                    ? "${NumberFormat('#,##,###.##').format(dashboardOverview!.bankAccount.receivedAmount)}"
                    : "0",
                ColorManager.kPrimaryColor,
                Icons.account_balance),
            _buildCompanyAccountCard(
                'company_admin.card_cash_accounts'.tr,
                'company_admin.card_cash_balance'.tr,
                dashboardOverview != null
                    ? "${NumberFormat('#,##,###.##').format(dashboardOverview!.cashAccount.receivedAmount)}"
                    : "0",
                ColorManager.kMagentha,
                Icons.account_balance_wallet),
            _buildCompanyAccountCard(
                'company_admin.card_total_revenue'.tr,
                'company_admin.card_overall_revenue'.tr,
                dashboardOverview != null
                    ? "${NumberFormat('#,##,###.##').format(dashboardOverview!.revenue.totalSales)}"
                    : "0",
                ColorManager.kOrange,
                Icons.trending_up),
            _buildCompanyAccountCard(
                'company_admin.card_total_customers'.tr,
                'company_admin.card_active_customers'.tr,
                dashboardOverview != null
                    ? dashboardOverview!.customers.totalCustomers.toString()
                    : "0",
                ColorManager.kBlue,
                Icons.people),
            _buildCompanyAccountCard(
                'company_admin.card_total_orders'.tr,
                'company_admin.card_completed_orders'.tr,
                dashboardOverview != null
                    ? dashboardOverview!.orders.totalOrders.toString()
                    : "0",
                const Color(0xFF4CAF50),
                Icons.shopping_cart),
          ],
        ),
      ],
    );
  }

  Widget _buildProductOverview() {
    return Column(
      children: [
        DashboardSectionHeader(title: 'company_admin.section_product_overview'.tr),
        ResponsiveStatGrid(
          cards: [
            _buildCompanyAccountCard(
                'company_admin.card_total_products'.tr,
                'company_admin.card_all_products'.tr,
                productStats != null
                    ? productStats!.totalProducts.toString()
                    : dashboardOverview != null
                        ? dashboardOverview!.products.total.toString()
                        : "0",
                ColorManager.kPrimaryColor,
                Icons.inventory),
            _buildCompanyAccountCard(
                'company_admin.card_active_products'.tr,
                'company_admin.card_currently_selling'.tr,
                productStats != null
                    ? productStats!.activeProducts.toString()
                    : "0",
                ColorManager.kMagentha,
                Icons.check_circle),
            _buildCompanyAccountCard(
                'company_admin.card_low_stock'.tr,
                'company_admin.card_needs_attention'.tr,
                productStats != null ? productStats!.lowStock.toString() : "0",
                ColorManager.kOrange,
                Icons.warning),
            _buildCompanyAccountCard(
                'company_admin.card_total_stock_qty'.tr,
                'company_admin.card_overall_inventory'.tr,
                productStats != null
                    ? productStats!.totalProductsStockQty.toString()
                    : "0",
                ColorManager.kBlue,
                Icons.inventory_2),
            _buildCompanyAccountCard(
                'company_admin.card_sellable_products'.tr,
                'company_admin.card_ready_for_sale'.tr,
                productStats != null
                    ? productStats!.sellableProducts.toString()
                    : "0",
                ColorManager.kGreen,
                Icons.sell),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesExecutiveOverview() {
    return Column(
      children: [
        DashboardSectionHeader(title: 'company_admin.section_exec_overview'.tr),
        ResponsiveStatGrid(
          cards: [
            _buildCompanyAccountCard(
                'company_admin.card_total_executives'.tr,
                'company_admin.card_sales_executives'.tr,
                executivesOverview != null
                    ? executivesOverview!.totalExecutives.toString()
                    : "0",
                ColorManager.kPrimaryColor,
                Icons.group),
            _buildCompanyAccountCard(
                'company_admin.card_total_sales'.tr,
                'company_admin.card_overall_performance'.tr,
                executivesOverview != null
                    ? "${NumberFormat('#,##,###').format(executivesOverview!.salesExecutivesGraph.fold(0, (sum, executive) => sum + executive.sales.fold(0, (saleSum, sale) => saleSum + sale.amount)))}"
                    : "0",
                ColorManager.kMagentha,
                Icons.check_circle),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesOverview() {
    Widget chartCard(String title, Widget chart) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(title: title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BuildBoxShadowContainer(
              padding: const EdgeInsets.all(16),
              height: 280,
              circleRadius: 14,
              blurRadius: 10,
              offsetValue: const Offset(0, 3),
              border: Border.all(color: Colors.grey.withOpacity(0.12)),
              child: chart,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: chartCard(
                    'company_admin.chart_exec_performance'.tr, _buildExecutiveSalesChart()),
              ),
              Expanded(
                child: chartCard('company_admin.chart_sales_trend'.tr, _buildSalesOverviewChart()),
              ),
            ],
          );
        }
        return Column(
          children: [
            chartCard(
                "Sales Executive Performance", _buildExecutiveSalesChart()),
            const SizedBox(height: 20),
            chartCard('company_admin.chart_sales_trend'.tr, _buildSalesOverviewChart()),
          ],
        );
      },
    );
  }

  Widget _buildCustomerOverview() {
    return Column(
      children: [
        DashboardSectionHeader(title: 'company_admin.section_customer_overview'.tr),
        ResponsiveStatGrid(
          cards: [
            _buildCompanyAccountCard(
                'company_admin.card_total_customers'.tr,
                'company_admin.card_all_customers'.tr,
                customerStats != null
                    ? customerStats!.totalCustomers.toString()
                    : dashboardOverview != null
                        ? dashboardOverview!.customers.totalCustomers.toString()
                        : "0",
                ColorManager.kPrimaryColor,
                Icons.people),
            _buildCompanyAccountCard(
                'company_admin.card_debit_customers'.tr,
                'company_admin.card_pending_payments'.tr,
                customerStats != null
                    ? customerStats!.debitCustomers.toString()
                    : "0",
                ColorManager.kMagentha,
                Icons.money_off),
            _buildCompanyAccountCard(
                'company_admin.card_credit_customers'.tr,
                'company_admin.card_balance_available'.tr,
                customerStats != null
                    ? customerStats!.creditCustomers.toString()
                    : "0",
                ColorManager.kOrange,
                Icons.account_balance_wallet),
            _buildCompanyAccountCard(
                'company_admin.card_crucial_customers'.tr,
                'company_admin.card_vvip_clients'.tr,
                customerStats != null
                    ? customerStats!.crucialCustomers.toString()
                    : "0",
                ColorManager.kBlue,
                Icons.star),
            _buildCompanyAccountCard(
                'company_admin.card_new_customers'.tr,
                'company_admin.card_added_today'.tr,
                customerStats != null && customerStats!.period == 'today'
                    ? 'company_admin.na'.tr
                    : dashboardOverview != null
                        ? dashboardOverview!.customers.newCustomers.toString()
                        : "0",
                ColorManager.kGreen,
                Icons.person_add),
          ],
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
                    child: _buildRecentTransactions(),
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
                    child: _buildTopProducts(),
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
                        "company_admin.low_stock_alert".tr,
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
                    child: _buildLowStockItems(),
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

  Widget _buildRecentTransactions() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTransactions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ColorManager.kPrimaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recentTransactions[index],
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
        );
      },
    );
  }

  Widget _buildTopProducts() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topProducts.length,
      itemBuilder: (context, index) {
        final product = topProducts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s10,
                      0.10,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product["name"],
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.10,
                        ColorManager.textColor,
                      ),
                    ),
                    Text(
                      "${product["sales"]} sales",
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s10,
                        0.10,
                        Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                product["revenue"],
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s11,
                  0.10,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLowStockItems() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lowStockItems.length,
      itemBuilder: (context, index) {
        final item = lowStockItems[index];
        final isCritical = item["status"] == "Critical";
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCritical ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["name"],
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.10,
                        ColorManager.textColor,
                      ),
                    ),
                    Text(
                      "${item["stock"]} units left",
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s10,
                        0.10,
                        Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical
                      ? Colors.red.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item["status"],
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.10,
                    isCritical ? Colors.red : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodsChart() {
    final paymentData = [
      PieChartSectionData(
        color: ColorManager.kPrimaryColor,
        value: 45,
        title: '${'company_admin.payment_card'.tr}\n45%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: ColorManager.kOrange,
        value: 30,
        title: '${'company_admin.payment_cash'.tr}\n30%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: ColorManager.kMagentha,
        value: 15,
        title: '${'company_admin.payment_upi'.tr}\n15%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: ColorManager.kBlue,
        value: 10,
        title: '${'company_admin.payment_other'.tr}\n10%',
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
    if (value != 'year' &&
        executiveSalesGraph != null &&
        executiveSalesGraph!.salesGraph.isNotEmpty) {
      final salesData = executiveSalesGraph!.salesGraph;

      // Find max value for Y scaling
      double maxY = salesData
          .map((data) => data.amount.toDouble())
          .reduce((a, b) => a > b ? a : b);
      double maxYValue = (maxY * 1.2);
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
                getDrawingHorizontalLine: (val) => FlLine(
                  color: Colors.grey[300]!,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (val, meta) => Text(
                      val.toInt().toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      int index = val.toInt();
                      if (index >= 0 && index < salesData.length) {
                        String label = '';
                        if (value == 'today') {
                          label = salesData[index].time ?? '';
                        } else if (value == 'week') {
                          label = salesData[index].day ?? '';
                        } else {
                          label = salesData[index].date ?? '';
                        }
                        return Text(
                          label,
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
                LineChartBarData(
                  spots: salesData.asMap().entries.map((entry) {
                    return FlSpot(
                        entry.key.toDouble(), entry.value.amount.toDouble());
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
              ],
            ),
          ),
        ),
      );
    }

    if (ordersPerMonthData != null &&
        ordersPerMonthData!.ordersPerMonth.isNotEmpty &&
        value == 'year') {
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
                getDrawingHorizontalLine: (val) => FlLine(
                  color: Colors.grey[300]!,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (val, meta) => Text(
                      val.toInt().toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      int index = val.toInt();
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
                          return Text('company_admin.pos'.tr,
                              style: const TextStyle(fontSize: 10));
                        case 1:
                          return Text('company_admin.web'.tr,
                              style: const TextStyle(fontSize: 10));
                        case 2:
                          return Text('company_admin.kiosk'.tr,
                              style: const TextStyle(fontSize: 10));
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

  Widget _buildExecutiveSalesChart() {
    // Use real API data if available, otherwise use dummy data
    List<SalesExecutiveGraph> executivesData =
        executivesOverview?.salesExecutivesGraph ??
            [
              // SalesExecutiveGraph(
              //     executiveId: 1,
              //     executiveName: 'John Doe',
              //     sales: [SalesData(date: '2023-01-01', amount: 125000)]),
              // SalesExecutiveGraph(
              //     executiveId: 2,
              //     executiveName: 'Jane Smith',
              //     sales: [SalesData(date: '2023-01-01', amount: 98000)]),
              // SalesExecutiveGraph(
              //     executiveId: 3,
              //     executiveName: 'Robert Johnson',
              //     sales: [SalesData(date: '2023-01-01', amount: 87500)]),
              // SalesExecutiveGraph(
              //     executiveId: 4,
              //     executiveName: 'Emily Davis',
              //     sales: [SalesData(date: '2023-01-01', amount: 76200)]),
              // SalesExecutiveGraph(
              //     executiveId: 5,
              //     executiveName: 'Michael Wilson',
              //     sales: [SalesData(date: '2023-01-01', amount: 65800)]),
            ];

    // Find the maximum sales for Y-axis scaling
    double maxY = 0;
    if (executivesData.isNotEmpty) {
      // Calculate total sales for each executive
      List<int> totalSales = executivesData
          .map((executive) =>
              executive.sales.fold(0, (sum, sale) => sum + sale.amount))
          .toList();

      maxY = totalSales.reduce((a, b) => a > b ? a : b).toDouble();
      // Add some padding to the top
      maxY = (maxY * 1.2);
      // Ensure minimum value for better visualization
      maxY = maxY < 10 ? 10 : maxY;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: const EdgeInsets.all(8),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  // Calculate total sales for this executive
                  int totalSales = executivesData[groupIndex]
                      .sales
                      .fold(0, (sum, sale) => sum + sale.amount);
                  return BarTooltipItem(
                    '${NumberFormat('#,##,###').format(totalSales)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= 0 &&
                        value.toInt() < executivesData.length) {
                      return Text(
                        executivesData[value.toInt()]
                            .executiveName
                            .split(' ')[0],
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
            barGroups: executivesData.asMap().entries.map((entry) {
              // Calculate total sales for this executive
              int totalSales =
                  entry.value.sales.fold(0, (sum, sale) => sum + sale.amount);
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: totalSales.toDouble(),
                    color: ColorManager.kPrimaryColor,
                    width: 20,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
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
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15, bottom: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Quick Actions",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.23,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            QuickAccessCard(
              onTap: () {},
              title: "New Sale",
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              size: MediaQuery.of(context).size,
              icon: Icons.point_of_sale,
            ),
            QuickAccessCard(
              onTap: () {},
              title: "Inventory",
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFf093fb),
                  Color(0xFFf5576c),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              size: MediaQuery.of(context).size,
              icon: Icons.inventory_2,
            ),
            QuickAccessCard(
              onTap: () {},
              title: "Reports",
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4facfe),
                  Color(0xFF00f2fe),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              size: MediaQuery.of(context).size,
              icon: Icons.analytics,
            ),
            QuickAccessCard(
              onTap: () {},
              title: "Settings",
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF43e97b),
                  Color(0xFF38f9d7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              size: MediaQuery.of(context).size,
              icon: Icons.settings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesCard(String title, Color color, IconData icon) {
    String valueText = _getSalesValue(title);
    String subtitle = _getCardSubtitle(title);

    return DashboardStatCard(
      title: "dashboard.cards.${title.toLowerCase()}".tr,
      subtitle: subtitle,
      value: valueText,
      color: color,
      icon: icon,
      valueWidget: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
          String displayValue = valueText;
          if (title == "Amount" || title == "Revenue") {
            final currency = settings.appSettings?.currency ?? 'INR';
            displayValue = "$currency $valueText";
          }
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              displayValue,
              maxLines: 1,
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s20,
                0.20,
                ColorManager.textColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompanyAccountCard(
      String title, String subtitle, String value, Color color, IconData icon) {
    return DashboardStatCard(
      title: title,
      subtitle: subtitle,
      value: value,
      color: color,
      icon: icon,
    );
  }

  String _getCardSubtitle(String title) {
    switch (title) {
      case "Count":
        return 'company_admin.subtitle_total_sales'.tr;
      case "Amount":
        return 'company_admin.subtitle_revenue'.tr;
      case "Customers":
        return 'company_admin.subtitle_active_users'.tr;
      case "Products":
        return 'company_admin.subtitle_in_stock'.tr;
      case "Revenue":
        return 'company_admin.subtitle_overall_total'.tr;
      case "Orders":
        return 'company_admin.subtitle_overall_count'.tr;
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
        DashboardSectionHeader(title: 'company_admin.section_works_team'.tr),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            member.name ?? 'company_admin.unknown'.tr,
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
}

// Enhanced GraphData class for dummy data
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
            // Main content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon ?? Icons.star,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: FontSize.s16,
                          letterSpacing: 0.23,
                          color: Colors.white,
                          fontWeight: FontWeightManager.semiBold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'View details',
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              fontSize: FontSize.s11,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeightManager.regular,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white.withOpacity(0.8),
                            size: 12,
                          ),
                        ],
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
}
