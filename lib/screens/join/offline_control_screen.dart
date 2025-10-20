import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/ble_provision_service.dart'; // Dùng service để lấy UUIDs
import '../../widgets/control_button.dart';
import '../../widgets/loading_indicator.dart';

class OfflineControlScreen extends StatefulWidget {
  final BluetoothDevice connectedDevice;

  const OfflineControlScreen({super.key, required this.connectedDevice});

  @override
  State<OfflineControlScreen> createState() => _OfflineControlScreenState();
}

class _OfflineControlScreenState extends State<OfflineControlScreen> {
  final BleProvisionService _bleService = BleProvisionService(); // Khởi tạo service
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _passwordChar;

  bool _isConnected = true;
  bool _isReadyToSend = false; // Cờ báo đã tìm thấy char và kết nối OK
  bool _isLoadingOpen = false;
  bool _isLoadingClose = false;
  bool _isLoadingStop = false;
  String? _errorMessage;

  final _passwordController = TextEditingController();
  bool _isVerifyingPassword = false; // Đang gửi pass

  @override
  void initState() {
    super.initState();
    // Lắng nghe trạng thái kết nối
    _connectionStateSubscription = widget.connectedDevice.connectionState.listen((state) {
      if (mounted) {
        final connected = (state == BluetoothConnectionState.connected);
        if (_isConnected && !connected) { // Bị mất kết nối
          _showErrorAndPop("Mất kết nối Bluetooth với thiết bị.");
        }
        setState(() => _isConnected = connected );
      }
    });
    // Bắt đầu tìm characteristic
    _findCharacteristics();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _passwordController.dispose();
    _bleService.disconnectFromDevice(widget.connectedDevice); // Ngắt kết nối khi rời màn hình
    super.dispose();
  }

  // Tìm Command và Password Characteristic
  Future<void> _findCharacteristics() async {
    if (!_isConnected) return;
    if (mounted) setState(() => _isReadyToSend = false);

    try {
      // Dùng hàm discoverControlServices từ service
      bool found = await _bleService.discoverControlServices(widget.connectedDevice);
      if (found && mounted) {
        setState(() => _isReadyToSend = true); // Sẵn sàng
      } else {
        _showErrorAndPop("Không tìm thấy characteristic cần thiết.");
      }
    } catch (e) {
      _showErrorAndPop("Lỗi tìm characteristic: ${e.toString().replaceFirst('Exception: ', '')}");
    }
  }

  // Gửi lệnh qua BLE (BAO GỒM CẢ GỬI PASS)
  Future<void> _sendBleCommand(String action) async {
    if (!_isReadyToSend || !_isConnected) {
      _showError("Chưa sẵn sàng gửi lệnh hoặc đã mất kết nối.");
      return;
    }
    final password = _passwordController.text;
    if (password.length < 6) { // Kiểm tra mật khẩu (giống logic backend)
      _showError("Mật khẩu Offline phải có ít nhất 6 ký tự.");
      return;
    }

    // Bật loading
    if(mounted) {
      setState(() {
        _errorMessage = null;
        _isVerifyingPassword = true; // Bật loading chung
        if (action == 'OPEN') _isLoadingOpen = true;
        if (action == 'CLOSE') _isLoadingClose = true;
        if (action == 'STOP') _isLoadingStop = true;
      });
    }

    try {
      // Bước 1: Gửi mật khẩu
      await _bleService.sendOfflinePassword(password);

      // Chờ 1 chút để ESP32 xử lý mật khẩu và set cờ
      await Future.delayed(const Duration(milliseconds: 300));

      // Bước 2: Gửi lệnh
      await _bleService.sendOfflineCommand(action);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi lệnh $action qua Bluetooth'), backgroundColor: Colors.blue.shade700, duration: const Duration(seconds: 1)),
        );
        _passwordController.clear(); // Xóa pass sau khi gửi thành công
      }

    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      print("Send BLE command/pass error: $errorMsg");
      _showError("Lỗi gửi lệnh/mật khẩu BLE: $errorMsg");
    } finally {
      // Tắt tất cả loading
      if (mounted) {
        setState(() {
          _isVerifyingPassword = false;
          _isLoadingOpen = false;
          _isLoadingClose = false;
          _isLoadingStop = false;
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
    final deviceName = widget.connectedDevice.platformName.isNotEmpty
        ? widget.connectedDevice.platformName
        : "Thiết bị BLE";

    return Scaffold(
      appBar: AppBar(
        title: Text("Offline - $deviceName"),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: !_isConnected
                ? const LinearProgressIndicator(color: Colors.red, valueColor: AlwaysStoppedAnimation(Colors.red)) // Đỏ nếu mất kết nối
                : !_isReadyToSend // Vàng nếu đang tìm char
                ? const LinearProgressIndicator(color: Colors.orange)
                : Container(height: 4.0, color: Colors.green) // Xanh nếu sẵn sàng
        ),
      ),
      body: !_isConnected
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bluetooth_disabled, size: 50, color: Colors.red), SizedBox(height: 10), Text("Đã mất kết nối Bluetooth.", style: TextStyle(color: Colors.red))]))
          : !_isReadyToSend
          ? const LoadingIndicator(message: "Đang kiểm tra kênh điều khiển...")
          : SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Nhập mật khẩu Offline để điều khiển:", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Mật khẩu Offline (yêu cầu mỗi lần)',
                prefixIcon: const Icon(Icons.phonelink_lock_outlined),
                suffixIcon: _isVerifyingPassword ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width:20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              enabled: !_isLoadingOpen && !_isLoadingClose && !_isLoadingStop, // Vô hiệu hóa khi đang gửi lệnh
            ),
            const SizedBox(height: 10),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 30),
            ControlButton(
              label: "MỞ CỬA",
              icon: Icons.arrow_upward,
              onPressed: () => _sendBleCommand("OPEN"),
              backgroundColor: Colors.green.shade600,
              isLoading: _isLoadingOpen || _isVerifyingPassword, // Loading nếu gửi pass HOẶC gửi lệnh
            ),
            const SizedBox(height: 40),
            ControlButton(
              label: "DỪNG",
              icon: Icons.stop,
              onPressed: () => _sendBleCommand("STOP"),
              backgroundColor: Colors.orange.shade700,
              isLoading: _isLoadingStop || _isVerifyingPassword,
            ),
            const SizedBox(height: 40),
            ControlButton(
              label: "ĐÓNG CỬA",
              icon: Icons.arrow_downward,
              onPressed: () => _sendBleCommand("CLOSE"),
              backgroundColor: Colors.red.shade600,
              isLoading: _isLoadingClose || _isVerifyingPassword,
            ),
          ],
        ),
      ),
    );
  }
}