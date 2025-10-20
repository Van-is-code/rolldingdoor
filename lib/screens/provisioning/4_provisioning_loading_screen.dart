import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/ble_provision_service.dart';
import '../../widgets/loading_indicator.dart';

class ProvisioningLoadingScreen extends StatefulWidget {
  final BluetoothDevice connectedDevice;
  final String deviceId;
  final String masterPassword;

  const ProvisioningLoadingScreen({
    super.key,
    required this.connectedDevice,
    required this.deviceId,
    required this.masterPassword,
  });

  @override
  State<ProvisioningLoadingScreen> createState() => _ProvisioningLoadingScreenState();
}

class _ProvisioningLoadingScreenState extends State<ProvisioningLoadingScreen> {
  final BleProvisionService _bleService = BleProvisionService();
  String _statusMessage = "Đang đăng ký thiết bị với máy chủ...";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFinalSteps());
  }

  Future<void> _startFinalSteps() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final token = Provider.of<AuthService>(context, listen: false).token;

    if (token == null) {
      _handleError("Lỗi xác thực người dùng. Vui lòng đăng nhập lại.");
      return;
    }

    try {
      // Bước 1: Gọi API Claim lên Backend
      if (mounted) setState(() => _statusMessage = "Đang đăng ký thiết bị với máy chủ...");
      await apiService.claimDevice(widget.deviceId, widget.masterPassword);

      // Bước 2: Gửi lệnh Provision qua BLE để ESP32 restart
      if (mounted) setState(() => _statusMessage = "Đang yêu cầu thiết bị kết nối Wi-Fi...");
      // *** SỬA TÊN HÀM: sendProvisionCommand -> sendProvisionStartCommand ***
      await _bleService.sendProvisionStartCommand(widget.connectedDevice);

      // Bước 3: Hoàn tất, trả về true cho màn hình trước
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      _handleError("Lỗi trong quá trình cài đặt: ${e.toString().replaceFirst('Exception: ', '')}");
      // Thử ngắt kết nối BLE nếu còn
      try { await _bleService.disconnectFromDevice(widget.connectedDevice); } catch (_) {}

      // Chờ 3s để user đọc lỗi rồi trả về false
      await Future.delayed(const Duration(seconds: 3));
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(false);
      }
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _statusMessage = "Cài đặt thất bại!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage == null)
                const LoadingIndicator(),
              const SizedBox(height: 30),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _errorMessage != null ? Colors.red : null,
                ),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Không có nút bấm, màn hình sẽ tự đóng
            ],
          ),
        ),
      ),
    );
  }
}