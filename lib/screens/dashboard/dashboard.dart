import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
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

  @override
  void initState() {
    super.initState();
    getDashBoardDetails();
    fetchGraphData(); // Fetch initial graph data
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
          graphData = data;
          chartData = data.reversed.take(5).toList().reversed.toList();
        });
      }
    } catch (error) {
      // Handle error (e.g., show a snackbar)
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load graph data: $error')),
      // );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void getDashBoardDetails() async {
    try {
      setState(() {
        isInitLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      // debugPrint("accessToken From AuthModel $accessToken");
      DashboardProvider()
          .dashbaord(accessToken ?? "", context)
          .then((response) {
        if (response["status"] == "success") {
          setState(() {
            DashBoardModel dashBoardModel = DashBoardModel.fromJson(response);
            dashBoardModelData = dashBoardModel.data;
            totalSales = dashBoardModelData!.totalSales;
          });
        } else {}
      });
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
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
                    // const SizedBox(height: 20),
                    // _buildSalesOverview(),
                    // const SizedBox(height: 20),
                    // _buildQuickAccess(),
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
          Text(
            "Dashboard",
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
          Row(
            children: [
              // CustomRoundButtonWithIcon(
              //   title: "Download Report",
              //   fct: () {},
              //   fontSize: 12,
              //   height: 50,
              //   width: 180,
              //   size: size,
              //   icon: const Icon(
              //     Icons.download_outlined,
              //     size: 16,
              //     color: Colors.white,
              //   ),
              // ),
              // const SizedBox(width: 12),
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
                      DateHelper.formatDate(DateTime.now()),
                      // Updated to show current date
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.10,
                        ColorManager.textColor,
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // const Icon(
                    //   Icons.keyboard_arrow_down,
                    //   size: 16,
                    // ),
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
            "Sales",
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
            value: value, // Set the initial value
            onChanged: (String? newValue) {
              setState(() {
                value =
                    newValue?.toLowerCase() ?? "today"; // Update selected value
              });
            },
            dropdownColor:
                Colors.white, // Set dropdown menu background color to white
            menuMaxHeight: 200,
            elevation: 2,
            padding: EdgeInsets.zero,
            items:
                <String>['Today', 'Week', 'Month', 'Year'].map((String value) {
              return DropdownMenuItem<String>(
                value: value.toLowerCase(), // Use lowercase for consistency
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
            underline: Container(), // No underline
            isExpanded: true, // Expand the dropdown to the container width
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
                      _buildSalesCard("Count", ColorManager.kPrimaryColor),
                      _buildSalesCard("Amount", ColorManager.kMagentha),
                      _buildSalesCard("Customers", ColorManager.kOrange),
                      _buildSalesCard("Products", ColorManager.kBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 8),
        //   height: 165,
        //   child: Row(
        //     mainAxisAlignment: MainAxisAlignment.start,
        //     children: [
        //       Expanded(
        //         child: ListView(
        //           scrollDirection: Axis.horizontal,
        //           shrinkWrap: true,
        //           children: [
        //             _buildSalesCard("Products", ColorManager.kBlue),
        //             _buildSalesCard(
        //                 "New Customers", ColorManager.kSuccessColor),
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  Widget _buildSalesOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Analytics Overview",
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s15,
              0.23,
              ColorManager.textColor,
            ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 300,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: BuildBoxShadowContainer(
                  margin: const EdgeInsets.symmetric(horizontal: 15),
                  padding: const EdgeInsets.all(15),
                  height: 300,
                  circleRadius: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Sales Trend",
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.23,
                              ColorManager.textColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Last 7 Days",
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.1,
                                ColorManager.kPrimaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(child: _buildSalesOverviewChart()),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: BuildBoxShadowContainer(
                  margin: const EdgeInsets.only(right: 15),
                  padding: const EdgeInsets.all(15),
                  height: 300,
                  circleRadius: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Sales Distribution",
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.23,
                              ColorManager.textColor,
                            ),
                          ),
                          Icon(Icons.more_vert,
                              color: ColorManager.textColor.withOpacity(0.5)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(child: _buildAnalyticsChart()),
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

  Widget _buildSalesOverviewChart() {
    // Dummy data for the line chart
    final List<FlSpot> dummySpots = [
      const FlSpot(0, 10),
      const FlSpot(1, 15),
      const FlSpot(2, 13),
      const FlSpot(3, 17),
      const FlSpot(4, 14),
      const FlSpot(5, 16),
      const FlSpot(6, 19),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}k',
                  style: TextStyle(
                    color: ColorManager.textColor.withOpacity(0.5),
                    fontSize: 12,
                  ),
                );
              },
              reservedSize: 35,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: TextStyle(
                      color: ColorManager.textColor.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 20,
        lineBarsData: [
          LineChartBarData(
            spots: dummySpots,
            isCurved: true,
            color: ColorManager.kPrimaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: ColorManager.kPrimaryColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: ColorManager.kPrimaryColor.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    // Dummy data for the bar chart
    final List<double> dummyData = [8, 12, 15, 10, 13];
    final List<String> categories = [
      'Food',
      'Drinks',
      'Snacks',
      'Dessert',
      'Other'
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}k',
                  style: TextStyle(
                    color: ColorManager.textColor.withOpacity(0.5),
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < categories.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      categories[value.toInt()],
                      style: TextStyle(
                        color: ColorManager.textColor.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: dummyData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                color: ColorManager.kPrimaryColor,
                width: 12,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Quick Access",
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s15,
                0.23, ColorManager.textColor),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            QuickAccessCard(
              onTap: () {},
              title: "Favourites",
              gradient: const LinearGradient(
                colors: [
                  ColorManager.kGradientCyan,
                  ColorManager.kGradientBlue,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              size: MediaQuery.of(context).size,
            ),
            QuickAccessCard(
              onTap: () {},
              title: "Orders",
              gradient: const LinearGradient(
                colors: [
                  ColorManager.kGradientPeach,
                  ColorManager.kGradientRose,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              size: MediaQuery.of(context).size,
            ),
            QuickAccessCard(
              onTap: () {},
              title: "Reports",
              gradient: const LinearGradient(
                colors: [
                  ColorManager.kGradientIndigo,
                  ColorManager.kGradientVoilet,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
              ),
              size: MediaQuery.of(context).size,
            ),
            QuickAccessCard(
              onTap: () {},
              title: "Settings",
              gradient: const LinearGradient(
                colors: [
                  ColorManager.kGradientGreen,
                  ColorManager.kGradientGreenLight,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
              ),
              size: MediaQuery.of(context).size,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesCard(String title, Color color) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(15),
      height: 136,
      width: 240,
      circleRadius: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: const Icon(
              Icons.calculate_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getSalesValue(title),
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.38,
              ColorManager.textColor,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              // Row(
              //   children: [
              //     Container(
              //       padding: const EdgeInsets.all(3),
              //       decoration: const BoxDecoration(
              //         shape: BoxShape.circle,
              //         color: ColorManager.kGreenWithOpacity,
              //       ),
              //       child: const Icon(
              //         Icons.arrow_forward,
              //         size: 15,
              //         color: ColorManager.kGreen,
              //       ),
              //     ),
              //     Text(
              //       "+ 0 %",
              //       style: buildCustomStyle(
              //         FontWeightManager.medium,
              //         FontSize.s15,
              //         0.23,
              //         ColorManager.kGreen,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ],
      ),
    );
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
        return periodStats.totalAmount?.toStringAsFixed(2) ?? "0";
      case "Customers":
        return periodStats.totalCustomers?.toString() ?? "0";
      case "Products":
        return Provider.of<LocalProductProvider>(context, listen: false)
            .products
            .length
            .toString();
      default:
        return "0";
    }
  }
}

class QuickAccessCard extends StatelessWidget {
  final Function onTap;
  final String title;
  final Gradient gradient;
  final Size size;

  const QuickAccessCard({
    Key? key,
    required this.onTap,
    required this.title,
    required this.gradient,
    required this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 10, left: 10),
      width: size.width * .18,
      decoration: BoxDecoration(
        gradient: gradient,
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: ColorManager.boxShadowColor,
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(left: 10),
                height: 60,
                width: 80,
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0X00000029),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: WebsafeSvg.asset(
                  ImageAssets.consultingIcon,
                  fit: BoxFit.none,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  title,
                  style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      fontSize: FontSize.s15,
                      letterSpacing: 0.23,
                      color: Colors.white,
                      fontWeight: FontWeightManager.semiBold),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            left: 100,
            child: Container(
              height: 150,
              width: 150,
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0X00000029),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 70,
            child: Container(
              height: 150,
              width: 150,
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0X00000029),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
