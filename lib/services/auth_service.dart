import 'package:flutter/material.dart';
import 'api_service.dart'; // Import ApiService

class AuthService with ChangeNotifier {
  String? _token;
  final ApiService _apiService; // Nhận ApiService qua constructor

  // *** SỬA LỖI: Thêm constructor ***
  AuthService(this._apiService);

  bool get isAuthenticated => _token != null;
  String? get token => _token;

  // Thử tự động login bằng token đã lưu
  Future<bool> tryAutoLogin() async {
    _token = await _apiService.getTokenFromStorage();
    if (_token == null) {
      return false;
    }
    // TODO: Thêm logic kiểm tra token hết hạn (ví dụ: dùng thư viện jwt_decoder)
    // Nếu hết hạn thì gọi logout() và return false
    notifyListeners();
    return true;
  }

  // Gọi API login
  Future<void> login(String username, String password) async {
    try {
      _token = await _apiService.login(username, password);
      notifyListeners(); // Thông báo UI cập nhật
    } catch (e) {
      _token = null; // Đảm bảo token là null nếu login lỗi
      notifyListeners();
      print("Login error: $e"); // In lỗi ra console
      rethrow; // Ném lại lỗi để UI xử lý và hiển thị
    }
  }

  // Gọi API register
  Future<void> register(String username, String password) async {
    try {
      await _apiService.register(username, password);
    } catch (e) {
      print("Register error: $e");
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    await _apiService.logout();
    notifyListeners(); // Thông báo UI cập nhật
  }
}