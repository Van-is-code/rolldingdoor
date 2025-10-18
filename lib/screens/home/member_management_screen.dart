import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_indicator.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Import thư viện QR

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
      // Hiển thị mã PIN (hoặc QR) trong Dialog
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

  // Hàm hiển thị Dialog chứa mã PIN và QR
  void _showPinDialog(String pin) {
    showDialog(
      context: context,
      // Đặt barrierDismissible = false để dialog không tự đóng khi hết hạn
      barrierDismissible: false,
      builder: (ctx) {
        // Sử dụng StatefulWidget bên trong Dialog để quản lý Timer
        return PinDisplayDialog(pin: pin, deviceId: widget.device.deviceId);
      },
    ).then((_) {
      // Reset _invitePin khi dialog đóng (để có thể tạo lại)
      if (mounted) setState(() => _invitePin = null);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý "${widget.device.name}"'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Phần Tạo mã mời ---
            const Text("Tạo mã mời (hiệu lực 5 phút):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _isLoadingPin
                ? const LoadingIndicator()
                : ElevatedButton.icon(
              icon: const Icon(Icons.pin_outlined),
              label: const Text("Tạo Mã PIN Mời"),
              onPressed: _generatePin,
            ),
            const SizedBox(height: 30),

            // --- Phần Danh sách yêu cầu đang chờ ---
            const Text("Yêu cầu đang chờ duyệt (Tự xóa sau 48h):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // TODO: Hiển thị ListView các yêu cầu PENDING (lấy từ API)
            // Ví dụ: ListTile(title: Text("Username"), trailing: ElevatedButton(onPressed: _approve, child: Text("Duyệt")))
            const Expanded(
              child: Center(child: Text("Tính năng đang phát triển...")),
            ),
            const SizedBox(height: 30),

            // --- Phần Danh sách thành viên đã duyệt ---
            const Text("Thành viên đã có quyền:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // TODO: Hiển thị ListView các thành viên ACCEPTED (lấy từ API)
            // Ví dụ: ListTile(title: Text("Username"), trailing: IconButton(icon: Icon(Icons.delete), onPressed: _removeMember))
            const Expanded(
              child: Center(child: Text("Tính năng đang phát triển...")),
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
        // Tự động đóng dialog khi hết giờ
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          setState(() {
            _secondsLeft--;
          });
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
    // Dữ liệu cho mã QR: deviceId và pin (có thể ngăn cách bằng dấu '|')
    final qrData = "${widget.deviceId}|${widget.pin}";

    return AlertDialog(
      title: const Text('Mã Mời Tham Gia'),
      content: SingleChildScrollView( // Cho phép cuộn nếu nội dung dài
        child: Column(
          mainAxisSize: MainAxisSize.min, // Thu gọn chiều cao
          children: [
            const Text("Chia sẻ mã PIN hoặc mã QR này cho người nhà để họ gửi yêu cầu tham gia.", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Text(
              widget.pin,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 5),
            ),
            const SizedBox(height: 20),
            // Hiển thị mã QR
            QrImageView( // Sử dụng QrImageView từ qr_flutter
              data: qrData, // Dữ liệu cần mã hóa
              version: QrVersions.auto, // Tự động chọn version
              size: 200.0, // Kích thước QR code
              gapless: false, // Để có khoảng trắng bao quanh
            ),
            const SizedBox(height: 15),
            Text("Device ID: ${widget.deviceId}", style: TextStyle(fontSize: 12, color: Colors.grey)), // Hiển thị deviceId dưới QR
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