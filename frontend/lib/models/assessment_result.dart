class MatchedRuleResult {
  final String ruleCode;
  final double support;
  final double confidence;
  final double cf;

  const MatchedRuleResult({
    required this.ruleCode,
    required this.support,
    required this.confidence,
    required this.cf,
  });

  factory MatchedRuleResult.fromJson(Map<String, dynamic> json) {
    return MatchedRuleResult(
      ruleCode: json['rule_code'] as String,
      support: (json['support'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      cf: (json['cf'] as num).toDouble(),
    );
  }
}

class AssessmentSummary {
  final int? diseaseId;
  final String? diseaseCode;
  final String? diseaseName;
  final String? riskLevel;
  final double finalCf;
  final String recommendation;

  const AssessmentSummary({
    required this.diseaseId,
    required this.diseaseCode,
    required this.diseaseName,
    required this.riskLevel,
    required this.finalCf,
    required this.recommendation,
  });

  factory AssessmentSummary.fromJson(Map<String, dynamic> json) {
    return AssessmentSummary(
      diseaseId: json['disease_id'] as int?,
      diseaseCode: json['disease_code'] as String?,
      diseaseName: json['disease_name'] as String?,
      riskLevel: json['risk_level'] as String?,
      finalCf: (json['final_cf'] as num).toDouble(),
      recommendation: json['recommendation'] as String,
    );
  }
}

class PatientRecord {
  final int patientId;
  final String patientCode;
  final String firstName;
  final String lastName;
  final String gender;
  final String? phone;
  final DateTime? birthDate;
  final int age;

  const PatientRecord({
    required this.patientId,
    required this.patientCode,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.phone,
    required this.birthDate,
    required this.age,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    return PatientRecord(
      patientId: json['patient_id'] as int,
      patientCode: json['patient_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String,
      phone: json['phone'] as String?,
      birthDate: DateTime.tryParse(json['birth_date'] as String? ?? ''),
      age: json['age'] as int,
    );
  }
}

class DiseaseAssessmentResult {
  final int diseaseId;
  final String diseaseCode;
  final String diseaseName;
  final bool isPositive;
  final List<MatchedRuleResult> matchedRules;
  final double finalCf;
  final String riskLevel;
  final String diagnosis;

  const DiseaseAssessmentResult({
    required this.diseaseId,
    required this.diseaseCode,
    required this.diseaseName,
    required this.isPositive,
    required this.matchedRules,
    required this.finalCf,
    required this.riskLevel,
    required this.diagnosis,
  });

  factory DiseaseAssessmentResult.fromJson(Map<String, dynamic> json) {
    return DiseaseAssessmentResult(
      diseaseId: json['disease_id'] as int,
      diseaseCode: json['disease_code'] as String,
      diseaseName: json['disease_name'] as String,
      isPositive: json['is_positive'] as bool,
      matchedRules: (json['matched_rules'] as List)
          .map(
            (rule) => MatchedRuleResult.fromJson(
              rule as Map<String, dynamic>,
            ),
          )
          .toList(),
      finalCf: (json['final_cf'] as num).toDouble(),
      riskLevel: json['risk_level'] as String,
      diagnosis: json['diagnosis'] as String,
    );
  }
}

class AssessmentResult {
  final int assessmentId;
  final PatientRecord patient;
  final AssessmentSummary summary;
  final List<DiseaseAssessmentResult> results;

  List<DiseaseAssessmentResult> get qualifyingResults => results
      .where((result) => result.isPositive)
      .toList(growable: false);

  const AssessmentResult({
    required this.assessmentId,
    required this.patient,
    required this.summary,
    required this.results,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    final patient = PatientRecord.fromJson(
      json['patient'] as Map<String, dynamic>,
    );
    return AssessmentResult(
      assessmentId: json['assessment_id'] as int? ?? patient.patientId,
      patient: patient,
      summary: AssessmentSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      results: (json['results'] as List)
          .map(
            (result) => DiseaseAssessmentResult.fromJson(
              result as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
