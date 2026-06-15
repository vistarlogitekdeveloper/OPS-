import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/vistar.dart';
import '../../data/dashboard_models.dart';

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.trend});
  final MonthlyTrend trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (trend.points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No data yet.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final maxY = trend.points.fold<double>(
      0,
      (m, p) => p.averageScore > m ? p.averageScore : m,
    );
    final yCap = (maxY < 10 ? 10.0 : maxY) * 1.15;
    final gridColor = theme.colorScheme.outline.withValues(alpha: 0.35);
    final labelStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (trend.points.length - 1).toDouble(),
          minY: 0,
          maxY: yCap,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: gridColor,
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: yCap / 4,
                getTitlesWidget: (v, _) =>
                    Text(v.toInt().toString(), style: labelStyle),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: trend.points.length <= 12 ? 1 : 2,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= trend.points.length) {
                    return const SizedBox.shrink();
                  }
                  final m = trend.points[i].month;
                  final short = m.length >= 7
                      ? '${m.substring(2, 4)}-${m.substring(5, 7)}'
                      : m;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(short, style: labelStyle),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              curveSmoothness: 0.25,
              gradient: Vistar.ribbon,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: Vistar.pink,
                  strokeColor: Colors.white.withValues(alpha: 0.9),
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Vistar.pink.withValues(alpha: 0.22),
                    Vistar.pink.withValues(alpha: 0.0),
                  ],
                ),
              ),
              spots: [
                for (int i = 0; i < trend.points.length; i++)
                  FlSpot(i.toDouble(), trend.points[i].averageScore),
              ],
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipMargin: 8,
              tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              getTooltipColor: (_) => Vistar.surface2,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    'avg ${s.y.toStringAsFixed(1)}',
                    const TextStyle(
                      color: Vistar.txt,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
