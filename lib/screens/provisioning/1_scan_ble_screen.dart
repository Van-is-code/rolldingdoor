import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/ble_provision_service.dart';
import '../../widgets/loading_indicator.dart';
import '2_select_wifi_screen.dart'; // Import màn hình tiếp theo

class ScanBleScreen extends StatefulWidget {
  const ScanBleScreen({super.key});

  @override
  State<ScanBleScreen> createState() => _ScanBleScreenState();
}

class _ScanBleScreenState extends State<ScanBleScreen> {
  final BleProvisionService _bleService = BleProvisionService();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _errorMessage;
  BluetoothDevice? _connectingDevice; // Thiết bị đang kết nối

  @override
  void initState() {
    super.initState();
    // Bắt đầu quét ngay khi màn hình mở
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    // Dừng quét và hủy subscription khi màn hình đóng
    _bleService.stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (mounted) {
      setState(() {
        _isScanning = true;
        _errorMessage = null;
        _scanResults = []; // Xóa kết quả cũ
        _connectingDevice = null;
      });
    }

    try {
      await _bleService.startScan(timeoutSeconds: 7); // Quét lâu hơn chút
      _scanSubscription?.cancel(); // Hủy sub cũ nếu có
      _scanSubscription = _bleService.scanResults.listen((results) {
        if(mounted) {
          setState(() {
            // Lọc và hiển thị các thiết bị có tên
            _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
          });
        }
      }, onError: (e) {
        _handleError("Lỗi stream kết quả quét: ${e.toString()}");
      });

      // Chờ quét xong (hoặc timeout)
      await _bleService.isScanning.where((s) => s == false).first;

      // Kiểm tra nếu không tìm thấy thiết bị mong muốn
      if (mounted && _scanResults.isEmpty) {
        _handleError("Không tìm thấy thiết bị nào.\nVui lòng đảm bảo thiết bị đã bật chế độ cài đặt (đèn nháy?) và ở gần.");
      }

    } catch (e) {
      _handleError("Lỗi khi bắt đầu quét: ${e.toString()}");
    } finally {
      if(mounted) {
        setState(() { _isScanning = false; });
      }
    }
  }

  Future<void> _connectAndProceed(BluetoothDevice device) async {
    if(mounted) setState(() => _connectingDevice = device); // Hiển thị loading cho item này

    try {
      // Kết nối BLE
      final connectedDevice = await _bleService.connectToDevice(device);

      // Nếu kết nối thành công, chuyển sang màn hình tiếp theo
      // Truyền device đã kết nối sang
      if (mounted) {
        final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (ctx) => SelectWifiScreen(connectedDevice: connectedDevice),
        ));
        // Nếu màn hình sau trả về true (thành công), đóng luôn màn hình này
        if (result == true && mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }
      }

    } catch (e) {
      _handleError("Kết nối thất bại: ${e.toString().replaceFirst('Exception: ', '')}");
    } finally {
      // Dù thành công hay thất bại, bỏ trạng thái loading của item
      if(mounted) setState(() => _connectingDevice = null);
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isScanning = false; // Dừng trạng thái quét nếu có lỗi
        _connectingDevice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bước 1: Tìm thiết bị'),
        actions: [
          // Nút quét lại
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Quét lại",
              onPressed: _startScan,
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Trạng thái quét
            if (_isScanning)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)),
                  SizedBox(width: 10),
                  Text("Đang tìm thiết bị 'CuaCuon_Setup'..."),
                ],
              )
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)
            else if (_scanResults.isEmpty)
                const Text("Không tìm thấy thiết bị nào.", textAlign: TextAlign.center),

            const SizedBox(height: 20),
            const Divider(),

            // Danh sách kết quả quét
            Expanded(
              child: ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (ctx, index) {
                  final result = _scanResults[index];
                  final isConnecting = _connectingDevice?.remoteId == result.device.remoteId;
                  return Card(
                    child: ListTile(
                      leading: isConnecting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.bluetooth_searching),
                      title: Text(result.device.platformName),
                      subtitle: Text(result.device.remoteId.toString()),
                      // Chỉ hiển thị nút Kết nối cho thiết bị 'CuaCuon_Setup'
                      trailing: result.device.platformName == "CuaCuon_Setup"
                          ? ElevatedButton(
                        child: const Text('Kết nối'),
                        // Vô hiệu hóa nếu đang quét hoặc đang kết nối thiết bị khác
                        onPressed: (_isScanning || _connectingDevice != null) ? null : () => _connectAndProceed(result.device),
                      )
                          : null, // Không hiển thị nút cho thiết bị khác
                    ),
                  );
                },
              ),
            ),
            if (!_isScanning)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Quét lại thiết bị"),
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