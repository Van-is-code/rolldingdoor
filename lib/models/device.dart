// Data class đơn giản để chứa thông tin thiết bị từ API
class Device {
  final String deviceId; // MAC address
  final String name;
  final String role; // "ADMIN" or "MEMBER"

  Device({
    required this.deviceId,
    required this.name,
    required this.role,
  });

  // Factory constructor để tạo Device từ Map (JSON)
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['deviceId'] ?? '',
      // Nếu name null hoặc rỗng, dùng deviceId làm tên tạm
      name: (json['name'] != null && json['name'].isNotEmpty) ? json['name'] : (json['deviceId'] ?? 'Thiết bị không tên'),
      role: json['role'] ?? 'MEMBER', // Mặc định là MEMBER nếu không có role
    );
  }
}