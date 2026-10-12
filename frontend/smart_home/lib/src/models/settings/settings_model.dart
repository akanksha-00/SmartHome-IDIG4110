enum TemperatureUnit { celsius, fahrenheit }

enum AlertDelivery { inApp, push, email }

enum HouseholdRole { owner, admin, member, guest }

class HouseholdMember {
  const HouseholdMember(
      {required this.id,
      required this.name,
      required this.email,
      required this.role});
  final String id;
  final String name;
  final String email;
  final HouseholdRole role;
}

class ProfileDetails {
  const ProfileDetails({required this.name, required this.email});
  final String name;
  final String email;
}
