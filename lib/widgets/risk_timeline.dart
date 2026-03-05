import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';

/// Risk score timeline for video analysis – horizontal scrolling bar chart.
class RiskTimeline extends StatefulWidget {
  final List<dynamic> timelineFlat;

  const RiskTimeline({super.key, required this.timelineFlat});

  @override
  State<RiskTimeline> createState() => _RiskTimelineState();
}

class _RiskTimelineState extends State<RiskTimeline> {
  int? _touched;

  List<Map<String, dynamic>> get _frames =>
      widget.timelineFlat.whereType<Map<String, dynamic>>().toList();

  Color _barColor(double score) {
    if (score > 0.7) return AppTheme.error;
    if (score > 0.4) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    if (frames.isEmpty) {
      return Center(
        child: Text('No timeline data', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final maxFrames = frames.length;
    final visible = maxFrames.clamp(0, 80);
    final displayFrames = frames.take(visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              _Legend(color: AppTheme.success, label: '< 40%'),
              const SizedBox(width: 16),
              _Legend(color: AppTheme.warning, label: '40–70%'),
              const SizedBox(width: 16),
              _Legend(color: AppTheme.error, label: '> 70%'),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: displayFrames.length * 12.0,
              child: BarChart(
                BarChartData(
                  maxY: 1.0,
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      if (response?.spot != null) {
                        setState(() => _touched = response!.spot!.touchedBarGroupIndex);
                      } else {
                        setState(() => _touched = null);
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final f = displayFrames[group.x.toInt()];
                        final score = (f['final_score'] as num?)?.toDouble() ?? 0;
                        return BarTooltipItem(
                          'Frame ${f['frame_index'] ?? group.x}\n${(score * 100).toStringAsFixed(1)}%',
                          TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (val, meta) => Text(
                          '${(val * 100).toInt()}%',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(displayFrames.length, (i) {
                    final f = displayFrames[i];
                    final score = (f['final_score'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: score,
                          color: _barColor(score),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                      showingTooltipIndicators: _touched == i ? [0] : [],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        if (maxFrames > visible)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Showing first $visible of $maxFrames frames',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}
