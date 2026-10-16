import json
import math
import re

from app.database import get_connection


FACTOR_DEFINITIONS = (
    ("AGE", "Age", "numeric"),
    ("GENDER", "Gender", "categorical"),
    ("BMI", "BMI", "numeric"),
    ("GLUCOSE", "Glucose", "numeric"),
    ("SYSTOLIC_BP", "Systolic BP", "numeric"),
    ("DIASTOLIC_BP", "Diastolic BP", "numeric"),
    ("CHOLESTEROL", "Cholesterol", "numeric"),
    ("FATIGUE", "Fatigue", "boolean"),
    ("HEADACHE", "Headache", "boolean"),
    ("DIZZINESS", "Dizziness", "boolean"),
    ("CHEST_PAIN", "Chest Pain", "boolean"),
    ("SHORTNESS_OF_BREATH", "Shortness of Breath", "boolean"),
    ("NAUSEA", "Nausea", "boolean"),
    ("BLURRED_VISION", "Blurred Vision", "boolean"),
    ("FREQUENT_URINATION", "Frequent Urination", "boolean"),
    ("EXCESSIVE_THIRST", "Excessive Thirst", "boolean"),
    ("PALPITATIONS", "Palpitations", "boolean"),
)

RANGE_CONDITION = re.compile(
    r"^\s*(-?\d+(?:\.\d+)?)\s*<\s*([A-Za-z_][A-Za-z0-9_]*)"
    r"\s*<\s*(-?\d+(?:\.\d+)?)\s*$"
)
SIMPLE_CONDITION = re.compile(
    r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(>=|<=|==|=|>|<)\s*(.*?)\s*$"
)


def _factor_definitions_from_columns(columns):
    available_columns = {column.casefold() for column in columns}
    factors = []
    for factor_id, (code, name, data_type) in enumerate(FACTOR_DEFINITIONS, 1):
        if code.casefold() not in available_columns:
            continue
        factors.append({
            "factor_id": factor_id,
            "factor_code": code,
            "factor_name": name,
            "data_type": data_type,
        })
    return factors


def load_assessment_schema():
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)

    try:
        cursor.execute("""
            SELECT COLUMN_NAME AS column_name
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dataset_records'
            ORDER BY ORDINAL_POSITION
        """)
        columns = [row["column_name"] for row in cursor.fetchall()]
        factors = _factor_definitions_from_columns(columns)

        cursor.execute("""
            SELECT disease_id, disease_code, disease_name
            FROM diseases
            ORDER BY disease_id
        """)
        diseases = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

    if not factors:
        raise RuntimeError("The dataset_records table has no supported factors")
    if not diseases:
        raise RuntimeError("The diseases table is empty")
    return {"factors": factors, "diseases": diseases}


def _normalize_factors(submitted_factors, factor_definitions):
    definitions = {
        factor["factor_code"]: factor
        for factor in factor_definitions
    }
    unknown_factors = set(submitted_factors) - set(definitions)
    if unknown_factors:
        raise ValueError(
            f"Unknown risk factor(s): {', '.join(sorted(unknown_factors))}"
        )

    normalized = {}
    for code, raw_value in submitted_factors.items():
        if raw_value is None or raw_value == "":
            continue

        factor = definitions[code]
        if factor["data_type"] == "numeric":
            try:
                value = float(raw_value)
            except (TypeError, ValueError) as error:
                raise ValueError(f"{code} must be a number") from error

            if not math.isfinite(value):
                raise ValueError(f"{code} must be a finite number")
            if value <= 0:
                raise ValueError(f"{code} must be greater than 0")
            if code == "BMI":
                if value >= 1000:
                    raise ValueError("BMI must be less than 1000")
                normalized[code] = value
            else:
                if not value.is_integer():
                    raise ValueError(f"{code} must be a whole number")
                if code == "AGE" and not 1 <= value <= 120:
                    raise ValueError("AGE must be between 1 and 120")
                normalized[code] = int(value)
        elif factor["data_type"] == "boolean":
            if raw_value in (True, 1, "1"):
                normalized[code] = 1
            elif raw_value in (False, 0, "0"):
                normalized[code] = 0
            else:
                raise ValueError(f"{code} must be 0 or 1")
        elif factor["data_type"] == "categorical":
            value = str(raw_value).strip()
            if not value:
                continue
            if code == "GENDER":
                gender_options = {"male": "Male", "female": "Female"}
                if value.casefold() not in gender_options:
                    raise ValueError("GENDER must be Male or Female")
                value = gender_options[value.casefold()]
            normalized[code] = value
        else:
            raise RuntimeError(
                f"Unsupported data type for factor {code}: {factor['data_type']}"
            )

    if "AGE" not in normalized or "BMI" not in normalized:
        raise ValueError("AGE and BMI are required for assessment")
    if "GENDER" not in normalized:
        raise ValueError("GENDER is required for patient registration")
    return normalized


