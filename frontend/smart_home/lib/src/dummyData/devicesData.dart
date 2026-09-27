import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartPlugDeviceModel.dart';

List<SmartDeviceModel> createSmartDevices() {
  return [
    LightDeviceModel(
      id: 'light-1',
      title: 'Ceiling Light 1',
      subtitle: 'Above sofa',
    ),
    LightDeviceModel(
      id: 'light-2',
      title: 'Ceiling Light 2',
      subtitle: 'Dining Area',
    ),
    LightDeviceModel(
      id: 'light-3',
      title: 'Ceiling Light 3',
      subtitle: 'Entrance',
    ),
    FanDeviceModel(
      id: 'fan-1',
      title: 'Fan 1',
      subtitle: 'Sofa area',
    ),
    FanDeviceModel(
      id: 'fan-2',
      title: 'Fan 2',
      subtitle: 'Dining area',
    ),
    SmartPlugDeviceModel(
      id: 'smart-plug-1',
      title: 'TV Plug',
      subtitle: 'TV wall',
    ),
    SmartPlugDeviceModel(
      id: 'smart-plug-2',
      title: 'Speaker Plug',
      subtitle: 'Media shelf',
    ),
  ];
}
