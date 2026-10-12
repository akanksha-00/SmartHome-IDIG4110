import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_home/src/dummyData/energyData.dart';
import 'package:smart_home/src/models/energy/energyUsageModel.dart';

class EnergyPage extends StatefulWidget {
  const EnergyPage({super.key});

  @override
  State<EnergyPage> createState() => _EnergyPageState();
}

class _EnergyPageState extends State<EnergyPage> {
  String _selectedFloor = 'all';
  String _selectedRoom = 'all';
  String _selectedPeriod = 'week';
  String _deviceQuery = '';
  int _sortColumn = 0;
  bool _sortAscending = true;
  final _deviceSearchController = TextEditingController();
  final _tableScrollController = ScrollController();

  @override
  void dispose() {
    _deviceSearchController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  void _clearDeviceSearch() {
    _deviceSearchController.clear();
    _deviceQuery = '';
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required String valueKey,
    Color? accentColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor ?? colors.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    key: ValueKey(valueKey),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergySummaryCards(EnergySummary summary) {
    final total = summary.totalEnergyKwh;
    final change = summary.changePercent;
    final peak = summary.peakIndex;
    final previous = summary.previousEnergyKwh;
    final colors = Theme.of(context).colorScheme;
    final changeColor = change == null || change == 0
        ? colors.onSurfaceVariant
        : change < 0
            ? Theme.of(context).brightness == Brightness.dark
                ? Colors.greenAccent
                : Colors.green.shade700
            : colors.primary;
    final cards = <Widget>[
      _buildSummaryCard(
        icon: Icons.bolt,
        title: 'Energy recorded',
        value: total == null ? '—' : '${total.toStringAsFixed(1)} kWh',
        valueKey: 'energy-total',
        subtitle: summary.devices.isEmpty
            ? 'No devices in this selection'
            : '${summary.reportingDeviceCount} of ${summary.devices.length} devices reporting',
      ),
      _buildSummaryCard(
        icon: change == null || change == 0
            ? Icons.trending_flat
            : change < 0
                ? Icons.trending_down
                : Icons.trending_up,
        title: 'Compared with ${summary.period.previousPeriodLabel}',
        value: change == null
            ? '—'
            : '${change > 0 ? '+' : ''}${change.toStringAsFixed(change.abs() < 1 ? 1 : 0)}%',
        valueKey: 'energy-comparison',
        subtitle: previous == null
            ? 'No comparable readings'
            : 'Previous: ${previous.toStringAsFixed(1)} kWh',
        accentColor: changeColor,
      ),
      _buildSummaryCard(
        icon: _selectedPeriod == 'today'
            ? Icons.schedule
            : Icons.calendar_today_outlined,
        title: _selectedPeriod == 'today'
            ? 'Highest usage hour'
            : 'Highest usage day',
        value: peak == null
            ? '—'
            : _selectedPeriod == 'today'
                ? summary.period.bucketLabels[peak]
                : summary.period.fullBucketLabels[peak],
        valueKey: 'energy-peak',
        subtitle: peak == null
            ? 'No peak usage recorded'
            : '${summary.energyByInterval[peak].toStringAsFixed(2)} kWh',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          cards[index],
        ],
      ],
    );
  }

  double _chartInterval(double peak) {
    if (peak <= 0) return .25;
    final rough = peak * 1.15 / 4;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor());
    final fraction = rough / magnitude;
    final nice = fraction <= 1
        ? 1
        : fraction <= 2
            ? 2
            : fraction <= 5
                ? 5
                : 10;
    return (nice * magnitude).toDouble();
  }

