import 'package:smart_home/src/models/settings/settings_model.dart';

const settingsFloors = {'floor1': 'Floor 1'};
const settingsRooms = {
  'living': 'Living Room',
  'kitchen': 'Kitchen',
  'bedroom1': 'Bedroom 1',
  'bathroom1': 'Bathroom 1',
};
const settingsTimeZones = [
  'Europe/Oslo',
  'Europe/London',
  'UTC',
  'Asia/Kolkata',
  'America/New_York'
];
const sampleHouseholdMembers = [
  HouseholdMember(
      id: 'owner',
      name: 'Alex',
      email: 'alex@example.com',
      role: HouseholdRole.owner),
  HouseholdMember(
      id: 'member-1',
      name: 'Jamie',
      email: 'jamie@example.com',
      role: HouseholdRole.member),
];
