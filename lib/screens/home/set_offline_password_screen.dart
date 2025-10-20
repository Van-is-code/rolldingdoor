import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_indicator.dart';

class SetOfflinePasswordScreen extends StatefulWidget {
  final Device device;
  const SetOfflinePasswordScreen({super.key, required this.device});

  @override
  State<SetOfflinePasswordScreen> createState() => _SetOfflinePasswordScreenState();
}

class _SetOfflinePasswordScreenState extends State<SetOfflinePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String _newPassword = '';
  final _passwordController = TextEditingController(); // Để xác nhận
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // Gọi API mới trên Backend
      await apiService.setOfflinePassword(widget.device.deviceId, _newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã gửi yêu cầu đặt mật khẩu offline mới! Thiết bị sẽ cập nhật sau giây lát."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            )
        );
        // Tự đóng sau 2 giây
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst(RegExp(r'^\d+:\s*'), ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt Mật khẩu Offline')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Thiết bị: ${widget.device.name}", style: Theme.of(context).textTheme.titleMedium),
              Text("(${widget.device.deviceId})", style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              const Text(
                "Mật khẩu này sẽ được yêu cầu mỗi khi điều khiển thiết bị qua Bluetooth ở chế độ Offline (không cần đăng nhập).",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
               Text(
                "Lưu ý: Thiết bị phải đang online (kết nối Wi-Fi) để nhận được mật khẩu mới này.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.orange.shade800, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu Offline Mới',
                  prefixIcon: Icon(Icons.phonelink_lock_outlined),
                ),
                obscureText: true,
                controller: _passwordController, // Dùng controller
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
                onSaved: (value) => _newPassword = value!,
              ),
              const SizedBox(height: 15),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Xác nhận Mật khẩu Mới',
                  prefixIcon: Icon(Icons.lock_clock_outlined),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Mật khẩu xác nhận không khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              _isLoading
                  ? const LoadingIndicator()
                  : ElevatedButton(
                onPressed: _submitNewPassword,
                child: const Text('Lưu Mật khẩu'),
              )
            ],
          ),
        ),
      ),
    );
  }
}