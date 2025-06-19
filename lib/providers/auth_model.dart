import 'package:flutter/material.dart';

class AuthModel extends ChangeNotifier {
  bool _isLoggedIn = false;
  int? _userId;
  String? _token;

  bool get isLoggedIn {
    debugPrint("🔧 AuthModel: isLoggedIn getter called, value: $_isLoggedIn");
    return _isLoggedIn;
  }
  
  int? get userId {
    debugPrint("🔧 AuthModel: userId getter called, value: $_userId");
    return _userId;
  }
  
  String? get token {
    debugPrint("🔧 AuthModel: token getter called, exists: ${_token != null}");
    if (_token != null) {
      debugPrint("🔧 AuthModel: token preview: ${_token!.length > 20 ? '${_token!.substring(0, 20)}...' : _token}");
    }
    return _token;
  }

  void login(String token, int userId) {
    debugPrint("🔧 AuthModel: login called with userId: $userId, token exists: ${token.isNotEmpty}");
    
    _isLoggedIn = true;
    _userId = userId;
    _token = token;
    
    debugPrint("✅ AuthModel: Login successful - isLoggedIn: $_isLoggedIn, userId: $_userId");

    notifyListeners();
    debugPrint("🔧 AuthModel: notifyListeners called after login");
  }

  void logout() {
    debugPrint("🔧 AuthModel: logout called");
    debugPrint("🔧 AuthModel: Previous state - isLoggedIn: $_isLoggedIn, userId: $_userId");
    
    _isLoggedIn = false;
    _userId = null;
    _token = null;
    
    debugPrint("✅ AuthModel: Logout successful - isLoggedIn: $_isLoggedIn, userId: $_userId");
    
    notifyListeners();
    debugPrint("🔧 AuthModel: notifyListeners called after logout");
  }
}
