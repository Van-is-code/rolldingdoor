import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/ble_provision_service.dart';
import '../../widgets/loading_indicator.dart';
import '3_create_master_key_screen.dart';

class SelectWifiScreen extends StatefulWidget {
  final BluetoothDevice connectedDevice;

  const SelectWifiScreen({super.key, required this.connectedDevice});

  @override
  State<SelectWifiScreen> createState() => _SelectWifiScreenState();
}

class _SelectWifiScreenState extends State<SelectWifiScreen> {
  final BleProvisionService _bleService = BleProvisionService();
  final GlobalKey<FormState> _formKey = GlobalKey();
  String _ssid = '';
  String _password = '';
  String? _deviceId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _discoverAndGetId();
  }

  Future<void> _discoverAndGetId() async {
    if(mounted) setState(() => _isLoading = true);
    try {
      // *** SỬA TÊN HÀM: discoverServicesAndGetDeviceId -> discoverProvisionServices ***
      _deviceId = await _bleService.discoverProvisionServices(widget.connectedDevice);
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
      // *** SỬA TÊN HÀM: sendCredentials -> sendProvisionCredentials ***
      await _bleService.sendProvisionCredentials(_ssid.trim(), _password);

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => CreateMasterKeyScreen(
              connectedDevice: widget.connectedDevice,
              deviceId: _deviceId!,
              ssid: _ssid.trim(),
              password: _password
          ),
        )).then((result) {
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
      body: _isLoading && _deviceId == null
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
                  return null; // Cho phép mật khẩu rỗng
                },
                onSaved: (value) => _password = value ?? '',
              ),
              const SizedBox(height: 30),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              _isLoading
                  ? const LoadingIndicator()
                  : ElevatedButton(
                onPressed: _submitWifi,
                child: const Text('Tiếp tục'),
              ),
              TextButton(
                  child: const Text("Hủy / Quay lại"),
                  onPressed: () {
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