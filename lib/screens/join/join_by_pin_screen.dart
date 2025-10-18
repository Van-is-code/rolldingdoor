import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_indicator.dart';

class JoinByPinScreen extends StatefulWidget {
  const JoinByPinScreen({super.key});

  @override
  State<JoinByPinScreen> createState() => _JoinByPinScreenState();
}

class _JoinByPinScreenState extends State<JoinByPinScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  String _deviceId = ''; // Người dùng sẽ phải nhập hoặc quét QR
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // TODO: Thêm chức năng quét QR để tự động điền deviceId và pin

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.requestAccess(_deviceId.trim(), _pin.trim());
      if (mounted) {
        setState(() {
          _successMessage = "Yêu cầu tham gia đã được gửi thành công!\nVui lòng chờ Admin phê duyệt.";
        });
        // Có thể tự động đóng màn hình sau vài giây
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop(true); // Trả về true để báo thành công
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
      appBar: AppBar(title: const Text('Tham gia bằng mã mời')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Nhập mã định danh (Device ID/MAC) của thiết bị và mã PIN mời (6 số) mà Admin đã cung cấp.",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Mã định danh (Device ID)',
                  hintText: 'AA:BB:CC:11:22:33', // Ví dụ
                  prefixIcon: Icon(Icons.perm_device_information),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập Device ID';
                  }
                  // TODO: Thêm validation cho định dạng MAC nếu cần
                  return null;
                },
                onSaved: (value) => _deviceId = value!,
              ),
              const SizedBox(height: 15),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Mã PIN mời (6 số)',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6, // Giới hạn 6 ký tự
                validator: (value) {
                  if (value == null || value.trim().length != 6) {
                    return 'Mã PIN phải có đúng 6 chữ số';
                  }
                  return null;
                },
                onSaved: (value) => _pin = value!,
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
                onPressed: _submitRequest,
                child: const Text('Gửi Yêu Cầu Tham Gia'),
              ),
              // TODO: Thêm nút quét QR
            ],
          ),
        ),
      ),
    );
  }
}