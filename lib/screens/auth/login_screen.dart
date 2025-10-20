import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_indicator.dart';
import 'register_screen.dart'; // Import màn hình đăng ký
import '../join/offline_scan_screen.dart'; // Import màn hình quét offline

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final Map<String, String> _authData = {'username': '', 'password': ''};
  var _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await Provider.of<AuthService>(context, listen: false).login(
        _authData['username']!,
        _authData['password']!,
      );
      // AuthWrapper sẽ tự chuyển màn hình nếu thành công
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceFirst(RegExp(r'^\d+:\s*'), ''); // Bỏ mã lỗi
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => const RegisterScreen(),
    ));
  }

  // --- HÀM MỚI: Điều hướng đến màn hình BLE Offline ---
  void _navigateToOfflineControl() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => const OfflineScanScreen(), // Màn hình quét BLE offline
    ));
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: deviceSize.width * 0.85,
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'ĐĂNG NHẬP',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên đăng nhập!';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _authData['username'] = value!.trim();
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu!';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _authData['password'] = value!;
                    },
                  ),
                  const SizedBox(height: 25),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ),
                  _isLoading
                      ? const LoadingIndicator()
                      : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('ĐĂNG NHẬP'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _navigateToRegister,
                    child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                  ),
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 15),
                  // --- NÚT MỚI: ĐIỀU KHIỂN OFFLINE ---
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Điều khiển Offline (Bluetooth)'),
                    onPressed: _navigateToOfflineControl,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}