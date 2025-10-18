import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // !!! THAY ĐỔI ĐỊA CHỈ IP HOẶC DOMAIN CỦA BACKEND CỦA BẠN !!!
  // Nếu test trên máy ảo Android, dùng 10.0.2.2
  // Nếu test trên máy thật cùng mạng Wi-Fi, dùng IP của máy tính (vd: 192.168.1.100)
  final String _baseUrl = "http://10.0.2.2:8080/api"; // Mặc định cho máy ảo Android

  final _storage = const FlutterSecureStorage();

  // ----- Helper Methods -----

  // Lấy token từ storage
  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwtToken');
  }

  // Tạo Headers chuẩn (bao gồm cả JWT nếu có)
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Hàm POST chung
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body, {bool includeAuth = true}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: includeAuth),
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  // Hàm GET chung
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final response = await http.get(
      url,
      headers: await _getHeaders(includeAuth: includeAuth),
    );
    return _handleResponse(response);
  }

  // Xử lý response chung
  dynamic _handleResponse(http.Response response) {
    final decodedBody = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody; // Trả về Map hoặc List
    } else {
      // Ném lỗi với thông báo từ server (nếu có)
      String errorMessage = "Lỗi không xác định";
      if (decodedBody is Map && decodedBody.containsKey('message')) {
        errorMessage = decodedBody['message'];
      } else if (decodedBody is String) {
        errorMessage = decodedBody;
      } else if (decodedBody is Map) {
        // Xử lý lỗi validation (trả về Map<String, String>)
        errorMessage = decodedBody.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      }
      throw Exception('Lỗi ${response.statusCode}: $errorMessage');
    }
  }

  // ----- Auth Endpoints -----

  Future<String> login(String username, String password) async {
    final response = await post('/auth/login', {'username': username, 'password': password}, includeAuth: false);
    final token = response['token'] as String;
    await _storage.write(key: 'jwtToken', value: token);
    return token;
  }

  Future<void> register(String username, String password) async {
    await post('/auth/register', {'username': username, 'password': password}, includeAuth: false);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwtToken');
  }

  Future<String?> getTokenFromStorage() async {
    return await _storage.read(key: 'jwtToken');
  }


  // ----- Device Endpoints -----

  Future<void> claimDevice(String deviceId, String masterPassword) async {
    await post('/devices/claim', {'deviceId': deviceId, 'devicePassword': masterPassword});
  }

  Future<void> sendCommand(String deviceId, String action) async {
    await post('/devices/command', {'deviceId': deviceId, 'action': action});
  }

  Future<List<dynamic>> getMyDevices() async {
    final response = await get('/devices/my-devices');
    return response as List<dynamic>; // Backend trả về List<DeviceResponse>
  }

  Future<String> generateInvitePin(String deviceId) async {
    final response = await get('/devices/$deviceId/generate-invite');
    return response['pin'] as String;
  }

  Future<void> requestAccess(String deviceId, String pin) async {
    await post('/devices/request-access', {'deviceId': deviceId, 'pin': pin});
  }

  Future<void> approveAccess(int accessRequestId) async {
    await post('/devices/approve-access', {'accessRequestId': accessRequestId});
  }

  Future<void> recoverAdmin(String deviceId, String masterPassword) async {
    await post('/devices/recover-admin', {'deviceId': deviceId, 'masterPassword': masterPassword});
  }

// (Thêm các hàm gọi API khác nếu cần: từ chối, xóa thành viên, đổi tên...)
}