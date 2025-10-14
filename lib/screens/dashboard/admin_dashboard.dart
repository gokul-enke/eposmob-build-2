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
import '../../models/dashboard_api.dart';
import '../../providers/dashboard_provider.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool isInitialLoading = true;
  String value = 'today';
  bool isLoading = false;

  // Supplier Dashboard Data State Variables
  SuppliersOverview? suppliersOverview;
  SuppliersPurchaseGraph? suppliersPurchaseGraph;
  SupplierTransactionsGraph? supplierTransactionsGraph;
  SupplierCreditBalanceGraph? supplierCreditBalanceGraph;

  // Cache for different periods
  Map<String, SuppliersOverview> cachedSuppliersOverview = {};
  Map<String, SuppliersPurchaseGraph> cachedSuppliersPurchaseGraph = {};
  Map<String, SupplierTransactionsGraph> cachedSupplierTransactionsGraph = {};
  Map<String, SupplierCreditBalanceGraph> cachedSupplierCreditBalanceGraph = {};

  @override
  void initState() {
    super.initState();
    debugPrint('=== AdminDashboard initState called ===');
    debugPrint('Starting initial data fetching...');
    fetchAllPeriodData(); // Fetch data for all periods once
    debugPrint('=== Initial data fetching initiated ===');
  }

  Future<void> fetchAllPeriodData() async {
    debugPrint('=== FETCHING SUPPLIER DATA FOR ALL PERIODS ===');
    try {
      setState(() {
        isInitialLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) {
        debugPrint('ERROR: No access token available');
        return;
      }

      // Fetch data for each period
      final periods = ['today', 'week', 'month', 'year'];

      for (String period in periods) {
        debugPrint('Fetching supplier data for period: $period');

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
            startDate = DateFormat('yyyy-MM-dd')
                .format(DateTime(now.year, now.month, 1));
            break;
          case "year":
            startDate =
                DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
            break;
          default:
            startDate = DateFormat('yyyy-MM-dd')
                .format(now.subtract(const Duration(days: 30)));
        }

        // Fetch supplier dashboard data for this period
        try {
          final dashboardProvider = DashboardProvider();

          // Fetch suppliers overview
          final suppliersOverview = await dashboardProvider
              .fetchSuppliersOverview(accessToken, startDate, endDate);
          cachedSuppliersOverview[period] = suppliersOverview;

          // Fetch suppliers purchase graph
          final suppliersPurchaseGraph = await dashboardProvider
              .fetchSuppliersPurchaseGraph(accessToken, startDate, endDate);
          cachedSuppliersPurchaseGraph[period] = suppliersPurchaseGraph;

          // Fetch supplier transactions graph
          final supplierTransactionsGraph = await dashboardProvider
              .fetchSupplierTransactionsGraph(accessToken, startDate, endDate);
          cachedSupplierTransactionsGraph[period] = supplierTransactionsGraph;

          // Fetch supplier credit balance graph
          final supplierCreditBalanceGraph = await dashboardProvider
              .fetchSupplierCreditBalance(accessToken, startDate, endDate);
          cachedSupplierCreditBalanceGraph[period] = supplierCreditBalanceGraph;

          debugPrint('Cached supplier data for period: $period');
        } catch (error) {
          debugPrint('Error fetching supplier data for period $period: $error');
        }
      }

      // Set initial data to today's data
      setState(() {
        suppliersOverview = cachedSuppliersOverview['today'];
        suppliersPurchaseGraph = cachedSuppliersPurchaseGraph['today'];
        supplierTransactionsGraph = cachedSupplierTransactionsGraph['today'];
        supplierCreditBalanceGraph = cachedSupplierCreditBalanceGraph['today'];
        isInitialLoading = false;
      });

      debugPrint('=== ALL SUPPLIER PERIOD DATA FETCHING COMPLETE ===');
    } catch (error) {
      debugPrint('Error in fetchAllPeriodData: $error');
      setState(() {
        isInitialLoading = false;
      });
    }
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
                    _buildSupplierOverview(),
                    const SizedBox(height: 20),
                    _buildSuppliersPurchaseGraph(),
                    const SizedBox(height: 20),
                    _buildSupplierTransactionsGraph(),
                    const SizedBox(height: 20),
                    _buildSupplierCreditBalanceGraph(),
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
                "Supplier Dashboard",
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
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

  Widget _buildSupplierOverview() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Supplier Overview",
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
                  setState(() {
                    value = newValue?.toLowerCase() ?? "today";
                    // Switch to cached data instead of refetching
                    suppliersOverview = cachedSuppliersOverview[value];
                    suppliersPurchaseGraph =
                        cachedSuppliersPurchaseGraph[value];
                    supplierTransactionsGraph =
                        cachedSupplierTransactionsGraph[value];
                    supplierCreditBalanceGraph =
                        cachedSupplierCreditBalanceGraph[value];
                  });
                },
                dropdownColor: Colors.white,
                menuMaxHeight: 200,
                elevation: 2,
                padding: EdgeInsets.zero,
                items: <String>['Today', 'Week', 'Month', 'Year']
                    .map((String value) {
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
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      _buildSupplierCountCard(),
                      const SizedBox(width: 16),
                      _buildNewSuppliersCard(),
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

  Widget _buildSupplierCountCard() {
    final totalSuppliers = suppliersOverview?.suppliers.totalSuppliers ?? 0;
    return BuildBoxShadowContainer(
      height: 150,
      width: 280,
      circleRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Suppliers",
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.10,
                  Colors.grey[600]!,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.supervisor_account,
                  color: ColorManager.kPrimaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
          Text(
            totalSuppliers.toString(),
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s24,
              0.30,
              ColorManager.textColor,
            ),
          ),
          Text(
            "Active suppliers in your business",
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.10,
              Colors.grey[500]!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSuppliersCard() {
    final newSuppliers = suppliersOverview?.suppliers.newSuppliers ?? 0;
    return BuildBoxShadowContainer(
      height: 150,
      width: 280,
      circleRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "New Suppliers",
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.10,
                  Colors.grey[600]!,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ColorManager.kSuccessColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: ColorManager.kSuccessColor,
                  size: 20,
                ),
              ),
            ],
          ),
          Text(
            newSuppliers.toString(),
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s24,
              0.30,
              ColorManager.textColor,
            ),
          ),
          Text(
            "Added in the selected period",
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.10,
              Colors.grey[500]!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersPurchaseGraph() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Supplier Purchase Graph",
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
          height: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildPurchaseGraphContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseGraphContent() {
    final purchaseData = suppliersPurchaseGraph?.purchaseGraph ?? [];

    if (purchaseData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "No purchase data available",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.10,
                Colors.grey[500]!,
              ),
            ),
          ],
        ),
      );
    }

    // Prepare data for the bar chart
    List<BarChartGroupData> barGroups = [];
    List<String> supplierNames = [];

    for (int i = 0; i < purchaseData.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: purchaseData[i].amount,
              color: ColorManager.kPrimaryColor.withOpacity(0.7),
              width: 20,
              borderRadius: BorderRadius.zero,
              rodStackItems: [],
            ),
          ],
        ),
      );
      supplierNames.add(purchaseData[i].supplierName);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Purchase Amount by Supplier",
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.10,
            Colors.grey[600]!,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < supplierNames.length) {
                        // Truncate long names
                        String name = supplierNames[index];
                        if (name.length > 10) {
                          name = '${name.substring(0, 7)}...';
                        }
                        return Text(
                          name,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s10,
                            0.10,
                            Colors.grey[600]!,
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        formatCurrency(value),
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s10,
                          0.10,
                          Colors.grey[600]!,
                        ),
                      );
                    },
                    reservedSize: 60,
                    // Removed interval to show all labels clearly
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: calculateInterval(
                    purchaseData.map((e) => e.amount).toList()),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${supplierNames[groupIndex]}\n',
                      TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: formatCurrency(rod.toY),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierTransactionsGraph() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Supplier Transactions Graph",
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
          height: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTransactionsGraphContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsGraphContent() {
    final transactionsData = supplierTransactionsGraph?.transactionsGraph ?? [];

    if (transactionsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "No transaction data available",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.10,
                Colors.grey[500]!,
              ),
            ),
          ],
        ),
      );
    }

    // Prepare data for the line chart
    List<FlSpot> receivedSpots = [];
    List<FlSpot> paidSpots = [];
    List<String> dates = [];

    for (int i = 0; i < transactionsData.length; i++) {
      receivedSpots
          .add(FlSpot(i.toDouble(), transactionsData[i].receivedAmount));
      paidSpots.add(FlSpot(i.toDouble(), transactionsData[i].paidAmount));

      // Use date if available, otherwise day or time
      String label = transactionsData[i].date ??
          transactionsData[i].day ??
          transactionsData[i].time ??
          'Day ${i + 1}';
      dates.add(label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Transactions Over Time",
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.10,
            Colors.grey[600]!,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: receivedSpots,
                  isCurved: true,
                  color: ColorManager.kSuccessColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                      show: true,
                      color: ColorManager.kSuccessColor.withOpacity(0.2)),
                ),
                LineChartBarData(
                  spots: paidSpots,
                  isCurved: true,
                  color: ColorManager.kErrorColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                      show: true,
                      color: ColorManager.kErrorColor.withOpacity(0.2)),
                ),
              ],
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < dates.length) {
                        // Truncate long dates
                        String date = dates[index];
                        if (date.length > 10) {
                          date = '${date.substring(0, 7)}...';
                        }
                        return Text(
                          date,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s10,
                            0.10,
                            Colors.grey[600]!,
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        formatCurrency(value),
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s10,
                          0.10,
                          Colors.grey[600]!,
                        ),
                      );
                    },
                    reservedSize: 60,
                    // Removed interval to show all labels clearly
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: calculateInterval(transactionsData
                    .expand((t) => [t.receivedAmount, t.paidAmount])
                    .toList()),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      final flSpot = barSpot;
                      if (flSpot != null) {
                        final index = flSpot.spotIndex;
                        final isReceived = barSpot.barIndex == 0;
                        final amount = isReceived
                            ? transactionsData[index].receivedAmount
                            : transactionsData[index].paidAmount;
                        final color = isReceived
                            ? ColorManager.kSuccessColor
                            : ColorManager.kErrorColor;
                        final label = isReceived ? 'Received' : 'Paid';

                        return LineTooltipItem(
                          '$label\n',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: formatCurrency(amount),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }
                      return LineTooltipItem('', const TextStyle());
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(ColorManager.kSuccessColor, 'Received'),
            const SizedBox(width: 20),
            _buildLegendItem(ColorManager.kErrorColor, 'Paid'),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplierCreditBalanceGraph() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Supplier Credit/Balance Graph",
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
          height: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildCreditBalanceGraphContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditBalanceGraphContent() {
    final creditBalanceData =
        supplierCreditBalanceGraph?.creditBalanceGraph ?? [];

    if (creditBalanceData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "No credit/balance data available",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.10,
                Colors.grey[500]!,
              ),
            ),
          ],
        ),
      );
    }

    // Prepare data for the line chart
    List<FlSpot> creditSpots = [];
    List<FlSpot> balanceSpots = [];
    List<String> dates = [];

    for (int i = 0; i < creditBalanceData.length; i++) {
      creditSpots.add(FlSpot(i.toDouble(), creditBalanceData[i].creditAmount));
      balanceSpots
          .add(FlSpot(i.toDouble(), creditBalanceData[i].balanceAmount));

      // Use date if available, otherwise day or time
      String label = creditBalanceData[i].date ??
          creditBalanceData[i].day ??
          creditBalanceData[i].time ??
          'Day ${i + 1}';
      dates.add(label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Credit vs Balance Over Time",
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.10,
            Colors.grey[600]!,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: creditSpots,
                  isCurved: true,
                  color: ColorManager.kPrimaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                      show: true,
                      color: ColorManager.kPrimaryColor.withOpacity(0.2)),
                ),
                LineChartBarData(
                  spots: balanceSpots,
                  isCurved: true,
                  color: ColorManager.kOrange,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                      show: true, color: ColorManager.kOrange.withOpacity(0.2)),
                ),
              ],
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < dates.length) {
                        // Truncate long dates
                        String date = dates[index];
                        if (date.length > 10) {
                          date = '${date.substring(0, 7)}...';
                        }
                        return Text(
                          date,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s10,
                            0.10,
                            Colors.grey[600]!,
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        formatCurrency(value),
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s10,
                          0.10,
                          Colors.grey[600]!,
                        ),
                      );
                    },
                    reservedSize: 60,
                    // Removed interval to show all labels clearly
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: calculateInterval(creditBalanceData
                    .expand((t) => [t.creditAmount, t.balanceAmount])
                    .toList()),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      final flSpot = barSpot;
                      if (flSpot != null) {
                        final index = flSpot.spotIndex;
                        final isCredit = barSpot.barIndex == 0;
                        final amount = isCredit
                            ? creditBalanceData[index].creditAmount
                            : creditBalanceData[index].balanceAmount;
                        final color = isCredit
                            ? ColorManager.kPrimaryColor
                            : ColorManager.kOrange;
                        final label = isCredit ? 'Credit' : 'Balance';

                        return LineTooltipItem(
                          '$label\n',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: formatCurrency(amount),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }
                      return LineTooltipItem('', const TextStyle());
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(ColorManager.kPrimaryColor, 'Credit'),
            const SizedBox(width: 20),
            _buildLegendItem(ColorManager.kOrange, 'Balance'),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.10,
            Colors.grey[700]!,
          ),
        ),
      ],
    );
  }

  // Helper method to format currency values
  String formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  // Helper method to calculate appropriate interval for Y-axis
  double calculateInterval(List<double> values) {
    if (values.isEmpty) return 1;

    double max = values.reduce((a, b) => a > b ? a : b);
    double min = values.reduce((a, b) => a < b ? a : b);
    double range = max - min;

    // Calculate a reasonable interval based on the range
    if (range == 0) return 1;

    double interval = range / 5; // Aim for about 5 intervals

    // Round to a nice number
    if (interval >= 1000000) {
      interval = (interval / 1000000).ceilToDouble() * 1000000;
    } else if (interval >= 100000) {
      interval = (interval / 100000).ceilToDouble() * 100000;
    } else if (interval >= 10000) {
      interval = (interval / 10000).ceilToDouble() * 10000;
    } else if (interval >= 1000) {
      interval = (interval / 1000).ceilToDouble() * 1000;
    } else if (interval >= 100) {
      interval = (interval / 100).ceilToDouble() * 100;
    } else if (interval >= 10) {
      interval = (interval / 10).ceilToDouble() * 10;
    } else {
      interval = interval.ceilToDouble();
    }

    return interval > 0 ? interval : 1;
  }

  // Helper method to calculate appropriate interval for Y-axis labels to prevent overlapping
  double calculateYAxisInterval(List<double> values) {
    if (values.isEmpty) return 1;

    double max = values.reduce((a, b) => a > b ? a : b);
    double min = values.reduce((a, b) => a < b ? a : b);
    double range = max - min;

    // Calculate a reasonable interval based on the range
    if (range == 0) return 1;

    // For Y-axis labels, we want fewer labels to prevent overlapping
    double interval = range / 4; // Aim for about 4 intervals for better balance

    // Round to a nice number
    if (interval >= 1000000) {
      interval = (interval / 1000000).ceilToDouble() * 1000000;
    } else if (interval >= 100000) {
      interval = (interval / 100000).ceilToDouble() * 100000;
    } else if (interval >= 10000) {
      interval = (interval / 10000).ceilToDouble() * 10000;
    } else if (interval >= 1000) {
      interval = (interval / 1000).ceilToDouble() * 1000;
    } else if (interval >= 100) {
      interval = (interval / 100).ceilToDouble() * 100;
    } else if (interval >= 10) {
      interval = (interval / 10).ceilToDouble() * 10;
    } else {
      interval = interval.ceilToDouble();
    }

    return interval > 0 ? interval : 1;
  }
}
