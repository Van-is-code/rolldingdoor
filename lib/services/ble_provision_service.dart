import 'dart:convert'; // Để dùng utf8
import 'dart:async'; // Để dùng Stream, Future, timeout
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleProvisionService {
  // --- UUIDs CHO CHẾ ĐỘ CÀI ĐẶT (Provisioning) ---
  // (Phải khớp 100% với code ESP32 `startBLEProvisioning`)
  final Guid provServiceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid provSsidCharUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
  final Guid provPassCharUuid = Guid("c31b315b-1c58-439d-8692-0b5bc1a5e1e0");
  final Guid provStartCharUuid = Guid("a8234a31-5091-4c74-a0f5-3b95a7ffc311");
  final Guid provDeviceIdCharUuid = Guid("d2e9c2f6-5e5d-4f1b-8f7a-8f0a5b2e3f5b");

  // --- UUIDs CHO CHẾ ĐỘ ĐIỀU KHIỂN (Control Offline) ---
  // (Phải khớp 100% với code ESP32 `startBLEControl`)
  final Guid controlServiceUuid = Guid("a97e1e75-5100-4ba4-98c8-1a8069db2142");
  final Guid controlCommandCharUuid = Guid("5f1816e8-232a-4302-8611-e1bc1824c9a4");
  final Guid controlPasswordCharUuid = Guid("b2a8d9e1-0e97-4c28-9c1b-7a5f674d32a1");

  // Các biến tạm để lưu characteristics tìm được
  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passChar;
  BluetoothCharacteristic? _provisionChar;
  BluetoothCharacteristic? _deviceIdChar;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _passwordChar;

  // Cung cấp các Stream để UI lắng nghe
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  // 1. Bắt đầu quét thiết bị BLE
  Future<void> startScan({int timeoutSeconds = 5, List<Guid> withServices = const []}) async {
    var adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw Exception("Vui lòng bật Bluetooth trên điện thoại.");
    }
    await FlutterBluePlus.stopScan(); // Dừng quét cũ
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: timeoutSeconds),
      withServices: withServices, // Lọc theo Service UUID nếu được cung cấp
    );
  }

  // 2. Dừng quét
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // 3. Kết nối đến thiết bị BLE
  Future<BluetoothDevice> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      print("Connected to ${device.platformName} (${device.remoteId})");

      // Yêu cầu ghép đôi (Pairing) nếu chưa
      // Cần check quyền Bluetooth connect trên AndroidManifest.xml và Info.plist
      try {
        print("Attempting to pair with ${device.remoteId}...");
        await device.pair();
        print("Pairing successful or already paired.");
      } catch (e) {
        print("Pairing failed (might be already paired or OS popup handled): $e");
        // Không ném lỗi ở đây, vì nhiều HĐH tự xử lý pairing khi kết nối
        // Chỉ ném lỗi nếu kết nối thất bại hoàn toàn
      }

      return device;
    } catch (e) {
      print("Connection error to ${device.remoteId}: $e");
      try { await device.disconnect(); } catch (_) {} // Cố gắng dọn dẹp
      throw Exception("Kết nối tới thiết bị thất bại. Vui lòng thử lại.");
    }
  }

  // 4. Ngắt kết nối
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print("Disconnected from ${device.platformName} (${device.remoteId})");
    } catch (e) {
      print("Disconnection error from ${device.remoteId}: $e");
    }
  }

  // 5. Tìm Services/Chars cho LUỒNG CÀI ĐẶT và đọc Device ID
  Future<String?> discoverProvisionServices(BluetoothDevice device) async {
    _ssidChar = _passChar = _provisionChar = _deviceIdChar = null;
    List<BluetoothService> services;
    try {
      print("Discovering Provision services for ${device.remoteId}...");
      services = await device.discoverServices(timeout: 10);
    } catch (e) {
      throw Exception("Không thể đọc dịch vụ (Provision) từ thiết bị: $e");
    }

    bool foundService = false;
    for (var service in services) {
      if (service.uuid == provServiceUuid) {
        foundService = true;
        for (var char in service.characteristics) {
          if (char.uuid == provSsidCharUuid) _ssidChar = char;
          if (char.uuid == provPassCharUuid) _passChar = char;
          if (char.uuid == provStartCharUuid) _provisionChar = char;
          if (char.uuid == provDeviceIdCharUuid) _deviceIdChar = char;
        }
        break;
      }
    }
    if (!foundService) throw Exception("Không tìm thấy Service UUID ($provServiceUuid) cho Cài đặt.");
    if (_ssidChar == null || _passChar == null || _provisionChar == null || _deviceIdChar == null) {
      throw Exception("Thiếu một hoặc nhiều characteristic BLE cho Cài đặt.");
    }

    // Đọc Device ID (MAC)
    try {
      final macBytes = await _deviceIdChar!.read(timeout: 5);
      if (macBytes.isEmpty) throw Exception("Device ID (MAC) trả về giá trị rỗng.");
      final deviceId = utf8.decode(macBytes);
      print("Read Device ID (MAC): $deviceId");
      return deviceId;
    } catch (e) {
      throw Exception("Lỗi khi đọc Device ID (MAC): $e");
    }
  }

  // 6. Gửi thông tin Wi-Fi (cho Luồng Cài đặt)
  Future<void> sendProvisionCredentials(String ssid, String password) async {
    if (_ssidChar == null || _passChar == null) {
      throw Exception("Chưa sẵn sàng gửi thông tin Wi-Fi (thiếu characteristic).");
    }
    try {
      print("Writing SSID: $ssid");
      await _ssidChar!.write(utf8.encode(ssid), withoutResponse: true, timeout: 5);
      await Future.delayed(const Duration(milliseconds: 300));
      print("Writing Password: $password");
      await _passChar!.write(utf8.encode(password), withoutResponse: true, timeout: 5);
      await Future.delayed(const Duration(milliseconds: 300));
      print("Credentials sent via BLE.");
    } catch (e) {
      throw Exception("Lỗi khi gửi thông tin Wi-Fi qua BLE: $e");
    }
  }

  // 7. Gửi lệnh bắt đầu Provisioning (cho Luồng Cài đặt)
  Future<void> sendProvisionStartCommand(BluetoothDevice device) async {
    if (_provisionChar == null) {
      throw Exception("Chưa sẵn sàng gửi lệnh provision (thiếu characteristic).");
    }
    try {
      print("Writing Provision command: start");
      await _provisionChar!.write(utf8.encode("start"), withoutResponse: true, timeout: 5);
      print("Provision command sent. Disconnecting BLE...");
      await disconnectFromDevice(device); // Ngắt kết nối để ESP32 restart
    } catch (e) {
      try { await disconnectFromDevice(device); } catch (_) {} // Cố gắng ngắt kết nối
      throw Exception("Lỗi khi gửi lệnh Provision qua BLE: $e");
    }
  }

  // 8. Tìm Services/Chars cho LUỒNG ĐIỀU KHIỂN OFFLINE
  Future<bool> discoverControlServices(BluetoothDevice device) async {
    _commandChar = _passwordChar = null; // Reset
    List<BluetoothService> services;
    try {
      print("Discovering Control services for ${device.remoteId}...");
      services = await device.discoverServices(timeout: 10);
    } catch (e) {
      throw Exception("Không thể đọc dịch vụ (Control) từ thiết bị: $e");
    }

    bool foundService = false;
    for (var service in services) {
      if (service.uuid == controlServiceUuid) {
        foundService = true;
        for (var char in service.characteristics) {
          if (char.uuid == controlCommandCharUuid) _commandChar = char;
          if (char.uuid == controlPasswordCharUuid) _passwordChar = char;
        }
        break;
      }
    }
    if (!foundService) throw Exception("Không tìm thấy Service UUID ($controlServiceUuid) cho Điều khiển.");
    if (_commandChar == null || _passwordChar == null) {
      print("Missing characteristics: command=$_commandChar, pass=$_passwordChar");
      throw Exception("Thiếu characteristic BLE (Command hoặc Password) cho Điều khiển.");
    }

    print("Control Characteristics found!");
    return true; // Sẵn sàng
  }

  // 9. Gửi Mật khẩu Offline (cho Luồng Điều khiển Offline)
  Future<void> sendOfflinePassword(String password) async {
    if (_passwordChar == null) {
      throw Exception("Characteristic Mật khẩu không tồn tại.");
    }
    try {
      print("Writing Offline Password...");
      await _passwordChar!.write(utf8.encode(password), withoutResponse: true, timeout: 5);
      print("Offline Password sent.");
    } catch (e) {
      throw Exception("Lỗi gửi Mật khẩu Offline qua BLE: $e");
    }
  }

  // 10. Gửi Lệnh Điều khiển Offline (cho Luồng Điều khiển Offline)
  Future<void> sendOfflineCommand(String command) async {
    if (_commandChar == null) {
      throw Exception("Characteristic Lệnh không tồn tại.");
    }
    try {
      print("Writing Offline Command: $command");
      await _commandChar!.write(utf8.encode(command), withoutResponse: true, timeout: 5);
      print("Offline Command sent.");
    } catch (e) {
      throw Exception("Lỗi gửi Lệnh ($command) qua BLE: $e");
    }
  }
}