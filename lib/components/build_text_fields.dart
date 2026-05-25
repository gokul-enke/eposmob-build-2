import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_title.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

class BuildTextField extends StatelessWidget {
  final Size size;
  final TextEditingController controller;
  final String? hintText;
  const BuildTextField(
      {super.key, required this.size, required this.controller, this.hintText});

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      padding: const EdgeInsets.only(left: 15),
      height: size.height * .07,
      width: size.width / 3,
      child: TextFormField(
        readOnly: true,
        keyboardType: TextInputType.text,
        cursorColor: ColorManager.kPrimaryColor,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText ?? '',
          hintStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            ColorManager.textColor.withOpacity(.5),
          ),
        ),
        controller: controller,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.27,
          ColorManager.textColor.withOpacity(.5),
        ),
      ),
    );
  }
}

class BuildTextFieldColumn extends StatelessWidget {
  final Size size;
  final TextEditingController controller;
  final String? hintText;
  final bool? isStarRed;
  final bool? isDouble;
  final bool isLeft;
  final bool? isTextField;
  final bool? read;
  final String title;
  final int? maxlines;
  final TextInputType? textInputType;
  final String? isDoubleTitle;
  final String? isDoubleHintText;
  final TextEditingController? isDoubleontroller;
  final String? Function(String?)? validator; // New validator parameter

  const BuildTextFieldColumn({
    Key? key,
    required this.size,
    this.maxlines,
    this.read,
    this.textInputType,
    required this.controller,
    this.hintText,
    required this.title,
    this.isStarRed,
    this.isTextField,
    required this.isLeft,
    this.isDouble,
    this.isDoubleTitle,
    this.isDoubleHintText,
    this.isDoubleontroller,
    this.validator, // Add validator to constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isDouble == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                isStarRed: isStarRed ?? false,
                isTextField: isTextField ?? false,
                title: title,
                textStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              BuildBoxShadowContainer(
                circleRadius: 7,
                alignment: Alignment.centerLeft,
                margin: isLeft
                    ? const EdgeInsets.only(left: 20)
                    : const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                padding: isLeft
                    ? const EdgeInsets.only(left: 15)
                    : const EdgeInsets.only(left: 15),
                height: maxlines == null ? size.height * .07 : size.height * .1,
                width: size.width / 3,
                child: TextFormField(
                  maxLines: maxlines ?? 1,
                  readOnly: read ?? true,
                  keyboardType: textInputType ?? TextInputType.text,
                  cursorColor: ColorManager.kPrimaryColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText ?? '',
                    hintStyle: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                  controller: controller,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                  validator: validator, // Apply validator
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                isStarRed: isStarRed ?? false,
                isTextField: isTextField ?? false,
                title: title,
                textStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              Column(
                children: [
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.centerLeft,
                    margin: isLeft
                        ? const EdgeInsets.only(left: 20)
                        : const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 0),
                    padding: isLeft
                        ? const EdgeInsets.only(left: 15)
                        : const EdgeInsets.only(left: 15),
                    height: size.height * .07,
                    width: size.width / 3,
                    child: TextFormField(
                      readOnly: read ?? true,
                      maxLines: maxlines ?? 1,
                      keyboardType: textInputType ?? TextInputType.text,
                      cursorColor: ColorManager.kPrimaryColor,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: hintText ?? '',
                        hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                      controller: controller,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      validator: validator, // Apply validator
                    ),
                  ),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.centerLeft,
                    margin: isLeft
                        ? const EdgeInsets.only(left: 20, top: 10)
                        : const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 0),
                    padding: isLeft
                        ? const EdgeInsets.only(left: 15)
                        : const EdgeInsets.only(left: 15),
                    height: size.height * .07,
                    width: size.width / 3,
                    child: TextFormField(
                      readOnly: true,
                      maxLines: maxlines ?? 1,
                      keyboardType: TextInputType.text,
                      cursorColor: ColorManager.kPrimaryColor,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: isDoubleHintText ?? '',
                        hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                      controller: isDoubleontroller,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      validator: validator, // Apply validator
                    ),
                  ),
                ],
              ),
            ],
          );
  }
}

class BuildTextFieldColumn3 extends StatelessWidget {
  final Size size;
  final TextEditingController controller;
  final String? hintText;
  final bool? isStarRed;
  final bool? isDouble;
  final bool? isDatePicker;
  final bool isLeft;
  final bool? isRead;
  final bool? isTextField;
  final String title;
  final TextInputType? textInputType;
  final String? isDoubleTitle;
  final String? isDoubleHintText;
  final TextEditingController? isDoubleontroller;
  const BuildTextFieldColumn3(
      {super.key,
      required this.size,
      this.isRead,
      this.textInputType,
      required this.controller,
      this.hintText,
      this.isDatePicker,
      required this.title,
      this.isStarRed,
      this.isTextField,
      required this.isLeft,
      this.isDouble,
      this.isDoubleTitle,
      this.isDoubleHintText,
      this.isDoubleontroller});

