import 'package:flutter/material.dart';

import '../../../resources/asset_manager.dart';
import '../components/build_container_box.dart';
import '../components/build_title.dart';
import '../models/list_cart_items_data.dart';
import '../providers/dashboard_provider.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

class YourBag extends StatefulWidget {
  const YourBag({super.key});

  @override
  State<YourBag> createState() => _YourBagState();
}

class _YourBagState extends State<YourBag> {
  bool isLoading = true;
  List<bool> customIcons = [];
  List<dynamic> serviceNames = [];
  List<String> serviceAreaNames = [];
  List<String> serviceAreaTypes = [];
  ServiceAreaType? serviceAreaTypeList;
  List<ServiceType> serviceTypesList = [];
  List<ServiceArea> serviceAreaList = [];
  Map<String, List<ServiceArea>> allServiceAreas = {};
  List<dynamic> serviceTypeListss = [];
  int index = 0;
  @override
  void initState() {
    fetchCartItems(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    //********* isloading calling ********//
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: ColorManager.kPrimaryColor,
        ),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            //********* Banner image ********//
            // const BannerImage(),
            const SizedBox(
              height: 10,
            ),
            //********* listview builder which build a service which have service name (mopwash,fullwash) ********//
            ListView.builder(
              itemCount: serviceTypeListss.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: (context, index) {
                var serviceType = serviceTypeListss[index];
                //   var serviceName = serviceType['service_name'];
                var serviceAreaTypes = serviceType['service_area_types'];
                // debugPrint("${serviceNames.length}");
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: BuildBoxShadowContainer(
                    circleRadius: 10,
                    width: size.width * 0.343,
                    // keyboardType: TextInputType.none,
                    // text: "",
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 27,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              //********* service name and image ********//
                              SizedBox(
                                width: 38,
                                height: 50,
                                child: Image.asset(ImageAssets.allImage),
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              BuildTextTile(
                                title: serviceNames[index],
                                textStyle: buildCustomStyle(
                                  FontWeight.bold,
                                  14,
                                  21,
                                  Colors.black,
                                ),
                              )
                            ],
                          ),
                        ),
                        //********* border line after service name ********//
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: const Color.fromARGB(255, 226, 224, 224),
                                width: customIcons[1] ? 0.5 : 1,
                              ),
                            ),
                          ),
                        ),
                        //********* listview builder which build a service area type... (...) ********//
                        ListView.builder(
                          itemCount: 0,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 0,
                                  ),
                                  //****** Service area type and ExpansionTile ********//
                                  child: ExpansionTile(
                                    title: Text(
                                      serviceAreaTypes[index],
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s16,
                                        25,
                                        Colors.black,
                                      ),
                                    ),
                                    trailing: Icon(
                                      customIcons[index]
                                          ? Icons.keyboard_arrow_down_outlined
                                          : Icons.keyboard_arrow_up_outlined,
                                      color: Colors.black,
                                    ),
                                    children: [
                                      //        ********* listview builder which build a service area name ... (...) ********//
                                      ListView.builder(
                                          itemCount: 0,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          shrinkWrap: true,
                                          itemBuilder: (context, index) {
                                            return Column(children: [
                                              //******* Service area name *******//
                                              // FullWash(
                                              //   title: serviceAreaNames[index],
                                              //   image: Image.asset(
                                              //       ImageAssets.floortile),
                                              // ),
                                              //******** padding border line after Service area name ********//
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: index !=
                                                            serviceAreaNames
                                                                    .length -
                                                                1
                                                        ? 16
                                                        : 4),
                                                child: index ==
                                                        serviceAreaNames
                                                                .length -
                                                            1
                                                    ? null
                                                    : Container(
                                                        decoration:
                                                            const BoxDecoration(
                                                          border: Border(
                                                            top: BorderSide(
                                                                width: 1,
                                                                color: Color
                                                                    .fromARGB(
                                                                        255,
                                                                        226,
                                                                        224,
                                                                        224)),
                                                          ),
                                                        ),
                                                      ),
                                              )
                                            ]);
                                          }),
                                      const SizedBox(height: 20),
                                    ],
                                    onExpansionChanged: (bool expanded) {
                                      setState(() {
                                        customIcons[index] = expanded;
                                      });
                                    },
                                  ),
                                ),
                                //********* border line after service area type ********//
                                Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color:
                                            Color.fromARGB(255, 226, 224, 224),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            //********* border line after all services ********//
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color.fromARGB(255, 226, 224, 224),
                    width: 1,
                  ),
                ),
              ),
            ),
            //******** price details *******//
            // const PriceDetails(
            //   circleRadius: 0,
            //   showShadow: false,
            //   width: 500,
            // ),

            //********* border line ********//
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color.fromARGB(255, 226, 224, 224),
                    width: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 40,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 7),
              child: Row(
                children: [
                  BuildTextTile(
                      // topPaddingTextTile: 0,
                      // bottomPaddingTextTile: 0,
                      title: "Total Price(3)",
                      textStyle: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s13,
                        21,
                        Colors.black,
                      )),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: BuildTextTile(
                        // topPaddingTextTile: 0,
                        // bottomPaddingTextTile: 0,
                        title:
                            "(Choose individual /family pack to save 20% off*)",
                        textStyle: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s8,
                          21,
                          ColorManager.kPrimaryColor,
                        )),
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  BuildTextTile(
                      // topPaddingTextTile: 0,
                      // bottomPaddingTextTile: 0,
                      title: "k450RS",
                      textStyle: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        21,
                        Colors.black,
                      )),
                ],
              ),
            ),
            //********* Continue To Data/Time Button ********//
            // BuildRoundBox(
            //   circleRadius: kCircleRadius25,
            //   width: size.width * kWidth88,
            //   height: size.height * kHeight55,
            //   color: ColorManager.primary,
            //   fct: () {},
            //   textButtonTitle: kcontinuetodatetime,
            // ),
            const SizedBox(
              height: 30,
            )
          ],
        ),
      ),
    );
  }

