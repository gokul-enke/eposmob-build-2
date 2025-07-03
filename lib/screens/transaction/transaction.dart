import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/transaction_model.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/screens/transaction/widgets/transaction_table.dart';
import 'package:pos_machine/components/build_pagination_control.dart';

import '../../components/build_container_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/custom_icons.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TextEditingController searchTextController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch API data on screen load
    Future.microtask(() {
      Provider.of<TransactionProvider>(context, listen: false)
          .fetchTransactions();
    });

    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    searchTextController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener is no longer needed with pagination control
  void _scrollListener() {
    // Empty implementation - we're using pagination control now
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final provider = Provider.of<TransactionProvider>(context);
    final transactions = provider.transactions;
    final isLoading = provider.isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Transactions ",
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: size.height * 0.07,
                  width: size.width * 0.5,
                  child: TextField(
                    controller: searchTextController,
                    cursorColor: ColorManager.kPrimaryColor,
                    onChanged: (value) {
                      Provider.of<TransactionProvider>(context, listen: false)
                          .searchTransactions(value);
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Search Transactions...",
                      hintStyle: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        ColorManager.textColor,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.black,
                        size: 35,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    height: size.height * 0.04,
                    width: size.width * 0.09,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: ColorManager.boxShadowColor,
                          blurRadius: 6,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          visualDensity:
                              const VisualDensity(horizontal: 0, vertical: 1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  title: Text(
                                    "Filter by Status",
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s14,
                                      0.2,
                                      Colors.black,
                                    ),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              Provider.of<TransactionProvider>(
                                                      context,
                                                      listen: false)
                                                  .filterByStatus("SUCC");
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text("Success"),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () {
                                              Provider.of<TransactionProvider>(
                                                      context,
                                                      listen: false)
                                                  .filterByStatus("INIT");
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text("Initiated"),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () {
                                              Provider.of<TransactionProvider>(
                                                      context,
                                                      listen: false)
                                                  .resetFilters();
                                              searchTextController.clear();
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text("Reset"),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Close"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: const Icon(
                            CustomIcons.iconFilterList,
                            color: Colors.black,
                            size: 10,
                          ),
                        ),
                        Text(
                          "Filters",
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s12,
                            0.27,
                            Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 30.0, right: 30.0),
            child: Divider(thickness: 2),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: TransactionTableWidget(
                      transactions: transactions,
                      isLoading: isLoading,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Add pagination control similar to stock.dart
                PaginationControl(
                  currentPage: provider.currentPage,
                  totalPages: provider.totalPages,
                  onPageChanged: (int page) {
                    provider.goToTransactionPage(page);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
