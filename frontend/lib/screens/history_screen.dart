import 'package:flutter/material.dart';

import '../models/assessment_history.dart';
import '../services/api_service.dart';
import '../widgets/normal_comparison_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _green = Color(0xFFEF806F);
  static const _deepGreen = Color(0xFFB94F45);
  static const _ink = Color(0xFF352C2A);
  static const _muted = Color(0xFF837571);
  static const _line = Color(0xFFF0DEDA);
  static const _diseaseLabels = {
    'DIABETES': 'เบาหวาน',
    'HYPERTENSION': 'ความดันโลหิตสูง',
    'HEART_DISEASE': 'โรคหัวใจ',
  };
  static const _factorLabels = {
    'AGE': 'อายุ',
    'GENDER': 'เพศ',
    'BMI': 'BMI',
    'GLUCOSE': 'น้ำตาลในเลือด',
    'SYSTOLIC_BP': 'ความดันตัวบน',
    'DIASTOLIC_BP': 'ความดันตัวล่าง',
    'CHOLESTEROL': 'คอเลสเตอรอล',
    'FATIGUE': 'อ่อนเพลีย',
    'HEADACHE': 'ปวดศีรษะ',
    'DIZZINESS': 'เวียนศีรษะ',
    'CHEST_PAIN': 'เจ็บหน้าอก',
    'SHORTNESS_OF_BREATH': 'หายใจลำบาก',
    'NAUSEA': 'คลื่นไส้',
    'BLURRED_VISION': 'ตามัว',
    'FREQUENT_URINATION': 'ปัสสาวะบ่อย',
    'EXCESSIVE_THIRST': 'กระหายน้ำมาก',
    'PALPITATIONS': 'ใจสั่น',
  };

  late Future<List<AssessmentHistoryRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ApiService.getAssessmentHistory();
  }

  void _reload() {
    setState(() => _historyFuture = ApiService.getAssessmentHistory());
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'ไม่ระบุวันเวลา';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute น.';
  }

  String _diseaseLabel(String? code, String? name) =>
      _diseaseLabels[code] ?? name ?? 'ยังไม่พบโรคที่เข้าข่าย';

  Color _riskColor(String? level) => switch (level) {
        'ระดับสูง' => const Color(0xFFB64435),
        'ระดับปานกลาง' => const Color(0xFFAA6B16),
        _ => const Color(0xFF4F8C70),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF7F5), Color(0xFFFFEBE7)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 900
              ? 40.0
              : constraints.maxWidth >= 600
                  ? 28.0
                  : 16.0;
          return FutureBuilder<List<AssessmentHistoryRecord>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    22,
                    horizontalPadding,
                    30,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(snapshot.data?.length),
                            const SizedBox(height: 22),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 64),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (snapshot.hasError)
                              _buildError(snapshot.error.toString())
                            else if (snapshot.data?.isEmpty ?? true)
                              _buildEmpty()
                            else ...[
                              Text(
                                'รายการประเมินล่าสุด',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: _ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ...snapshot.data!.map(_buildHistoryCard),
                              const SizedBox(height: 4),
                              const Center(
                                child: Text(
                                  'แสดงประวัติล่าสุดไม่เกิน 100 รายการ',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(int? count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_green, _deepGreen],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ประวัติสุขภาพ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  count == null
                      ? 'ติดตามผลการประเมินย้อนหลังของคุณ'
                      : 'มีประวัติการประเมิน $count รายการ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(AssessmentHistoryRecord record) {
    final summary = record.summary;
    final riskLevel = summary['risk_level'] as String?;
    final summaryDisease = _diseaseLabel(
      summary['disease_code'] as String?,
      summary['disease_name'] as String?,
    );
    final riskColor = _riskColor(riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE6E0),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_outlined,
                      color: _green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dateLabel(record.assessedAt)} · ${record.assessmentCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Icon(
                      riskLevel == null
                          ? Icons.check_circle_outline_rounded
                          : Icons.insights_rounded,
                      color: riskColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summaryDisease,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (riskLevel != null)
                      Text(
                        '$riskLevel · '
                        '${(((summary['final_cf'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  _smallInfo(Icons.badge_outlined, record.patientCode),
                  const SizedBox(width: 14),
                  if (record.phone != null)
                    _smallInfo(Icons.phone_outlined, record.phone!),
                  if (record.phone != null && record.age != null)
                    const SizedBox(width: 14),
                  if (record.age != null)
                    _smallInfo(Icons.cake_outlined, '${record.age} ปี'),
                  const Spacer(),
                  const Text(
                    'แตะเพื่อดูรายละเอียด',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFFFE6E0),
            child: Icon(Icons.event_note_rounded, color: _green, size: 28),
          ),
          SizedBox(height: 14),
          Text(
            'ยังไม่มีประวัติการประเมิน',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'เมื่อประเมินสุขภาพแล้ว ผลจะแสดงในหน้านี้',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EE),
        border: Border.all(color: const Color(0xFFF0C7BE)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'โหลดประวัติไม่สำเร็จ',
            style: TextStyle(
              color: Color(0xFF8B362A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.replaceFirst('Exception: ', ''),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }

  void _showDetails(AssessmentHistoryRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D5D1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                record.fullName,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_dateLabel(record.assessedAt)} · ${record.assessmentCode}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _detailSection(
                'สรุปผล',
                Icons.insights_rounded,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _diseaseLabel(
                        record.summary['disease_code'] as String?,
                        record.summary['disease_name'] as String?,
                      ),
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (record.summary['risk_level'] != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${record.summary['risk_level']} · '
                        'คะแนน CF '
                        '${(((record.summary['final_cf'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _riskColor(
                            record.summary['risk_level'] as String?,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (record.summary['recommendation'] != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        record.summary['recommendation'] as String,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NormalComparisonChart(
                measurements: {
                  for (final entry in record.factors.entries)
                    if (entry.value is num)
                      entry.key: (entry.value as num).toDouble(),
                },
                age: record.age,
              ),
              const SizedBox(height: 12),
              _detailSection(
                'ผลแยกรายโรค',
                Icons.favorite_border_rounded,
                Column(
                  children: record.results.map(_buildDiseaseRow).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _detailSection(
                'ข้อมูลที่ใช้ประเมิน',
                Icons.fact_check_outlined,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: record.factors.entries
                      .where((entry) => entry.value != null)
                      .map((entry) {
                    final value = entry.value == 1
                        ? 'มี'
                        : entry.value == 0
                            ? 'ไม่มี'
                            : entry.key == 'GENDER'
                                ? (entry.value == 'Male' ? 'ชาย' : 'หญิง')
                                : entry.value.toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0ED),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        '${_factorLabels[entry.key] ?? entry.key}: $value',
                        style: const TextStyle(color: _ink, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ผลนี้เป็นการคัดกรองจากข้อมูลและกฎในระบบ ไม่ใช่การวินิจฉัยโรค',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _green),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _buildDiseaseRow(Map<String, dynamic> result) {
    final riskLevel = result['risk_level'] as String?;
    final riskColor = _riskColor(riskLevel);
    final score = ((result['final_cf'] as num?)?.toDouble() ?? 0) * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result['is_positive'] == true
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: riskColor,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _diseaseLabel(
                    result['disease_code'] as String?,
                    result['disease_name'] as String?,
                  ),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  result['diagnosis'] as String? ?? 'ไม่มีรายละเอียด',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${score.toStringAsFixed(1)}%',
            style: TextStyle(
              color: riskColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
