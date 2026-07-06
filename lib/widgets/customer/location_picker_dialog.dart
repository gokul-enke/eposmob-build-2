import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

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
  const LocationPickerDialog({Key? key}) : super(key: key);

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

  // Android WebView Controller
  late final WebViewController _androidController;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Location picker asset template missing.")),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // 3. Inject API Key
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final injectedHtml = htmlString.replaceAll('GOOGLE_MAPS_API_KEY_PLACEHOLDER', apiKey);

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
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
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

    _androidController = WebViewController()
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
  }

  Future<void> _initWindowsWebView(String htmlContent, Position? currentPosition) async {
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

      final dataUrl = 'data:text/html;charset=utf-8,${Uri.encodeComponent(processedHtml)}';
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
    return WebViewWidget(controller: _androidController);
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Pick Customer Location",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            const Divider(height: 1),

            // Map View Port
            Container(
              height: 400,
              color: Colors.grey.shade100,
              child: Stack(
                children: [
                  if (Platform.isWindows)
                    _buildWindowsWebView()
                  else
                    _buildAndroidWebView(),

                  if (_isMapLoading)
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.blue),
                          SizedBox(height: 12),
                          Text("Loading map picker..."),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Green Details Box
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationResult != null && _locationResult!.formattedAddress.isNotEmpty
                                ? _locationResult!.formattedAddress
                                : "No location selected yet. Search an address or tap/drag the map pin.",
                            style: TextStyle(
                              fontSize: 13,
                              color: _locationResult != null ? Colors.green.shade900 : Colors.grey.shade600,
                              fontWeight: _locationResult != null ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bottom Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _locationResult == null
                            ? null
                            : () => Navigator.of(context).pop(_locationResult),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Confirm Location"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
