import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diabetes_expert_system/main.dart';
import 'package:diabetes_expert_system/models/assessment_result.dart';
import 'package:diabetes_expert_system/widgets/normal_comparison_chart.dart';

void main() {
  test('parses patient details returned by the assessment API', () {
    final result = AssessmentResult.fromJson({
      'patient': {
        'patient_id': 4,
        'patient_code': 'HN0001',
        'first_name': 'Ada',
        'last_name': 'Example',
        'gender': 'Female',
        'phone': '0812345678',
        'birth_date': '1980-01-01',
        'age': 45,
      },
      'summary': {
        'disease_id': null,
        'disease_code': null,
        'disease_name': null,
        'risk_level': null,
        'final_cf': 0,
        'recommendation': 'ปรึกษาบุคลากรทางการแพทย์',
      },
      'results': [],
    });

    expect(result.patient.patientCode, 'HN0001');
    expect(result.assessmentId, result.patient.patientId);
    expect(result.patient.firstName, 'Ada');
    expect(result.patient.gender, 'Female');
    expect(result.patient.phone, '0812345678');
    expect(result.patient.birthDate, DateTime(1980, 1, 1));
  });

  test('shows only diseases with at least one matched rule', () {
    final result = AssessmentResult.fromJson({
      'patient': {
        'patient_id': 4,
        'patient_code': 'HN0001',
        'first_name': 'Ada',
        'last_name': 'Example',
        'gender': 'Female',
        'age': 45,
      },
      'summary': {
        'disease_id': 1,
        'disease_code': 'DIABETES',
        'disease_name': 'Diabetes',
        'risk_level': 'ระดับสูง',
        'final_cf': 0.4,
        'recommendation': 'ตรวจน้ำตาลในเลือด',
      },
      'results': [
        {
          'disease_id': 1,
          'disease_code': 'DIABETES',
          'disease_name': 'Diabetes',
          'is_positive': true,
          'matched_rules': [
            {
              'rule_code': 'D01',
              'support': 0.5,
              'confidence': 0.8,
              'cf': 0.4,
            },
          ],
          'final_cf': 0.4,
          'risk_level': 'ระดับสูง',
          'diagnosis': 'พบปัจจัยเสี่ยง',
        },
        {
          'disease_id': 2,
          'disease_code': 'HYPERTENSION',
          'disease_name': 'Hypertension',
          'is_positive': false,
          'matched_rules': [],
          'final_cf': 0,
          'risk_level': 'ระดับต่ำ',
          'diagnosis': 'ไม่พบกฎที่ตรง',
        },
      ],
    });

    expect(
      result.qualifyingResults.map((disease) => disease.diseaseName),
      ['Diabetes'],
    );
    expect(
      result.qualifyingResults.map((disease) => disease.finalCf),
      [0.4],
    );
    expect(
      result.qualifyingResults.every((disease) => disease.isPositive),
      isTrue,
    );

    final noMatches = AssessmentResult.fromJson({
      'patient': {
        'patient_id': 4,
        'patient_code': 'HN0001',
        'first_name': 'Ada',
        'last_name': 'Example',
        'gender': 'Female',
        'age': 45,
      },
      'summary': {
        'disease_id': null,
        'disease_code': null,
        'disease_name': null,
        'risk_level': null,
        'final_cf': 0,
        'recommendation': 'ดูแลสุขภาพ',
      },
      'results': [
        {
          'disease_id': 2,
          'disease_code': 'HYPERTENSION',
          'disease_name': 'Hypertension',
          'is_positive': false,
          'matched_rules': [],
          'final_cf': 0,
          'risk_level': 'ระดับต่ำ',
          'diagnosis': 'ไม่พบกฎที่ตรง',
        },
      ],
    });

    expect(noMatches.qualifyingResults, isEmpty);
  });

  testWidgets('plots measured values against adult reference thresholds',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NormalComparisonChart(
              age: 45,
              measurements: {
                'BMI': 27,
                'GLUCOSE': 110,
                'SYSTOLIC_BP': 130,
                'DIASTOLIC_BP': 85,
                'CHOLESTEROL': 190,
                'AGE': 45,
              },
            ),
          ),
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('normal-comparison-chart')), findsOneWidget);
    expect(find.text('ค่าที่วัดได้เทียบเกณฑ์อ้างอิง'), findsOneWidget);
    expect(find.textContaining('น้ำตาล · 70–99* mg/dL'), findsOneWidget);
    expect(find.text('ความดันบน · <120 mmHg'), findsOneWidget);
    expect(find.text('27 kg/m²'), findsOneWidget);
    expect(find.text('สูงกว่าเกณฑ์อ้างอิง'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the database-driven risk assessment screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DiabetesExpertSystemApp());

    expect(find.text('เริ่มต้นด้วยข้อมูลผู้ป่วย'), findsOneWidget);
    expect(find.text('ข้อมูลผู้ป่วย'), findsWidgets);
    expect(find.text('เบอร์โทรศัพท์'), findsOneWidget);
    expect(find.text('วันเดือนปีเกิด'), findsOneWidget);
    expect(find.textContaining('อายุที่คำนวณได้'), findsNothing);
    expect(find.text('ส่วนสูง'), findsOneWidget);
    expect(find.text('น้ำหนัก'), findsOneWidget);
    expect(find.text('ดัชนีมวลกาย (BMI)'), findsOneWidget);
    expect(find.text('ไปยังแบบประเมิน'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('patient-height')),
      '170',
    );
    await tester.enterText(
      find.byKey(const ValueKey('patient-weight')),
      '65',
    );
    await tester.pump();

    expect(find.text('22.49'), findsOneWidget);
  });

  testWidgets('shows dashboard sidebar on wide layouts',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DiabetesExpertSystemApp());

    expect(find.text('สุขภาพดี'), findsOneWidget);
    expect(find.text('ประเมินสุขภาพ'), findsOneWidget);
    expect(find.text('ประวัติการประเมิน'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
