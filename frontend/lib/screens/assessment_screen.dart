import 'package:flutter/material.dart';

import '../models/assessment_options.dart';
import '../models/assessment_result.dart';
import '../widgets/normal_comparison_chart.dart';
import 'history_screen.dart';
import '../services/api_service.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  static const _green = Color(0xFFEF806F);
  static const _deepGreen = Color(0xFFB94F45);
  static const _mint = Color(0xFFFFE6E0);
  static const _ink = Color(0xFF352C2A);
  static const _muted = Color(0xFF837571);
  static const _line = Color(0xFFF0DEDA);
  static const _canvas = Color(0xFFFFF7F5);
  static const _factorLabels = {
    'AGE': 'อายุ',
    'GENDER': 'เพศ',
    'BMI': 'ดัชนีมวลกาย (BMI)',
    'GLUCOSE': 'ระดับน้ำตาลในเลือด',
    'SYSTOLIC_BP': 'ความดันโลหิตตัวบน',
    'DIASTOLIC_BP': 'ความดันโลหิตตัวล่าง',
    'CHOLESTEROL': 'ระดับคอเลสเตอรอล',
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
  static const _diseaseLabels = {
    'DIABETES': 'โรคเบาหวาน',
    'HYPERTENSION': 'โรคความดันโลหิตสูง',
    'HEART_DISEASE': 'โรคหัวใจ',
  };

  final _patientFormKey = GlobalKey<FormState>();
  final _assessmentFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _factorValues = {};
  Map<String, double> _submittedMeasurements = const {};
  AssessmentOptions? _options;
  bool _isLoadingOptions = true;
  String? _optionsError;
  bool _isLoading = false;
  String? _errorMessage;
  AssessmentResult? _result;
  int _formResetCount = 0;
  int _selectedTab = 0;
  int _assessmentStep = 0;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _optionsError = null;
    });

    try {
      final options = await ApiService.getAssessmentOptions();
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers
        ..clear()
        ..addEntries(
          options.factors.where((factor) => factor.dataType == 'numeric').map(
                (factor) => MapEntry(
                  factor.code,
                  TextEditingController(),
                ),
              ),
        );
      setState(() {
        _options = options;
        _isLoadingOptions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _optionsError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingOptions = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_assessmentFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final submittedFactors = <String, dynamic>{
        for (final factor in _options!.factors)
          if (factor.dataType == 'numeric' &&
              factor.code != 'AGE' &&
              _controllers[factor.code]!.text.trim().isNotEmpty)
            factor.code: factor.code == 'BMI'
                ? double.parse(_controllers[factor.code]!.text)
                : int.parse(_controllers[factor.code]!.text),
        ..._factorValues,
      };
      final submittedMeasurements = <String, double>{
        for (final entry in submittedFactors.entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      };
      final result = await ApiService.assessRisk(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        birthDate: _birthDate!,
        phone: _phoneController.text.trim(),
        factors: submittedFactors,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _submittedMeasurements = submittedMeasurements;
        _assessmentStep = 2;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() =>
          _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reset() {
    _patientFormKey.currentState?.reset();
    _assessmentFormKey.currentState?.reset();
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
    _birthDateController.clear();
    _heightController.clear();
    _weightController.clear();
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _formResetCount++;
      _factorValues.clear();
      _birthDate = null;
      _result = null;
      _submittedMeasurements = const {};
      _errorMessage = null;
      _assessmentStep = 0;
    });
  }

  void _continueToAssessment() {
    if (!_patientFormKey.currentState!.validate()) return;
    setState(() {
      _assessmentStep = 1;
      _errorMessage = null;
    });
  }

  int? _calculatedAge() {
    final birthDate = _birthDate;
    if (birthDate == null) return null;
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  double? _calculatedBmi() {
    final heightCm = double.tryParse(_heightController.text.trim());
    final weightKg = double.tryParse(_weightController.text.trim());
    if (heightCm == null ||
        weightKg == null ||
        heightCm <= 0 ||
        weightKg <= 0) {
      return null;
    }
    return weightKg / ((heightCm / 100) * (heightCm / 100));
  }

  void _updateBmi() {
    final bmi = _calculatedBmi();
    final bmiController = _controllers['BMI'];
    if (bmiController != null) {
      bmiController.text = bmi?.toStringAsFixed(2) ?? '';
    }
    setState(() {});
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(today.year - 30, today.month, today.day),
      firstDate: DateTime(today.year - 120, today.month, today.day),
      lastDate: today,
      helpText: 'เลือกวันเดือนปีเกิด',
      cancelText: 'ยกเลิก',
      confirmText: 'เลือก',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _deepGreen,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate = DateTime(picked.year, picked.month, picked.day);
      _birthDateController.text = _formatDate(picked);
    });
  }

  String _factorLabel(RiskFactor factor) =>
      _factorLabels[factor.code] ?? factor.name;

  String _diseaseLabel(String code, String name) =>
      _diseaseLabels[code] ?? name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1000;
            if (!isDesktop) return _buildPageContent();
            return Row(
              children: [
                SizedBox(width: 232, child: _buildSidebar()),
                Expanded(child: _buildPageContent()),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 1000
          ? null
          : NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (index) {
                setState(() => _selectedTab = index);
              },
              backgroundColor: Colors.white,
              indicatorColor: _mint,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.health_and_safety_outlined),
                  selectedIcon: Icon(Icons.health_and_safety_rounded),
                  label: 'ประเมิน',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'ประวัติ',
                ),
              ],
            ),
    );
  }

  Widget _buildPageContent() {
    if (_selectedTab == 1) return const HistoryScreen();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_canvas, Color(0xFFFFEBE7)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = switch (constraints.maxWidth) {
            >= 1200 => 40.0,
            >= 600 => 28.0,
            _ => 16.0,
          };

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: constraints.maxWidth >= 600 ? 32 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildProgress(),
                    const SizedBox(height: 18),
                    if (_assessmentStep == 0)
                      _buildPatientStep()
                    else if (_assessmentStep == 1)
                      _buildAssessmentStep()
                    else
                      _buildResultPanel(),
                    const SizedBox(height: 18),
                    _buildDisclaimer(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 26, 14, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF99A89), Color(0xFFEF806F), Color(0xFFE96F60)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 8, 30),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'สุขภาพดี',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _sidebarItem(0, Icons.dashboard_rounded, 'ประเมินสุขภาพ'),
          const SizedBox(height: 8),
          _sidebarItem(1, Icons.history_rounded, 'ประวัติการประเมิน'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'ดูแลสุขภาพ เริ่มต้นจากการรู้เท่าทันความเสี่ยง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    final selected = _selectedTab == index;
    return Material(
      color: selected ? _deepGreen.withValues(alpha: 0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedTab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_green, _deepGreen],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -40,
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 190,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: Color(0xFFFFD3C9), size: 15),
                    SizedBox(width: 7),
                    Text(
                      'ประเมินความเสี่ยงสุขภาพ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                switch (_assessmentStep) {
                  0 => 'เริ่มต้นด้วยข้อมูลผู้ป่วย',
                  1 => 'กรอกข้อมูลเพื่อประเมินสุขภาพ',
                  _ => 'ผลการประเมินสุขภาพ',
                },
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_assessmentStep) {
                  0 => 'กรอกข้อมูลพื้นฐานก่อนเริ่มแบบประเมิน',
                  1 => 'ประเมินปัจจัยสุขภาพเบื้องต้น พร้อมกัน 3 โรค',
                  _ => 'สรุปผลคัดกรองจากข้อมูลที่คุณกรอก',
                },
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderDiseasePill(
                    icon: Icons.water_drop_rounded,
                    label: 'เบาหวาน',
                  ),
                  _HeaderDiseasePill(
                    icon: Icons.speed_rounded,
                    label: 'ความดันโลหิตสูง',
                  ),
                  _HeaderDiseasePill(
                    icon: Icons.monitor_heart_rounded,
                    label: 'โรคหัวใจ',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    const steps = [
      ('ข้อมูลผู้ป่วย', Icons.badge_outlined),
      ('แบบประเมิน', Icons.fact_check_outlined),
      ('ผลประเมิน', Icons.insights_outlined),
    ];
    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          if (index > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: index <= _assessmentStep ? _green : _line,
              ),
            ),
          _ProgressStep(
            label: steps[index].$1,
            icon: steps[index].$2,
            active: index == _assessmentStep,
            complete: index < _assessmentStep,
          ),
        ],
      ],
    );
  }

  Widget _buildPatientStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('ข้อมูลผู้ป่วย', '01'),
          const SizedBox(height: 8),
          const Text(
            'กรอกข้อมูลพื้นฐานก่อนเริ่มทำแบบประเมิน ระบบจะบันทึกข้อมูลนี้ '
            'เพื่อเชื่อมกับผลย้อนหลัง',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 22),
          Form(
            key: _patientFormKey,
            child: _buildPatientFields(),
          ),
          if (_isLoadingOptions)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            )
          else if (_optionsError != null) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildErrorMessage(_optionsError!),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadOptions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('โหลดข้อมูลจากฐานข้อมูลอีกครั้ง'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isLoadingOptions || _options == null
                  ? null
                  : _continueToAssessment,
              style: FilledButton.styleFrom(
                backgroundColor: _deepGreen,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: _green.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ไปยังแบบประเมิน'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentStep() {
    final patientName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    final genderLabel = _factorValues['GENDER'] == 'Male' ? 'ชาย' : 'หญิง';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _assessmentFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _sectionHeading('แบบประเมินสุขภาพ', '02')),
                TextButton.icon(
                  onPressed: () => setState(() => _assessmentStep = 0),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('ข้อมูลผู้ป่วย'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _mint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _green.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: _green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ผู้ทำแบบประเมิน',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patientName,
                          style: const TextStyle(
                            color: _deepGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _patientDetailChip(
                              Icons.wc_outlined,
                              'เพศ: $genderLabel',
                            ),
                            _patientDetailChip(
                              Icons.cake_outlined,
                              'อายุ: ${_calculatedAge()} ปี',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'กรอกปัจจัยที่ทราบ ไม่จำเป็นต้องตอบทุกข้อ '
              'ข้อมูลที่เว้นไว้จะไม่นำไปจับคู่กฎ',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            if (_isLoadingOptions)
              const Center(child: CircularProgressIndicator())
            else if (_optionsError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildErrorMessage(_optionsError!),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadOptions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('โหลดข้อมูลจากฐานข้อมูลอีกครั้ง'),
                  ),
                ],
              )
            else
              _buildFactorSections(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              _buildErrorMessage(_errorMessage!),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading || _isLoadingOptions || _options == null
                    ? null
                    : _submit,
                icon: _isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.monitor_heart_outlined),
                label: Text(
                  _isLoading ? 'กำลังประเมิน...' : 'ประเมินและดูผล',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _deepGreen,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: _green.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _green),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _deepGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: _green),
              SizedBox(width: 8),
              Text(
                'ข้อมูลผู้ป่วย',
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'ระบบจะสร้างรหัสผู้ป่วยให้อัตโนมัติ',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 480;
              final fieldWidth = isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      validator: _requiredNameValidator,
                      decoration: _inputDecoration(label: 'ชื่อ'),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      validator: _requiredNameValidator,
                      decoration: _inputDecoration(label: 'นามสกุล'),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('patient-gender-$_formResetCount'),
                      initialValue: _factorValues['GENDER'] as String?,
                      validator: (value) =>
                          value == null ? 'กรุณาเลือกเพศ' : null,
                      decoration: _inputDecoration(label: 'เพศ'),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('ชาย')),
                        DropdownMenuItem(value: 'Female', child: Text('หญิง')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          if (value == null) {
                            _factorValues.remove('GENDER');
                          } else {
                            _factorValues['GENDER'] = value;
                          }
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                      decoration: _inputDecoration(
                        label: 'เบอร์โทรศัพท์',
                        suffix: null,
                      ).copyWith(
                        prefixIcon: const Icon(Icons.phone_outlined, size: 19),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _selectBirthDate,
                      validator: (value) {
                        if (_birthDate == null) {
                          return 'กรุณาเลือกวันเดือนปีเกิด';
                        }
                        final age = _calculatedAge()!;
                        if (age < 1) return 'ผู้ป่วยต้องมีอายุอย่างน้อย 1 ปี';
                        if (age > 120) return 'อายุต้องไม่เกิน 120 ปี';
                        return null;
                      },
                      decoration: _inputDecoration(
                        label: 'วันเดือนปีเกิด',
                      ).copyWith(
                        hintText: 'วัน / เดือน / ปี',
                        suffixIcon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: InputDecorator(
                      decoration: _inputDecoration(label: 'อายุ').copyWith(
                        suffixText: 'ปี',
                      ),
                      child: Text(
                        _calculatedAge()?.toString() ?? 'เลือกวันเกิดก่อน',
                        style: TextStyle(
                          color: _calculatedAge() == null ? _muted : _ink,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      key: const ValueKey('patient-height'),
                      controller: _heightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _updateBmi(),
                      validator: _validateHeight,
                      decoration: _inputDecoration(
                        label: 'ส่วนสูง',
                        suffix: 'ซม.',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      key: const ValueKey('patient-weight'),
                      controller: _weightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _updateBmi(),
                      validator: _validateWeight,
                      decoration: _inputDecoration(
                        label: 'น้ำหนัก',
                        suffix: 'กก.',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: InputDecorator(
                      key: const ValueKey('calculated-bmi'),
                      decoration: _inputDecoration(
                        label: 'ดัชนีมวลกาย (BMI)',
                      ).copyWith(suffixText: 'kg/m²'),
                      child: Text(
                        _calculatedBmi()?.toStringAsFixed(2) ??
                            'กรอกส่วนสูงและน้ำหนัก',
                        style: TextStyle(
                          color: _calculatedBmi() == null ? _muted : _ink,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
    if (digits.length < 9 || digits.length > 15) {
      return 'กรุณากรอกเบอร์โทรศัพท์ 9–15 หลัก';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'กรุณากรอกส่วนสูง';
    final height = double.tryParse(text);
    if (height == null || !height.isFinite) return 'กรอกส่วนสูงเป็นตัวเลข';
    if (height < 50 || height > 250) {
      return 'ส่วนสูงต้องอยู่ระหว่าง 50–250 ซม.';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'กรุณากรอกน้ำหนัก';
    final weight = double.tryParse(text);
    if (weight == null || !weight.isFinite) return 'กรอกน้ำหนักเป็นตัวเลข';
    if (weight < 1 || weight > 500) {
      return 'น้ำหนักต้องอยู่ระหว่าง 1–500 กก.';
    }
    return null;
  }

  String? _requiredNameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกข้อมูลนี้';
    }
    if (value.trim().length > 100) {
      return 'กรอกได้ไม่เกิน 100 ตัวอักษร';
    }
    return null;
  }

  Widget _buildFactorField(RiskFactor factor) {
    if (factor.dataType == 'numeric') {
      final required = factor.code == 'AGE' || factor.code == 'BMI';
      final isInteger = factor.code != 'BMI';
      return TextFormField(
        controller: _controllers[factor.code],
        keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
        validator: (value) => _validateNumericFactor(
          factor.code,
          value,
          required: required,
          integer: isInteger,
        ),
        decoration: _inputDecoration(
          label: _factorLabel(factor),
          suffix: _factorSuffix(factor.code),
        ),
      );
    }

    if (factor.dataType == 'boolean') {
      return DropdownButtonFormField<int>(
        key: ValueKey('${factor.code}-$_formResetCount'),
        initialValue: _factorValues[factor.code] as int?,
        decoration: _inputDecoration(label: _factorLabel(factor)),
        items: const [
          DropdownMenuItem(value: 1, child: Text('มี')),
          DropdownMenuItem(value: 0, child: Text('ไม่มี')),
        ],
        onChanged: (value) {
          setState(() {
            if (value == null) {
              _factorValues.remove(factor.code);
            } else {
              _factorValues[factor.code] = value;
            }
          });
        },
      );
    }

    return TextFormField(
      initialValue: _factorValues[factor.code] as String?,
      decoration: _inputDecoration(label: _factorLabel(factor)),
      onChanged: (value) => _factorValues[factor.code] = value,
    );
  }

  Widget _buildFactorSections() {
    const sections = <(String, IconData, Set<String>)>[
      (
        'ระดับน้ำตาลและอาการที่เกี่ยวข้อง',
        Icons.water_drop_outlined,
        {
          'GLUCOSE',
          'FATIGUE',
          'BLURRED_VISION',
          'FREQUENT_URINATION',
          'EXCESSIVE_THIRST',
          'NAUSEA',
        },
      ),
      (
        'ความดันโลหิตและอาการ',
        Icons.monitor_heart_outlined,
        {'SYSTOLIC_BP', 'DIASTOLIC_BP', 'HEADACHE', 'DIZZINESS'},
      ),
      (
        'ไขมันและสุขภาพหัวใจ',
        Icons.favorite_border_rounded,
        {
          'CHOLESTEROL',
          'CHEST_PAIN',
          'SHORTNESS_OF_BREATH',
          'PALPITATIONS',
        },
      ),
    ];

    final remaining = _options!.factors
        .map((factor) => factor.code)
        .where((code) => code != 'GENDER' && code != 'AGE' && code != 'BMI')
        .toSet();
    final children = <Widget>[];

    for (final (title, icon, codes) in sections) {
      final factors = _options!.factors
          .where((factor) => codes.contains(factor.code))
          .toList();
      remaining.removeAll(codes);
      if (factors.isEmpty) continue;
      children
        ..add(_buildFactorGroup(title, icon, factors))
        ..add(const SizedBox(height: 22));
    }

    final otherFactors = _options!.factors
        .where((factor) => remaining.contains(factor.code))
        .toList();
    if (otherFactors.isNotEmpty) {
      children.add(
        _buildFactorGroup(
          'ปัจจัยเพิ่มเติม',
          Icons.add_circle_outline_rounded,
          otherFactors,
        ),
      );
    } else if (children.isNotEmpty) {
      children.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildFactorGroup(
    String title,
    IconData icon,
    List<RiskFactor> factors,
  ) {
    return Column(
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680
                ? 3
                : constraints.maxWidth >= 430
                    ? 2
                    : 1;
            const spacing = 12.0;
            final fieldWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: 14,
              children: factors
                  .map(
                    (factor) => SizedBox(
                      width: fieldWidth,
                      child: _buildFactorField(factor),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  String? _factorSuffix(String code) {
    return switch (code) {
      'AGE' => 'ปี',
      'BMI' => 'kg/m²',
      'GLUCOSE' || 'CHOLESTEROL' => 'mg/dL',
      'SYSTOLIC_BP' || 'DIASTOLIC_BP' => 'mmHg',
      _ => null,
    };
  }

  String? _validateNumericFactor(
    String code,
    String? rawValue, {
    required bool required,
    required bool integer,
  }) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      return required ? 'กรุณากรอกข้อมูลนี้' : null;
    }

    final number = double.tryParse(value);
    if (number == null || !number.isFinite) {
      return 'กรอกตัวเลขให้ถูกต้อง';
    }
    if (number <= 0) return 'กรอกตัวเลขที่มากกว่า 0';
    if (integer && number != number.truncateToDouble()) {
      return 'กรอกจำนวนเต็ม';
    }
    if (code == 'AGE' && number > 120) return 'กรอกอายุไม่เกิน 120 ปี';
    return null;
  }

  Widget _buildResultPanel() {
    final result = _result;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: result == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading('ผลการประเมิน', '02'),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBFA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line.withValues(alpha: 0.75)),
                  ),
                  child: const Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _mint,
                        child: Icon(
                          Icons.fact_check_outlined,
                          size: 28,
                          color: _green,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'พร้อมประเมินสุขภาพ',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'กรอกข้อมูลด้านซ้าย แล้วกดปุ่มประเมิน\\nเพื่อดูผลความเสี่ยงรายโรค',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _sectionHeading('ผลการประเมิน', '03')),
                    IconButton(
                      tooltip: 'เริ่มประเมินใหม่',
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'เลขที่การประเมิน ${result.assessmentId}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  '${result.patient.firstName} ${result.patient.lastName} · '
                  'รหัส ${result.patient.patientCode}',
                  style: const TextStyle(
                    color: _deepGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _buildAssessmentSummary(result.summary),
                const SizedBox(height: 16),
                NormalComparisonChart(
                  measurements: _submittedMeasurements,
                  age: result.patient.age,
                ),
                if (result.qualifyingResults.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeading('โรคที่เข้าข่ายตามกฎ', '03'),
                  const SizedBox(height: 14),
                  ...result.qualifyingResults.map(_buildDiseaseResult),
                ] else ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _line),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, color: _green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ไม่พบโรคที่เข้าข่ายตามกฎจากข้อมูลที่กรอก '
                            'หากมีอาการหรือกังวล ควรปรึกษาบุคลากรทางการแพทย์',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 480;
                    final buttons = [
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _assessmentStep = 1;
                          _errorMessage = null;
                        }),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('แก้ไขแบบประเมิน'),
                      ),
                      FilledButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('ประเมินใหม่'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _deepGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ];
                    if (!isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buttons[0],
                          const SizedBox(height: 8),
                          buttons[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: buttons[0]),
                        const SizedBox(width: 12),
                        Expanded(child: buttons[1]),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildAssessmentSummary(AssessmentSummary summary) {
    final hasMostLikelyDisease = summary.diseaseName != null;
    final riskColor = switch (summary.riskLevel) {
      'ระดับสูง' => const Color(0xFFB64435),
      'ระดับปานกลาง' => const Color(0xFFAA6B16),
      _ => const Color(0xFF4F8C70),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9E4), Color(0xFFFFFBFA)],
        ),
        border: Border.all(color: const Color(0xFFF3D6D0)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _green, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'สรุปผลการประเมิน',
                  style: TextStyle(
                    color: _deepGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasMostLikelyDisease)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    summary.riskLevel!,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 14),
          if (hasMostLikelyDisease) ...[
            const Text(
              'โรคที่เข้าข่ายตามผลคัดกรอง',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _diseaseLabel(summary.diseaseCode!, summary.diseaseName!),
              style: const TextStyle(
                color: _deepGreen,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: riskColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      color: riskColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ค่า CF',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        summary.finalCf.toStringAsFixed(3),
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 31,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${(summary.finalCf * 100).toStringAsFixed(1)}% จาก 1.000',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'CF เป็นคะแนนความเชื่อมั่นของกฎที่ตรง ไม่ใช่เปอร์เซ็นต์โอกาสป่วย',
              style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
            ),
          ] else
            const Text(
              'ผลคัดกรอง: ไม่พบโรคที่เข้าข่ายจากข้อมูลที่กรอก',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFAA6B16),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'คำแนะนำ',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.recommendation,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'เป็นผลคัดกรองจากกฎและข้อมูลที่กรอก ไม่ใช่การวินิจฉัยหรือเปอร์เซ็นต์โอกาสป่วย',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseResult(DiseaseAssessmentResult result) {
    final riskColor = switch (result.riskLevel) {
      'ระดับสูง' => const Color(0xFFB64435),
      'ระดับปานกลาง' => const Color(0xFFAA6B16),
      _ => const Color(0xFF4F8C70),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _diseaseLabel(result.diseaseCode, result.diseaseName),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  result.isPositive ? 'เข้าข่าย' : 'ไม่เข้าข่าย',
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.isPositive
                ? 'พบกฎที่ตรงกับข้อมูล ${result.matchedRules.length} ข้อ'
                : 'ไม่พบกฎที่ตรงกับข้อมูลที่กรอก',
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.diagnosis,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ค่า CF ของกฎที่ตรง (0–1)',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${result.finalCf.toStringAsFixed(3)} / 1.000',
                style: const TextStyle(
                  color: _deepGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${(result.finalCf * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: result.finalCf.clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: riskColor,
            backgroundColor: const Color(0xFFFFECE8),
          ),
          const SizedBox(height: 7),
          Text(
            result.isPositive
                ? 'CF คือคะแนนความเชื่อมั่นของกฎที่ตรง ไม่ใช่เปอร์เซ็นต์โอกาสป่วย'
                : 'ไม่มีเงื่อนไขที่ตรงกับกฎ ค่า CF จึงเป็น 0.000',
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
          ),
          const SizedBox(height: 14),
          Text(
            'กฎที่ตรงกัน (${result.matchedRules.length})',
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Support = สัดส่วนข้อมูลที่ตรงกับกฎ · '
            'Confidence = สัดส่วนผลลัพธ์ตามกฎเมื่อเงื่อนไขตรง',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.5),
          ),
          if (result.matchedRules.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'ไม่พบกฎที่ตรงกับข้อมูลที่กรอก',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            )
          else
            ...result.matchedRules.map(
              (rule) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line.withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 15, color: _green),
                        const SizedBox(width: 7),
                        Text(
                          rule.ruleCode,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _buildRuleMetric(
                          'Support',
                          rule.support,
                          'ความถี่ของกฎในชุดข้อมูล',
                        ),
                        _buildRuleMetric(
                          'Confidence',
                          rule.confidence,
                          'สัดส่วนผลลัพธ์ตามกฎในชุดข้อมูล',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRuleMetric(String label, double value, String description) {
    return Tooltip(
      message: description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line.withValues(alpha: 0.8)),
        ),
        child: Text(
          '$label ${(value * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line.withValues(alpha: 0.7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: _green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ผลประเมินนี้เป็นข้อมูลคัดกรองเบื้องต้น ไม่ใช่การวินิจฉัยทางการแพทย์ '
              'หากกังวลเรื่องสุขภาพ ควรปรึกษาบุคลากรทางการแพทย์',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String index) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _mint,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? label, String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: const TextStyle(color: _muted, fontSize: 13),
      suffixStyle: const TextStyle(color: _muted, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFFFFBFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: _line.withValues(alpha: 0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _green, width: 1.6),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'เชื่อมต่อหรือประเมินไม่สำเร็จ: $message',
        style: const TextStyle(color: Color(0xFF9B352B), fontSize: 13),
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.icon,
    required this.active,
    required this.complete,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color =
        active || complete ? const Color(0xFFEF806F) : const Color(0xFFAA9995);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active || complete ? const Color(0xFFEF806F) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: active || complete
                  ? const Color(0xFFEF806F)
                  : const Color(0xFFF0DEDA),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFEF806F).withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            complete ? Icons.check_rounded : icon,
            color: active || complete ? Colors.white : color,
            size: 19,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFB94F45) : color,
            fontSize: 10,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeaderDiseasePill extends StatelessWidget {
  const _HeaderDiseasePill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFFFD8D0)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
