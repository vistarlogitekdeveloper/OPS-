import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/dashboard_models.dart';

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.trend});
  final MonthlyTrend trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (trend.points.isEmpty) {
      return Center(child: Text('No data yet.', style: theme.textTheme.bodyMedium));
    }
    final maxY = trend.points.fold<double>(
      0,
      (m, p) => p.averageScore > m ? p.averageScore : m,
    );
    final yCap = (maxY < 10 ? 10.0 : maxY) * 1.15;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (trend.points.length - 1).toDouble(),
          minY: 0,
          maxY: yCap,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: yCap / 4,
                getTitlesWidget: (v, _) =>
                    Text(v.toInt().toString(), style: theme.textTheme.bodySmall),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: trend.points.length <= 12 ? 1 : 2,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= trend.points.length) return const SizedBox.shrink();
                  final m = trend.points[i].month;
                  // Short label "YY-MM"
                  final short = m.length >= 7 ? '${m.substring(2, 4)}-${m.substring(5, 7)}' : m;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short, style: theme.textTheme.bodySmall),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: false,
              color: theme.colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
              ),
              spots: [
                for (int i = 0; i < trend.points.length; i++)
                  FlSpot(i.toDouble(), trend.points[i].averageScore),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
