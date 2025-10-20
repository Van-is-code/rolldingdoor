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
          // Truyền ApiService vào AuthService qua constructor
          create: (ctx) => AuthService(Provider.of<ApiService>(ctx, listen: false)),
        ),
      ],
      child: MaterialApp(
        title: 'Cửa cuốn thông minh',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 4,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.deepPurple, width: 2.0),
            ),
            prefixIconColor: Colors.deepPurple,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepPurple,
            ),
          ),
          cardTheme: CardTheme(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
        home: const AuthWrapper(), // Bắt đầu với AuthWrapper
        debugShowCheckedModeBanner: false, // Tắt banner debug
      ),
    );
  }
}

// --- AuthWrapper (Đã sửa thành StatefulWidget) ---
// Giúp tối ưu, chỉ chạy tryAutoLogin() 1 LẦN DUY NHẤT khi app khởi động
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<bool> _tryAutoLoginFuture;

  @override
  void initState() {
    super.initState();
    // Gọi tryAutoLogin() MỘT LẦN trong initState
    _tryAutoLoginFuture = Provider.of<AuthService>(context, listen: false).tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    // Dùng FutureBuilder để xử lý việc "chờ" lần đầu khởi động
    return FutureBuilder(
      future: _tryAutoLoginFuture, // Sử dụng future đã lưu
      builder: (ctx, authSnapshot) {
        // Nếu vẫn đang chờ check token lần đầu, hiển thị màn hình chờ
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(key: ValueKey('initial_load'))),
          );
        }

        // Đã check xong, dùng Consumer để "lắng nghe" thay đổi
        // (như khi nhấn login/logout)
        return Consumer<AuthService>(
          builder: (ctx, authService, _) {
            // Dựa vào trạng thái isAuthenticated để quyết định màn hình
            if (authService.isAuthenticated) {
              return const DeviceListScreen();
            } else {
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}