//********* fetchCartItems function ********//
  Future<void> fetchCartItems(BuildContext context) async {
    try {
      // DashboardProvider().listCartItnes(context).then((value) {
      //   // debugPrint("listCartItems Listing");
      //   // debugPrint(value["status"]);
      // });
      await DashboardProvider().listCartItnes(context).then((response) {
        // debugPrint("inside api call");
        // debugPrint(response['status']);
        //// debugPrint(response['data']['service_types'].toString());

        // ListCartItems listCartItemResponse = ListCartItems.fromJson(response);
        // debugPrint("function called inside fetchCartItems");
        // debugPrint(listCartItemResponse.status);
        // ListCartItemsData? listCartItemsData =
        //     listCartItemResponse.listCartItemsData;
        // serviceAreaTypeList = listCartItemsData!.serviceAreaType;
        // serviceAreaList = listCartItemsData.serviceArea;
        // serviceTypesList = listCartItemsData.serviceTypes;
        // debugPrint("serviceAreaList.map((e) => debugPrint(e.serviceTypeId));");

        // for (var e in serviceAreaList) {
        //   // debugPrint(e.serviceAreaName);
        //   // debugPrint(e.serviceAreaType);
        //   // debugPrint(e.serviceTypeId);
        // }
        // debugPrint("serviceTypesList");
        // for (var e in serviceTypesList) {
        //   // debugPrint(e.serviceAreaTypes!.floor.toString());
        //   // debugPrint(e.serviceName);
        //   // debugPrint(e.serviceAreaTypes!.vehicle.toString());
        // }
        // debugPrint(
        //     "serviceTypesList checking------------------------------------------------------");
        // for (var e in serviceTypesList) {
        //   // debugPrint(e.serviceAreaTypes!.toJson().toString());
        //   // debugPrint(e.serviceAreaTypes!.floor.toString());
        //   // debugPrint(e.serviceName);
        //   // debugPrint(e.serviceAreaTypes!.vehicle.toString());
        // }
        //        serviceAreaTypes.forEach((key, values) {
        //   debugPrint('$key: $values');
        // });
        // debugPrint(
        //     "serviceTypesList checking------------------------------------------------------");
        // debugPrint(serviceAreaTypeList!.wall);
        // serviceTypesList
        //     .map((e) => // debugPrint(e.serviceAreaTypes!.floor.toString()));
        // debugPrint("Print and update service names to the list");
        // serviceTypesList.map((e) {
        //   // debugPrint(e.serviceAreaTypes.toString());
        //   // debugPrint(e.serviceAreaTypes!.vehicle.toString());
        // });
        // Print and update service names to the list
        // for (ServiceType serviceType
        //     in listCartItemResponse.listCartItemsData!.serviceTypes) {
        //   String serviceName = serviceType.serviceName;
        //   // debugPrint("Service Name: $serviceName");
        //   serviceNames.add(serviceName);
        // }

        //Print and update service area types to the list:
        // listCartItemResponse.listCartItemsData!.serviceAreaType
        //     .toJson()
        //     .values
        //     .forEach((value) {
        //   // debugPrint("Service Area Type: $value");
        //   serviceAreaTypes.add(value);
        //   if (value == 'Floor') {
        //     // debugPrint("haiiiiiiiiii");
        //   } else if (value == 'Vehicle') {
        //     // debugPrint("haiiiiiiiiii");
        //   }
        // });

        //Print and update service area names to the list:
        // for (ServiceArea serviceArea
        //     in listCartItemResponse.listCartItemsData!.serviceArea) {
        //   String serviceAreaName = serviceArea.serviceAreaName;
        //   // debugPrint("Service Area Name: $serviceAreaName");
        //   //serviceAreaNames.add(serviceAreaName);
        // }

//         ServiceData serviceData = ServiceData.fromJson(response);

//         Map<String, dynamic> serviceAreaTypeData =
//             serviceData.data['service_area_type'];
//         ServiceAreaType serviceAreaType =
//             ServiceAreaType.fromJson(serviceAreaTypeData);

// Parse service area types and their data
//         List<dynamic> serviceTypesData = serviceData.data['service_types'];
//         Map<String, List<ServiceArea>> serviceAreaTypes = {};
//         serviceTypesData.forEach((serviceTypeData) {
//           String key = serviceTypeData['service_type_id']
//               .toString(); // Assuming service_type_id is the key
//           List<ServiceArea> serviceAreas = [];
//           serviceTypeData['service_area_types']['floor']
//               .forEach((serviceAreaData) {
//             // Assuming ServiceArea is a model class for service area data
//             ServiceArea serviceArea = ServiceArea.fromJson(serviceAreaData);
//             serviceAreas.add(serviceArea);
//           });
//           serviceAreaTypes[key] = serviceAreas;
//         });

// Print service area types
//         serviceAreaTypes.forEach((key, value) {
//           // debugPrint("Service Type ID: $key");
//           value.forEach((serviceArea) {
//             // debugPrint("Service Area Name: ${serviceArea.serviceAreaName}");
//             // Print other properties of service area if needed
//           });
//         });

//         Map<String, dynamic> serviceTypesData = response['service_types'];
//Map<String, List<ServiceArea>> allServiceAreas = {};

//         serviceTypesData.forEach((key, value) {
//           List<ServiceArea> serviceAreas = [];
//           value['service_area_types'].forEach((areaType, areaDataList) {
//             areaDataList.forEach((areaData) {
//               ServiceArea area = ServiceArea.fromJson(areaData);
//               serviceAreas.add(area);
//             });
//           });
//           allServiceAreas[key] = serviceAreas;
//         });

// Extract service types
        List<dynamic> serviceTypes = response['data']['service_types'];

// Extract service names
        // setState(() {
        //   serviceNames = serviceTypes
        //       .map((serviceType) => serviceType['service_name'])
        //       .toList();
        // });

        setState(() {
          customIcons = List.generate(4, (index) => false);
          isLoading = false;
        });

        // Extract the "service_types" array from the data
        // List<dynamic> serviceTypes1 = response['data']['service_types'];

        // Extract service names from each service type
        //List<String> serviceNames = [];
        for (var serviceType in serviceTypes) {
          String serviceName = serviceType['service_name'];
          serviceNames.add(serviceName);
        }

        // Print the extracted service names
        // debugPrint('All Service Names: $serviceNames');

        serviceTypeListss = response['data']['service_types'];
      });
    } catch (error) {
      // Handle any exceptions here, e.g., show an error dialog
      // debugPrint(error.toString());
      // Show an error dialog or handle the error accordingly
      setState(() {
        isLoading = false;
      });
    }
  }
}