  Widget _buildEnergyChart(EnergySummary summary, {double? height = 330}) {
    if (summary.reportingDeviceCount == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(summary.devices.isEmpty
              ? 'No devices in this selection'
              : 'These devices do not report energy readings'),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    final values = summary.energyByInterval;
    final peak = values.reduce(math.max);
    final interval = _chartInterval(peak);
    final maxY = peak == 0 ? 1.0 : (peak / interval).ceil() * interval;
    final labels = summary.period.bucketLabels;
    final spots = List.generate(
        values.length, (index) => FlSpot(index.toDouble(), values[index]));
    return Semantics(
      label: '${summary.period.chartTitle}, '
          '${summary.totalEnergyKwh!.toStringAsFixed(1)} kilowatt hours',
      child: SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, constraints) {
          final xInterval = math.max(
              1,
              ((labels.length - 1) / (constraints.maxWidth < 340 ? 3 : 6))
                  .ceil());
          return LineChart(
            key: ValueKey('energy-chart-$_selectedPeriod-$_selectedRoom'),
            LineChartData(
              minX: 0,
              maxX: (values.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('kWh'),
                  axisNameSize: 22,
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: interval,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(interval < .1
                          ? 2
                          : interval < 1
                              ? 1
                              : 0),
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget:
                      Text(_selectedPeriod == 'today' ? 'Time of day' : 'Day'),
                  axisNameSize: 22,
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: xInterval.toDouble(),
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (value != index ||
                          index < 0 ||
                          index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta,
                            distanceFromEdge: 0),
                        child: Text(labels[index],
                            style: TextStyle(
                                fontSize: 12, color: colors.onSurfaceVariant)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: colors.outlineVariant.withValues(alpha: .45),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => colors.surfaceContainerHighest,
                  getTooltipItems: (spots) => spots
                      .map((spot) => LineTooltipItem(
                            '${summary.period.fullBucketLabels[spot.spotIndex]}\n'
                            '${spot.y.toStringAsFixed(2)} kWh',
                            TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600),
                          ))
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: colors.primary,
                  barWidth: 3,
                  isCurved: false,
                  dotData: FlDotData(show: values.length <= 7),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colors.primary.withValues(alpha: .12),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEnergyChartCard(EnergySummary summary, {bool stretch = false}) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.period.chartTitle,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(summary.period.caption,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              if (stretch)
                Expanded(child: _buildEnergyChart(summary, height: null))
              else
                _buildEnergyChart(summary),
            ],
          ),
        ),
      );

  Widget _buildEnergySection(EnergySummary summary) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 850) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEnergyChartCard(summary),
                const SizedBox(height: 16),
                _buildEnergySummaryCards(summary),
              ],
            );
          }
          // The stats column sets the section height; the chart fills it.
          return Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: 316,
                child: _buildEnergyChartCard(summary, stretch: true),
              ),
              Align(
                alignment: Alignment.centerRight,
                heightFactor: 1,
                child: SizedBox(
                  width: 300,
                  child: _buildEnergySummaryCards(summary),
                ),
              ),
            ],
          );
        },
      );

  List<DeviceEnergyUsage> _visibleDeviceRows(EnergySummary summary) {
    final query = _deviceQuery.trim().toLowerCase();
    final rows = summary.devices
        .where((device) =>
            device.title.toLowerCase().contains(query) ||
            device.roomName.toLowerCase().contains(query))
        .toList();
    rows.sort((a, b) {
      // Missing readings stay at the end, regardless of sort direction.
      if (_sortColumn == 3) {
        if (a.totalEnergyKwh == null && b.totalEnergyKwh != null) return 1;
        if (b.totalEnergyKwh == null && a.totalEnergyKwh != null) return -1;
      }
      final result = switch (_sortColumn) {
        1 => a.roomName.compareTo(b.roomName),
        2 => a.runtimeHours.compareTo(b.runtimeHours),
        3 => (a.totalEnergyKwh ?? 0).compareTo(b.totalEnergyKwh ?? 0),
        _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
      if (result == 0) return a.title.compareTo(b.title);
      return _sortAscending ? result : -result;
    });
    return rows;
  }

  void _sortDevices(int column, bool ascending) => setState(() {
        _sortColumn = column;
        _sortAscending = ascending;
      });

  Widget _buildDeviceSearch() => TextField(
        key: const ValueKey('energy-device-search'),
        controller: _deviceSearchController,
        decoration: InputDecoration(
          hintText: 'Find a device',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: _deviceQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () => setState(_clearDeviceSearch),
                  icon: const Icon(Icons.close),
                ),
        ),
        onChanged: (value) => setState(() => _deviceQuery = value),
      );

  Widget _buildDeviceBreakdown(EnergySummary summary) {
    final rows = _visibleDeviceRows(summary);
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              const heading = Text('Device breakdown',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 12),
                    _buildDeviceSearch()
                  ],
                );
              }
              return Row(children: [
                const Expanded(child: heading),
                const SizedBox(width: 16),
                SizedBox(width: 260, child: _buildDeviceSearch()),
              ]);
            }),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: Text(summary.devices.isEmpty
                        ? 'No devices in this selection'
                        : 'No devices match your search')),
              )
            else
              LayoutBuilder(
                  builder: (context, constraints) => Scrollbar(
                        controller: _tableScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _tableScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              key: const ValueKey('energy-device-table'),
                              sortColumnIndex: _sortColumn,
                              sortAscending: _sortAscending,
                              headingRowHeight: 44,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              columnSpacing: 28,
                              horizontalMargin: 12,
                              columns: [
                                DataColumn(
                                    label: const Text('Device'),
                                    onSort: _sortDevices),
                                DataColumn(
                                    label: const Text('Room'),
                                    onSort: _sortDevices),
                                DataColumn(
                                    label: const Text('Runtime'),
                                    numeric: true,
                                    onSort: _sortDevices),
                                DataColumn(
                                    label: const Text('Energy'),
                                    numeric: true,
                                    onSort: _sortDevices),
                              ],
                              rows: rows
                                  .map((device) => DataRow(
                                        key: ValueKey(device.id),
                                        cells: [
                                          DataCell(Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                    switch (device.type) {
                                                      EnergyDeviceType.light =>
                                                        Icons.lightbulb_outline,
                                                      EnergyDeviceType.fan =>
                                                        Icons.air,
                                                      EnergyDeviceType.plug =>
                                                        Icons.power_outlined,
                                                    },
                                                    size: 18,
                                                    color: colors.primary),
                                                const SizedBox(width: 8),
                                                Text(device.title),
                                              ])),
                                          DataCell(Text(device.roomName)),
                                          DataCell(Text(
                                              '${device.runtimeHours.toStringAsFixed(device.runtimeHours % 1 == 0 ? 0 : 1)} h')),
                                          DataCell(Text(device.totalEnergyKwh ==
                                                  null
                                              ? '—'
                                              : '${device.totalEnergyKwh!.toStringAsFixed(2)} kWh')),
                                        ],
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      )),
            const SizedBox(height: 8),
            Text('Energy is shown only for devices that report it.',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() => LayoutBuilder(builder: (context, constraints) {
        const controlHeight = 48.0;
        const dropdownDecoration = InputDecorationTheme(
          constraints: BoxConstraints.tightFor(height: controlHeight),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        );
        final dropdownWidth = math.min(200.0, constraints.maxWidth);
        final periodWidth = math.min(300.0, constraints.maxWidth);
        final colors = Theme.of(context).colorScheme;
        final dropdowns = [
          DropdownMenu<String>(
            key: const ValueKey('energy-floor-filter'),
            width: dropdownWidth,
            inputDecorationTheme: dropdownDecoration,
            initialSelection: _selectedFloor,
            selectOnly: true,
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: 'all', label: 'All floors'),
              ...energyFloorLabels.entries.map((entry) =>
                  DropdownMenuEntry(value: entry.key, label: entry.value)),
            ],
            onSelected: (value) {
              if (value == null) return;
              setState(() {
                _selectedFloor = value;
                _selectedRoom = 'all';
                _clearDeviceSearch();
              });
            },
          ),
          DropdownMenu<String>(
            key: ValueKey('energy-room-$_selectedFloor'),
            width: dropdownWidth,
            inputDecorationTheme: dropdownDecoration,
            initialSelection: _selectedRoom,
            selectOnly: true,
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: 'all', label: 'All rooms'),
              ...energyRoomLabels.entries.map((entry) =>
                  DropdownMenuEntry(value: entry.key, label: entry.value)),
            ],
            onSelected: (value) {
              if (value == null) return;
              setState(() {
                _selectedRoom = value;
                _clearDeviceSearch();
              });
            },
          ),
        ];
        final periodSelector = SizedBox(
          width: periodWidth,
          height: controlHeight,
          child: SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: colors.primary,
              selectedForegroundColor: colors.onPrimary,
              minimumSize: const Size(0, controlHeight),
              fixedSize: const Size.fromHeight(controlHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: BorderSide(color: colors.outline),
            ),
            segments: const [
              ButtonSegment(value: 'today', label: Text('Today')),
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (selection) =>
                setState(() => _selectedPeriod = selection.first),
          ),
        );
        if (constraints.maxWidth >= dropdownWidth * 2 + periodWidth + 32) {
          return Row(
            children: [
              dropdowns[0],
              const SizedBox(width: 16),
              dropdowns[1],
              const Spacer(),
              const SizedBox(width: 16),
              periodSelector,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 16, runSpacing: 16, children: dropdowns),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: periodSelector),
          ],
        );
      });

  @override
  Widget build(BuildContext context) {
    final summary = EnergySummary.fromPeriod(
      sampleEnergyPeriods[_selectedPeriod]!,
      floorId: _selectedFloor,
      roomId: _selectedRoom,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Energy consumption',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 24),
          _buildEnergySection(summary),
          const SizedBox(height: 16),
          _buildDeviceBreakdown(summary),
        ],
      ),
    );
  }
}
