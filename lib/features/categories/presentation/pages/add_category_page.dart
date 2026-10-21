import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_err_view.dart';
import 'package:pos_machine/models/product_list_file.dart';
import 'package:pos_machine/providers/grid_provider.dart';

import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';

import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/category_list_scope.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import '../widgets/form/category_form_responsive.dart';
import '../state/category_form_mixin.dart';

part '../state/category_add_form_state.dart';
part '../widgets/form/category_add_form_view.dart';
part '../widgets/form/category_add_media_dialogs.dart';

class AddCategoryPageScreen extends StatefulWidget {
  const AddCategoryPageScreen({super.key});

  @override
  State<AddCategoryPageScreen> createState() => _AddCategoryPageScreenState();
}

class _AddCategoryPageScreenState extends State<AddCategoryPageScreen>
    with
        CategoryFormMixin<AddCategoryPageScreen>,
        CategoryAddFormState<AddCategoryPageScreen>,
        CategoryAddMediaDialogs<AddCategoryPageScreen>,
        CategoryAddFormView<AddCategoryPageScreen> {}
