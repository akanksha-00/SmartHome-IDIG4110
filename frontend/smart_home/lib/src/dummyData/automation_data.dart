import 'package:smart_home/src/models/automations/automation_model.dart';

const automationFloorLabels = {'floor1': 'Floor 1'};
const automationRoomLabels = {
  'living': 'Living Room',
  'kitchen': 'Kitchen',
  'bedroom1': 'Bedroom 1',
  'bathroom1': 'Bathroom 1',
};

// Local demonstration routines. Targets match the existing Home inventory.
List<AutomationModel> createSampleAutomations() => [
      AutomationModel(
        id: 'morning',
        title: 'Morning lights',
        floorId: 'floor1',
        roomId: 'living',
        trigger: const AutomationTrigger(
          type: AutomationTriggerType.schedule,
          minutesOfDay: 7 * 60,
          repeat: AutomationRepeat.weekdays,
        ),
        action: AutomationAction(
          type: AutomationActionType.brightness,
          deviceIds: ['light-2', 'light-3'],
          level: 80,
        ),
      ),
      AutomationModel(
        id: 'evening',
        title: 'Evening wind down',
        floorId: 'floor1',
        roomId: 'living',
        trigger: const AutomationTrigger(type: AutomationTriggerType.sunset),
        action: AutomationAction(
          type: AutomationActionType.brightness,
          deviceIds: ['light-2', 'light-3'],
          level: 30,
        ),
      ),
      AutomationModel(
        id: 'cool',
        title: 'Keep the room cool',
        floorId: 'floor1',
        roomId: 'living',
        trigger:
            const AutomationTrigger(type: AutomationTriggerType.temperature),
        action: AutomationAction(
          type: AutomationActionType.fanSpeed,
          deviceIds: ['fan-1'],
          level: 2,
        ),
      ),
      AutomationModel(
        id: 'bedtime',
        title: 'Bedtime',
        floorId: 'floor1',
        roomId: 'living',
        isEnabled: false,
        trigger: const AutomationTrigger(
            type: AutomationTriggerType.schedule, minutesOfDay: 23 * 60),
        action: AutomationAction(
          type: AutomationActionType.turnOff,
          deviceIds: ['light-2', 'light-3', 'smart-plug-1'],
        ),
      ),
    ];

const sampleAutomationRuns = [
  AutomationRun(
    id: 'run-1',
    automationId: 'morning',
    title: 'Morning lights',
    floorId: 'floor1',
    roomId: 'living',
    triggerType: AutomationTriggerType.schedule,
    timeLabel: 'Today, 07:00',
    status: AutomationRunStatus.completed,
  ),
  AutomationRun(
    id: 'run-2',
    automationId: 'evening',
    title: 'Evening wind down',
    floorId: 'floor1',
    roomId: 'living',
    triggerType: AutomationTriggerType.sunset,
    timeLabel: 'Yesterday, 18:35',
    status: AutomationRunStatus.completed,
  ),
  AutomationRun(
    id: 'run-3',
    automationId: 'cool',
    title: 'Keep the room cool',
    floorId: 'floor1',
    roomId: 'living',
    triggerType: AutomationTriggerType.temperature,
    timeLabel: 'Yesterday, 14:12',
    status: AutomationRunStatus.failed,
    detail: 'Fan 1 is offline',
  ),
  AutomationRun(
    id: 'run-4',
    automationId: 'morning',
    title: 'Morning lights',
    floorId: 'floor1',
    roomId: 'living',
    triggerType: AutomationTriggerType.schedule,
    timeLabel: 'Yesterday, 07:00',
    status: AutomationRunStatus.completed,
  ),
];
