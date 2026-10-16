import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/assessment_options.dart';
import '../models/assessment_history.dart';
import '../models/assessment_result.dart';

class ApiService {
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static Future<AssessmentOptions> getAssessmentOptions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/assessment/options'),
    );

    if (response.statusCode != 200) {
      throw Exception('Loading assessment options failed: ${response.body}');
    }

    return AssessmentOptions.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<List<AssessmentHistoryRecord>> getAssessmentHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/assessment/history'),
    );

    if (response.statusCode != 200) {
      throw Exception('Loading assessment history failed: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['history'] as List)
        .map(
          (item) => AssessmentHistoryRecord.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  static Future<AssessmentResult> assessRisk({
    required Map<String, dynamic> factors,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/assessment/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patient': {
          'first_name': firstName,
          'last_name': lastName,
          'birth_date': birthDate.toIso8601String().substring(0, 10),
          'phone': phone,
        },
        'factors': factors,
      }),
    );

    if (response.statusCode == 200) {
      return AssessmentResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Assessment failed: ${response.body}');
    }
  }
}
