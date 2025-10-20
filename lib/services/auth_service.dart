import 'package:flutter/material.dart';
import 'api_service.dart'; // Import ApiService

class AuthService with ChangeNotifier {
  String? _token;

  // Bỏ dòng này: final ApiService _apiService = ApiService();

  // Thêm dòng này:
  final ApiService _apiService; // Nhận ApiService qua constructor

  // *** THÊM CONSTRUCTOR NÀY ***
  AuthService(this._apiService);

  bool get isAuthenticated => _token != null;
  String? get token => _token;

  // (Các hàm còn lại: tryAutoLogin, login, register, logout giữ nguyên)
  // ...
  Future<bool> tryAutoLogin() async { //
    _token = await _apiService.getTokenFromStorage();
    if (_token == null) {
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<void> login(String username, String password) async { //
    try {
      _token = await _apiService.login(username, password);
      notifyListeners();
    } catch (e) {
      _token = null;
      notifyListeners();
      print("Login error: $e");
      rethrow;
    }
  }

  Future<void> register(String username, String password) async { //
    try {
      await _apiService.register(username, password);
    } catch (e) {
      print("Register error: $e");
      rethrow;
    }
  }

  Future<void> logout() async { //
    _token = null;
    await _apiService.logout();
    notifyListeners();
  }
}