import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
// import 'package:pos_machine/screens/login/store_selection_screen.dart';
import 'dart:convert';

class UserSwitcher extends StatefulWidget {
  final bool compact;

  const UserSwitcher({Key? key, this.compact = false}) : super(key: key);

  @override
  State<UserSwitcher> createState() => _UserSwitcherState();
}

class _UserSwitcherState extends State<UserSwitcher> {
  bool _isDropdownOpen = false;
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint("🔧 UserSwitcher: initState called");
    // Fetch sales executives when the widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          "🔧 UserSwitcher: Post frame callback - fetching sales executives");
      debugPrint("🔧 UserSwitcher: Context is valid");
      debugPrint("🔧 UserSwitcher: Mounted is: $mounted");

      try {
        final provider =
            Provider.of<SalesExecutiveProvider>(context, listen: false);
        debugPrint(
            "🔧 UserSwitcher: SalesExecutiveProvider obtained successfully");
        debugPrint(
            "🔧 UserSwitcher: Current executives count before fetch: ${provider.salesExecutives.length}");

        provider.fetchSalesExecutives(context);
        debugPrint("🔧 UserSwitcher: fetchSalesExecutives called successfully");
      } catch (e) {
        debugPrint("❌ UserSwitcher: Error fetching sales executives: $e");
        debugPrint("❌ UserSwitcher: Error stack trace: ${StackTrace.current}");
      }
    });
  }

  Future<void> _showPasswordConfirmationDialog(SalesExecutive executive) async {
    _passwordController.clear();
    _obscureText = true;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width / 2,
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'general.switch_user'.tr,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'general.enter_password_for'.trParams(
                          {'name': executive.name},
                        ),
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        executive.email ?? 'general.no_email'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s14,
                          0.21,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          labelText: 'general.password'.tr,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.5),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: CustomRoundButton(
                              title: 'general.cancel'.tr,
                              isLoading: false,
                              fontSize: FontSize.s12,
                              height: MediaQuery.of(context).size.height * .05,
                              width: 120,
                              textColor: Colors.blue,
                              borderColor: Colors.blue,
                              boxColor: Colors.white,
                              fct: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomRoundButton(
                              title: 'general.switch'.tr,
                              isLoading: _isLoading,
                              fontSize: FontSize.s12,
                              height: MediaQuery.of(context).size.height * .05,
                              width: 120,
                              fct: () async {
                                if (_passwordController.text.isEmpty) {
                                  showScaffoldError(
                                    context: context,
                                    message: 'general.enter_password'.tr,
                                  );
                                  return;
                                }

                                setState(() {
                                  _isLoading = true;
                                });

                                try {
                                  final result =
                                      await AuthenticationProvider().login(
                                    executive.email ?? '',
                                    _passwordController.text,
                                    context,
                                  );

                                  if (result["status"] == "success") {
                                    ExecutiveModel executiveModel =
                                        ExecutiveModel.fromJson(result);
                                    ExecutiveModelData? executiveModelData =
                                        executiveModel.data;

                                    if (executiveModelData != null) {
                                      // Get current active store
                                      final storeSession =
                                          Provider.of<StoreSessionProvider>(
                                              context,
                                              listen: false);
                                      final currentActiveStore =
                                          storeSession.activeStore;
                                      final newUserStores =
                                          executiveModelData.stores ?? [];

                                      // Check if new user has access to current store
                                      bool hasAccessToCurrentStore =
                                          currentActiveStore == null ||
                                              newUserStores.any((store) =>
                                                  store.storeId ==
                                                  currentActiveStore.storeId);

                                      if (!hasAccessToCurrentStore &&
                                          newUserStores.isNotEmpty) {
                                        // User doesn't have access to current store - DO NOT SWITCH USER
                                        showScaffoldError(
                                          context: context,
                                          message:
                                              'general.no_current_store_access'.trParams({
                                                'name': executive.name,
                                              }),
                                        );
                                        return;
                                      } else if (!hasAccessToCurrentStore &&
                                          newUserStores.isEmpty) {
                                        // User has no store access at all
                                        showScaffoldError(
                                          context: context,
                                          message:
                                              'general.no_store_permission'.trParams({
                                                'name': executive.name,
                                              }),
                                        );
                                        return;
                                      }

                                      // User has access to current store, proceed with normal switch
                                      // Update auth state
                                      Provider.of<AuthModel>(context,
                                              listen: false)
                                          .login(
                                        executiveModelData.accessToken ?? "",
                                        executiveModelData.userId ?? 0,
                                      );

                                      // Convert stores list to JSON string for shared preferences
                                      String? storesJson;
                                      if (newUserStores.isNotEmpty) {
                                        storesJson = json.encode(newUserStores
                                            .map((store) => store.toJson())
                                            .toList());
                                      }

                                      // Save to shared preferences
                                      SharedPreferenceProvider()
                                          .saveAccessTokenandCustomerId(
                                        executiveModelData.accessToken ?? "",
                                        executiveModelData.userId ?? 0,
                                        executiveModelData.userName ?? "",
                                        executiveModelData.userRole ?? "",
                                        tokenType: executiveModelData.tokenType,
                                        companyId: executiveModelData.companyId,
                                        companyName:
                                            executiveModelData.companyName,
                                        storesJson: storesJson,
                                      );

                                      // Switch to the selected executive
                                      final success = await Provider.of<
                                                  SalesExecutiveProvider>(
                                              context,
                                              listen: false)
                                          .switchToExecutive(
                                              context, executive.id);

                                      if (success) {
                                        Navigator.of(context)
                                            .pop(); // Close dialog
                                        this.setState(() {
                                          _isDropdownOpen = false;
                                        });
                                        showScaffold(
                                          context: context,
                                          message:
                                              'general.switched_successfully'.trParams({
                                                'name': executive.name,
                                              }),
                                        );
                                      }
                                    }
                                  } else {
                                    showScaffoldError(
                                      context: context,
                                      message: result["message"] ??
                                          'general.authentication_failed'.tr,
                                    );
                                  }
                                } catch (e) {
                                  showScaffoldError(
                                    context: context,
                                    message: '${'general.error_prefix'.tr} ${e.toString()}',
                                  );
                                } finally {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🔧 UserSwitcher: build method called");

    return Consumer<SalesExecutiveProvider>(
      builder: (context, salesExecutiveProvider, child) {
        debugPrint("🔧 UserSwitcher: Consumer builder called");
        debugPrint(
            "🔧 UserSwitcher: Sales executives count: ${salesExecutiveProvider.salesExecutives.length}");

        final currentUser = salesExecutiveProvider.getCurrentUser(context);

        if (currentUser == null) {
          debugPrint(
              "❌ UserSwitcher: currentUser is null - widget will be hidden");
          debugPrint(
              "🔧 UserSwitcher: Available executives: ${salesExecutiveProvider.salesExecutives.map((e) => e.name).toList()}");

          // Instead of hiding completely, show a fallback UI with debug info
          return Container();
        }

        debugPrint(
            "✅ UserSwitcher: currentUser found: ${currentUser.name} (${currentUser.email ?? 'no email'})");

        final avatarRadius = widget.compact ? 14.0 : 16.0;
        final nameFontSize = widget.compact ? FontSize.s13 : FontSize.s14;
        final emailFontSize = widget.compact ? FontSize.s11 : FontSize.s12;
        final cardPadding = widget.compact
            ? const EdgeInsets.symmetric(vertical: 6, horizontal: 12)
            : const EdgeInsets.symmetric(vertical: 8, horizontal: 15);

        return LayoutBuilder(
          builder: (context, constraints) {
            final switcherBody = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current user display
                InkWell(
                  onTap: () {
                    debugPrint("🔧 UserSwitcher: Dropdown toggle tapped");
                    setState(() {
                      _isDropdownOpen = !_isDropdownOpen;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: cardPadding,
                    decoration: BoxDecoration(
                      color: ColorManager.kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorManager.kPrimaryColor.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: ColorManager.kPrimaryColor,
                          radius: avatarRadius,
                          child: Text(
                            currentUser.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: widget.compact ? 13 : 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentUser.name,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  nameFontSize,
                                  0.21,
                                  ColorManager.kTitleTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                currentUser.email ?? 'general.no_email'.tr,
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  emailFontSize,
                                  0.18,
                                  ColorManager.kGreyColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isDropdownOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: ColorManager.kPrimaryColor,
                          size: widget.compact ? 20 : 24,
                        ),
                      ],
                    ),
                  ),
                ),

                // Dropdown for switching users
                if (_isDropdownOpen)
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.only(top: 5),
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              'general.switch_user'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s14,
                                0.21,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                          const Divider(),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: salesExecutiveProvider.salesExecutives
                                    .map((executive) {
                                  final isCurrentUser =
                                      executive.id == currentUser.id;
                                  return Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isCurrentUser
                                            ? ColorManager.kPrimaryColor
                                            : Colors.grey.shade300,
                                        radius: 16,
                                        child: Text(
                                          executive.name
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: isCurrentUser
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        executive.name,
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s14,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        executive.email ?? 'general.no_email'.tr,
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s12,
                                          0.18,
                                          Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: isCurrentUser
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: ColorManager.kPrimaryColor,
                                            )
                                          : null,
                                      onTap: isCurrentUser
                                          ? null
                                          : () async {
                                              debugPrint(
                                                  "🔧 UserSwitcher: Switching to user: ${executive.name}");
                                              // Show password confirmation dialog
                                              await _showPasswordConfirmationDialog(
                                                  executive);
                                            },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );

            if (constraints.hasBoundedHeight &&
                constraints.maxHeight < double.infinity) {
              return SizedBox(
                height: constraints.maxHeight,
                child: switcherBody,
              );
            }
            return switcherBody;
          },
        );
      },
    );
  }
}