def _parse_condition(condition_text, factor_definition_by_code, rule_code):
    range_match = RANGE_CONDITION.match(condition_text)
    if range_match:
        lower, factor_code, upper = range_match.groups()
        condition = {
            "factor_code": factor_code.upper(),
            "operator": "range",
            "lower": float(lower),
            "upper": float(upper),
        }
    else:
        simple_match = SIMPLE_CONDITION.match(condition_text)
        if not simple_match:
            raise RuntimeError(
                f"Rule {rule_code} has an unsupported condition: {condition_text}"
            )
        factor_code, operator, condition_value = simple_match.groups()
        condition_value = condition_value.strip().strip("\"'")
        condition = {
            "factor_code": factor_code.upper(),
            "operator": operator,
            "condition_value": condition_value,
        }

    if condition["factor_code"] not in factor_definition_by_code:
        raise RuntimeError(
            f"Rule {rule_code} references an unknown factor: "
            f"{condition['factor_code']}"
        )
    return condition


def _condition_matches(condition, factors, factor_definitions):
    value = factors.get(condition["factor_code"])
    if value is None:
        return False

    if condition["operator"] == "range":
        try:
            numeric_value = float(value)
        except (TypeError, ValueError):
            return False
        return condition["lower"] < numeric_value < condition["upper"]

    operator = condition["operator"]
    factor_type = factor_definitions[condition["factor_code"]]["data_type"]
    if factor_type == "numeric" or (
        factor_type == "boolean" and operator != "="
    ):
        try:
            left = float(value)
            right = float(condition["condition_value"])
        except (TypeError, ValueError) as error:
            raise RuntimeError(
                f"Rule has a non-numeric value for {condition['factor_code']}"
            ) from error
    else:
        left = str(value).casefold()
        right = str(condition["condition_value"]).casefold()

    comparisons = {
        ">=": lambda: left >= right,
        "<=": lambda: left <= right,
        ">": lambda: left > right,
        "<": lambda: left < right,
        "=": lambda: left == right,
        "==": lambda: left == right,
    }
    if operator not in comparisons:
        raise RuntimeError(f"Unsupported rule operator in database: {operator}")
    return comparisons[operator]()


def _risk_level(final_cf):
    if final_cf >= 0.30:
        return "ระดับสูง"
    if final_cf >= 0.15:
        return "ระดับปานกลาง"
    return "ระดับต่ำ"


def _recommendation(disease_code, risk_level):
    if risk_level == "ระดับสูง":
        follow_up = "คะแนนคัดกรองอยู่ในระดับสูง ควรปรึกษาแพทย์เพื่อประเมินเพิ่มเติม"
    elif risk_level == "ระดับปานกลาง":
        follow_up = "ควรติดตามสุขภาพและปรึกษาแพทย์หากพบปัจจัยเสี่ยงต่อเนื่อง"
    else:
        follow_up = "ดูแลสุขภาพและตรวจสุขภาพตามกำหนด"

    disease_advice = {
        "DIABETES": (
            "พิจารณาตรวจระดับน้ำตาลในเลือดหรือ HbA1c "
            "ตามคำแนะนำของบุคลากรทางการแพทย์"
        ),
        "HYPERTENSION": (
            "วัดความดันซ้ำขณะพักในวันอื่น ๆ และปรึกษาแพทย์ "
            "หากค่าสูงต่อเนื่อง"
        ),
        "HEART_DISEASE": (
            "หากมีอาการเจ็บหน้าอกรุนแรงหรือหายใจลำบากเฉียบพลัน "
            "ให้โทร 1669 หรือไปห้องฉุกเฉินทันที"
        ),
    }
    specific_advice = disease_advice.get(
        disease_code,
        "ปรึกษาบุคลากรทางการแพทย์เพื่อรับคำแนะนำที่เหมาะสม",
    )
    return f"{follow_up} {specific_advice}"


