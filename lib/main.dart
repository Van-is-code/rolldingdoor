import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import Screens
import 'screens/auth/login_screen.dart';
import 'screens/home/device_list_screen.dart';

// Import Services
import 'services/auth_service.dart';
import 'services/api_service.dart';

void main() {
  // Đảm bảo Flutter binding đã được khởi tạo trước khi chạy app
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Sử dụng MultiProvider để cung cấp các services cho toàn bộ ứng dụng
    return MultiProvider(
      providers: [
        // ApiService không cần ChangeNotifier vì nó không thay đổi state UI trực tiếp
        Provider<ApiService>(create: (_) => ApiService()),
        // AuthService cần ChangeNotifier để cập nhật UI khi login/logout
        ChangeNotifierProvider<AuthService>(
          // *** SỬA LỖI: Truyền ApiService vào AuthService qua constructor ***
          create: (ctx) => AuthService(Provider.of<ApiService>(ctx, listen: false)),
        ),
      ],
      child: MaterialApp(
        title: 'Cửa cuốn thông minh',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true, // Bật Material 3 UI
          appBarTheme: const AppBarTheme( // Thống nhất AppBar style
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white, // Màu chữ và icon trên AppBar
            elevation: 4,
            centerTitle: true, // Căn giữa tiêu đề AppBar (tùy chọn)
          ),
          elevatedButtonTheme: ElevatedButtonThemeData( // Thống nhất Button style
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple, // Màu nền nút
              foregroundColor: Colors.white, // Màu chữ nút
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // Bo góc nút
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme( // Thêm style cho TextField
            border: OutlineInputBorder( // Viền mặc định
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder( // Viền khi focus
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2.0),
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIconColor: Colors.deepPurple.shade300, // Màu icon trong TextField
            floatingLabelStyle: const TextStyle(color: Colors.deepPurple), // Màu label khi focus
          ),
          textButtonTheme: TextButtonThemeData( // Style cho TextButton
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepPurple, // Màu chữ
            ),
          ),
          cardTheme: CardTheme( // Style cho Card (dùng trong DeviceList)
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
        home: const AuthWrapper(), // Màn hình quyết định đăng nhập hay vào home
        debugShowCheckedModeBanner: false, // Tắt banner debug
      ),
    );
  }
}

// Widget kiểm tra trạng thái đăng nhập ban đầu
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return FutureBuilder(
      future: authService.tryAutoLogin(),
      builder: (ctx, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authService.isAuthenticated) {
          return const DeviceListScreen(); // Vào màn hình danh sách thiết bị
        } else {
          return const LoginScreen(); // Bắt đầu bằng màn hình Login
        }
      },
    );
  }
}