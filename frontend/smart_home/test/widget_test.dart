import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/main.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/widgets/device_startup_gate.dart';

import 'helpers/device_test_data.dart';

Widget startupHarness(DeviceBloc bloc) => BlocProvider.value(
      value: bloc,
      child: MaterialApp(
          home: DeviceStartupGate(child: Builder(builder: (context) {
        final devices = context.watch<DeviceBloc>().state.devices;
        return Scaffold(body: Text('Loaded ${devices.length} devices'));
      }))),
    );

void main() {
  testWidgets('startup displays BLoC loading then its fetched device list',
      (tester) async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((_) => response.future);
    bloc.add(const DevicesRequested());
    await tester.pumpWidget(startupHarness(bloc));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(jsonResponse([deviceJson()]));
    await tester.pumpAndSettle();
    expect(find.text('Loaded 1 devices'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an empty house opens the loaded UI', (tester) async {
    final bloc = testDeviceBloc((_) async => jsonResponse([]));
    bloc.add(const DevicesRequested());
    await tester.pumpWidget(startupHarness(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Loaded 0 devices'), findsOneWidget);
  });

  testWidgets('failed startup retries through the BLoC', (tester) async {
    var calls = 0;
    final bloc = testDeviceBloc((_) async {
      calls++;
      return calls == 1
          ? http.Response('Unavailable', 503)
          : jsonResponse([deviceJson()]);
    });
    bloc.add(const DevicesRequested());
    await tester.pumpWidget(startupHarness(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Could not load devices'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Loaded 1 devices'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('rebuilds do not recreate the BLoC or fetch devices again',
      (tester) async {
    var calls = 0;
    final bloc = testDeviceBloc((_) async {
      calls++;
      return jsonResponse([deviceJson()]);
    });
    bloc.add(const DevicesRequested());
    await tester.pumpWidget(startupHarness(bloc));
    await tester.pumpAndSettle();
    await tester.pumpWidget(startupHarness(bloc));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('actual MyApp initializes device loading before displaying Home',
      (tester) async {
    final response = Completer<http.Response>();
    final source = testDeviceBloc((_) => response.future);
    await tester.pumpWidget(MyApp(deviceRepository: source.repository));
    expect(find.text('Loading devices…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(jsonResponse([]));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
