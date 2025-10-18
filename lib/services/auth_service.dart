import 'package:flutter/material.dart';
import 'api_service.dart'; // Import ApiService

class AuthService with ChangeNotifier {
  String? _token;
  final ApiService _apiService = ApiService(); // Khởi tạo ApiService

  bool get isAuthenticated => _token != null;
  String? get token => _token;

  // Thử tự động login bằng token đã lưu
  Future<bool> tryAutoLogin() async {
    _token = await _apiService.getTokenFromStorage();
    if (_token == null) {
      return false;
    }
    // TODO: Thêm logic kiểm tra token hết hạn (ví dụ: dùng thư viện jwt_decoder)
    notifyListeners();
    return true;
  }

  // Gọi API login
  Future<void> login(String username, String password) async {
    try {
      _token = await _apiService.login(username, password);
      notifyListeners();
    } catch (e) {
      rethrow; // Ném lại lỗi để UI xử lý
    }
  }

  // Gọi API register
  Future<void> register(String username, String password) async {
    try {
      await _apiService.register(username, password);
      // Có thể tự động login sau khi đăng ký thành công
      // await login(username, password);
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    await _apiService.logout();
    notifyListeners();
  }
}