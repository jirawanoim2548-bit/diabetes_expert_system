class AssessmentHistoryRecord {
  final int assessmentId;
  final String assessmentCode;
  final String patientCode;
  final String fullName;
  final String gender;
  final String? phone;
  final DateTime? birthDate;
  final int? age;
  final DateTime? assessedAt;
  final Map<String, dynamic> factors;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> results;

  const AssessmentHistoryRecord({
    required this.assessmentId,
    required this.assessmentCode,
    required this.patientCode,
    required this.fullName,
    required this.gender,
    required this.phone,
    required this.birthDate,
    required this.age,
    required this.assessedAt,
    required this.factors,
    required this.summary,
    required this.results,
  });

  factory AssessmentHistoryRecord.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>;
    return AssessmentHistoryRecord(
      assessmentId: json['assessment_id'] as int,
      assessmentCode: json['assessment_code'] as String,
      patientCode: patient['patient_code'] as String,
      fullName: patient['full_name'] as String,
      gender: patient['gender'] as String? ?? '',
      phone: patient['phone'] as String?,
      birthDate: DateTime.tryParse(patient['birth_date'] as String? ?? ''),
      age: patient['age'] as int?,
      assessedAt: DateTime.tryParse(json['assessed_at'] as String? ?? ''),
      factors: Map<String, dynamic>.from(
        json['factors'] as Map<String, dynamic>? ?? const {},
      ),
      summary: Map<String, dynamic>.from(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      results: (json['results'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
    );
  }
}
