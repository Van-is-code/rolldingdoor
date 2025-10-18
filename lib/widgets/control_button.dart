import 'package:flutter/material.dart';

// Widget nút bấm tái sử dụng cho màn hình điều khiển
class ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final bool isLoading; // Thêm trạng thái loading

  const ControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    this.isLoading = false, // Mặc định không loading
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: isLoading
          ? Container( // Thay icon bằng vòng quay nhỏ
        width: 24,
        height: 24,
        padding: const EdgeInsets.all(2.0),
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      )
          : Icon(icon, size: 40),
      label: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      onPressed: isLoading ? null : onPressed, // Vô hiệu hóa nút khi đang loading
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 25), // Tăng chiều cao nút
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Bo góc nhiều hơn
        ),
        elevation: 5, // Thêm đổ bóng
      ),
    );
  }
}