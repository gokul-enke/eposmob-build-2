import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/role.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleProvider extends ChangeNotifier {
  List<Role> _roles = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserRole; // Track current user role

  List<Role> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserRole => _currentUserRole;

  // Fetch roles from the API
  Future<void> fetchRoles(BuildContext context) async {
    debugPrint("🔧 RoleProvider: fetchRoles started");

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token;

      debugPrint("🔧 RoleProvider: Auth token exists: ${token != null}");
      debugPrint("🔧 RoleProvider: API URL: ${APPUrl.listRoles}");

      if (token == null) {
        debugPrint("❌ RoleProvider: No auth token available");
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get current user role from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _currentUserRole = prefs.getString('userRole');
      debugPrint("🔧 RoleProvider: Current user role: $_currentUserRole");

      debugPrint("🔧 RoleProvider: Making API request...");
      // Get API key from SharedPreferences
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final response = await http.get(
        Uri.parse(APPUrl.listRoles),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Tenant': apiKey,
        },
      );

      debugPrint("🔧 RoleProvider: API response status: ${response.statusCode}");
      debugPrint("🔧 RoleProvider: API response body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success') {
          final RoleModelData roleData = RoleModelData.fromJson(data['data']);
          _roles = roleData.roles;
          debugPrint("✅ RoleProvider: Successfully loaded ${_roles.length} roles");

          for (var role in _roles) {
            debugPrint(
                "   - Loaded role: ID=${role.id}, Name=${role.name}, Permissions=${role.permissionsCount}");
          }
        } else {
          _error = data['message'] ?? 'Failed to fetch roles';
          debugPrint("❌ RoleProvider: API returned error: $_error");
        }
      } else {
        _error = 'Failed to fetch roles: ${response.statusCode}';
        debugPrint("❌ RoleProvider: HTTP error: $_error");
      }
    } catch (e) {
      _error = 'Error: $e';
      debugPrint("❌ RoleProvider: Exception occurred: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint("🔧 RoleProvider: fetchRoles completed");
    }
  }

  // Get role by original name
  Role? getRoleByOriginalName(String originalName) {
    try {
      return _roles.firstWhere((role) => role.originalName == originalName);
    } catch (e) {
      debugPrint("❌ RoleProvider: No role found with original name $originalName");
      return null;
    }
  }

  // Check if a role has specific permission
  bool hasPermission(String originalRoleName, String permission) {
    final role = getRoleByOriginalName(originalRoleName);
    if (role == null) return false;
    
    return role.permissions.contains(permission);
  }

  // Check if current user has specific permission (gets role automatically)
  bool currentUserHasPermissionSync(String permission) {
    if (_currentUserRole == null) {
      debugPrint("❌ RoleProvider: No current user role available");
      return false;
    }
    
    return hasPermission(_currentUserRole!, permission);
  }

  // Get all permissions for a role
  List<String> getRolePermissions(String originalRoleName) {
    final role = getRoleByOriginalName(originalRoleName);
    if (role == null) return [];
    
    return role.permissions;
  }

  // Check if user has permission based on their role
  Future<bool> currentUserHasPermission(BuildContext context, String permission) async {
    try {
      // Get current user role from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('user_role');
      
      if (userRole == null) {
        debugPrint("❌ RoleProvider: No user role found in SharedPreferences");
        return false;
      }

      // If roles are not loaded yet, fetch them
      if (_roles.isEmpty) {
        await fetchRoles(context);
      }

      return hasPermission(userRole, permission);
    } catch (e) {
      debugPrint("❌ RoleProvider: Error checking user permission: $e");
      return false;
    }
  }

  // Get current user permissions
  Future<List<String>> getCurrentUserPermissions(BuildContext context) async {
    try {
      // Get current user role from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('user_role');
      
      if (userRole == null) {
        debugPrint("❌ RoleProvider: No user role found in SharedPreferences");
        return [];
      }

      // If roles are not loaded yet, fetch them
      if (_roles.isEmpty) {
        await fetchRoles(context);
      }

      return getRolePermissions(userRole);
    } catch (e) {
      debugPrint("❌ RoleProvider: Error getting user permissions: $e");
      return [];
    }
  }

  // Clear roles data
  void clearRoles() {
    _roles = [];
    _error = null;
    notifyListeners();
  }

  // Refresh roles data
  Future<void> refreshRoles(BuildContext context) async {
    await fetchRoles(context);
  }
}
