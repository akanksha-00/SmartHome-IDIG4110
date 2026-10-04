import 'smartDeviceModel.dart';

class SmartPlugDeviceModel extends SmartDeviceModel {
  SmartPlugDeviceModel({
    required super.id,
    required super.title,
    required super.subtitle,
    super.isOn = false,
    super.roomId,
  });
}
