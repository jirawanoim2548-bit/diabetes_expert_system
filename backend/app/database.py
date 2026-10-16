import os
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")


def ensure_assessment_schema():
    connection = get_connection()
    cursor = connection.cursor()

    try:
        cursor.execute("""
            SELECT TABLE_NAME, COLUMN_NAME
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
        """)
        schema = {}
        for table_name, column_name in cursor.fetchall():
            schema.setdefault(table_name, set()).add(column_name)

        required = {
            "assessed_persons": {
                "person_id", "person_code", "full_name", "birth_date",
                "gender", "phone",
            },
            "assessment_history": {
                "assessment_id", "assessment_code", "person_id",
                "age", "gender", "bmi", "glucose", "systolic_bp",
                "diastolic_bp", "cholesterol", "fatigue", "headache",
                "dizziness", "chest_pain", "shortness_of_breath", "nausea",
                "blurred_vision", "frequent_urination", "excessive_thirst",
                "palpitations", "diabetes_risk_level", "diabetes_score",
                "diabetes_summary", "hypertension_risk_level",
                "hypertension_score", "hypertension_summary",
                "heart_disease_risk_level", "heart_disease_score",
                "heart_disease_summary", "matched_rules_json",
                "assessment_status", "completed_at",
            },
            "dataset_records": {
                "age", "gender", "bmi", "glucose", "systolic_bp",
                "diastolic_bp", "cholesterol", "fatigue", "headache",
                "dizziness", "chest_pain", "shortness_of_breath", "nausea",
                "blurred_vision", "frequent_urination", "excessive_thirst",
                "palpitations",
            },
            "diseases": {"disease_id", "disease_code", "disease_name"},
            "rules": {
                "rule_id", "disease_id", "rule_code", "rule_level",
                "rule_category", "conditions_json", "conclusion", "support",
                "confidence", "cf", "is_active",
            },
        }
        missing = []
        for table_name, columns in required.items():
            if table_name not in schema:
                missing.append(table_name)
                continue
            missing.extend(
                f"{table_name}.{column}"
                for column in sorted(columns - schema[table_name])
            )
        if missing:
            raise RuntimeError(
                "Database schema is incompatible; missing: "
                + ", ".join(missing)
            )
    finally:
        cursor.close()
        connection.close()


def get_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME", "diabetess_expert_system")
    )