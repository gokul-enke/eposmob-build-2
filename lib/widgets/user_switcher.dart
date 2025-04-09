import 'package:flutter/material.dart';
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

class UserSwitcher extends StatefulWidget {
  const UserSwitcher({Key? key}) : super(key: key);

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
    // Fetch sales executives when the widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SalesExecutiveProvider>(context, listen: false)
          .fetchSalesExecutives(context);
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Switch User",
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
                      "Enter password for ${executive.name}",
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      executive.email,
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
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: ColorManager.kPrimaryColor.withOpacity(0.5),
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
                        CustomRoundButton(
                          title: "Cancel",
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
                        const SizedBox(width: 10),
                        CustomRoundButton(
                          title: "Switch",
                          isLoading: _isLoading,
                          fontSize: FontSize.s12,
                          height: MediaQuery.of(context).size.height * .05,
                          width: 120,
                          fct: () async {
                            if (_passwordController.text.isEmpty) {
                              showScaffoldError(
                                context: context,
                                message: 'Please enter password',
                              );
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              final result =
                                  await AuthenticationProvider().login(
                                executive.email,
                                _passwordController.text,
                                context,
                              );

                              if (result["status"] == "success") {
                                ExecutiveModel executiveModel =
                                    ExecutiveModel.fromJson(result);
                                ExecutiveModelData? executiveModelData =
                                    executiveModel.data;

                                if (executiveModelData != null) {
                                  // Update auth state
                                  Provider.of<AuthModel>(context, listen: false)
                                      .login(
                                    executiveModelData.accessToken ?? "",
                                    executiveModelData.userId ?? 0,
                                  );

                                  // Save to shared preferences
                                  SharedPreferenceProvider()
                                      .saveAccessTokenandCustomerId(
                                    executiveModelData.accessToken ?? "",
                                    executiveModelData.userId ?? 0,
                                    executiveModelData.userName ?? "",
                                  );

                                  // Switch to the selected executive
                                  final success =
                                      await Provider.of<SalesExecutiveProvider>(
                                              context,
                                              listen: false)
                                          .switchToExecutive(
                                              context, executive.id);

                                  if (success) {
                                    Navigator.of(context).pop(); // Close dialog
                                    this.setState(() {
                                      _isDropdownOpen = false;
                                    });
                                    showScaffold(
                                      context: context,
                                      message:
                                          'Successfully switched to ${executive.name}',
                                    );
                                  }
                                }
                              } else {
                                showScaffoldError(
                                  context: context,
                                  message: result["message"] ??
                                      'Authentication failed',
                                );
                              }
                            } catch (e) {
                              showScaffoldError(
                                context: context,
                                message: 'Error: ${e.toString()}',
                              );
                            } finally {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
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
    return Consumer<SalesExecutiveProvider>(
      builder: (context, salesExecutiveProvider, child) {
        final currentUser = salesExecutiveProvider.getCurrentUser(context);

        if (currentUser == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            // Current user display
            InkWell(
              onTap: () {
                setState(() {
                  _isDropdownOpen = !_isDropdownOpen;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: ColorManager.kPrimaryColor,
                            radius: 16,
                            child: Text(
                              currentUser.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentUser.name,
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s14,
                                    0.21,
                                    ColorManager.textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  currentUser.email,
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s12,
                                    0.18,
                                    Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isDropdownOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ],
                ),
              ),
            ),

            // Dropdown for switching users
            if (_isDropdownOpen)
              Container(
                margin: const EdgeInsets.only(top: 5),
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        'Switch User',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s14,
                          0.21,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                    const Divider(),
                    ...salesExecutiveProvider.salesExecutives.map((executive) {
                      final isCurrentUser = executive.id == currentUser.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrentUser
                              ? ColorManager.kPrimaryColor
                              : Colors.grey.shade300,
                          radius: 16,
                          child: Text(
                            executive.name.substring(0, 1).toUpperCase(),
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
                          executive.email,
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
                                // Show password confirmation dialog
                                await _showPasswordConfirmationDialog(
                                    executive);
                              },
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
