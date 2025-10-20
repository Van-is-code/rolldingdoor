import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/ble_provision_service.dart'; // Dùng lại UUIDs
import '../../widgets/control_button.dart';
import '../../widgets/loading_indicator.dart'; // Import LoadingIndicator

class OfflineControlScreen extends StatefulWidget {
  final BluetoothDevice connectedDevice;

  const OfflineControlScreen({super.key, required this.connectedDevice});

  @override
  State<OfflineControlScreen> createState() => _OfflineControlScreenState();
}

class _OfflineControlScreenState extends State<OfflineControlScreen> {
  // UUIDs
  final BleProvisionService _bleProvService = BleProvisionService(); // Chỉ để lấy UUID
  late final Guid _controlServiceUuid;
  late final Guid _commandCharUuid;
  late final Guid _passwordCharUuid; // UUID mới

  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _passwordChar; // Characteristic mới
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  bool _isConnected = true;
  bool _isReadyToSend = false; // Cờ báo đã tìm thấy char và kết nối OK
  bool _isLoadingOpen = false;
  bool _isLoadingClose = false;
  bool _isLoadingStop = false;
  String? _errorMessage;

  // Controller và state cho việc nhập mật khẩu
  final _passwordController = TextEditingController();
  bool _isPasswordVerified = false; // Cờ tạm báo pass vừa gửi OK
  bool _isVerifyingPassword = false; // Đang gửi pass

  @override
  void initState() {
    super.initState();
    // Gán UUIDs
    _controlServiceUuid = Guid("a97e1e75-5100-4ba4-98c8-1a8069db2142");
    _commandCharUuid = Guid("5f1816e8-232a-4302-8611-e1bc1824c9a4");
    _passwordCharUuid = Guid("b2a8d9e1-0e97-4c28-9c1b-7a5f674d32a1"); // UUID của Password Char

    _connectionStateSubscription = widget.connectedDevice.connectionState.listen((state) {
      if (mounted) {
        final connected = (state == BluetoothConnectionState.connected);
        if (_isConnected && !connected) { // Bị mất kết nối
          _showErrorAndPop("Mất kết nối Bluetooth với thiết bị.");
        }
        setState(() => _isConnected = connected );
      }
    });

    _findCharacteristics();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _passwordController.dispose();
    // Ngắt kết nối khi rời màn hình
    widget.connectedDevice.disconnect();
    super.dispose();
  }

  // Tìm cả Command và Password Characteristic
  Future<void> _findCharacteristics() async {
    if (!_isConnected) return;
    if (mounted) setState(() => _isReadyToSend = false); // Chưa sẵn sàng

    try {
      List<BluetoothService> services = await widget.connectedDevice.discoverServices(timeout: 10);
      bool foundCommand = false;
      bool foundPassword = false;
      for (var service in services) {
        if (service.uuid == _controlServiceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid == _commandCharUuid) {
              _commandChar = char;
              foundCommand = true;
              print("Found Command Char: ${char.uuid}");
            } else if (char.uuid == _passwordCharUuid) {
              _passwordChar = char;
              foundPassword = true;
              print("Found Password Char: ${char.uuid}");
            }
          }
          break; // Tìm thấy service rồi
        }
      }