def run_inference(submitted_factors):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)

    try:
        cursor.execute("""
            SELECT COLUMN_NAME AS column_name
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dataset_records'
            ORDER BY ORDINAL_POSITION
        """)
        columns = [row["column_name"] for row in cursor.fetchall()]
        factor_definitions = _factor_definitions_from_columns(columns)
        if not factor_definitions:
            raise RuntimeError("The dataset_records table has no supported factors")

        factors = _normalize_factors(submitted_factors, factor_definitions)
        factor_definition_by_code = {
            factor["factor_code"]: factor
            for factor in factor_definitions
        }

        cursor.execute("""
            SELECT disease_id, disease_code, disease_name
            FROM diseases
            ORDER BY disease_id
        """)
        diseases = cursor.fetchall()
        if not diseases:
            raise RuntimeError("The diseases table is empty")

        cursor.execute("""
            SELECT
                rule_id, disease_id, rule_code, rule_level, rule_category,
                conclusion, conditions_json, support, confidence, cf
            FROM rules
            WHERE is_active = 1
            ORDER BY disease_id, rule_level, rule_id
        """)
        rows = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

    rules_by_disease = {}
    for row in rows:
        conditions = row["conditions_json"]
        if isinstance(conditions, str):
            try:
                conditions = json.loads(conditions)
            except json.JSONDecodeError as error:
                raise RuntimeError(
                    f"Rule {row['rule_code']} has invalid conditions_json"
                ) from error
        if not isinstance(conditions, list) or not all(
            isinstance(item, str) for item in conditions
        ):
            raise RuntimeError(
                f"Rule {row['rule_code']} conditions_json must be a string list"
            )

        rule = {
            key: row[key]
            for key in (
                "rule_id", "disease_id", "rule_code", "rule_level",
                "rule_category", "conclusion", "support", "confidence", "cf",
            )
        }
        rule["conditions"] = [
            _parse_condition(
                condition,
                factor_definition_by_code,
                row["rule_code"],
            )
            for condition in conditions
        ]
        rules_by_disease.setdefault(row["disease_id"], []).append(rule)

    results = []
    for disease in diseases:
        matched_rules = [
            rule
            for rule in rules_by_disease.get(disease["disease_id"], [])
            if rule["conditions"] and all(
                _condition_matches(
                    condition,
                    factors,
                    factor_definition_by_code,
                )
                for condition in rule["conditions"]
            )
        ]

        final_cf = max(
            (float(rule["cf"]) for rule in matched_rules),
            default=0.0,
        )
        top_rule = max(
            matched_rules,
            key=lambda rule: (
                float(rule["cf"]),
                float(rule["confidence"]),
                float(rule["support"]),
            ),
            default=None,
        )
        results.append({
            **disease,
            "matched_rules": matched_rules,
            "is_positive": bool(matched_rules),
            "final_cf": round(final_cf, 6),
            "risk_level": _risk_level(final_cf),
            "top_rule": top_rule,
            "diagnosis": (
                f"เข้าข่ายตามกฎในฐานข้อมูลสำหรับ {disease['disease_name']}"
                if matched_rules
                else (
                    f"ไม่พบกฎสนับสนุน {disease['disease_name']} "
                    "จากข้อมูลที่กรอก"
                )
            ),
        })

    candidates = [result for result in results if result["matched_rules"]]
    if candidates:
        most_likely = max(
            candidates,
            key=lambda result: (
                result["final_cf"],
                float(result["top_rule"]["confidence"]),
                float(result["top_rule"]["support"]),
            ),
        )
        summary = {
            "disease_id": most_likely["disease_id"],
            "disease_code": most_likely["disease_code"],
            "disease_name": most_likely["disease_name"],
            "risk_level": most_likely["risk_level"],
            "final_cf": most_likely["final_cf"],
            "recommendation": _recommendation(
                most_likely["disease_code"],
                most_likely["risk_level"],
            ),
        }
    else:
        summary = {
            "disease_id": None,
            "disease_code": None,
            "disease_name": None,
            "risk_level": None,
            "final_cf": 0.0,
            "recommendation": (
                "ไม่พบกฎสนับสนุนโรคทั้งสามจากข้อมูลที่กรอก "
                "ผลนี้ไม่ได้ยืนยันว่าไม่มีโรค หากมีอาการหรือกังวล "
                "ควรปรึกษาบุคลากรทางการแพทย์"
            ),
        }

    return {"factors": factors, "results": results, "summary": summary}
