import 'package:flutter/material.dart';

// Widget nút bấm tái sử dụng cho màn hình điều khiển
class ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed; // Cho phép null để vô hiệu hóa
  final Color backgroundColor;
  final bool isLoading;

  const ControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Vô hiệu hóa nút nếu đang loading HOẶC nếu onPressed là null
    final bool isDisabled = isLoading || onPressed == null;

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
      onPressed: isDisabled ? null : onPressed, // Vô hiệu hóa nút
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        // Làm mờ nút nếu bị vô hiệu hóa
        disabledBackgroundColor: backgroundColor.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 25), // Tăng chiều cao nút
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Bo góc nhiều hơn
        ),
        elevation: 5, // Thêm đổ bóng
      ),
    );
  }
}