import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../feedback/app_toast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

import '../display/app_icon_tile.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';
import 'location_picker_footer.dart';

class LocationResult {
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String placeId;
  final String landmark;
  final String country;
  final String state;
  final String city;
  final String pincode;

  LocationResult({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    required this.landmark,
    required this.country,
    required this.state,
    required this.city,
    required this.pincode,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      formattedAddress: json['formatted_address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      placeId: json['place_id'] ?? '',
      landmark: json['landmark'] ?? '',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      city: json['city'] ?? '',
      pincode: json['pincode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formatted_address': formattedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'place_id': placeId,
      'landmark': landmark,
      'country': country,
      'state': state,
      'city': city,
      'pincode': pincode,
    };
  }
}

class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({super.key});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  LocationResult? _locationResult;
  bool _isMapLoading = true;
  Position? _currentPosition;

  // Windows WebView Controller
  final win.WebviewController _winController = win.WebviewController();
  bool _isWinInitialized = false;

  // Android WebView controller; null until the map template is loaded.
  WebViewController? _androidController;

  @override
  void initState() {
    super.initState();
    _loadLocationAndWebView();
  }

  Future<void> _loadLocationAndWebView() async {
    try {
      // 1. Get device position
      _currentPosition = await _determinePosition();
    } catch (e) {
      debugPrint("LocationPickerDialog: GPS position unavailable: $e");
    }

    // 2. Load the picker HTML template
    String htmlString = "";
    try {
      htmlString = await rootBundle.loadString('assets/html/map_picker.html');
    } catch (e) {
      debugPrint("LocationPickerDialog: Error loading template asset: $e");
      if (mounted) {
        AppToast.error(context, 'common.location_picker_asset_missing'.tr);
        Navigator.of(context).pop();
      }
      return;
    }

    // 3. Inject API Key
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final injectedHtml =
        htmlString.replaceAll('GOOGLE_MAPS_API_KEY_PLACEHOLDER', apiKey);

    // 4. Initialize platform WebView
    if (Platform.isWindows) {
      await _initWindowsWebView(injectedHtml, _currentPosition);
    } else {
      _initAndroidWebView(injectedHtml, _currentPosition);
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      ),
    );
  }

  void _initAndroidWebView(String htmlContent, Position? currentPosition) {
    String processedHtml = htmlContent;
    if (currentPosition != null) {
      processedHtml = processedHtml
          .replaceAll(
            "const latParam = parseFloat(urlParams.get('lat'));",
            "const latParam = ${currentPosition.latitude};",
          )
          .replaceAll(
            "const lngParam = parseFloat(urlParams.get('lng'));",
            "const lngParam = ${currentPosition.longitude};",
          );
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _onLocationReceived(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isMapLoading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(processedHtml);
    if (!mounted) return;
    setState(() => _androidController = controller);
  }

  Future<void> _initWindowsWebView(
      String htmlContent, Position? currentPosition) async {
    String processedHtml = htmlContent;
    if (currentPosition != null) {
      processedHtml = processedHtml
          .replaceAll(
            "const latParam = parseFloat(urlParams.get('lat'));",
            "const latParam = ${currentPosition.latitude};",
          )
          .replaceAll(
            "const lngParam = parseFloat(urlParams.get('lng'));",
            "const lngParam = ${currentPosition.longitude};",
          );
    }

    try {
      await _winController.initialize();
      _winController.webMessage.listen((dynamic message) {
        if (message is String) {
          _onLocationReceived(message);
        } else if (message is Map) {
          _onLocationReceived(jsonEncode(message));
        }
      });

      final dataUrl =
          'data:text/html;charset=utf-8,${Uri.encodeComponent(processedHtml)}';
      await _winController.loadUrl(dataUrl);

      if (mounted) {
        setState(() {
          _isWinInitialized = true;
          _isMapLoading = false;
        });
      }
    } catch (e) {
      debugPrint("LocationPickerDialog: Error building Windows WebView: $e");
      if (mounted) {
        setState(() {
          _isMapLoading = false;
        });
      }
    }
  }

  void _onLocationReceived(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final result = LocationResult.fromJson(data);
      if (mounted) {
        setState(() {
          _locationResult = result;
        });
      }
    } catch (e) {
      debugPrint("LocationPickerDialog: Error decoding received location: $e");
    }
  }

  Widget _buildAndroidWebView() {
    if (Platform.isWindows) return const SizedBox.shrink();
    final controller = _androidController;
    if (controller == null) return const SizedBox.shrink();
    return WebViewWidget(controller: controller);
  }

  Widget _buildWindowsWebView() {
    if (!Platform.isWindows) return const SizedBox.shrink();
    if (!_isWinInitialized) return const SizedBox.shrink();
    return win.Webview(_winController);
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      _winController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _locationResult;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitleBar(context),
            const Divider(height: 1, color: AppColors.border),
            SizedBox(
              height: 400,
              child: ColoredBox(
                color: AppColors.canvas,
                child: Stack(
                  children: [
                    if (Platform.isWindows)
                      _buildWindowsWebView()
                    else
                      _buildAndroidWebView(),
                    if (_isMapLoading) _buildMapLoading(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            LocationPickerFooter(
              address: result?.formattedAddress,
              emptyLabel: 'common.no_location_selected'.tr,
              cancelLabel: 'general.cancel'.tr,
              confirmLabel: 'common.confirm_location'.tr,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: result == null
                  ? null
                  : () => Navigator.of(context).pop(result),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const AppIconTile(
            icon: Icons.map_outlined,
            iconSize: 18,
            background: AppColors.softBlue,
            foreground: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'common.pick_customer_location'.tr,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.muted,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text('common.loading_map_picker'.tr, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
