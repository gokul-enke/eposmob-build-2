import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/customer_list.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_title.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../components/build_dialog_box.dart';

class CustomerInformationEditWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData? customer; // Add this line

  const CustomerInformationEditWidget({
    Key? key,
    required this.size,
    required this.customer, // Add this line
  }) : super(key: key);

  @override
  State<CustomerInformationEditWidget> createState() =>
      _CustomerInformationEditWidgetState();
}

class _CustomerInformationEditWidgetState
    extends State<CustomerInformationEditWidget> {
  // Gender selectedGender = Gender.Male;
  late TextEditingController firstNameTextController;
  late TextEditingController lastNameTextController;
  late TextEditingController emailTextController;
  late TextEditingController phoneNumberController;
  late TextEditingController addressTextController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with customer data if available
    firstNameTextController = TextEditingController(
        text: widget.customer?.name?.split(' ').first ?? '');
    lastNameTextController = TextEditingController(
        text: widget.customer?.name?.split(' ').last ?? '');
    emailTextController =
        TextEditingController(text: widget.customer?.email ?? '');
    phoneNumberController =
        TextEditingController(text: widget.customer?.phone ?? '');
    addressTextController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    // Dispose of controllers
    firstNameTextController.dispose();
    lastNameTextController.dispose();
    emailTextController.dispose();
    phoneNumberController.dispose();
    addressTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = widget.size;
    return Expanded(
      child: BuildBoxShadowContainer(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(15),
          height: size.height * 0.75,
          circleRadius: 7,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "First Name",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 0, right: 10, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "First Name",
                              hintStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s10,
                                0.16,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            controller: firstNameTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "Last Name",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 10, right: 0, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,

                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Last Name",
                              hintStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s10,
                                0.16,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            controller: lastNameTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                BuildTitle(
                  title: "Email Address",
                  textStyle: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s10,
                    0.16,
                    Colors.black.withOpacity(0.6),
                  ),
                ),
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  alignment: Alignment.centerLeft,
                  margin: const EdgeInsets.only(
                      left: 0, right: 10, top: 15, bottom: 10),
                  padding: const EdgeInsets.only(left: 15),
                  height: size.height * .07,
                  width: size.width / 2.8, //size.width,
                  child: TextFormField(
                    //  initialValue: initialValue,
                    keyboardType: TextInputType.text,
                    cursorColor: ColorManager.kPrimaryColor,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    controller: emailTextController,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s13,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "Phone Number",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 0, right: 10, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: phoneNumberController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "Address",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 10, right: 0, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: addressTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [

//---------------------------------existing edit profile button------------------------------------------------------------


                    CustomRoundButton(
                      radius: 14,
                      title: "Edit Profile",
                      fct: () async {
                        debugPrint("Edit Profile button pressed");

                        // Get the access token
                        String? accessToken =
                            Provider.of<AuthModel>(context, listen: false)
                                .token;
                        if (accessToken == null) {
                          debugPrint("No access token found");
                          showScaffoldError(
                              context: context, message: "Please login again");
                          return;
                        }

                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                              child: CircularProgressIndicator.adaptive()),
                        );

                        try {
                          // Get the customer provider
                          final customerProvider =
                              Provider.of<CustomerProvider>(context,
                                  listen: false);

                          // Get the customer ID
                          int customerId = widget.customer?.id ?? 0;
                          if (customerId == 0) {
                            throw Exception("Invalid customer ID");
                          }

                          // Extract state and district from address if available
                          String state =
                              ""; // You'll need to implement state selection
                          String city =
                              ""; // You'll need to implement district selection
                          String country =
                              ""; // You'll need to implement country input
                          String pincode =
                              ""; // You'll need to implement pincode input
                          String address = addressTextController.text;

                          debugPrint(
                              "Preparing to update customer with ID: $customerId");
                          debugPrint(
                              "Name: ${firstNameTextController.text} ${lastNameTextController.text}");
                          debugPrint("Email: ${emailTextController.text}");
                          debugPrint("Phone: ${phoneNumberController.text}");
                          debugPrint("Address: $address");

                          final response =
                              await customerProvider.updateCustomer(
                            accessToken,
                            phoneNumberController.text,
                            "${firstNameTextController.text} ${lastNameTextController.text}",
                            emailTextController.text,
                            address,
                            pincode,
                            city,
                            state,
                            country,
                            customerId,
                            context,
                          );

                          // Close loading dialog
                          Navigator.pop(context);

                          if (response["status"] == "success") {
                            debugPrint("Customer updated successfully");
                            showScaffold(
                                context: context,
                                message: response["message"] ??
                                    "Customer updated successfully");

                            // Refresh customer data
                            await customerProvider.fetchUserById(
                                accessToken, customerId, context);
                          } else {
                            String errorMessage = "";

                            if (response.containsKey("errors")) {
                              Map<String, dynamic> errors = response["errors"];
                              List<String> errorMessages = [];

                              errors.forEach((field, messages) {
                                if (messages is List) {
                                  for (var message in messages) {
                                    errorMessages.add("$field: $message");
                                  }
                                } else {
                                  errorMessages.add("$field: $messages");
                                }
                              });

                              errorMessage = errorMessages.join("\n");
                              debugPrint("Validation errors: $errorMessage");
                            } else {
                              errorMessage = response["message"] ??
                                  "Failed to update customer";
                              debugPrint("Error message: $errorMessage");
                            }

                            showScaffoldError(
                                context: context, message: errorMessage);
                          }
                        } catch (error) {
                          debugPrint(
                              "Exception occurred during update: $error");
                          Navigator.pop(context); // Close loading dialog
                          showScaffoldError(
                              context: context, message: 'Error: $error');
                        }
                      },
                      height: 50,
                      width: size.width * 0.175,
                      fontSize: FontSize.s12,
                    ),


//---------------------------------debug edit profile button------------------------------------------------------------


                    // CustomRoundButton(
                    //   radius: 14,
                    //   title: "Edit Profile",
                    //   fct: () async {
                    //     debugPrint(
                    //         "⏳ Edit Profile button pressed - Starting process...");

                    //     // Validate required fields
                    //     if (firstNameTextController.text.isEmpty ||
                    //         lastNameTextController.text.isEmpty) {
                    //       debugPrint(
                    //           "❌ Validation failed: Missing name fields");
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "First name and last name are required");
                    //       return;
                    //     }

                    //     // Validate phone (if required)
                    //     if (phoneNumberController.text.isEmpty) {
                    //       debugPrint(
                    //           "❌ Validation failed: Missing phone number");
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "Phone number is required");
                    //       return;
                    //     }

                    //     // Validate email format (if provided)
                    //     if (emailTextController.text.isNotEmpty &&
                    //         !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    //             .hasMatch(emailTextController.text)) {
                    //       debugPrint(
                    //           "❌ Validation failed: Invalid email format");
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "Please enter a valid email");
                    //       return;
                    //     }

                    //     // Get access token
                    //     final accessToken =
                    //         Provider.of<AuthModel>(context, listen: false)
                    //             .token;
                    //     if (accessToken == null || accessToken.isEmpty) {
                    //       debugPrint(
                    //           "🔐 Error: No access token found or token is empty");
                    //       showScaffoldError(
                    //           context: context, message: "Please login again");
                    //       return;
                    //     }
                    //     debugPrint(
                    //         "🔑 Token obtained (first 10 chars): ${accessToken.substring(0, min(accessToken.length, 10))}...");

                    //     // Get customer ID
                    //     final customerId = widget.customer?.id;
                    //     if (customerId == null) {
                    //       debugPrint("🆔 Error: Customer ID is null");
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "Invalid customer data");
                    //       return;
                    //     }
                    //     debugPrint("👤 Customer ID: $customerId");

                    //     // Show loading dialog
                    //     debugPrint("⏳ Showing loading dialog...");
                    //     showDialog(
                    //       context: context,
                    //       barrierDismissible: false,
                    //       builder: (context) =>
                    //           Center(child: CircularProgressIndicator()),
                    //     );

                    //     try {
                    //       final customerProvider =
                    //           Provider.of<CustomerProvider>(context,
                    //               listen: false);
                    //       final fullName =
                    //           "${firstNameTextController.text} ${lastNameTextController.text}"
                    //               .trim();
                    //       final phone = phoneNumberController.text;
                    //       final email = emailTextController.text;

                    //       debugPrint("📤 Preparing API request with data:");
                    //       debugPrint("📝 Name: $fullName");
                    //       debugPrint("📱 Phone: $phone");
                    //       debugPrint("📧 Email: $email");
                    //       debugPrint("🌐 Calling updateCustomer API...");

                    //       final response = await customerProvider
                    //           .updateCustomer(
                    //             accessToken,
                    //             phone,
                    //             fullName,
                    //             email,
                    //             "", // address
                    //             "", // pincode
                    //             "", // city
                    //             "", // state
                    //             "", // country
                    //             customerId,
                    //             context,
                    //           )
                    //           .timeout(const Duration(seconds: 30));

                    //       debugPrint("✅ API call completed");
                    //       debugPrint("📥 Response: ${response.toString()}");

                    //       // Close loading dialog
                    //       Navigator.pop(context);
                    //       debugPrint("🗂 Closed loading dialog");

                    //       if (response["status"] == "success") {
                    //         debugPrint("🎉 Update successful!");
                    //         // Show success message
                    //         ScaffoldMessenger.of(context).showSnackBar(
                    //           const SnackBar(
                    //             content: Text("Profile updated successfully!"),
                    //             backgroundColor: Colors.green,
                    //             duration: Duration(seconds: 2),
                    //           ),
                    //         );

                    //         // Refresh customer data
                    //         debugPrint("🔄 Refreshing customer data...");
                    //         await customerProvider.fetchUserById(
                    //             accessToken, customerId, context);

                    //         // Close the edit screen after delay
                    //         Future.delayed(Duration(milliseconds: 1500), () {
                    //           Navigator.pop(context);
                    //           debugPrint("🚪 Closed edit screen");
                    //         });
                    //       } else {
                    //         debugPrint("❌ API returned error status");
                    //         String errorMsg = "Failed to update customer";

                    //         if (response["message"] != null) {
                    //           errorMsg = response["message"];
                    //           debugPrint("📌 Server message: $errorMsg");
                    //         }

                    //         if (response["errors"] != null) {
                    //           debugPrint("📌 Server errors:");
                    //           response["errors"].forEach((key, value) {
                    //             debugPrint("   - $key: ${value.join(', ')}");
                    //           });
                    //           errorMsg += "\n\nDetails:";
                    //           response["errors"].forEach((key, value) {
                    //             errorMsg += "\n- ${key}: ${value.join(', ')}";
                    //           });
                    //         }

                    //         showScaffoldError(
                    //             context: context, message: errorMsg);
                    //       }
                    //     } on TimeoutException {
                    //       Navigator.pop(context);
                    //       debugPrint("⏰ Error: Request timed out");
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "Request timed out. Please try again.");
                    //     } on SocketException {
                    //       Navigator.pop(context);
                    //       debugPrint("📡 Error: No internet connection");
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "No internet connection");
                    //     } catch (error) {
                    //       Navigator.pop(context);
                    //       debugPrint("‼️ Unexpected error: $error");
                    //       debugPrint("🔄 Error type: ${error.runtimeType}");
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "An unexpected error occurred");
                    //     }
                    //   },
                    //   height: 50,
                    //   width: size.width * 0.175,
                    //   fontSize: FontSize.s12,
                    // ),

