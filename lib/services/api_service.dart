import 'dart:convert';
import 'dart:io'; // Để check platform
import 'dart:async'; // Để dùng TimeoutException
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // !!! THAY ĐỔI ĐỊA CHỈ NÀY THÀNH URL HEROKU CỦA BẠN !!!
  // Hoặc dùng IP tương ứng để test local
  late final String _baseUrl;
  final int _requestTimeout = 15; // Thời gian chờ (giây)

  final _storage = const FlutterSecureStorage();

  ApiService() {
    // --- CẤU HÌNH ĐỊA CHỈ BACKEND ---
    const String herokuUrl = "https://rolldingdoor-36a1a3a76e60.herokuapp.com/api"; // URL Heroku của bạn
    const String localPcIp = "192.168.1.100"; // THAY IP MÁY TÍNH CỦA BẠN

    const bool useHeroku = true; // Đặt là true để dùng Heroku, false để test local

    if (useHeroku) {
      _baseUrl = herokuUrl;
    } else {
      if (Platform.isAndroid) {
        _baseUrl = "http://10.0.2.2:8080/api"; // Android Emulator
        // _baseUrl = "http://$localPcIp:8080/api"; // Máy Android thật
      } else {
        _baseUrl = "http://localhost:8080/api"; // iOS Simulator / Desktop
        // _baseUrl = "http://$localPcIp:8080/api"; // Máy iPhone thật
      }
    }
    print("ApiService using base URL: $_baseUrl");
  }

  // ----- Helper Methods -----

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwtToken');
  }

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Xử lý response và lỗi chung
  dynamic _handleResponse(http.Response response) {
    String responseBody;
    try {
      responseBody = utf8.decode(response.bodyBytes);
    } catch (_) {
      responseBody = response.body;
    }

    dynamic decodedBody;
    try {
      decodedBody = json.decode(responseBody);
    } catch (_) {
      decodedBody = responseBody;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      print("API Response ${response.statusCode}: $responseBody");
      return decodedBody;
    } else {
      String errorMessage = "Lỗi không xác định";
      if (decodedBody is Map && decodedBody['message'] is String) {
        errorMessage = decodedBody['message'];
      } else if (decodedBody is Map) {
        try {
          errorMessage = decodedBody.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        } catch (_) {
          errorMessage = decodedBody.toString();
        }
      } else if (decodedBody is String && decodedBody.isNotEmpty) {
        errorMessage = decodedBody;
      } else if (response.reasonPhrase != null && response.reasonPhrase!.isNotEmpty) {
        errorMessage = response.reasonPhrase!;
      }
      print("API Error ${response.statusCode}: $errorMessage");
      throw Exception('${response.statusCode}: $errorMessage');
    }
  }


  // Hàm POST chung
  Future<dynamic> post(String endpoint, Map<String, dynamic> body, {bool includeAuth = true}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    print("POST $url");
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(includeAuth: includeAuth),
        body: json.encode(body),
      ).timeout(Duration(seconds: _requestTimeout));
      return _handleResponse(response);
    } on SocketException catch (e) {
      print("Network Error (POST $endpoint): $e");
      throw Exception("Lỗi kết nối mạng. Vui lòng kiểm tra Internet và địa chỉ máy chủ.");
    } on TimeoutException {
      print("Timeout Error (POST $endpoint)");
      throw Exception("Yêu cầu tới máy chủ quá hạn ($_requestTimeout giây). Vui lòng thử lại.");
    } catch (e) {
      print("Unknown Error (POST $endpoint): $e");
      rethrow;
    }
  }

  // Hàm GET chung
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    print("GET $url");
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(includeAuth: includeAuth),
      ).timeout(Duration(seconds: _requestTimeout));
      return _handleResponse(response);
    } on SocketException catch (e) {
      print("Network Error (GET $endpoint): $e");
      throw Exception("Lỗi kết nối mạng. Vui lòng kiểm tra Internet và địa chỉ máy chủ.");
    } on TimeoutException {
      print("Timeout Error (GET $endpoint)");
      throw Exception("Yêu cầu tới máy chủ quá hạn ($_requestTimeout giây). Vui lòng thử lại.");
    } catch (e) {
      print("Unknown Error (GET $endpoint): $e");
      rethrow;
    }
  }

  // Hàm PUT chung (Cho Rename)
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    print("PUT $url");
    try {
      final response = await http.put(
        url,
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(body),
      ).timeout(Duration(seconds: _requestTimeout));
      return _handleResponse(response);
    } on SocketException catch (e) {
      print("Network Error (PUT $endpoint): $e");
      throw Exception("Lỗi kết nối mạng.");
    } on TimeoutException {
      print("Timeout Error (PUT $endpoint)");
      throw Exception("Yêu cầu quá hạn.");
    } catch (e) {
      print("Unknown Error (PUT $endpoint): $e");
      rethrow;
    }
  }

  // Hàm DELETE chung (Cho Remove/Delete)
  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    print("DELETE $url");
    try {
      final response = await http.delete(
        url,
        headers: await _getHeaders(includeAuth: true),
        body: body != null ? json.encode(body) : null, // Body cho removeMember
      ).timeout(Duration(seconds: _requestTimeout));
      return _handleResponse(response);
    } on SocketException catch (e) {
      print("Network Error (DELETE $endpoint): $e");
      throw Exception("Lỗi kết nối mạng.");
    } on TimeoutException {
      print("Timeout Error (DELETE $endpoint)");
      throw Exception("Yêu cầu quá hạn.");
    } catch (e) {
      print("Unknown Error (DELETE $endpoint): $e");
      rethrow;
    }
  }

  // ----- Auth Endpoints -----

  Future<String> login(String username, String password) async {
    final response = await post('/auth/login', {'username': username, 'password': password}, includeAuth: false);
    if (response is Map && response['token'] is String) {
      final token = response['token'] as String;
      await _storage.write(key: 'jwtToken', value: token);
      return token;
    } else {
      throw Exception("Phản hồi đăng nhập không hợp lệ từ máy chủ.");
    }
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
    return (response is List) ? response : [];
  }

  Future<String> generateInvitePin(String deviceId) async {
    final encodedDeviceId = Uri.encodeComponent(deviceId);
    final response = await get('/devices/$encodedDeviceId/generate-invite');
    if (response is Map && response['pin'] is String) {
      return response['pin'] as String;
    } else {
      throw Exception("Phản hồi tạo mã PIN không hợp lệ.");
    }
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

  // --- CÁC API MỚI ĐÃ THÊM ---
  Future<void> setOfflinePassword(String deviceId, String newPassword) async {
    await post('/devices/set-offline-password', {
      'deviceId': deviceId,
      'newPassword': newPassword,
    });
  }

  Future<void> rejectAccess(int accessRequestId) async {
    await post('/devices/reject-access', {'accessRequestId': accessRequestId});
  }

  Future<void> removeMember(int accessId) async {
    // API yêu cầu DTO RemoveMemberRequest, chỉ chứa accessId trong body
    await delete('/devices/remove-member', body: {'accessId': accessId});
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    await put('/devices/rename-device', {'deviceId': deviceId, 'newName': newName});
  }

  Future<void> deleteDevice(String deviceId) async {
    final encodedDeviceId = Uri.encodeComponent(deviceId);
    await delete('/devices/delete-device/$encodedDeviceId');
  }
}