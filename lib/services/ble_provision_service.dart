// Pseudo-code cho logic cài đặt
class BleProvisionService {
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String WIFI_SSID_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String WIFI_PASS_CHAR_UUID = "c31b315b-1c58-439d-8692-0b5bc1a5e1e0";
  final String PROVISION_CHAR_UUID = "a8234a31-5091-4c74-a0f5-3b95a7ffc311";

  BluetoothDevice? connectedDevice;

  // App gọi đây (Luồng 1 - Giai đoạn 2)
  Future<void> startProvisioning(String ssid, String password) async {
    try {
      // 1. Tìm các Characteristic
      BluetoothCharacteristic wifiSsidChar = ...;
    BluetoothCharacteristic wifiPassChar = ...;
    BluetoothCharacteristic provisionChar = ...;

    // 2. Ghi thông tin Wi-Fi vào ESP32
    await wifiSsidChar.write(ssid.codeUnits);
    await wifiPassChar.write(password.codeUnits);

    // 3. Ghi lệnh "bắt đầu"
    await provisionChar.write("start".codeUnits);

    // ESP32 sẽ nhận lệnh này và bắt đầu tự kết nối Wi-Fi,
    // sau đó gọi Backend /provision

    } catch (e) {
    // Xử lý lỗi
    }
  }
}