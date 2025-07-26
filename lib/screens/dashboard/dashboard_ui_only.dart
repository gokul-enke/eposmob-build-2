import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../../models/dashboard.dart';
import '../../providers/dashboard_provider.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isInitLoading = false;
  DashBoardModelData? dashBoardModelData;
  TotalSales? totalSales;
  String value = 'today';
  bool isLoading = false;
  List<GraphData> graphData = [];
  List<GraphData> chartData = [];

  // Dummy data for demonstration
  final List<String> recentTransactions = [
    "Transaction #12345 - ₹2,450.00",
    "Transaction #12346 - ₹1,200.50",
    "Transaction #12347 - ₹890.75",
    "Transaction #12348 - ₹3,100.00",
    "Transaction #12349 - ₹567.25",
  ];

  final List<Map<String, dynamic>> topProducts = [
    {"name": "Smartphone", "sales": 245, "revenue": "₹2,45,000"},
    {"name": "Laptop", "sales": 123, "revenue": "₹6,15,000"},
    {"name": "Headphones", "sales": 567, "revenue": "₹1,13,400"},
    {"name": "Tablet", "sales": 89, "revenue": "₹2,67,000"},
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
          chartData = data.reversed.take(5).toList().reversed.cast<GraphData>().toList();
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

  void getDashBoardDetails() async {
    try {
      setState(() {
        isInitLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      DashboardProvider()
          .dashbaord(accessToken ?? "", context)
          .then((response) {
        if (response["status"] == "success") {
          setState(() {
            DashBoardModel dashBoardModel = DashBoardModel.fromJson(response);
            dashBoardModelData = dashBoardModel.data;
            totalSales = dashBoardModelData!.totalSales;
          });
        } else {
          // Use dummy data for demonstration
          _setDummyDashboardData();
        }
      }).catchError((error) {
        _setDummyDashboardData();
      });
    } catch (error) {
      _setDummyDashboardData();
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
  }

  void _setDummyDashboardData() {
    // Create dummy data for demonstration
    setState(() {
      totalSales = TotalSales(
        today: PeriodStats(
          totalSales: 45,
          totalAmount: 12500.50,
          totalCustomers: 28,
        ),
        week: PeriodStats(
          totalSales: 234,
          totalAmount: 65780.25,
          totalCustomers: 156,
        ),
        month: PeriodStats(
          totalSales: 1045,
          totalAmount: 345600.75,
          totalCustomers: 678,
        ),
        year: PeriodStats(
          totalSales: 12450,
          totalAmount: 4567890.50,
          totalCustomers: 8234,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: isInitLoading
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
                    _buildSalesOverview(),
                    const SizedBox(height: 20),
                    _buildAdditionalStats(),
                    const SizedBox(height: 20),
                    _buildQuickAccess(),
                    const SizedBox(height: 20),
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
                "Dashboard",
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Welcome back! Here's your business overview",
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.10,
                  Colors.grey[600]!,
                ),
              ),
            ],
          ),
          Row(
            children: [
              CustomRoundButtonWithIcon(
                title: "Export",
                fct: () {},
                fontSize: 12,
                height: 40,
                width: 120,
                size: size,
                icon: const Icon(
                  Icons.download_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
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
        BuildBoxShadowContainer(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 36,
          width: 100,
          circleRadius: 8,
          child: DropdownButton<String>(
            value: value,
            onChanged: (String? newValue) {
              setState(() {
                value = newValue?.toLowerCase() ?? "today";
              });
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
          height: 165,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesOverview() {
    return SizedBox(
      height: 350,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 15, top: 15),
                  child: Text(
                    "Sales Trend",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s15,
                      0.23,
                      ColorManager.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                BuildBoxShadowContainer(
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(15),
                  height: 250,
                  circleRadius: 7,
                  child: _buildSalesOverviewChart(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 15, top: 15),
                  child: Text(
                    "Category Performance",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s15,
                      0.23,
                      ColorManager.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                BuildBoxShadowContainer(
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(15),
                  height: 250,
                  circleRadius: 7,
                  child: _buildAnalyticsChart(),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 200,
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
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 200,
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
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 200,
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
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding: const EdgeInsets.all(15),
                    height: 200,
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
      itemCount: lowStockItems.length,
      itemBuilder: (context, index) {
        final item = lowStockItems[index];
        final isCustomical = item["status"] == "Critical";
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCustomical ? Colors.red : Colors.orange,
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
                  color: isCustomical
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
                    isCustomical ? Colors.red : Colors.orange,
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

  Widget _buildAnalyticsChart() {
    if (chartData.isEmpty) {
      _generateDummyData();
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 25,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${chartData[groupIndex].count}',
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
                  if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(
                        DateFormat('dd/MM')
                            .format(chartData[value.toInt()].date),
                        style: const TextStyle(
                          color: ColorManager.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
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
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: ColorManager.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                reservedSize: 40,
                interval: 5,
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            chartData.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: chartData[index].count.toDouble(),
                  gradient: LinearGradient(
                    colors: [
                      ColorManager.kPrimaryColor.withOpacity(0.8),
                      ColorManager.kPrimaryColor,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                )
              ],
              showingTooltipIndicators: [0],
            ),
          ),
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
    String value = _getSalesValue(title);
    String subtitle = _getCardSubtitle(title);

    return BuildBoxShadowContainer(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(12),
      height: 136,
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
          // const SizedBox(height: 4),
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
        return "₹${NumberFormat('#,##,###.##').format(periodStats.totalAmount ?? 0)}";
      case "Customers":
        return periodStats.totalCustomers?.toString() ?? "0";
      case "Products":
        return Provider.of<LocalProductProvider>(context, listen: false)
            .products
            .length
            .toString();
      case "Revenue":
        return "₹${NumberFormat('#,##,###').format((periodStats.totalAmount ?? 0) * 0.85)}";
      case "Orders":
        return "${(periodStats.totalSales ?? 0) + 15}";
      default:
        return "0";
    }
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
