import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/ble_provision_service.dart'; // Dùng lại UUIDs từ đây
import '../../widgets/loading_indicator.dart';
import '../../widgets/device_card.dart'; // Dùng lại DeviceCard
import '../../models/device.dart'; // Dùng model Device
import 'offline_control_screen.dart'; // Màn hình điều khiển offline

class OfflineScanScreen extends StatefulWidget {
  const OfflineScanScreen({super.key});

  @override
  State<OfflineScanScreen> createState() => _OfflineScanScreenState();
}

class _OfflineScanScreenState extends State<OfflineScanScreen> {
  final BleProvisionService _bleService = BleProvisionService(); // Dùng service
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _errorMessage;
  BluetoothDevice? _connectingDevice; // Thiết bị đang kết nối

  late final Guid _controlServiceUuid; // UUID cho chế độ Control

  @override
  void initState() {
    super.initState();
    // Lấy UUID từ service
    _controlServiceUuid = _bleService.controlServiceUuid;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _bleService.stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (mounted) setState(() { _isScanning = true; _errorMessage = null; _scanResults = []; _connectingDevice = null; });

    try {
      // Quét các thiết bị có Control Service UUID
      await _bleService.startScan(
          timeoutSeconds: 5,
          withServices: [_controlServiceUuid]
      );

      _scanSubscription?.cancel();
      _scanSubscription = _bleService.scanResults.listen((results) {
        if(mounted) {
          setState(() {
            // Lọc các thiết bị có tên (thường là "CuaCuonController")
            _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
          });
        }
      }, onError: (e) {
        _handleError("Lỗi stream kết quả quét: ${e.toString()}");
      });

      // Chờ quét xong
      await _bleService.isScanning.where((s) => s == false).first;
      if (mounted && _scanResults.isEmpty) {
        _handleError("Không tìm thấy cửa cuốn nào gần đây.\nHãy đảm bảo bạn đã 'Ghép đôi' (Pair) thiết bị trong Cài đặt Bluetooth của điện thoại trước.");
      }

    } catch (e) {
      _handleError("Lỗi khi quét BLE: ${e.toString().replaceFirst('Exception: ', '')}");
    } finally {
      if(mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectAndControl(BluetoothDevice device) async {
    if(mounted) setState(() => _connectingDevice = device);
    await _bleService.stopScan(); // Dừng quét

    try {
      // Kết nối (sẽ tự dùng bonding nếu có)
      // Service sẽ tự xử lý việc pair
      final connectedDevice = await _bleService.connectToDevice(device);

      // Nếu thành công, chuyển sang màn hình điều khiển offline
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => OfflineControlScreen(connectedDevice: connectedDevice),
        )).then((_) {
          // Khi quay lại từ màn điều khiển, không tự quét lại
          // setState(() => _connectingDevice = null);
        });
      }

    } catch (e) {
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('133')) { // Lỗi GATT 133
        _handleError("Kết nối thất bại (Lỗi 133). Vui lòng thử khởi động lại Bluetooth và quét lại.");
      } else {
        _handleError("Kết nối thất bại: $errorMsg");
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
          if (_isScanning)
            const Padding(padding: EdgeInsets.only(right: 15.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
          else
            IconButton( icon: const Icon(Icons.refresh), onPressed: _startScan, tooltip: "Quét lại")
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Trạng thái
            if (_isScanning)
              const Text("Đang tìm cửa cuốn ở gần...")
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)
            else
              const Text("Chọn thiết bị bạn muốn kết nối:", style: TextStyle(fontSize: 16)),

            const SizedBox(height: 10),
            const Divider(),

            // Danh sách kết quả
            Expanded(
              child: _scanResults.isEmpty && !_isScanning
                  ? Center(child: Text(_errorMessage ?? "Không tìm thấy thiết bị nào.", textAlign: TextAlign.center))
                  : ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (ctx, index) {
                  final result = _scanResults[index];
                  final isConnecting = _connectingDevice?.remoteId == result.device.remoteId;

                  return DeviceCard(
                    device: Device(
                        deviceId: result.device.remoteId.toString(),
                        name: result.device.platformName,
                        role: '' // Role không quan trọng
                    ),
                    trailingWidget: isConnecting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                        : const Icon(Icons.chevron_right),
                    onTapAction: (_isScanning || _connectingDevice != null) ? null : () => _connectAndControl(result.device),
                    onLongPressAction: null,
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