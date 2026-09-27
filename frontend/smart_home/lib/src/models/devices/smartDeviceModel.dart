abstract class SmartDeviceModel {
  SmartDeviceModel(
      {required this.id,
      required this.title,
      required this.subtitle,
      this.isOn = false});

  final String id;
  final String title;
  final String subtitle;

  bool isOn;
}
