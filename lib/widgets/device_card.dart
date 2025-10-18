import 'package:flutter/material.dart';
import '../models/device.dart';
import '../screens/home/device_control_screen.dart';
import '../screens/home/member_management_screen.dart';

// Widget hiển thị thông tin 1 thiết bị trong danh sách
class DeviceCard extends StatelessWidget {
  final Device device;

  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = device.role == 'ADMIN';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 3, // Thêm đổ bóng nhẹ
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Bo góc
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(
          Icons.garage_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 45,
        ),
        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(device.deviceId, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Chip(
          label: Text(device.role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          backgroundColor: isAdmin ? Colors.orange.shade100 : Colors.blue.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          side: BorderSide.none, // Bỏ viền
        ),
        onTap: () {
          // Điều hướng đến màn hình điều khiển
          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => DeviceControlScreen(device: device),
          ));
        },
        // Nhấn giữ để vào quản lý thành viên (chỉ Admin)
        onLongPress: isAdmin
            ? () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => MemberManagementScreen(device: device),
          ));
        }
            : null,
      ),
    );
  }
}