//---------------------------------updated edit profile button------------------------------------------------------------
                    
                    // CustomRoundButton(
                    //   radius: 14,
                    //   title: "Edit Profile",
                    //   fct: () async {
                    //     // Validate required fields
                    //     if (firstNameTextController.text.isEmpty ||
                    //         lastNameTextController.text.isEmpty ||
                    //         phoneNumberController.text.isEmpty) {
                    //       showScaffoldError(
                    //           context: context,
                    //           message:
                    //               "First name, last name, and phone are required");
                    //       return;
                    //     }

                    //     // Validate email format (if provided)
                    //     if (emailTextController.text.isNotEmpty &&
                    //         !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    //             .hasMatch(emailTextController.text)) {
                    //       showScaffoldError(
                    //           context: context,
                    //           message: "Please enter a valid email");
                    //       return;
                    //     }

                    //     // Get access token
                    //     final accessToken =
                    //         Provider.of<AuthModel>(context, listen: false)
                    //             .token;
                    //     if (accessToken == null) {
                    //       showScaffoldError(
                    //           context: context, message: "Please login again");
                    //       return;
                    //     }

                    //     // Show loading dialog
                    //     showDialog(
                    //       context: context,
                    //       barrierDismissible: false,
                    //       builder: (context) =>
                    //           Center(child: CircularProgressIndicator()),
                    //     );

                    //     try {
                    //       final customerProvider =
                    //           Provider.of<CustomerProvider>(context,
                    //               listen: false);
                    //       final customerId = widget.customer?.id;
                    //       if (customerId == null)
                    //         throw Exception("Invalid customer ID");

                    //       // Call API
                    //       final response =
                    //           await customerProvider.updateCustomer(
                    //         accessToken,
                    //         phoneNumberController.text,
                    //         "${firstNameTextController.text} ${lastNameTextController.text}",
                    //         emailTextController.text,
                    //         "",
                    //         "", // pincode (optional)
                    //         "", // city (optional)
                    //         "", // state (optional)
                    //         "", // country (optional)
                    //         customerId,
                    //         context,
                    //       );

                    //       Navigator.pop(context); // Close loading dialog

                    //       if (response["status"] == "success") {
                    //         // Show success message
                    //         ScaffoldMessenger.of(context).showSnackBar(
                    //           SnackBar(
                    //             content: Text("Profile updated successfully!"),
                    //             backgroundColor: Colors.green,
                    //           ),
                    //         );

                    //         // Refresh customer data
                    //         await customerProvider.fetchUserById(
                    //             accessToken, customerId, context);

                    //         // Close the edit screen
                    //         Navigator.pop(context);
                    //       } else {
                    //         // Parse API error response
                    //         String errorMsg =
                    //             response["message"] ?? "Update failed";
                    //         if (response["errors"] != null) {
                    //           errorMsg +=
                    //               "\n${response["errors"].entries.map((e) => "${e.key}: ${e.value.join(', ')}").join("\n")}";
                    //         }
                    //         showScaffoldError(
                    //             context: context, message: errorMsg);
                    //       }
                    //     } catch (error) {
                    //       Navigator.pop(context); // Close loading dialog
                    //       showScaffoldError(
                    //           context: context, message: "Error: $error");
                    //     }

                    //   },
                    //   height: 50,
                    //   width: size.width * 0.175,
                    //   fontSize: FontSize.s12,
                    // ),
                    SizedBox(width: 16),
                    CustomRoundButton(
                      radius: 14,
                      title: "Change Password",
                      fct: () => _showPasswordChangeConfirmation(context),
                      height: 50,
                      width: size.width * 0.175,
                      fontSize: FontSize.s12,
                      boxColor: Colors.white,
                      textColor: ColorManager.kPrimaryColor,
                      borderColor: ColorManager.kPrimaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          )),
    );
  }
}
// Add this button in your widget tree (after the Edit Profile button)

// Add this method to your state class
void _showPasswordChangeConfirmation(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        "Change Password Request",
        style: buildCustomStyle(
          FontWeightManager.bold,
          FontSize.s16,
          0.24,
          ColorManager.textColor,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.email_outlined, size: 48, color: Colors.black),
          SizedBox(height: 16),
          Text(
            "A password change link will be sent to the customer's registered email address.",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.18,
              Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            "Do you want to proceed?",
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s14,
              0.21,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.18,
              Colors.black,
            ),
          ),
        ),
        CustomRoundButton(
          title: "Send Link",
          // boxColor: Colors.grey,
          // borderColor: Colors.white,
          fct: () {
            Navigator.pop(context); // Close the dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Password change link sent (demo)",
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.18,
                    Colors.white,
                  ),
                ),
                backgroundColor: Colors.green,
              ),
            );
          },
          height: 40,
          width: 100,
          fontSize: FontSize.s12,
        ),
      ],
    ),
  );
}
