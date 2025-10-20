import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_indicator.dart';
// import 'login_screen.dart'; // Không cần import nữa vì dùng Navigator.pop

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final Map<String, String> _authData = {'username': '', 'password': ''};
  var _isLoading = false;
  final _passwordController = TextEditingController();
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.register(
        _authData['username']!,
        _authData['password']!,
      );

      // Đăng ký thành công, thông báo user đăng nhập
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
            backgroundColor: Colors.green,
          ),
        );
        // Tự động quay lại màn hình Login
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }

      // (Bỏ qua tự động login để user tự đăng nhập lại)
      // await authService.login(
      //   _authData['username']!,
      //   _authData['password']!,
      // );
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceFirst(RegExp(r'^\d+:\s*'), '');
        });
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
    final deviceSize = MediaQuery.of(context).size;
    return Scaffold(
      // Thêm AppBar để có nút Back quay lại Login
      appBar: AppBar(
        title: const Text('Đăng ký tài khoản'),
        backgroundColor: Colors.transparent, // Trong suốt
        elevation: 0,
        foregroundColor: Colors.grey.shade700, // Màu nút back
      ),
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
                  // Không cần tiêu đề nữa vì đã có trên AppBar
                  const SizedBox(height: 10),
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
                      if (value.trim().length < 3) {
                        return 'Tên đăng nhập phải có ít nhất 3 ký tự!';
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
                    controller: _passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu!';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự!';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _authData['password'] = value!;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận Mật khẩu',
                      prefixIcon: Icon(Icons.lock_clock_outlined), // Icon khác
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu!';
                      }
                      if (value != _passwordController.text) {
                        return 'Mật khẩu xác nhận không khớp!';
                      }
                      return null;
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
                    child: const Text('ĐĂNG KÝ'),
                  ),
                  const SizedBox(height: 10),
                  // Nút quay lại login
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(), // Chỉ cần pop
                    child: const Text('Đã có tài khoản? Đăng nhập'),
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