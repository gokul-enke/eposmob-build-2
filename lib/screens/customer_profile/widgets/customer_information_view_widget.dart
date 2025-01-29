import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_detail_row.dart';
import 'package:pos_machine/models/customer_list.dart';
import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class CustomerInformationViewWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData? customer; // Add this line

  const CustomerInformationViewWidget({
    Key? key,
    required this.size,
    required this.customer, // Add this line
  }) : super(key: key);

  @override
  State<CustomerInformationViewWidget> createState() =>
      _CustomerInformationViewWidgetState();
}

class _CustomerInformationViewWidgetState
    extends State<CustomerInformationViewWidget> {
  @override
  Widget build(BuildContext context) {
    Size size = widget.size;
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(15),
        height: size.height * 0.75,
        circleRadius: 7,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: ListView(
            children: [
              // CustomBackButton(
              //   onPressed: () {
              //     sideBarController.index.value =
              //         15; // Adjust this value as needed for your customer list page
              //   },
              //   text: 'All Customers',
              // ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Customer Information",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              BuildBoxShadowContainer(
                height: size.height,
                margin: const EdgeInsets.only(
                    top: 0, bottom: 10, left: 10, right: 10),
                padding: const EdgeInsets.only(
                    top: 10, bottom: 10, left: 10, right: 10),
                circleRadius: 7,
                offsetValue: const Offset(1, 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BuildDetailRow(
                      title1: "Name",
                      content1: widget.customer!.name ?? "",
                      title2: "Email",
                      content2: widget.customer!.email ?? "",
                    ),
                    BuildDetailRow(
                      title1: "Phone",
                      content1: widget.customer!.phone ?? "",
                      title2: "Address",
                      content2: widget.customer!.name ?? "N/A",
                    ),
                    BuildDetailRow(
                      title1: "Customer ID",
                      content1: widget.customer!.id?.toString() ?? "",
                      title2: "Loyalty Points",
                      content2: "",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}













//     return SafeArea(
//       child: Container(
//         margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(22),
//           boxShadow: const [
//             BoxShadow(
//               color: ColorManager.boxShadowColor,
//               blurRadius: 6,
//               offset: Offset(1, 1),
//             ),
//           ],
//           color: Colors.white,
//         ),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
//           child: ListView(
//             children: [
//               CustomBackButton(
//                 onPressed: () {
//                   sideBarController.index.value =
//                       15; // Adjust this value as needed for your customer list page
//                 },
//                 text: 'All Customers',
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     "Customer Information",
//                     style: buildCustomStyle(FontWeightManager.semiBold,
//                         FontSize.s20, 0.30, ColorManager.textColor),
//                   ),
//                 ],
//               ),
//               Container(
//                 height: 60,
//                 decoration: const BoxDecoration(
//                   color: ColorManager.kPrimaryColor,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(7),
//                     topRight: Radius.circular(7),
//                   ),
//                 ),
//                 padding: const EdgeInsets.only(
//                   left: 20,
//                   top: 20,
//                 ),
//                 margin: const EdgeInsets.only(
//                     top: 20, bottom: 0, left: 10, right: 10),
//                 child: Text(
//                   "Customer Details",
//                   style: buildCustomStyle(FontWeightManager.semiBold,
//                       FontSize.s15, 0.30, Colors.white),
//                 ),
//               ),
//               BuildBoxShadowContainer(
//                 height: size.height,
//                 margin: const EdgeInsets.only(
//                     top: 0, bottom: 10, left: 10, right: 10),
//                 padding: const EdgeInsets.only(
//                     top: 10, bottom: 10, left: 10, right: 10),
//                 circleRadius: 7,
//                 offsetValue: const Offset(1, 1),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     BuildDetailRow(
//                       title1: "Name",
//                       content1: widget.customer!!.name ?? "",
//                       title2: "Email",
//                       content2: widget.customer!.email ?? "",
//                     ),
//                     BuildDetailRow(
//                       title1: "Phone",
//                       content1: widget.customer!.phone ?? "",
//                       title2: "Address",
//                       content2: widget.customer!.name ?? "N/A",
//                     ),
//                     BuildDetailRow(
//                       title1: "Customer ID",
//                       content1: widget.customer!.id?.toString() ?? "",
//                       title2: "Loyalty Points",
//                       content2: "",
//                     ),
//                     const SizedBox(height: 20),
//                     const Text(
//                       "Recent Orders",
//                       style: TextStyle(
//                         fontSize: FontSize.s16,
//                         fontWeight: FontWeightManager.semiBold,
//                       ),
//                     ),
//                     // Add a list of recent orders here if available
//                     const SizedBox(height: 50),
//                     Padding(
//                       padding: const EdgeInsets.only(left: 10.0),
//                       child: CustomRoundButton(
//                         title: "Back",
//                         boxColor: Colors.white,
//                         textColor: ColorManager.kPrimaryColor,
//                         fct: () async {
//                           sideBarController.index.value =
//                               15; // Adjust this value as needed for your customer list page
//                         },
//                         height: 50,
//                         width: size.width * 0.19,
//                         fontSize: FontSize.s12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