      if (foundCommand && foundPassword) {
        if (mounted) setState(() => _isReadyToSend = true); // Sẵn sàng nhận pass
      } else {
        _showErrorAndPop("Thiếu characteristic cần thiết (Command hoặc Password).");
      }

    } catch (e) {
      _showErrorAndPop("Lỗi tìm characteristic: ${e.toString()}");
    }
  }

  // Hàm gửi mật khẩu qua BLE
  Future<bool> _sendPassword() async {
    if (_passwordChar == null || !_isConnected || !_isReadyToSend) {
      _showError("Chưa sẵn sàng gửi mật khẩu hoặc đã mất kết nối.");
      return false;
    }
    final password = _passwordController.text;
    if (password.isEmpty) {
      _showError("Vui lòng nhập mật khẩu offline.");
      return false;
    }

    if (mounted) setState(() => _isVerifyingPassword = true);

    try {
      print("Writing BLE password...");
      await _passwordChar!.write(utf8.encode(password), withoutResponse: true, timeout: 5);
      print("Password sent via BLE.");
      // Giả định là thành công, ESP32 sẽ set cờ nội bộ
      // TODO: Tốt hơn là chờ xác nhận Notify từ ESP32 nếu có
      if (mounted) {
        setState(() => _isPasswordVerified = true); // Đánh dấu là đã gửi pass OK
      }
      return true;

    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      print("Send BLE password error: $errorMsg");
      _showError("Lỗi gửi mật khẩu BLE: $errorMsg");
      if (mounted) setState(() => _isPasswordVerified = false);
      return false;
    } finally {
      if (mounted) setState(() => _isVerifyingPassword = false);
    }
  }


  // Gửi lệnh qua BLE (SAU KHI ĐÃ GỬI PASSWORD)
  Future<void> _sendBleCommand(String action) async {
    // Bước 1: Gửi mật khẩu
    final passwordSent = await _sendPassword();
    if (!passwordSent) return; // Dừng nếu gửi pass lỗi

    // Nếu gửi pass thành công, chờ 1 chút rồi gửi lệnh
    await Future.delayed(const Duration(milliseconds: 200));

    if (_commandChar == null || !_isConnected) {
      _showError("Chưa sẵn sàng gửi lệnh hoặc đã mất kết nối.");
      return;
    }

    if(mounted) {
      setState(() {
        _errorMessage = null; // Xóa lỗi cũ
        if (action == 'OPEN') _isLoadingOpen = true;
        if (action == 'CLOSE') _isLoadingClose = true;
        if (action == 'STOP') _isLoadingStop = true;
      });
    }

    try {
      print("Writing BLE command: $action");
      await _commandChar!.write(utf8.encode(action), withoutResponse: true, timeout: 5);
      print("BLE command sent.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi lệnh $action qua Bluetooth'), backgroundColor: Colors.blue.shade700, duration: const Duration(seconds: 1)),
        );
      }
      // Reset cờ verified sau khi gửi lệnh thành công, bắt nhập lại cho lần sau
      if (mounted) setState(() => _isPasswordVerified = false);


    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      print("Send BLE command error: $errorMsg");
      _showError("Lỗi gửi lệnh BLE: $errorMsg");
      // Reset cờ nếu gửi lệnh lỗi
      if (mounted) setState(() => _isPasswordVerified = false);
    } finally {
      if (mounted) {
        setState(() {
          if (action == 'OPEN') _isLoadingOpen = false;
          if (action == 'CLOSE') _isLoadingClose = false;
          if (action == 'STOP') _isLoadingStop = false;
        });
      }
    }
  }

  // Hiển thị lỗi dùng SnackBar
  void _showError(String message) {
    if(mounted) {
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

  // Hiển thị lỗi và tự động quay lại màn hình trước
  void _showErrorAndPop(String message) {
    if(mounted) {
      _showError(message);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Xác định tên thiết bị
    final deviceName = widget.connectedDevice.platformName.isNotEmpty
        ? widget.connectedDevice.platformName
        : "Thiết bị BLE";

    return Scaffold(
      appBar: AppBar(
        title: Text("Offline - $deviceName"),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: !_isConnected
                ? const LinearProgressIndicator(color: Colors.red) // Đỏ nếu mất kết nối
                : !_isReadyToSend // Vàng nếu đang tìm char
                ? const LinearProgressIndicator(color: Colors.orange)
                : Container(height: 4.0, color: Colors.green) // Xanh nếu sẵn sàng
        ),
      ),
      body: !_isConnected
          ? const Center(child: Text("Đã mất kết nối Bluetooth.", style: TextStyle(color: Colors.red)))
          : !_isReadyToSend
          ? const LoadingIndicator(message: "Đang tìm kênh điều khiển và mật khẩu...")
          : SingleChildScrollView( // Cho phép cuộn
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Phần nhập mật khẩu ---
            Text("Nhập mật khẩu Offline để điều khiển:", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Mật khẩu Offline',
                prefixIcon: const Icon(Icons.phonelink_lock_outlined),
                suffixIcon: _isVerifyingPassword ? const SizedBox(width:20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              ),
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              // Không cần validator, nhấn nút sẽ tự kiểm tra
              // Bật/tắt nút dựa trên trạng thái loading
              enabled: !_isLoadingOpen && !_isLoadingClose && !_isLoadingStop && !_isVerifyingPassword,
            ),
            const SizedBox(height: 10),
            // Hiển thị lỗi nếu có
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 30),
            // --- Các nút điều khiển ---
            ControlButton(
              label: "MỞ CỬA",
              icon: Icons.arrow_upward,
              // Chỉ bật khi không có nút nào khác đang loading và không đang gửi pass
              onPressed: (_isLoadingClose || _isLoadingStop || _isVerifyingPassword) ? null : () => _sendBleCommand("OPEN"),
              backgroundColor: Colors.green.shade600,
              isLoading: _isLoadingOpen,
            ),
            const SizedBox(height: 40),
            ControlButton(
              label: "DỪNG",
              icon: Icons.stop,
              onPressed: (_isLoadingOpen || _isLoadingClose || _isVerifyingPassword) ? null : () => _sendBleCommand("STOP"),
              backgroundColor: Colors.orange.shade700,
              isLoading: _isLoadingStop,
            ),
            const SizedBox(height: 40),
            ControlButton(
              label: "ĐÓNG CỬA",
              icon: Icons.arrow_downward,
              onPressed: (_isLoadingOpen || _isLoadingStop || _isVerifyingPassword) ? null : () => _sendBleCommand("CLOSE"),
              backgroundColor: Colors.red.shade600,
              isLoading: _isLoadingClose,
            ),
          ],
        ),
      ),
    );
  }
}