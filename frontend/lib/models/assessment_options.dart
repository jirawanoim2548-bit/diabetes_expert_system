class RiskFactor {
  final int factorId;
  final String code;
  final String name;
  final String dataType;

  const RiskFactor({
    required this.factorId,
    required this.code,
    required this.name,
    required this.dataType,
  });

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      factorId: json['factor_id'] as int,
      code: json['factor_code'] as String,
      name: json['factor_name'] as String,
      dataType: json['data_type'] as String,
    );
  }
}

class DiseaseOption {
  final int diseaseId;
  final String code;
  final String name;

  const DiseaseOption({
    required this.diseaseId,
    required this.code,
    required this.name,
  });

  factory DiseaseOption.fromJson(Map<String, dynamic> json) {
    return DiseaseOption(
      diseaseId: json['disease_id'] as int,
      code: json['disease_code'] as String,
      name: json['disease_name'] as String,
    );
  }
}

class AssessmentOptions {
  final List<RiskFactor> factors;
  final List<DiseaseOption> diseases;

  const AssessmentOptions({
    required this.factors,
    required this.diseases,
  });

  factory AssessmentOptions.fromJson(Map<String, dynamic> json) {
    return AssessmentOptions(
      factors: (json['factors'] as List)
          .map((item) => RiskFactor.fromJson(item as Map<String, dynamic>))
          .toList(),
      diseases: (json['diseases'] as List)
          .map((item) => DiseaseOption.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
