// Thêm dòng import này vào đầu file
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert'; // Để dùng utf8
import 'dart:async'; // Để dùng Stream, Future, timeout

class BleProvisionService {
  // UUIDs (Phải khớp 100% với code ESP32)
  final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid wifiSsidCharUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
  final Guid wifiPassCharUuid = Guid("c31b315b-1c58-439d-8692-0b5bc1a5e1e0");
  final Guid provisionCharUuid = Guid("a8234a31-5091-4c74-a0f5-3b95a7ffc311");
  final Guid deviceIdCharUuid = Guid("d2e9c2f6-5e5d-4f1b-8f7a-8f0a5b2e3f5b");

  // Các biến để lưu characteristic tìm được
  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passChar;
  BluetoothCharacteristic? _provisionChar;
  BluetoothCharacteristic? _deviceIdChar;

  // Cung cấp các Stream để UI lắng nghe
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  // 1. Bắt đầu quét thiết bị BLE
  Future<void> startScan({int timeoutSeconds = 5}) async {
    // Kiểm tra Bluetooth Adapter
    var adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw Exception("Vui lòng bật Bluetooth trên điện thoại.");
    }
    // Dừng quét cũ (nếu có) trước khi bắt đầu quét mới
    await FlutterBluePlus.stopScan();
    // Bắt đầu quét
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: timeoutSeconds),
      // withServices: [serviceUuid], // Có thể lọc theo service UUID
    );
  }

  // 2. Dừng quét
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // 3. Kết nối đến thiết bị BLE
  Future<BluetoothDevice> connectToDevice(BluetoothDevice device) async {
    try {
      // Ngắt kết nối các thiết bị khác trước khi kết nối mới (đảm bảo chỉ kết nối 1 thiết bị)
      // List<BluetoothDevice> connected = FlutterBluePlus.connectedDevices;
      // for (var d in connected) {
      //   if (d.remoteId != device.remoteId) {
      //     await d.disconnect();
      //   }
      // }

      // Kết nối với timeout
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      print("Connected to ${device.platformName} (${device.remoteId})");
      return device;
    } catch (e) {
      print("Connection error to ${device.remoteId}: $e");
      // Thử ngắt kết nối nếu lỗi xảy ra trong quá trình kết nối
      try { await device.disconnect(); } catch (_) {}
      throw Exception("Kết nối tới thiết bị thất bại. Vui lòng thử lại.");
    }
  }

  // 4. Ngắt kết nối khỏi thiết bị BLE
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print("Disconnected from ${device.platformName} (${device.remoteId})");
    } catch (e) {
      print("Disconnection error from ${device.remoteId}: $e");
      // Không cần throw lỗi ở đây
    }
  }

  // 5. Tìm Services, Characteristics và đọc Device ID (MAC)
  Future<String?> discoverServicesAndGetDeviceId(BluetoothDevice device) async {
    _ssidChar = _passChar = _provisionChar = _deviceIdChar = null; // Reset
    List<BluetoothService> services;
    try {
      print("Discovering services for ${device.remoteId}...");
      services = await device.discoverServices(timeout: 10);
    } catch (e) {
      print("Service discovery error for ${device.remoteId}: $e");
      throw Exception("Không thể đọc dịch vụ từ thiết bị (${e.toString()}).");
    }

    bool foundService = false;
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        foundService = true;
        print("Found target service: ${service.uuid}");
        for (var char in service.characteristics) {
          if (char.uuid == wifiSsidCharUuid) _ssidChar = char;
          if (char.uuid == wifiPassCharUuid) _passChar = char;
          if (char.uuid == provisionCharUuid) _provisionChar = char;
          if (char.uuid == deviceIdCharUuid) _deviceIdChar = char;
        }
        break;
      }
    }

    if (!foundService) {
      throw Exception("Không tìm thấy Service UUID ($serviceUuid) cần thiết trên thiết bị.");
    }
    if (_ssidChar == null || _passChar == null || _provisionChar == null || _deviceIdChar == null) {
      print("Missing characteristics: ssid=${_ssidChar?.uuid}, pass=${_passChar?.uuid}, prov=${_provisionChar?.uuid}, devId=${_deviceIdChar?.uuid}");
      throw Exception("Thiếu một hoặc nhiều characteristic BLE cần thiết.");
    }

    // Đọc Device ID (MAC)
    try {
      print("Reading Device ID characteristic (${_deviceIdChar!.uuid})...");
      final macBytes = await _deviceIdChar!.read(timeout: 5);
      if (macBytes.isEmpty) {
        throw Exception("Characteristic Device ID trả về giá trị rỗng.");
      }
      final deviceId = utf8.decode(macBytes);
      print("Read Device ID (MAC): $deviceId");
      return deviceId;
    } catch (e) {
      print("Error reading Device ID char: $e");
      throw Exception("Lỗi khi đọc Device ID (MAC): ${e.toString()}");
    }
  }

  // 6. Gửi thông tin Wi-Fi
  Future<void> sendCredentials(String ssid, String password) async {
    if (_ssidChar == null || _passChar == null) {
      throw Exception("BLE characteristics chưa sẵn sàng để gửi Wi-Fi.");
    }
    try {
      print("Writing SSID: $ssid");
      await _ssidChar!.write(utf8.encode(ssid), withoutResponse: true, timeout: 5);
      await Future.delayed(const Duration(milliseconds: 300)); // Tăng delay

      print("Writing Password: $password");
      await _passChar!.write(utf8.encode(password), withoutResponse: true, timeout: 5);
      await Future.delayed(const Duration(milliseconds: 300)); // Tăng delay

      print("Credentials sent via BLE.");
    } catch (e) {
      print("Error writing credentials: $e");
      throw Exception("Lỗi khi gửi thông tin Wi-Fi qua BLE: ${e.toString()}");
    }
  }

  // 7. Gửi lệnh Provision
  Future<void> sendProvisionCommand(BluetoothDevice device) async {
    if (_provisionChar == null) {
      throw Exception("BLE characteristic chưa sẵn sàng để gửi lệnh Provision.");
    }
    try {
      print("Writing Provision command: start");
      await _provisionChar!.write(utf8.encode("start"), withoutResponse: true, timeout: 5);
      print("Provision command sent. Disconnecting BLE...");
      // Ngắt kết nối BLE ngay sau khi gửi lệnh
      await disconnectFromDevice(device);
    } catch (e) {
      print("Error writing provision command: $e");
      // Thử ngắt kết nối dù có lỗi
      try { await disconnectFromDevice(device); } catch (_) {}
      throw Exception("Lỗi khi gửi lệnh Provision qua BLE: ${e.toString()}");
    }
  }
}