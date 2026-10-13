part of '../../pages/add_category_page.dart';

/// Existing image/icon picker dialogs and selection callbacks.
mixin CategoryAddMediaDialogs<T extends StatefulWidget>
    on State<T>, CategoryAddFormState<T>, CategoryFormMixin<T> {
  showDialogFunctionForCategoryImageDetails(BuildContext context,
      final List<GetProductListFileModelData>? attachment, Size size) {
    // debugPrint("showDialogFunctionForProductDetailsAnimated");
    return showDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "",
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            final isPhone = categoryIsPhone(context);
            final dialogWidth = categoryDialogWidth(context);
            final dialogHeight = categoryDialogHeight(context);
            final uploadButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.12;
            final actionButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.19;

            return Center(
              child: SizedBox(
                height: dialogHeight,
                width: dialogWidth,
                child: Material(
                  type: MaterialType.transparency,
                  child: BuildBoxShadowContainer(
                      circleRadius: 14,
                      padding: EdgeInsets.all(isPhone ? 12 : 16),
                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
                      color: Colors.white,
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'category.dialog_select_image'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s16,
                                          0.18,
                                          ColorManager.kTitleTextColor,
                                        ),
                                      ),
                                    ),
                                    CategoryDialogCloseButton(
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title:
                                                'category.btn_upload_device'.tr,
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  imageFilePathController.text =
                                                      result.files.single
                                                              .path ??
                                                          '';
                                                  _selectedImagePath =
                                                      result.files.single.path;
                                                  _imageError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          if (_selectedImagePath != null) ...[
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedImagePath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          CustomRoundButton(
                                            title:
                                                'category.btn_upload_device'.tr,
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  imageFilePathController.text =
                                                      result.files.single
                                                              .path ??
                                                          '';
                                                  _selectedImagePath =
                                                      result.files.single.path;
                                                  _imageError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(width: 16),
                                          if (_selectedImagePath != null)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedImagePath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                              if (isPhone && attachment != null)
                                ...attachment.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final image = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: BuildBoxShadowContainer(
                                      circleRadius: 10,
                                      border: Border.all(
                                          color: Colors.grey.withOpacity(0.12)),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Radio<int>(
                                            value: index,
                                            groupValue: selectedImageIndex,
                                            onChanged: (int? value) {
                                              setState(() {
                                                selectedImageIndex = value ?? 0;
                                              });
                                              debugPrint(
                                                  "showDialog $index $selectedImageIndex");
                                              imageFilePathController.text =
                                                  image.id.toString();
                                              imageAltController.text =
                                                  image.alt ?? "";
                                              imageTitleController.text =
                                                  image.title ?? "";
                                            },
                                          ),
                                          Expanded(
                                            child: Text(
                                              "${image.title}",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          BuildBoxShadowContainer(
                                            margin: const EdgeInsetsDirectional
                                                .only(start: 5, end: 5),
                                            circleRadius: 5,
                                            height: 48,
                                            width: 48,
                                            child: Image.network(
                                              image.s3Url ?? "",
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              if (!isPhone)
                                SizedBox(
                                  width: dialogWidth,
                                  child: Table(
                                    columnWidths: const {
                                      0: FractionColumnWidth(0.01),
                                      1: FractionColumnWidth(0.01),
                                      2: FractionColumnWidth(0.1),
                                      3: FractionColumnWidth(0.06),
                                      4: FractionColumnWidth(0.06),
                                      5: FractionColumnWidth(0.05),
                                    },
                                    border: const TableBorder.symmetric(
                                        outside: BorderSide(
                                            color:
                                                ColorManager.tableBOrderColor,
                                            width: 0.3),
                                        inside: BorderSide(
                                            color:
                                                ColorManager.tableBOrderColor,
                                            width: 0.8)),
                                    defaultVerticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    children: [
                                      TableRow(
                                          decoration: const BoxDecoration(
                                              color: ColorManager.tableBGColor),
                                          children: [
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                      child: Text(
                                                    'category.tbl_select'.tr,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.18,
                                                      ColorManager
                                                          .kPrimaryColor,
                                                    ),
                                                  )),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                      child: Text(
                                                    'category.tbl_image_title'
                                                        .tr,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.18,
                                                      ColorManager
                                                          .kPrimaryColor,
                                                    ),
                                                  )),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                      child: Text(
                                                    'category.tbl_preview'.tr,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.18,
                                                      ColorManager
                                                          .kPrimaryColor,
                                                    ),
                                                  )),
                                                )),
                                          ]),

                                      // Map your order data to table rows here
                                      // ...imageFiles!.map((image) {
                                      if (attachment != null)
                                        ...attachment
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final image = entry.value;
                                          return TableRow(
                                            children: [
                                              TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15.0),
                                                    child: Center(
                                                      child: Radio<int>(
                                                        value: index,
                                                        groupValue:
                                                            selectedImageIndex,
                                                        onChanged:
                                                            (int? value) {
                                                          // Set the selected image index
                                                          setState(() {
                                                            selectedImageIndex =
                                                                value ?? 0;
                                                          });

                                                          debugPrint(
                                                              "showDialog $index $selectedImageIndex");
                                                          imageFilePathController
                                                                  .text =
                                                              image.id
                                                                  .toString();
                                                          imageAltController
                                                                  .text =
                                                              image.alt ?? "";
                                                          imageTitleController
                                                                  .text =
                                                              image.title ?? "";
                                                          // Perform any other action if needed
                                                        },
                                                      ),
                                                    ),
                                                  )),
                                              TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15.0),
                                                    child: Center(
                                                      child: Text(
                                                        "${image.title}",
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .medium,
                                                          FontSize.s9,
                                                          0.13,
                                                          Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  )),
                                              TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15.0),
                                                    child: Center(
                                                      child:
                                                          BuildBoxShadowContainer(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 5,
                                                                      right: 5),
                                                              circleRadius: 5,
                                                              child:
                                                                  Image.network(
                                                                image.s3Url ??
                                                                    "",
                                                                fit: BoxFit
                                                                    .cover,
                                                              )),
                                                    ),
                                                  )),
                                            ],
                                          );
                                        }).toList(),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title: 'category.btn_cancel'.tr,
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(height: 10),
                                          CustomRoundButton(
                                            title: 'category.btn_choose'.tr,
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: 'category.btn_cancel'.tr,
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: 'category.btn_choose'.tr,
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ),
              ),
            );
          });
        });
  }

  showDialogFunctionForCategoryIconDetails(BuildContext context,
      final List<GetProductListFileModelData>? attachment, Size size) {
    // debugPrint("showDialogFunctionForCategoryIconDetails");
    return showDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "",
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            final isPhone = categoryIsPhone(context);
            final dialogWidth = categoryDialogWidth(context);
            final dialogHeight = categoryDialogHeight(context);
            final uploadButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.12;
            final actionButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.19;

            return Center(
              child: SizedBox(
                height: dialogHeight,
                width: dialogWidth,
                child: Material(
                  type: MaterialType.transparency,
                  child: BuildBoxShadowContainer(
                      circleRadius: 14,
                      padding: EdgeInsets.all(isPhone ? 12 : 16),
                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
                      color: Colors.white,
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'category.dialog_select_icon'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s16,
                                          0.18,
                                          ColorManager.kTitleTextColor,
                                        ),
                                      ),
                                    ),
                                    CategoryDialogCloseButton(
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title:
                                                'category.btn_upload_device'.tr,
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  iconFilePathController.text =
                                                      result.files.single
                                                              .path ??
                                                          '';
                                                  _selectedIconPath =
                                                      result.files.single.path;
                                                  _iconError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          if (_selectedIconPath != null) ...[
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedIconPath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          CustomRoundButton(
                                            title:
                                                'category.btn_upload_device'.tr,
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  iconFilePathController.text =
                                                      result.files.single
                                                              .path ??
                                                          '';
                                                  _selectedIconPath =
                                                      result.files.single.path;
                                                  _iconError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(width: 16),
                                          if (_selectedIconPath != null)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedIconPath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                              if (isPhone && attachment != null)
                                ...attachment.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final image = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: BuildBoxShadowContainer(
                                      circleRadius: 10,
                                      border: Border.all(
                                          color: Colors.grey.withOpacity(0.12)),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Radio<int>(
                                            value: index,
                                            groupValue: selectedIconIndex,
                                            onChanged: (int? value) {
                                              setState(() {
                                                selectedIconIndex = value ?? 0;
                                              });
                                              debugPrint(
                                                  "showDialog $index $selectedIconIndex");
                                              iconFilePathController.text =
                                                  image.id.toString();
                                              iconAltController.text =
                                                  image.alt ?? "";
                                              iconTitleController.text =
                                                  image.title ?? "";
                                            },
                                          ),
                                          Expanded(
                                            child: Text(
                                              "${image.title}",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          BuildBoxShadowContainer(
                                            margin: const EdgeInsetsDirectional
                                                .only(start: 5, end: 5),
                                            circleRadius: 5,
                                            height: 48,
                                            width: 48,
                                            child: Image.network(
                                              image.s3Url ?? "",
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              if (!isPhone)
                                SizedBox(
                                  width: dialogWidth,
                                  child: Table(
                                    columnWidths: const {
                                      0: FractionColumnWidth(0.01),
                                      1: FractionColumnWidth(0.01),
                                      2: FractionColumnWidth(0.1),
                                      3: FractionColumnWidth(0.06),
                                      4: FractionColumnWidth(0.06),
                                      5: FractionColumnWidth(0.05),
                                    },
                                    border: const TableBorder.symmetric(
                                        outside: BorderSide(
                                            color:
                                                ColorManager.tableBOrderColor,
                                            width: 0.3),
                                        inside: BorderSide(
                                            color:
                                                ColorManager.tableBOrderColor,
                                            width: 0.8)),
                                    defaultVerticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    children: [
                                      TableRow(
                                          decoration: const BoxDecoration(
                                              color: ColorManager.tableBGColor),
                                          children: [
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                      child: Text(
                                                    'category.tbl_select'.tr,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.18,
                                                      ColorManager
                                                          .kPrimaryColor,
                                                    ),
                                                  )),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                      child: Text(
                                                    'category.tbl_image_title'
                                                        .tr,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.18,
                                                      ColorManager
                                                          .kPrimaryColor,
                                                    ),
                                                  )),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                      child: Text(
                                                    'category.tbl_preview'.tr,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.18,
                                                      ColorManager
                                                          .kPrimaryColor,
                                                    ),
                                                  )),
                                                )),
                                          ]),

                                      // Map your order data to table rows here
                                      // ...imageFiles!.map((image) {
                                      if (attachment != null)
                                        ...attachment
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final image = entry.value;
                                          return TableRow(
                                            children: [
                                              TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15.0),
                                                    child: Center(
                                                      child: Radio<int>(
                                                        value: index,
                                                        groupValue:
                                                            selectedIconIndex,
                                                        onChanged:
                                                            (int? value) {
                                                          // Set the selected image index
                                                          setState(() {
                                                            selectedIconIndex =
                                                                value ?? 0;
                                                          });

                                                          debugPrint(
                                                              "showDialog $index $selectedIconIndex");
                                                          iconFilePathController
                                                                  .text =
                                                              image.id
                                                                  .toString();
                                                          iconAltController
                                                                  .text =
                                                              image.alt ?? "";
                                                          iconTitleController
                                                                  .text =
                                                              image.title ?? "";
                                                          // Perform any other action if needed
                                                        },
                                                      ),
                                                    ),
                                                  )),
                                              TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15.0),
                                                    child: Center(
                                                      child: Text(
                                                        "${image.title}",
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .medium,
                                                          FontSize.s9,
                                                          0.13,
                                                          Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  )),
                                              TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15.0),
                                                    child: Center(
                                                      child:
                                                          BuildBoxShadowContainer(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 5,
                                                                      right: 5),
                                                              circleRadius: 5,
                                                              child:
                                                                  Image.network(
                                                                image.s3Url ??
                                                                    "",
                                                                fit: BoxFit
                                                                    .cover,
                                                              )),
                                                    ),
                                                  )),
                                            ],
                                          );
                                        }).toList(),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title: 'category.btn_cancel'.tr,
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(height: 10),
                                          CustomRoundButton(
                                            title: 'category.btn_choose'.tr,
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: 'category.btn_cancel'.tr,
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: 'category.btn_choose'.tr,
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ),
              ),
            );
          });
        });
  }
}
