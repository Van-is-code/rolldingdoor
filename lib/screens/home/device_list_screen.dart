import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import Screens
import 'device_control_screen.dart';
import '../provisioning/1_scan_ble_screen.dart'; // Import màn hình quét BLE
import '../join/join_by_pin_screen.dart';
import 'member_management_screen.dart'; // Import màn hình quản lý TV

// Import Services & Models
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/device.dart';

// Import Widgets
import '../../widgets/loading_indicator.dart';
import '../../widgets/device_card.dart'; // Import DeviceCard

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late Future<List<Device>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    print('>>> DeviceListScreen initState'); // <--- THÊM LOG
    _devicesFuture = _loadDevices();
  }

  // Lấy danh sách thiết bị từ API
  Future<List<Device>> _loadDevices() async {
    print('>>> Bắt đầu _loadDevices'); // <--- THÊM LOG
    // Dùng Provider.of để lấy instance
    // Sử dụng context.read an toàn hơn trong initState/future callbacks
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final token = authService.token;

    if (token == null) {
      print('>>> _loadDevices: Không tìm thấy token, đang đăng xuất'); // <--- THÊM LOG
      // Đăng xuất nếu không có token
      // Không cần await nếu không cần đợi kết quả logout hoàn thành ngay lập tức
      authService.logout();
      // Ném lỗi để FutureBuilder hiển thị
      throw Exception("Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.");
    }
    try {
      print('>>> Chuẩn bị gọi apiService.getMyDevices()'); // <--- THÊM LOG
      final List<dynamic> rawData = await apiService.getMyDevices();
      print('>>> Gọi getMyDevices() thành công, data: $rawData'); // <--- THÊM LOG
      return rawData.map((data) => Device.fromJson(data as Map<String, dynamic>)).toList();
    } catch (e) {
      print('>>> Lỗi trong _loadDevices: $e'); // <--- THÊM LOG lỗi
      // Xử lý lỗi token hết hạn (ví dụ)
      if (e.toString().contains('401') || e.toString().contains('403')) {
        print('>>> _loadDevices: Lỗi 401/403, đang đăng xuất'); // <--- THÊM LOG
        // Không cần await
        authService.logout();
        throw Exception("Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.");
      }
      rethrow; // Ném lại các lỗi khác
    } finally {
      print('>>> Kết thúc _loadDevices'); // <--- THÊM LOG
    }
  }

  // Refresh danh sách
  Future<void> _refreshDevices() async {
    if (mounted) {
      print('>>> Bắt đầu _refreshDevices'); // <--- THÊM LOG
      setState(() {
        _devicesFuture = _loadDevices();
      });
    }
  }

  // Điều hướng đến màn hình Thêm thiết bị (Quét BLE)
  void _navigateToAddDevice() async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (ctx) => const ScanBleScreen(), // Bắt đầu từ màn hình quét
    ));
    // Nếu màn hình Provision trả về true (thành công), thì refresh list
    if (result == true && mounted) {
      _refreshDevices();
    }
  }

  // Điều hướng đến màn hình Tham gia bằng PIN
  void _navigateToJoinDevice() async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (ctx) => const JoinByPinScreen(),
    ));
    if (result == true && mounted) {
      _refreshDevices();
    }
  }

  // Hàm hiển thị dialog lỗi
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Có lỗi xảy ra'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  // Hàm đăng xuất
  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      // Dùng context.read vì đang ở trong hàm async
      await context.read<AuthService>().logout();
      // AuthWrapper sẽ tự chuyển về màn hình Login
    }
  }

  @override
  Widget build(BuildContext context) {
    print('>>> DeviceListScreen build'); // <--- THÊM LOG
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thiết bị Cửa Cuốn"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: "Thêm thiết bị mới (Admin)",
            onPressed: _navigateToAddDevice,
          ),
          IconButton(
            icon: const Icon(Icons.pin_outlined), // Icon mã PIN
            tooltip: "Tham gia thiết bị bằng mã PIN",
            onPressed: _navigateToJoinDevice,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Đăng xuất",
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<Device>>(
        future: _devicesFuture,
        builder: (ctx, snapshot) {
          print('>>> DeviceList FutureBuilder state: ${snapshot.connectionState}'); // <--- THÊM LOG
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('>>> DeviceList FutureBuilder đang chờ...'); // <--- THÊM LOG
            return const LoadingIndicator();
          }
          if (snapshot.hasError) {
            print('>>> DeviceList FutureBuilder có lỗi: ${snapshot.error}'); // <--- THÊM LOG lỗi
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 10),
                    Text("Lỗi tải danh sách thiết bị:\n${snapshot.error.toString().replaceFirst('Exception: ','')}",
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade800)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Thử lại"),
                      onPressed: _refreshDevices,
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            print('>>> DeviceList FutureBuilder: Không có dữ liệu hoặc danh sách rỗng'); // <--- THÊM LOG
            return RefreshIndicator(
              onRefresh: _refreshDevices,
              child: ListView( // Dùng ListView để có hiệu ứng kéo
                  physics: const AlwaysScrollableScrollPhysics(), // Luôn cho phép kéo
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.2), // Cách top 20%
                    const Center(child: Text(
                      "Bạn chưa có thiết bị nào.\n\n"
                          "Nhấn (+) để thêm mới (nếu bạn là chủ thiết bị).\n"
                          "Nhấn (PIN) để tham gia bằng mã mời.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    )),
                  ]
              ),
            );
          }

          print('>>> DeviceList FutureBuilder: Có dữ liệu, đang hiển thị ListView'); // <--- THÊM LOG
          final devices = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refreshDevices,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0), // Thêm padding
              itemCount: devices.length,
              itemBuilder: (ctx, index) {
                // Sử dụng Widget DeviceCard tái sử dụng
                return DeviceCard(device: devices[index]);
              },
            ),
          );
        },
      ),
    );
  }
}