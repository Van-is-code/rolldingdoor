import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/ble_provision_service.dart';
import '../../widgets/loading_indicator.dart';
import '4_provisioning_loading_screen.dart'; // Import màn hình cuối

class CreateMasterKeyScreen extends StatefulWidget {
  final BluetoothDevice connectedDevice;
  final String deviceId; // Nhận từ màn hình trước
  final String ssid;     // Nhận từ màn hình trước
  final String password; // Nhận từ màn hình trước

  const CreateMasterKeyScreen({
    super.key,
    required this.connectedDevice,
    required this.deviceId,
    required this.ssid,
    required this.password,
  });

  @override
  State<CreateMasterKeyScreen> createState() => _CreateMasterKeyScreenState();
}

class _CreateMasterKeyScreenState extends State<CreateMasterKeyScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  String _masterPassword = '';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitMasterKey() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    // Chuyển sang màn hình Loading cuối cùng để thực hiện 2 bước cuối
    final result = await Navigator.of(context).pushReplacement<bool>(MaterialPageRoute( // Dùng Replacement
      builder: (ctx) => ProvisioningLoadingScreen(
        connectedDevice: widget.connectedDevice,
        deviceId: widget.deviceId,
        masterPassword: _masterPassword,
        // ssid và password không cần gửi nữa vì đã gửi ở bước trước
        // ssid: widget.ssid,
        // password: widget.password,
      ),
    ));

    // Nếu màn hình Loading trả về true, đóng luôn màn hình này và trả về true
    if (result == true && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop(true);
    } else if (result == false) {
      // Nếu màn hình Loading trả về false (lỗi), hiển thị lỗi ở đây
      if(mounted) {
        setState(() {
          _isLoading = false; // Tắt loading ở đây
          _errorMessage = "Quá trình cài đặt thất bại. Vui lòng thử lại từ đầu.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bước 3: Tạo Mật khẩu Gốc')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Tạo một Mật khẩu Gốc (Master Key) cho thiết bị này. \n"
                    "Mật khẩu này dùng để khôi phục quyền Admin nếu bạn mất tài khoản.\n"
                    "Hãy ghi nhớ mật khẩu này!",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Text("Device ID: ${widget.deviceId}", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu Gốc (ít nhất 6 ký tự)',
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
                onSaved: (value) => _masterPassword = value!,
              ),
              const SizedBox(height: 30),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              _isLoading
                  ? const LoadingIndicator()
                  : ElevatedButton(
                onPressed: _submitMasterKey,
                child: const Text('Hoàn tất Cài đặt'),
              ),
              TextButton(
                  child: const Text("Hủy / Quay lại"),
                  onPressed: () {
                    // Không cần ngắt BLE vì màn hình trước sẽ xử lý
                    Navigator.of(context).pop();
                  }
              )
            ],
          ),
        ),
      ),
    );
  }
}