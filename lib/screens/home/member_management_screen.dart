import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_indicator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'set_offline_password_screen.dart'; // *** THÊM IMPORT NÀY ***

class MemberManagementScreen extends StatefulWidget {
  final Device device;
  const MemberManagementScreen({super.key, required this.device});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  String? _invitePin;
  bool _isLoadingPin = false;
  // TODO: Thêm Future để load danh sách thành viên và yêu cầu đang chờ

  @override
  void initState() {
    super.initState();
    // TODO: Gọi API load danh sách thành viên và yêu cầu
  }

  Future<void> _generatePin() async {
    if (mounted) setState(() => _isLoadingPin = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final pin = await apiService.generateInvitePin(widget.device.deviceId);
      if (mounted) setState(() => _invitePin = pin);
      _showPinDialog(pin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo mã PIN: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPin = false);
    }
  }

  void _showPinDialog(String pin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PinDisplayDialog(pin: pin, deviceId: widget.device.deviceId);
      },
    ).then((_) {
      if (mounted) setState(() => _invitePin = null);
    });
  }

  // *** HÀM MỚI ĐỂ MỞ MÀN HÌNH ĐẶT MẬT KHẨU ***
  void _navigateToSetOfflinePassword() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => SetOfflinePasswordScreen(device: widget.device),
    ));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý "${widget.device.name}"'),
      ),
      body: SingleChildScrollView( // Thay bằng SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Phần Tạo mã mời ---
            const Text("Mời thành viên (hiệu lực 5 phút):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _isLoadingPin
                ? const LoadingIndicator()
                : ElevatedButton.icon(
              icon: const Icon(Icons.pin_outlined),
              label: const Text("Tạo Mã PIN Mời"),
              onPressed: _generatePin,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // --- THÊM PHẦN CÀI ĐẶT OFFLINE ---
            const Text("Cài đặt điều khiển Offline:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.phonelink_lock_outlined),
              label: const Text("Đặt/Đổi mật khẩu Offline"),
              onPressed: _navigateToSetOfflinePassword, // Gọi hàm mới
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),
            // --------------------------------

            // --- Phần Danh sách yêu cầu đang chờ ---
            const Text("Yêu cầu đang chờ duyệt (Tự xóa sau 48h):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // TODO: Hiển thị ListView các yêu cầu PENDING (lấy từ API)
            Container(
              height: 150, // Giới hạn chiều cao
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text("Tính năng đang phát triển...")),
            ),
            const SizedBox(height: 30),

            // --- Phần Danh sách thành viên đã duyệt ---
            const Text("Thành viên đã có quyền:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // TODO: Hiển thị ListView các thành viên ACCEPTED (lấy từ API)
            Container(
              height: 150, // Giới hạn chiều cao
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text("Tính năng đang phát triển...")),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Widget Dialog hiển thị mã PIN và QR ---
class PinDisplayDialog extends StatefulWidget {
  final String pin;
  final String deviceId;

  const PinDisplayDialog({super.key, required this.pin, required this.deviceId});

  @override
  _PinDisplayDialogState createState() => _PinDisplayDialogState();
}

class _PinDisplayDialogState extends State<PinDisplayDialog> {
  Timer? _timer;
  int _secondsLeft = 300; // 5 phút

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          setState(() { _secondsLeft--; });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get timerText {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final qrData = "${widget.deviceId}|${widget.pin}";

    return AlertDialog(
      title: const Text('Mã Mời Tham Gia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Chia sẻ mã PIN hoặc mã QR này cho người nhà để họ gửi yêu cầu tham gia.", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Text(
              widget.pin,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 5),
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
            ),
            const SizedBox(height: 15),
            Text("Device ID: ${widget.deviceId}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            Text(
              "Mã sẽ hết hạn sau: $timerText",
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Đóng'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}