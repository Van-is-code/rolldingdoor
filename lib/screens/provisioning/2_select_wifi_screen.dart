import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/ble_provision_service.dart';
import '../../widgets/loading_indicator.dart';
import '3_create_master_key_screen.dart'; // Import màn hình tiếp theo

class SelectWifiScreen extends StatefulWidget {
  final BluetoothDevice connectedDevice; // Nhận device đã kết nối từ màn hình trước

  const SelectWifiScreen({super.key, required this.connectedDevice});

  @override
  State<SelectWifiScreen> createState() => _SelectWifiScreenState();
}

class _SelectWifiScreenState extends State<SelectWifiScreen> {
  final BleProvisionService _bleService = BleProvisionService();
  final GlobalKey<FormState> _formKey = GlobalKey();
  String _ssid = ''; // Tạm thời nhập tay
  String _password = '';
  String? _deviceId; // MAC Address đọc từ BLE
  bool _isLoading = true; // Bắt đầu bằng loading để đọc deviceId
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _discoverAndGetId();
  }

  // Hàm đọc deviceId sau khi kết nối
  Future<void> _discoverAndGetId() async {
    if(mounted) setState(() => _isLoading = true);
    try {
      _deviceId = await _bleService.discoverServicesAndGetDeviceId(widget.connectedDevice);
      if (_deviceId == null && mounted) {
        _handleError("Không đọc được Device ID (MAC) từ thiết bị.");
      }
    } catch(e) {
      _handleError("Lỗi đọc thông tin BLE: ${e.toString().replaceFirst('Exception: ', '')}");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _submitWifi() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Gửi thông tin Wi-Fi qua BLE
      await _bleService.sendCredentials(_ssid.trim(), _password);

      // Nếu gửi thành công, chuyển sang màn hình tạo Master Key
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => CreateMasterKeyScreen(
              connectedDevice: widget.connectedDevice, // Truyền tiếp device
              deviceId: _deviceId!, // Truyền deviceId đã đọc được
              ssid: _ssid.trim(), // Truyền ssid
              password: _password // Truyền password
          ),
        )).then((result) {
          // Nếu màn hình sau trả về true (thành công), đóng luôn màn hình này
          if (result == true && mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      _handleError("Lỗi gửi thông tin Wi-Fi: ${e.toString().replaceFirst('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bước 2: Thông tin Wi-Fi')),
      body: _isLoading && _deviceId == null // Chỉ loading khi chưa đọc được deviceId
          ? const LoadingIndicator()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Thiết bị (${widget.connectedDevice.platformName}) đã kết nối.", textAlign: TextAlign.center),
              if (_deviceId != null) Text("Device ID (MAC): $_deviceId", textAlign: TextAlign.center),
              const SizedBox(height: 25),
              const Text("Nhập thông tin mạng Wi-Fi bạn muốn thiết bị kết nối vào:", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              // TODO: Lấy danh sách Wi-Fi từ ESP32 thay vì nhập tay
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Tên Wi-Fi (SSID)",
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên Wi-Fi';
                  }
                  return null;
                },
                onSaved: (value) => _ssid = value!,
              ),
              const SizedBox(height: 15),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Mật khẩu Wi-Fi",
                  prefixIcon: Icon(Icons.password),
                ),
                obscureText: true,
                validator: (value) {
                  // Cho phép mật khẩu rỗng đối với mạng không bảo mật
                  // if (value == null || value.isEmpty) {
                  //   return 'Vui lòng nhập mật khẩu Wi-Fi';
                  // }
                  return null;
                },
                onSaved: (value) => _password = value ?? '', // Lưu là chuỗi rỗng nếu null
              ),
              const SizedBox(height: 30),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              _isLoading // Loading khi gửi Wi-Fi
                  ? const LoadingIndicator()
                  : ElevatedButton(
                onPressed: _submitWifi,
                child: const Text('Tiếp tục'),
              ),
              TextButton(
                  child: const Text("Hủy / Quay lại"),
                  onPressed: () {
                    // Ngắt kết nối BLE trước khi pop
                    _bleService.disconnectFromDevice(widget.connectedDevice);
                    Navigator.of(context).pop();
                  }
              )
            ],
          ),
        ),
      ),
    );
  }
}