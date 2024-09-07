import 'package:flutter/material.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

// void showErrorDialog({required String error, required BuildContext ctx}) {
//   showCupertinoDialog(
//       barrierDismissible: true,
//       context: ctx,
//       builder: (context) {
//         return AlertDialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//           title: Row(
//             children: [
//               const Padding(
//                 padding: EdgeInsets.all(8.0),
//                 child: Icon(
//                   Icons.error_outline_rounded,
//                   color: ColorManager.kPrimaryColor,
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text(
//                   'Error Occurred ',
//                   style: buildCustomStyle(FontWeightManager.bold, FontSize.s13,
//                       0.11, ColorManager.kPrimaryColor),
//                 ),
//               ),
//             ],
//           ),
//           content: Text(
//             error,
//             style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
//                 0.11, ColorManager.textColor),
//           ),
//           actions: [
//             Center(
//               child: CustomRoundButton(
//                   title: "Ok",
//                   fct: () {
//                     Navigator.canPop(context) ? Navigator.pop(context) : null;
//                   },
//                   radius: 10,
//                   height: 40,
//                   width: 100,
//                   fontSize: FontSize.s12),
//             ),
//           ],
//         );
//       });
// }

ScaffoldMessengerState showScaffold({required BuildContext context, message}) {
  return ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.up,
        closeIconColor: Colors.white,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: EdgeInsets.only(
            top: 50, left: MediaQuery.of(context).size.width / 1.9, right: 10),
        backgroundColor: ColorManager.kSuccessColor.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          message, //  'Added To Cart',
          style: buildCustomStyle(
              FontWeightManager.medium, FontSize.s12, 0.12, Colors.white),
        )));
}

ScaffoldMessengerState showScaffoldError(
    {required BuildContext context, required String message}) {
  return ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.up,
        closeIconColor: Colors.white,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: EdgeInsets.only(
            top: 50, left: MediaQuery.of(context).size.width / 1.9, right: 10),
        backgroundColor: ColorManager.kErrorColor.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          message, //  'Added To Cart',
          style: buildCustomStyle(
              FontWeightManager.medium, FontSize.s12, 0.12, Colors.white),
        )));
}
