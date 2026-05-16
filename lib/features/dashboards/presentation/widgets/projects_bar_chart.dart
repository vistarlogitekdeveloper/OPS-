import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/dashboard_models.dart';

class ProjectsBarChart extends StatelessWidget {
  const ProjectsBarChart({super.key, required this.page});
  final ProjectScoresPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = page.items;
    if (items.isEmpty) {
      return Center(child: Text('No projects in scope.', style: theme.textTheme.bodyMedium));
    }
    final maxScore = items.fold<int>(0, (m, r) => r.totalScore > m ? r.totalScore : m);
    final maxY = (maxScore < 10 ? 10 : maxScore).toDouble();

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.1,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: maxY / 4,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: theme.textTheme.bodySmall),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= items.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        items[i].code,
                        style: theme.textTheme.bodySmall,
                      ),
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
                    color: _colorForStatus(items[i].status, theme),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipMargin: 6,
              getTooltipItem: (group, _, rod, _) {
                final row = items[group.x];
                return BarTooltipItem(
                  '${row.code}\n${row.totalScore} marks\n${row.status}',
                  TextStyle(color: theme.colorScheme.onInverseSurface),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _colorForStatus(String status, ThemeData theme) {
    return switch (status) {
      'APPROVED' => theme.colorScheme.primary,
      'SUBMITTED' => theme.colorScheme.secondary,
      'REJECTED' => theme.colorScheme.error,
      'DRAFT' => theme.colorScheme.tertiary,
      _ => theme.colorScheme.outlineVariant,
    };
  }
}
