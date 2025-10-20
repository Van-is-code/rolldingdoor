import 'package:flutter/material.dart';
import '../models/device.dart';
import '../screens/home/device_control_screen.dart';
import '../screens/home/member_management_screen.dart';

// Widget hiển thị thông tin 1 thiết bị trong danh sách
// Đã cập nhật để linh hoạt hơn cho cả 2 chế độ Online và Offline
class DeviceCard extends StatelessWidget {
  final Device device;
  final Widget? trailingWidget; // Widget hiển thị bên phải (ví dụ: nút Kết nối)
  final VoidCallback? onTapAction; // Hàm gọi khi nhấn
  final VoidCallback? onLongPressAction; // Hàm gọi khi nhấn giữ

  const DeviceCard({
    super.key,
    required this.device,
    this.trailingWidget,
    this.onTapAction,
    this.onLongPressAction,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = device.role == 'ADMIN';

    return Card(
      // style đã được định nghĩa trong main.dart
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(
          Icons.garage_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 45,
        ),
        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(device.deviceId, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        // Ưu tiên trailingWidget nếu được cung cấp, nếu không thì hiển thị Chip vai trò
        trailing: trailingWidget ?? (device.role.isNotEmpty ? Chip(
          label: Text(device.role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          backgroundColor: isAdmin ? Colors.orange.shade100 : Colors.blue.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          side: BorderSide.none, // Bỏ viền
        ) : null),
        // Ưu tiên onTapAction nếu được cung cấp
        onTap: onTapAction ?? () {
          // Mặc định: vào màn hình điều khiển online
          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => DeviceControlScreen(device: device),
          ));
        },
        // Ưu tiên onLongPressAction nếu được cung cấp
        onLongPress: onLongPressAction ?? (isAdmin ? () {
          // Mặc định: Admin nhấn giữ vào quản lý
          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => MemberManagementScreen(device: device),
          ));
        } : null), // Member nhấn giữ không làm gì
      ),
    );
  }
}