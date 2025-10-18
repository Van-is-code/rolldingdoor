import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_indicator.dart';

class RecoverAdminScreen extends StatefulWidget {
  const RecoverAdminScreen({super.key});

  @override
  State<RecoverAdminScreen> createState() => _RecoverAdminScreenState();
}

class _RecoverAdminScreenState extends State<RecoverAdminScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  String _deviceId = '';
  String _masterPassword = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _submitRecovery() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // API này yêu cầu phải đăng nhập bằng tài khoản MỚI mà bạn muốn gán quyền Admin
      await apiService.recoverAdmin(_deviceId.trim(), _masterPassword);
      if (mounted) {
        setState(() {
          _successMessage = "Khôi phục quyền Admin thành công!\nBạn đã là Admin của thiết bị này.";
        });
        // Có thể đóng màn hình sau vài giây
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khôi phục Quyền Admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Nhập Mã định danh (Device ID/MAC) và Mật khẩu Gốc (Master Key) của thiết bị để lấy lại quyền Admin cho tài khoản hiện tại.",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Mã định danh (Device ID)',
                  hintText: 'AA:BB:CC:11:22:33',
                  prefixIcon: Icon(Icons.perm_device_information),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập Device ID';
                  }
                  return null;
                },
                onSaved: (value) => _deviceId = value!,
              ),
              const SizedBox(height: 15),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu Gốc (Master Key)',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập Mật khẩu Gốc';
                  }
                  if (value.length < 6) {
                    return 'Mật khẩu Gốc phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
                onSaved: (value) => _masterPassword = value!,
              ),
              const SizedBox(height: 30),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(_successMessage!, style: const TextStyle(color: Colors.green), textAlign: TextAlign.center),
                ),
              _isLoading
                  ? const LoadingIndicator()
                  : ElevatedButton(
                onPressed: _submitRecovery,
                child: const Text('Xác nhận Khôi phục'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}