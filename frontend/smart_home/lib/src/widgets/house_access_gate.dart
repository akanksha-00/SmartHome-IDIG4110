import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/repositories/room_repository.dart';
import 'package:smart_home/src/widgets/house_session.dart';

/// Resolve the first house authorized by the backend before opening its data.
class HouseAccessGate extends StatefulWidget {
  const HouseAccessGate({
    super.key,
    this.apiClient,
    this.deviceRepository,
    this.roomRepository,
    this.realtime,
  });

  final ApiClient? apiClient;
  final DeviceRepository? deviceRepository;
  final RoomRepository? roomRepository;
  final HouseRealtimeRepository? realtime;

  @override
  State<HouseAccessGate> createState() => _HouseAccessGateState();
}

class _HouseAccessGateState extends State<HouseAccessGate> {
  ApiClient? _client;
  Future<String?>? _house;

  @override
  void initState() {
    super.initState();
    if (widget.deviceRepository == null) {
      final auth = context.read<AuthRepository>();
      _client =
          widget.apiClient ?? ApiClient(accessToken: () => auth.accessToken);
      _house = _loadHouse();
    }
  }

  Future<String?> _loadHouse() async {
    final response = await _client!.get(ApiEndpoints.houses);
    if (response is! List) {
      throw const FormatException('Expected a list of authorized houses');
    }
    if (response.isEmpty) return null;
    final first = response.first;
    if (first is! Map ||
        first['id'] is! String ||
        (first['id'] as String).trim().isEmpty) {
      throw const FormatException('The authorized house has no valid ID');
    }
    return first['id'] as String;
  }

  void _retry() {
    setState(() {
      _house = _loadHouse();
    });
  }

  @override
  void dispose() {
    if (widget.apiClient == null) _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Existing injected repositories already specify their test/selected house.
    if (widget.deviceRepository != null) {
      return HouseSession(
        deviceRepository: widget.deviceRepository,
        roomRepository: widget.roomRepository,
        realtime: widget.realtime,
      );
    }
    return FutureBuilder<String?>(
      future: _house,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            snapshot.data != null) {
          return HouseSession(
            key: ValueKey(snapshot.data),
            apiClient: _client,
            houseId: snapshot.data,
            roomRepository: widget.roomRepository,
            realtime: widget.realtime,
          );
        }
        final loading = snapshot.connectionState != ConnectionState.done;
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) const CircularProgressIndicator(),
                  if (!loading) const Icon(Icons.home_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    loading
                        ? 'Loading your houses…'
                        : snapshot.hasError
                            ? 'Could not load your houses.'
                            : 'No house is assigned to your account.',
                    textAlign: TextAlign.center,
                  ),
                  if (!loading) ...[
                    const SizedBox(height: 8),
                    Text(
                      snapshot.hasError
                          ? 'Check your connection and try again.'
                          : 'Ask your administrator to assign a house.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                  TextButton(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
