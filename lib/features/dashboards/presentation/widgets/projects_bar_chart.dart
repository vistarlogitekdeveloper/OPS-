import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/vistar.dart';
import '../../data/dashboard_models.dart';

class ProjectsBarChart extends StatelessWidget {
  const ProjectsBarChart({super.key, required this.page});
  final ProjectScoresPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = page.items;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No projects in scope.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final maxScore =
        items.fold<int>(0, (m, r) => r.totalScore > m ? r.totalScore : m);
    final maxY = (maxScore < 10 ? 10 : maxScore).toDouble();
    final gridColor = theme.colorScheme.outline.withValues(alpha: 0.35);
    final labelStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.1,
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
                interval: maxY / 4,
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
                reservedSize: 40,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= items.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(items[i].code, style: labelStyle),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < items.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: items[i].totalScore.toDouble(),
                    width: 14,
                    gradient: _gradientForStatus(items[i].status),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipMargin: 8,
              tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              getTooltipColor: (_) => Vistar.surface2,
              getTooltipItem: (group, _, rod, _) {
                final row = items[group.x];
                return BarTooltipItem(
                  '${row.code}\n${row.totalScore} marks  •  ${row.status}',
                  const TextStyle(
                    color: Vistar.txt,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _gradientForStatus(String status) {
    switch (status) {
      case 'APPROVED':
        return Vistar.ribbon;
      case 'SUBMITTED':
        return LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Vistar.info.withValues(alpha: 0.6), Vistar.info],
        );
      case 'REJECTED':
        return LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Vistar.bad.withValues(alpha: 0.6), Vistar.bad],
        );
      case 'DRAFT':
        return LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Vistar.txt3.withValues(alpha: 0.4),
            Vistar.txt3.withValues(alpha: 0.7),
          ],
        );
      default:
        return LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Vistar.surface3,
            Vistar.surface3.withValues(alpha: 0.6),
          ],
        );
    }
  }
}
