import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/ble_provision_service.dart'; // Dùng lại UUIDs từ đây
import '../../widgets/loading_indicator.dart';
import 'offline_control_screen.dart'; // Màn hình điều khiển offline

class OfflineScanScreen extends StatefulWidget {
  const OfflineScanScreen({super.key});

  @override
  State<OfflineScanScreen> createState() => _OfflineScanScreenState();
}

class _OfflineScanScreenState extends State<OfflineScanScreen> {
  // Dùng trực tiếp FlutterBluePlus thay vì service riêng
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _errorMessage;
  BluetoothDevice? _connectingDevice;

  // Lấy UUID từ provisioning service (hoặc định nghĩa lại ở đây)
  final BleProvisionService _bleProvService = BleProvisionService();
  late final Guid _controlServiceUuid; // = Guid("a97e1e75-5100-4ba4-98c8-1a8069db2142");

  @override
  void initState() {
    super.initState();
    // Lấy UUID từ service (nếu service khởi tạo sẵn UUID)
    // Hoặc gán trực tiếp: _controlServiceUuid = Guid("...");
    // _controlServiceUuid = _bleProvService.CONTROL_SERVICE_UUID; // Cần định nghĩa trong service
    _controlServiceUuid = Guid("a97e1e75-5100-4ba4-98c8-1a8069db2142"); // Gán trực tiếp

    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (mounted) setState(() { _isScanning = true; _errorMessage = null; _scanResults = []; _connectingDevice = null; });

    // Kiểm tra Bluetooth
    var adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _handleError("Vui lòng bật Bluetooth.");
      return;
    }

    try {
      await FlutterBluePlus.startScan(
        // Lọc theo Service UUID của chế độ Control
          withServices: [_controlServiceUuid],
          timeout: const Duration(seconds: 5)
      );

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if(mounted) {
          setState(() {
            _scanResults = results;
            // Có thể dừng sớm nếu thấy thiết bị mong muốn
          });
        }
      }, onError: (e) {
        _handleError("Lỗi stream kết quả quét: ${e.toString()}");
      });

      // Chờ quét xong
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
      if (mounted && _scanResults.isEmpty) {
        _handleError("Không tìm thấy cửa cuốn nào gần đây. Hãy đảm bảo bạn đã ghép đôi thiết bị trước đó.");
      }

    } catch (e) {
      _handleError("Lỗi khi quét BLE: ${e.toString()}");
    } finally {
      if(mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectAndControl(BluetoothDevice device) async {
    if(mounted) setState(() => _connectingDevice = device);
    await FlutterBluePlus.stopScan(); // Dừng quét khi bắt đầu kết nối

    try {
      // Kết nối (sẽ tự dùng bonding nếu có)
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);

      // Nếu thành công, chuyển sang màn hình điều khiển offline
      if (mounted) {
        // Không dùng pushReplacement để có thể back lại màn quét
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => OfflineControlScreen(connectedDevice: device),
        )).then((_) {
          // Khi quay lại từ màn điều khiển, có thể quét lại
          // _startScan(); // Tùy chọn: quét lại ngay
        });
      }

    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('pair') || errorMsg.contains('auth')) {
        _handleError("Ghép đôi thất bại. Vui lòng thử lại hoặc vào cài đặt Bluetooth của điện thoại để ghép đôi thủ công.");
      } else {
        _handleError("Kết nối thất bại: ${errorMsg.replaceFirst('Exception: ', '')}");
      }
      // Thử ngắt kết nối nếu đang kết nối dở
      try { await device.disconnect(); } catch (_) {}
    } finally {
      if(mounted) setState(() => _connectingDevice = null);
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isScanning = false;
        _connectingDevice = null;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều Khiển Bluetooth Offline'),
        actions: [
          if (!_isScanning)
            IconButton( icon: const Icon(Icons.refresh), onPressed: _startScan)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isScanning)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ LoadingIndicator(), SizedBox(width: 10), Text("Đang tìm cửa cuốn gần đây...")],
              )
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)
            else if (_scanResults.isEmpty)
                const Text("Không tìm thấy thiết bị cửa cuốn nào đã ghép đôi gần đây.", textAlign: TextAlign.center),

            const SizedBox(height: 10),
            const Divider(),

            Expanded(
              child: ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (ctx, index) {
                  final result = _scanResults[index];
                  final isConnecting = _connectingDevice?.remoteId == result.device.remoteId;
                  return DeviceCard( // Dùng lại DeviceCard nhưng sửa đổi chút
                    device: Device( // Tạo đối tượng Device tạm thời
                        deviceId: result.device.remoteId.toString(),
                        name: result.device.platformName.isNotEmpty ? result.device.platformName : "Thiết bị không tên",
                        role: '' // Role không quan trọng ở chế độ offline
                    ),
                    // Thêm nút kết nối
                    trailingWidget: isConnecting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                        : ElevatedButton(
                      child: const Text('Kết nối'),
                      onPressed: (_isScanning || _connectingDevice != null) ? null : () => _connectAndControl(result.device),
                    ),
                    onTapAction: () => _connectAndControl(result.device), // Nhấn vào thẻ cũng là kết nối
                    onLongPressAction: null, // Không cần long press
                  );
                },
              ),
            ),
            if (!_isScanning)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Quét lại"),
                  onPressed: _startScan,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black87),
                ),
              )
          ],
        ),
      ),
    );
  }
}

// Cần sửa đổi DeviceCard để nhận thêm trailingWidget và action
class DeviceCard extends StatelessWidget {
  final Device device;
  final Widget? trailingWidget; // Thêm
  final VoidCallback? onTapAction; // Thêm
  final VoidCallback? onLongPressAction; // Thêm

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(
          Icons.garage_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 45,
        ),
        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(device.deviceId, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: trailingWidget ?? (device.role.isNotEmpty ? Chip( // Ưu tiên trailingWidget
          label: Text(device.role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          backgroundColor: isAdmin ? Colors.orange.shade100 : Colors.blue.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          side: BorderSide.none,
        ) : null),
        onTap: onTapAction ?? () { // Ưu tiên onTapAction
          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => DeviceControlScreen(device: device),
          ));
        },
        onLongPress: onLongPressAction ?? (isAdmin ? () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => MemberManagementScreen(device: device),
          ));
        } : null),
      ),
    );
  }
}