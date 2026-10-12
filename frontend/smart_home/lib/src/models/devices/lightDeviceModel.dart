import 'smartDeviceModel.dart';

class LightDeviceModel extends SmartDeviceModel {
  LightDeviceModel({
    required super.id,
    required super.title,
    required super.subtitle,
    super.isOn = false,
    super.roomId,
    this.brightness = 0.0,
  });

  double brightness;
}
