import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';
import 'package:provider/provider.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final TextEditingController amountRefController = TextEditingController();
  //final TextEditingController dateController = TextEditingController();
  SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  List<ListTransaction>? listTransaction = [];
  String searchAmount = '';
  String searchDate = '';
  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      await invoiceProvider
          .listAllTransaction(type: null, accessToken: accessToken ?? "")
          .then((value) {
        if (value['status'] == 'success') {
          ListTransactionModel listTransactionModel =
              ListTransactionModel.fromJson(value);
          listTransaction = listTransactionModel.data?.transactions ?? [];
        } else {
          showScaffold(context: context, message: "Data Not Found");
        }
      });
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  Widget _buildFilterField({
    required String label,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: TextFormField(
            onChanged: (value) {
              setState(() {
                searchAmount = value;
              });
            },
            cursorColor: ColorManager.kPrimaryColor,
            cursorHeight: 13,
            controller: amountRefController,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              ColorManager.textColor,
            ),
            decoration: decoration.copyWith(
              hintText: hintText,
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              prefixIconColor: Colors.black,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    InvoiceProvider invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final isCompact = size.width < kSettingsPhoneBreakpoint;

    return SettingsPageShell(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsPageHeader(
            title: 'Location Management',
            subtitle: 'Search and manage location records',
          ),
          const SizedBox(height: 16),
          SettingsFilterWrap(
            actions: [
              CustomRoundButton(
                title: 'Search',
                fct: () async {},
                height: 48,
                width: isCompact ? double.infinity : 120,
                fontSize: FontSize.s12,
              ),
              CustomRoundButton(
                title: 'Reset',
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: () async {
                  amountRefController.clear();
                  setState(() {
                    searchAmount = '';
                  });
                  // sideBarController.index.value = 22;
                },
                height: 48,
                width: isCompact ? double.infinity : 120,
                fontSize: FontSize.s12,
              ),
            ],
            children: [
              _buildFilterField(label: 'State', hintText: 'State'),
              _buildFilterField(label: 'District', hintText: 'District'),
              _buildFilterField(label: 'Pincode', hintText: 'Pincode'),
              _buildFilterField(
                label: 'Location Name',
                hintText: 'Location Name',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionHeader(title: 'Location Records'),
          const SizedBox(height: 10),
          SettingsResponsiveTable(
              minWidth: 720,
              table: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(0.8),
                },
                border: const TableBorder.symmetric(
                  outside: BorderSide(
                    color: ColorManager.tableBOrderColor,
                    width: 0.3,
                  ),
                  inside: BorderSide(
                    color: ColorManager.tableBOrderColor,
                    width: 0.8,
                  ),
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      color: ColorManager.tableBGColor,
                    ),
                    children: [
                      _buildHeaderCell('Name'),
                      _buildHeaderCell('Type'),
                      _buildHeaderCell('Amount'),
                      _buildHeaderCell('Status'),
                      _buildHeaderCell('Action'),
                    ],
                  ),
                  ...listTransaction!.where((transaction) {
                    return transaction.amount!.contains(searchAmount);
                  }).map((transaction) {
                    String? userName = invoiceProvider
                        .getUserUpOnId(transaction.orderId ?? 1);

                    return TableRow(
                      children: [
                        _buildDataCell(userName ?? ''),
                        _buildDataCell('${transaction.type}'),
                        _buildDataCell('${transaction.amount}'),
                        _buildDataCell('${transaction.status}'),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Center(
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: BuildBoxShadowContainer(
                                  circleRadius: 8,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.visibility,
                                      size: 18,
                                      color: ColorManager.kPrimaryColor
                                          .withOpacity(0.9),
                                    ),
                                    onPressed: () {
                                      invoiceProvider
                                          .callDetailsOfTransaction(
                                        id: transaction.id ?? 0,
                                        accessToken: token ?? '',
                                      );
                                      sideBarController.index.value = 30;
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Center(
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String value) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Center(
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
