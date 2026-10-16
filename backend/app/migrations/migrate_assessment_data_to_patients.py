import json
from datetime import date, datetime
from decimal import Decimal

from app.database import get_connection


ASSESSMENT_FACTOR_COLUMNS = {
    "AGE": "age",
    "GENDER": "gender",
    "BMI": "bmi",
    "GLUCOSE": "glucose",
    "SYSTOLIC_BP": "systolic_bp",
    "DIASTOLIC_BP": "diastolic_bp",
    "CHOLESTEROL": "cholesterol",
    "FATIGUE": "fatigue",
    "HEADACHE": "headache",
    "DIZZINESS": "dizziness",
    "CHEST_PAIN": "chest_pain",
    "SHORTNESS_OF_BREATH": "shortness_of_breath",
    "NAUSEA": "nausea",
    "BLURRED_VISION": "blurred_vision",
    "FREQUENT_URINATION": "frequent_urination",
    "EXCESSIVE_THIRST": "excessive_thirst",
    "PALPITATIONS": "palpitations",
}


def _json_value(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def _values_match(left, right):
    if left is None or right is None:
        return left is right
    try:
        return Decimal(str(left)) == Decimal(str(right))
    except Exception:
        return str(left).casefold() == str(right).casefold()


def _risk_level(final_cf):
    if final_cf >= 0.30:
        return "ระดับสูง"
    if final_cf >= 0.15:
        return "ระดับปานกลาง"
    return "ระดับต่ำ"


def migrate():
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("SHOW TABLES")
        table_names = {
            next(iter(row.values()))
            for row in cursor.fetchall()
        }
        if "patients" not in table_names:
            raise RuntimeError("The patients table does not exist")

        cursor.execute("""
            SELECT COLUMN_NAME
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'patients'
        """)
        patient_columns = {
            row["COLUMN_NAME"]
            for row in cursor.fetchall()
        }
        if "bmi" not in patient_columns:
            cursor.execute(
                "ALTER TABLE patients ADD COLUMN bmi DECIMAL(5, 2) NULL"
            )
        if "assessment_data" not in patient_columns:
            cursor.execute(
                "ALTER TABLE patients ADD COLUMN assessment_data LONGTEXT NULL"
            )

        source_tables = {
            "assessments",
            "assessment_factors",
            "assessment_rules",
            "assessment_results",
        }
        present_sources = source_tables & table_names
        if not present_sources:
            print("Assessment tables are already removed; nothing to migrate.")
            return
        if present_sources != source_tables:
            missing = ", ".join(sorted(source_tables - present_sources))
            raise RuntimeError(
                "Migration stopped because source tables are missing: "
                + missing
            )

        cursor.execute("SELECT * FROM assessments ORDER BY assessment_id")
        assessments = cursor.fetchall()
        cursor.execute("""
            SELECT af.assessment_id, rf.factor_code, af.factor_value
            FROM assessment_factors af
            JOIN risk_factors rf ON rf.factor_id = af.factor_id
            ORDER BY af.assessment_id, rf.factor_code
        """)
        factors_by_assessment = {}
        for row in cursor.fetchall():
            factors_by_assessment.setdefault(
                row["assessment_id"], {}
            )[row["factor_code"]] = row["factor_value"]

        cursor.execute("""
            SELECT
                ar.assessment_id,
                ar.rule_id,
                ar.rule_cf,
                ar.matched,
                kb.rule_code,
                kb.disease_id,
                kb.support,
                kb.confidence,
                kb.cf
            FROM assessment_rules ar
            LEFT JOIN knowledge_base kb ON kb.rule_id = ar.rule_id
            ORDER BY ar.assessment_id, ar.rule_id
        """)
        rules_by_assessment = {}
        for row in cursor.fetchall():
            rules_by_assessment.setdefault(
                row["assessment_id"], {}
            ).setdefault(row["disease_id"], []).append(row)

        cursor.execute("""
            SELECT
                result.assessment_id,
                result.disease_id,
                disease.disease_code,
                disease.disease_name,
                result.final_cf,
                result.matched_rule_count,
                result.result_text,
                result.created_at
            FROM assessment_results result
            LEFT JOIN diseases disease ON disease.disease_id = result.disease_id
            ORDER BY result.assessment_id, result.disease_id
        """)
        results_by_assessment = {}
        for row in cursor.fetchall():
            results_by_assessment.setdefault(
                row["assessment_id"], []
            ).append(row)

        source_patient_ids = {
            row["patient_id"]
            for row in assessments
            if row["patient_id"] is not None
        }
        patients_by_id = {}
        if source_patient_ids:
            placeholders = ", ".join(["%s"] * len(source_patient_ids))
            cursor.execute(
                "SELECT patient_id, patient_code, first_name, last_name, "
                "gender, age "
                f"FROM patients WHERE patient_id IN ({placeholders})",
                tuple(source_patient_ids),
            )
            patients_by_id = {
                row["patient_id"]: row
                for row in cursor.fetchall()
            }

        migrated_codes = []
        for assessment in assessments:
            assessment_id = assessment["assessment_id"]
            patient_code = f"PT-LEGACY-{assessment_id}"
            cursor.execute(
                "SELECT patient_id, assessment_data FROM patients "
                "WHERE patient_code = %s",
                (patient_code,),
            )
            existing = cursor.fetchone()
            if existing:
                payload = json.loads(existing["assessment_data"] or "{}")
                if payload.get("legacy_assessment_id") != assessment_id:
                    raise RuntimeError(
                        f"Patient code collision for legacy assessment "
                        f"{assessment_id}"
                    )
                migrated_codes.append(patient_code)
                continue

            factor_values = factors_by_assessment.get(assessment_id, {}).copy()
            legacy_conflicts = {}
            for code, column in ASSESSMENT_FACTOR_COLUMNS.items():
                column_value = assessment.get(column)
                if column_value is None:
                    continue
                factor_value = factor_values.get(code)
                if factor_value is None:
                    factor_values[code] = _json_value(column_value)
                elif not _values_match(column_value, factor_value):
                    legacy_conflicts[code] = {
                        "assessment_column": _json_value(column_value),
                        "assessment_factor": _json_value(factor_value),
                    }

            saved_results = []
            for result in results_by_assessment.get(assessment_id, []):
                disease_rules = rules_by_assessment.get(
                    assessment_id, {}
                ).get(result["disease_id"], [])
                matched_rules = [
                    {
                        "rule_id": rule["rule_id"],
                        "rule_code": rule["rule_code"],
                        "support": _json_value(rule["support"]),
                        "confidence": _json_value(rule["confidence"]),
                        "cf": _json_value(
                            rule["cf"] if rule["cf"] is not None
                            else rule["rule_cf"]
                        ),
                        "matched": rule["matched"],
                    }
                    for rule in disease_rules
                ]
                final_cf = float(result["final_cf"])
                saved_results.append({
                    "disease_id": result["disease_id"],
                    "disease_code": result["disease_code"],
                    "disease_name": result["disease_name"],
                    "final_cf": final_cf,
                    "risk_level": _risk_level(final_cf),
                    "matched_rule_count": result["matched_rule_count"],
                    "diagnosis": result["result_text"],
                    "created_at": _json_value(result["created_at"]),
                    "matched_rules": matched_rules,
                })

            source_patient = patients_by_id.get(assessment["patient_id"])
            payload = {
                "legacy_assessment_id": assessment_id,
                "legacy_patient_id": assessment["patient_id"],
                "factors": {
                    code: _json_value(value)
                    for code, value in factor_values.items()
                    if code not in {"AGE", "GENDER", "BMI"}
                },
                "summary": None,
                "results": saved_results,
            }
            if source_patient:
                payload["legacy_patient"] = {
                    "patient_code": source_patient["patient_code"],
                    "gender": source_patient["gender"],
                    "age": source_patient["age"],
                }
            if legacy_conflicts:
                payload["legacy_factor_conflicts"] = legacy_conflicts

            cursor.execute("""
                INSERT INTO patients
                    (patient_code, first_name, last_name, gender, age, bmi,
                     created_at, assessment_data)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                patient_code,
                source_patient["first_name"] if source_patient else None,
                source_patient["last_name"] if source_patient else None,
                assessment.get("gender"),
                assessment["age"],
                assessment["bmi"],
                assessment["created_at"],
                json.dumps(payload, ensure_ascii=False, allow_nan=False),
            ))
            migrated_codes.append(patient_code)

        connection.commit()

        cursor.execute(
            "SELECT patient_code, assessment_data FROM patients "
            "WHERE patient_code LIKE 'PT-LEGACY-%'"
        )
        migrated = {
            row["patient_code"]: json.loads(row["assessment_data"] or "{}")
            for row in cursor.fetchall()
        }
        expected_ids = {
            row["assessment_id"]
            for row in assessments
        }
        found_ids = {
            payload.get("legacy_assessment_id")
            for payload in migrated.values()
        }
        if not expected_ids.issubset(found_ids):
            raise RuntimeError(
                "Migration verification failed; source tables were not dropped"
            )
        for assessment_id in expected_ids:
            payload = next(
                item for item in migrated.values()
                if item.get("legacy_assessment_id") == assessment_id
            )
            if len(payload.get("results", [])) != len(
                results_by_assessment.get(assessment_id, [])
            ):
                raise RuntimeError(
                    "Disease result verification failed; source tables were "
                    "not dropped"
                )

        if source_patient_ids:
            placeholders = ", ".join(["%s"] * len(source_patient_ids))
            cursor.execute(
                f"DELETE FROM patients WHERE patient_id IN ({placeholders})",
                tuple(source_patient_ids),
            )
            connection.commit()

        for table_name in (
            "assessment_factors",
            "assessment_rules",
            "assessment_results",
            "assessments",
        ):
            cursor.execute(f"DROP TABLE {table_name}")

        print(
            f"Migrated {len(expected_ids)} assessment record(s) to patients "
            "and removed the four assessment history tables."
        )
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()


if __name__ == "__main__":
    migrate()
