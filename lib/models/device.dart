class Device {
  final String deviceId;
  final String name;
  final String role;

  Device({
    required this.deviceId,
    required this.name,
    required this.role,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['deviceId'] ?? '',
      name: json['name'] ?? json['deviceId'] ?? 'Unknown Device',
      role: json['role'] ?? 'MEMBER',
    );
  }
}