  @override
  Widget build(BuildContext context) {
    return isDouble == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                isStarRed: isStarRed ?? false,
                isTextField: isTextField ?? false,
                title: title,
                textStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              isDatePicker == null
                  ? BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: isLeft
                          ? const EdgeInsets.only(left: 20)
                          : const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 0),
                      padding: isLeft
                          ? const EdgeInsets.only(left: 15)
                          : const EdgeInsets.only(left: 15),
                      height: size.height * .07,
                      width: size.width / 4.5,
                      child: TextFormField(
                        readOnly: isRead ?? false,
                        keyboardType: textInputType ?? TextInputType.text,
                        cursorColor: ColorManager.kPrimaryColor,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: hintText ?? '',
                          hintStyle: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.27,
                            ColorManager.textColor.withOpacity(.5),
                          ),
                        ),
                        controller: controller,
                        // validator: (value) {
                        //   if (value == null || value.isEmpty) {
                        //     return 'This field is required';
                        //   }
                        //   return null;
                        // },
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                    )
                  : BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 0),
                      height: size.height * .07,
                      width: size.width / 4.5,
                      child: Container(
                        height: size.height * .06,
                        width: size.width / 4.3,
                        margin: isLeft
                            ? const EdgeInsets.only(left: 8)
                            : const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 0),
                        child: CalendarPickerTableCell(
                          onDateSelected: (date) {
                            // debugPrint(date.toString());
                            controller.text =
                                DateFormat('yyyy-MM-dd').format(date);
                            // debugPrint(DateFormat('yyyy-MM-dd').format(date));
                          },
                        ),
                      ),
                    ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                isStarRed: isStarRed ?? false,
                isTextField: isTextField ?? false,
                title: title,
                textStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              Column(
                children: [
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.centerLeft,
                    margin: isLeft
                        ? const EdgeInsets.only(left: 20)
                        : const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 0),
                    padding: isLeft
                        ? const EdgeInsets.only(left: 15)
                        : const EdgeInsets.only(left: 15),
                    height: size.height * .07,
                    width: size.width / 4.5,
                    child: TextFormField(
                      readOnly: true,
                      keyboardType: TextInputType.text,
                      cursorColor: ColorManager.kPrimaryColor,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: hintText ?? '',
                        hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                      controller: controller,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.centerLeft,
                    margin: isLeft
                        ? const EdgeInsets.only(left: 20, top: 10)
                        : const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 0),
                    padding: isLeft
                        ? const EdgeInsets.only(left: 15)
                        : const EdgeInsets.only(left: 15),
                    height: size.height * .07,
                    width: size.width / 4.5,
                    child: TextFormField(
                      readOnly: true,
                      keyboardType: TextInputType.text,
                      cursorColor: ColorManager.kPrimaryColor,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: isDoubleHintText ?? '',
                        hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                      controller: isDoubleontroller,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
  }
}

DateTime parseDate(String date) {
  try {
    return DateFormat("dd/MM/yyyy").parse(date);
  } catch (e) {
    // debugPrint("Error parsing date: $e");
    return DateTime.now();
  }
}

class BuildDropDownStatic extends StatelessWidget {
  final Size size;
  final bool? isSmall;
  final bool? isStarRed;
  final bool? isStar;
  final bool? isLeft;
  final bool? isWidth;
  final List<String> items;
  final String? selectedItem;
  final String hintText;
  final String title;
  final void Function(String?)? onChanged;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const BuildDropDownStatic(
      {super.key,
      required this.size,
      this.isSmall,
      this.isStar,
      this.isLeft,
      this.isWidth,
      required this.items,
      required this.selectedItem,
      required this.hintText,
      this.isStarRed,
      required this.onChanged,
      required this.title,
      this.height,
      this.width,
      this.margin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: title,
          isStarRed: isStarRed ?? false,
          isTextField: isStar ?? false,
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: margin ??
              (isLeft != null
                  ? const EdgeInsets.only(left: 20)
                  : const EdgeInsets.symmetric(horizontal: 05, vertical: 0)),
          padding: const EdgeInsets.only(left: 15),
          height: height ?? size.height * .07,
          width: width ?? (isWidth == null ? size.width / 3 : size.width / 4.5),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: InputBorder.none, // Remove the underline
            ),
            initialValue: selectedItem,
            hint: Text(
              hintText,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            icon: const Icon(Icons.arrow_drop_down),
            iconSize: 24,
            elevation: 16,
            onChanged: onChanged,
            items: items
                .map((String unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(
                      unit,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                  );
                })
                .toSet()
                .toList(),
          ),
        ),
      ],
    );
  }
}

Widget buildColumnWidgetForTextFields({
  Key? key,
  TextEditingController? controller,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  required Size size,
  double? width,
  double? height,
  bool isStarRed = false,
  EdgeInsetsGeometry? margin,
  bool isLeft = false,
  bool readOnly = false,
  String? title,
  void Function(String?)? onchanged,
  void Function(String?)? onSubmitted,
  required String hintText,
  String? Function(String?)? validator,
  FocusNode? focusNode,
  bool autofocus = false,
  VoidCallback? onTap,
  bool useSystemKeyboard = true,
}) =>
    Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          BuildTextTile(
            title: title,
            isStarRed: isStarRed,
            textStyle: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: !isLeft
              ? margin ?? const EdgeInsets.symmetric(horizontal: 5, vertical: 0)
              : const EdgeInsets.only(left: 20),
          padding: const EdgeInsets.only(left: 15),
          height: height ?? size.height * .07,
          width: width ?? size.width / 3, //3.05,
          child: TextFormField(
            onTap: onTap,
            onChanged: onchanged,
            onFieldSubmitted: onSubmitted,
            autofocus: autofocus,
            focusNode: focusNode,
            readOnly: readOnly || !useSystemKeyboard,
            keyboardType: useSystemKeyboard
                ? (keyboardType ?? TextInputType.text)
                : TextInputType.none,
            inputFormatters: inputFormatters,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s11,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
                errorStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red, // Red color for error message
                )
                // .copyWith(height: 2), // Adjust line height for spacing
                // contentPadding: const EdgeInsets.only(top: 0, bottom: 10.0),
                ),
            controller: controller,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s13,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
            validator: validator, // Apply the validator
          ),
        ),
      ],
    );
