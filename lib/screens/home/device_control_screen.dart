import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/device.dart'; // Import model Device
import '../../widgets/control_button.dart'; // Import ControlButton
import '../../widgets/loading_indicator.dart'; // Import LoadingIndicator

class DeviceControlScreen extends StatefulWidget {
  final Device device; // Nhận đối tượng Device thay vì Map
  const DeviceControlScreen({super.key, required this.device});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  // Không cần ApiService ở đây vì dùng Provider
  // final ApiService _apiService = ApiService();
  bool _isLoadingOpen = false;
  bool _isLoadingClose = false;
  bool _isLoadingStop = false;
  String? _errorMessage; // Để hiển thị lỗi

  // Hàm gửi lệnh chung
  Future<void> _sendCommand(String action) async {
    // Xác định nút nào đang được nhấn để bật loading
    if(mounted) {
      setState(() {
        _errorMessage = null; // Xóa lỗi cũ
        if (action == 'OPEN') _isLoadingOpen = true;
        if (action == 'CLOSE') _isLoadingClose = true;
        if (action == 'STOP') _isLoadingStop = true;
      });
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final token = Provider.of<AuthService>(context, listen: false).token;

      if (token == null) {
        throw Exception("Lỗi xác thực.");
      }

      await apiService.sendCommand(widget.device.deviceId, action);

      // Hiển thị thông báo thành công (Snackbar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi lệnh $action thành công!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      print("Send command error: $errorMsg");
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
        // Hiển thị lỗi bằng Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Tắt loading cho nút tương ứng
      if (mounted) {
        setState(() {
          if (action == 'OPEN') _isLoadingOpen = false;
          if (action == 'CLOSE') _isLoadingClose = false;
          if (action == 'STOP') _isLoadingStop = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name)), // Lấy tên từ Device object
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hiển thị lỗi nếu có
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),

            // Nút MỞ (LÊN) - Dùng ControlButton
            ControlButton(
              label: "MỞ CỬA",
              icon: Icons.arrow_upward,
              onPressed: () => _sendCommand("OPEN"),
              backgroundColor: Colors.green.shade600,
              isLoading: _isLoadingOpen,
            ),
            const SizedBox(height: 40), // Tăng khoảng cách

            // Nút DỪNG - Dùng ControlButton
            ControlButton(
              label: "DỪNG",
              icon: Icons.stop,
              onPressed: () => _sendCommand("STOP"),
              backgroundColor: Colors.orange.shade700,
              isLoading: _isLoadingStop,
            ),
            const SizedBox(height: 40),

            // Nút ĐÓNG (XUỐNG) - Dùng ControlButton
            ControlButton(
              label: "ĐÓNG CỬA",
              icon: Icons.arrow_downward,
              onPressed: () => _sendCommand("CLOSE"),
              backgroundColor: Colors.red.shade600,
              isLoading: _isLoadingClose,
            ),
          ],
        ),
      ),
    );
  }
}