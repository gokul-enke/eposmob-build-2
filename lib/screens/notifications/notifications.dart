import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/build_container_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/notification_list_tile.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<bool> isExpandedList = [false, false, false];
  UniqueKey keyTile = UniqueKey();
  bool expanded = false; // Initial expansion states for each tile

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: BuildBoxShadowContainer(
        circleRadius: 22,
        margin: const EdgeInsets.only(bottom: 0, top: 30),
        blurRadius: 6,
        padding:
            const EdgeInsets.only(left: 20.0, right: 20, top: 30, bottom: 20),
        offsetValue: const Offset(1, 1),
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 10.0, bottom: 10),
              child: Text(
                'notifications.page_title'.tr,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
              ),
            ),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                NotificationListTileWidget(
                  itemsCount: 3,
                  size: size,
                  card: "Debit Card",
                  orderNumber: "34545656",
                  index: 0,
                  amount: "115",
                  time: "10m ago",
                  success: true,
                  indexExpand: isExpandedList[0],
                  subTitle: 'has been paid successfully',
                ),
                NotificationListTileWidget(
                  size: size,
                  itemsCount: 2,
                  orderNumber: "34545657",
                  index: 1,
                  card: "",
                  success: false,
                  amount: "",
                  subTitle: "has 2 items canceled",
                  indexExpand: isExpandedList[1],
                  time: '20m ago',
                ),
                NotificationListTileWidget(
                  itemsCount: 3,
                  size: size,
                  card: "cash",
                  orderNumber: "34545656",
                  index: 0,
                  amount: "3.15",
                  time: "30m ago",
                  success: true,
                  indexExpand: isExpandedList[0],
                  subTitle: 'has been paid successfully',
                ),
                NotificationListTileWidget(
                  size: size,
                  itemsCount: 2,
                  orderNumber: "34545659",
                  index: 1,
                  card: "",
                  success: false,
                  amount: "",
                  subTitle: "has 2 items canceled",
                  indexExpand: isExpandedList[1],
                  time: '50m ago',
                ),
                NotificationListTileWidget(
                  size: size,
                  itemsCount: 3,
                  orderNumber: "34545660",
                  index: 1,
                  card: "Cash",
                  success: true,
                  amount: "112",
                  subTitle: "has been paid successfully",
                  indexExpand: isExpandedList[1],
                  time: '1hour ago',
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
