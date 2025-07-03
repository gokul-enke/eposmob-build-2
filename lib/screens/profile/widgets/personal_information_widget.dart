// import 'package:flutter/material.dart';

// import '../../../components/add_radio_button.dart';
// import '../../../components/build_container_box.dart';
// import '../../../components/build_title.dart';
// import '../../../resources/color_manager.dart';
// import '../../../resources/font_manager.dart';
// import '../../../resources/style_manager.dart';

// class PersonalInformationWidget extends StatefulWidget {
//   final Size size;
//   const PersonalInformationWidget({super.key, required this.size});

//   @override
//   State<PersonalInformationWidget> createState() =>
//       _PersonalInformationWidgetState();
// }

// class _PersonalInformationWidgetState extends State<PersonalInformationWidget> {
//   Gender selectedGender = Gender.Male;
//   final firstNameTextController = TextEditingController();
//   final lastNameTextController = TextEditingController();
//   final emailTextController = TextEditingController();
//   final phoneNumberController = TextEditingController();
//   final addressTextController = TextEditingController();

//   Gender? gender;
//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//     gender = selectedGender;
//     return Expanded(
//       child: BuildBoxShadowContainer(
//           margin: const EdgeInsets.all(24),
//           padding: const EdgeInsets.all(15),
//           height: size.height * 0.75, //180,
//           // width: 220,
//           circleRadius: 7,
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 10),
//                 Text(
//                   "Personal Information",
//                   style: buildCustomStyle(FontWeightManager.semiBold,
//                       FontSize.s15, 0.23, ColorManager.textColor),
//                 ),
//                 const SizedBox(height: 20),
//                 const Text(
//                   "Lorem Ipsum is simply dummy text of the printing and typesetting industry.Lorem Ipsum has been the industry's standard dummy text ever since the 1500s",
//                   style: TextStyle(
//                       fontWeight: FontWeightManager.regular,
//                       fontFamily: FontConstants.fontFamily,
//                       fontSize: FontSize.s10,
//                       letterSpacing: 0.13,
//                       color: ColorManager.blackWithOpacity50),
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     SizedBox(
//                       width: 100,
//                       child: AddRadioButton(
//                           title: Gender.Male.name,
//                           value: Gender.Male,
//                           selectedTypeOfAddressEnum: gender,
//                           onChanged: (value) {
//                             setState(() {
//                               gender = value;
//                               selectedGender = value!;
//                             });
//                           }),
//                     ),
//                     const SizedBox(width: 50),
//                     SizedBox(
//                       width: 120,
//                       child: AddRadioButton(
//                           title: Gender.Female.name,
//                           value: Gender.Female,
//                           selectedTypeOfAddressEnum: gender,
//                           onChanged: (value) {
//                             setState(() {
//                               gender = value;
//                               selectedGender = value!;
//                             });
//                           }),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 15),
//                 Row(
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         BuildTitle(
//                           title: "First Name",
//                           textStyle: buildCustomStyle(
//                             FontWeightManager.regular,
//                             FontSize.s10,
//                             0.16,
//                             Colors.black.withOpacity(0.6),
//                           ),
//                         ),
//                         BuildBoxShadowContainer(
//                           circleRadius: 7,
//                           alignment: Alignment.centerLeft,
//                           margin: const EdgeInsets.only(
//                               top: 15, left: 0, right: 10, bottom: 20),
//                           padding: const EdgeInsets.only(left: 15),
//                           height: size.height * .07,
//                           width: size.width / 5.8,
//                           child: TextFormField(
//                             //  initialValue: initialValue,
//                             keyboardType: TextInputType.text,
//                             cursorColor: ColorManager.kPrimaryColor,
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                               hintText: "First Name",
//                               hintStyle: buildCustomStyle(
//                                 FontWeightManager.regular,
//                                 FontSize.s10,
//                                 0.16,
//                                 Colors.black.withOpacity(0.6),
//                               ),
//                             ),
//                             controller: firstNameTextController,
//                             style: buildCustomStyle(
//                               FontWeightManager.medium,
//                               FontSize.s13,
//                               0.27,
//                               ColorManager.textColor.withOpacity(.5),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         BuildTitle(
//                           title: "Last Name",
//                           textStyle: buildCustomStyle(
//                             FontWeightManager.regular,
//                             FontSize.s10,
//                             0.16,
//                             Colors.black.withOpacity(0.6),
//                           ),
//                         ),
//                         BuildBoxShadowContainer(
//                           circleRadius: 7,
//                           alignment: Alignment.centerLeft,
//                           margin: const EdgeInsets.only(
//                               top: 15, left: 10, right: 0, bottom: 20),
//                           padding: const EdgeInsets.only(left: 15),
//                           height: size.height * .07,
//                           width: size.width / 5.8,
//                           child: TextFormField(
//                             //  initialValue: initialValue,

//                             keyboardType: TextInputType.text,
//                             cursorColor: ColorManager.kPrimaryColor,
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                               hintText: "Last Name",
//                               hintStyle: buildCustomStyle(
//                                 FontWeightManager.regular,
//                                 FontSize.s10,
//                                 0.16,
//                                 Colors.black.withOpacity(0.6),
//                               ),
//                             ),
//                             controller: lastNameTextController,
//                             style: buildCustomStyle(
//                               FontWeightManager.medium,
//                               FontSize.s13,
//                               0.27,
//                               ColorManager.textColor.withOpacity(.5),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 BuildTitle(
//                   title: "Email Address",
//                   textStyle: buildCustomStyle(
//                     FontWeightManager.regular,
//                     FontSize.s10,
//                     0.16,
//                     Colors.black.withOpacity(0.6),
//                   ),
//                 ),
//                 BuildBoxShadowContainer(
//                   circleRadius: 7,
//                   alignment: Alignment.centerLeft,
//                   margin: const EdgeInsets.only(
//                       left: 0, right: 10, top: 15, bottom: 10),
//                   padding: const EdgeInsets.only(left: 15),
//                   height: size.height * .07,
//                   width: size.width / 2.8, //size.width,
//                   child: TextFormField(
//                     //  initialValue: initialValue,
//                     keyboardType: TextInputType.text,
//                     cursorColor: ColorManager.kPrimaryColor,
//                     decoration: const InputDecoration(
//                       border: InputBorder.none,
//                     ),
//                     controller: emailTextController,
//                     style: buildCustomStyle(
//                       FontWeightManager.medium,
//                       FontSize.s13,
//                       0.27,
//                       ColorManager.textColor.withOpacity(.5),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 15),
//                 Row(
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         BuildTitle(
//                           title: "Phone Number",
//                           textStyle: buildCustomStyle(
//                             FontWeightManager.regular,
//                             FontSize.s10,
//                             0.16,
//                             Colors.black.withOpacity(0.6),
//                           ),
//                         ),
//                         BuildBoxShadowContainer(
//                           circleRadius: 7,
//                           alignment: Alignment.centerLeft,
//                           margin: const EdgeInsets.only(
//                               top: 15, left: 0, right: 10, bottom: 20),
//                           padding: const EdgeInsets.only(left: 15),
//                           height: size.height * .07,
//                           width: size.width / 5.8,
//                           child: TextFormField(
//                             //  initialValue: initialValue,
//                             keyboardType: TextInputType.text,
//                             cursorColor: ColorManager.kPrimaryColor,
//                             decoration: const InputDecoration(
//                               border: InputBorder.none,
//                             ),
//                             controller: phoneNumberController,
//                             style: buildCustomStyle(
//                               FontWeightManager.medium,
//                               FontSize.s13,
//                               0.27,
//                               ColorManager.textColor.withOpacity(.5),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         BuildTitle(
//                           title: "Address",
//                           textStyle: buildCustomStyle(
//                             FontWeightManager.regular,
//                             FontSize.s10,
//                             0.16,
//                             Colors.black.withOpacity(0.6),
//                           ),
//                         ),
//                         BuildBoxShadowContainer(
//                           circleRadius: 7,
//                           alignment: Alignment.centerLeft,
//                           margin: const EdgeInsets.only(
//                               top: 15, left: 10, right: 0, bottom: 20),
//                           padding: const EdgeInsets.only(left: 15),
//                           height: size.height * .07,
//                           width: size.width / 5.8,
//                           child: TextFormField(
//                             //  initialValue: initialValue,
//                             keyboardType: TextInputType.text,
//                             cursorColor: ColorManager.kPrimaryColor,
//                             decoration: const InputDecoration(
//                               border: InputBorder.none,
//                             ),
//                             controller: addressTextController,
//                             style: buildCustomStyle(
//                               FontWeightManager.medium,
//                               FontSize.s13,
//                               0.27,
//                               ColorManager.textColor.withOpacity(.5),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//               ],
//             ),
//           )),
//     );
//   }
// }
//   // Text(
//   //                 'Selected Gender: ${selectedGender.toString().split('.').last}'),