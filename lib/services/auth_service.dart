import 'package:flutter/material.dart';
import 'api_service.dart'; // Import ApiService

class AuthService with ChangeNotifier {
  String? _token;
  // Bỏ final ApiService _apiService = ApiService();

  // Thêm final và constructor
  final ApiService _apiService;
  AuthService(this._apiService); // Constructor nhận ApiService

  bool get isAuthenticated => _token != null;
  String? get token => _token;

  Future<bool> tryAutoLogin() async {
    _token = await _apiService.getTokenFromStorage();
    if (_token == null) {
      return false;
    }
    // TODO: Validate token expiry
    notifyListeners();
    return true;
  }

  Future<void> login(String username, String password) async {
    try {
      _token = await _apiService.login(username, password);
      notifyListeners();
    } catch (e) {
      _token = null; // Reset token on error
      notifyListeners();
      print("Login error: $e");
      rethrow;
    }
  }

  Future<void> register(String username, String password) async {
    try {
      await _apiService.register(username, password);
    } catch (e) {
      print("Register error: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    await _apiService.logout();
    notifyListeners();
  }
}