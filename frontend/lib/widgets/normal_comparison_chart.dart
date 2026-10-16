import 'dart:math' as math;

import 'package:flutter/material.dart';

class NormalComparisonChart extends StatelessWidget {
  const NormalComparisonChart({
    required this.measurements,
    this.age,
    super.key,
  });

  final Map<String, double> measurements;
  final int? age;

  static const _metrics = <_ReferenceMetric>[
    _ReferenceMetric(
      code: 'BMI',
      label: 'BMI',
      unit: 'kg/m²',
      referenceLabel: '18.5–24.9',
      upperReference: 24.9,
      lowerReference: 18.5,
    ),
    _ReferenceMetric(
      code: 'GLUCOSE',
      label: 'น้ำตาล',
      unit: 'mg/dL',
      referenceLabel: '70–99*',
      upperReference: 99,
      lowerReference: 70,
    ),
    _ReferenceMetric(
      code: 'SYSTOLIC_BP',
      label: 'ความดันบน',
      unit: 'mmHg',
      referenceLabel: '<120',
      upperReference: 120,
    ),
    _ReferenceMetric(
      code: 'DIASTOLIC_BP',
      label: 'ความดันล่าง',
      unit: 'mmHg',
      referenceLabel: '<80',
      upperReference: 80,
    ),
    _ReferenceMetric(
      code: 'CHOLESTEROL',
      label: 'คอเลสเตอรอล',
      unit: 'mg/dL',
      referenceLabel: '<200',
      upperReference: 200,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics
        .where((metric) => measurements.containsKey(metric.code))
        .toList(growable: false);

    return Container(
      key: const ValueKey('normal-comparison-chart'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        border: Border.all(color: const Color(0xFFF0DEDA)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ค่าที่วัดได้เทียบเกณฑ์อ้างอิง',
            style: TextStyle(
              color: Color(0xFF352C2A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'แกนตั้งแสดงสัดส่วนเทียบขอบบนของเกณฑ์อ้างอิง (100%) '
            'เพื่อเปรียบเทียบค่าต่างหน่วย',
            style: TextStyle(
              color: Color(0xFF837571),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (metrics.isEmpty)
            const Text(
              'ไม่มีค่าตัวเลขสำหรับแสดงกราฟ',
              style: TextStyle(color: Color(0xFF837571), fontSize: 12),
            )
          else ...[
            const _ChartLegend(
              entries: [
                _LegendEntry(
                  color: Color(0xFF4F8C70),
                  label: 'ขอบบนเกณฑ์อ้างอิง',
                ),
                _LegendEntry(
                  color: Color(0xFFEF806F),
                  label: 'ค่าที่วัดได้',
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const leftAxisWidth = 42.0;
                const rightPadding = 12.0;
                final chartWidth = math.max(
                  constraints.maxWidth,
                  leftAxisWidth + rightPadding + metrics.length * 78.0,
                );
                final plotWidth = chartWidth - leftAxisWidth - rightPadding;
                final itemWidth = plotWidth / metrics.length;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 174,
                          child: CustomPaint(
                            size: Size(chartWidth, 174),
                            painter: _ComparisonChartPainter(
                              metrics: metrics,
                              measurements: measurements,
                              leftAxisWidth: leftAxisWidth,
                              rightPadding: rightPadding,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: leftAxisWidth,
                            right: rightPadding,
                          ),
                          child: Row(
                            children: [
                              for (final metric in metrics)
                                SizedBox(
                                  width: itemWidth,
                                  child: Text(
                                    metric.label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF837571),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            for (final metric in metrics)
              _MeasurementRow(
                metric: metric,
                value: measurements[metric.code]!,
              ),
          ],
          const SizedBox(height: 10),
          Text(
            '* น้ำตาลใช้อ้างอิงเกณฑ์ขณะอดอาหาร · '
            'เกณฑ์ BMI เป็นเกณฑ์ผู้ใหญ่'
            '${age == null ? '' : ' · อายุ $age ปี'}',
            style: const TextStyle(
              color: Color(0xFF837571),
              fontSize: 10,
              height: 1.5,
            ),
          ),
          if (age != null && age! < 18)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'เกณฑ์นี้เป็นเกณฑ์ผู้ใหญ่ ไม่เหมาะสำหรับแปลผลในผู้มีอายุต่ำกว่า 18 ปี',
                style: TextStyle(
                  color: Color(0xFFAA6B16),
                  fontSize: 10,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'เป็นเพียงการเปรียบเทียบกับเกณฑ์อ้างอิงทั่วไป ไม่ใช่การวินิจฉัย '
            'และไม่ทดแทนคำแนะนำจากบุคลากรทางการแพทย์',
            style: TextStyle(
              color: Color(0xFF837571),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceMetric {
  const _ReferenceMetric({
    required this.code,
    required this.label,
    required this.unit,
    required this.referenceLabel,
    required this.upperReference,
    this.lowerReference,
  });

  final String code;
  final String label;
  final String unit;
  final String referenceLabel;
  final double upperReference;
  final double? lowerReference;

  String statusFor(double value) {
    if (lowerReference != null && value < lowerReference!) {
      return 'ต่ำกว่าเกณฑ์อ้างอิง';
    }
    if (value > upperReference) return 'สูงกว่าเกณฑ์อ้างอิง';
    return 'อยู่ในช่วงอ้างอิง';
  }
}

class _ComparisonChartPainter extends CustomPainter {
  const _ComparisonChartPainter({
    required this.metrics,
    required this.measurements,
    required this.leftAxisWidth,
    required this.rightPadding,
  });

  final List<_ReferenceMetric> metrics;
  final Map<String, double> measurements;
  final double leftAxisWidth;
  final double rightPadding;

  static const _plotTop = 12.0;
  static const _plotBottom = 150.0;
  static const _referenceColor = Color(0xFF4F8C70);
  static const _measurementColor = Color(0xFFEF806F);

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - leftAxisWidth - rightPadding;
    final maxPercent = metrics.fold<double>(
      150,
      (maximum, metric) => math.max(
        maximum,
        measurements[metric.code]! / metric.upperReference * 100,
      ),
    );
    final maxY = (maxPercent / 50).ceil() * 50.0;

    double yFor(double value) {
      return _plotBottom - (value / maxY) * (_plotBottom - _plotTop);
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFEADBD7)
      ..strokeWidth = 1;
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var value = 0.0; value <= maxY; value += 50) {
      final y = yFor(value);
      canvas.drawLine(
        Offset(leftAxisWidth, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
      labelPainter
        ..text = TextSpan(
          text: '${value.toInt()}%',
          style: const TextStyle(
            color: Color(0xFF837571),
            fontSize: 9,
          ),
        )
        ..layout();
      labelPainter.paint(
        canvas,
        Offset(leftAxisWidth - labelPainter.width - 6,
            y - labelPainter.height / 2),
      );
    }

    final referenceY = yFor(100);
    final referencePaint = Paint()
      ..color = _referenceColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(leftAxisWidth, referenceY),
      Offset(size.width - rightPadding, referenceY),
      referencePaint,
    );

    final measurementPoints = <Offset>[];
    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      final x = leftAxisWidth + plotWidth * (index + 0.5) / metrics.length;
      final value = measurements[metric.code]!;
      measurementPoints.add(
        Offset(x, yFor(value / metric.upperReference * 100)),
      );
      labelPainter
        ..text = TextSpan(
          text: metric.referenceLabel,
          style: const TextStyle(
            color: _referenceColor,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        )
        ..layout(maxWidth: plotWidth / metrics.length);
      labelPainter.paint(
        canvas,
        Offset(x - labelPainter.width / 2, referenceY - 14),
      );
    }

    if (measurementPoints.length > 1) {
      final linePaint = Paint()
        ..color = _measurementColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final line = Path()
        ..moveTo(measurementPoints.first.dx, measurementPoints.first.dy);
      for (final point in measurementPoints.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(line, linePaint);
    }

    final pointPaint = Paint()..color = _measurementColor;
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in measurementPoints) {
      canvas
        ..drawCircle(point, 5, pointPaint)
        ..drawCircle(point, 5, pointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(_ComparisonChartPainter oldDelegate) {
    return oldDelegate.metrics != metrics ||
        oldDelegate.measurements != measurements;
  }
}

class _LegendEntry {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final String label;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.entries});

  final List<_LegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: entry.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                entry.label,
                style: const TextStyle(
                  color: Color(0xFF837571),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({required this.metric, required this.value});

  final _ReferenceMetric metric;
  final double value;

  @override
  Widget build(BuildContext context) {
    final isOutsideReference = metric.statusFor(value) != 'อยู่ในช่วงอ้างอิง';
    final color =
        isOutsideReference ? const Color(0xFFAA6B16) : const Color(0xFF4F8C70);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${metric.label} · ${metric.referenceLabel} ${metric.unit}',
              style: const TextStyle(
                color: Color(0xFF352C2A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} '
                '${metric.unit}',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                metric.statusFor(value),
                style: TextStyle(color: color, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
