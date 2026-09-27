import 'smartDeviceModel.dart';

class FanDeviceModel extends SmartDeviceModel {
  FanDeviceModel({
    required super.id,
    required super.title,
    required super.subtitle,
    super.isOn = false,
    this.speed = 1,
  });

  int speed;
}
