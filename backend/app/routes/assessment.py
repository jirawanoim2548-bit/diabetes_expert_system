import json
import re
from datetime import date
from uuid import uuid4

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.database import get_connection
from app.services.inference_engine import load_assessment_schema, run_inference


router = APIRouter(
    prefix="/api/assessment",
    tags=["Assessment"]
)

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

DISEASE_COLUMNS = {
    "DIABETES": ("diabetes_risk_level", "diabetes_score", "diabetes_summary"),
    "HYPERTENSION": (
        "hypertension_risk_level",
        "hypertension_score",
        "hypertension_summary",
    ),
    "HEART_DISEASE": (
        "heart_disease_risk_level",
        "heart_disease_score",
        "heart_disease_summary",
    ),
}


class PatientRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    birth_date: date
    phone: str = Field(min_length=9, max_length=30)


class AssessmentRequest(BaseModel):
    factors: dict[str, object]
    patient: PatientRequest


def _calculate_age(birth_date, today=None):
    today = today or date.today()
    if birth_date > today:
        raise HTTPException(
            status_code=422,
            detail="Birth date cannot be in the future",
        )
    age = today.year - birth_date.year
    if (today.month, today.day) < (birth_date.month, birth_date.day):
        age -= 1
    if age < 1:
        raise HTTPException(
            status_code=422,
            detail="Patient must be at least 1 year old",
        )
    if age > 120:
        raise HTTPException(status_code=422, detail="Age must not exceed 120")
    return age


def _normalize_phone(phone):
    normalized = re.sub(r"[\s()-]", "", phone)
    if not re.fullmatch(r"\+?\d{9,15}", normalized):
        raise HTTPException(
            status_code=422,
            detail="Enter a valid phone number with 9 to 15 digits",
        )
    return normalized


@router.get("/options")
def assessment_options():
    schema = load_assessment_schema()
    return schema


@router.get("/history")
def assessment_history():
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)

    try:
        cursor.execute("""
            SELECT
                h.assessment_id,
                h.assessment_code,
                p.person_id,
                p.person_code,
                p.full_name,
                p.birth_date,
                p.phone,
                h.age,
                h.gender,
                h.bmi,
                h.glucose,
                h.systolic_bp,
                h.diastolic_bp,
                h.cholesterol,
                h.fatigue,
                h.headache,
                h.dizziness,
                h.chest_pain,
                h.shortness_of_breath,
                h.nausea,
                h.blurred_vision,
                h.frequent_urination,
                h.excessive_thirst,
                h.palpitations,
                h.diabetes_risk_level,
                h.diabetes_score,
                h.diabetes_summary,
                h.hypertension_risk_level,
                h.hypertension_score,
                h.hypertension_summary,
                h.heart_disease_risk_level,
                h.heart_disease_score,
                h.heart_disease_summary,
                h.matched_rules_json,
                h.assessed_at,
                h.completed_at
            FROM assessment_history h
            JOIN assessed_persons p ON p.person_id = h.person_id
            ORDER BY h.assessed_at DESC, h.assessment_id DESC
            LIMIT 100
        """)
        rows = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

    history = []
    for row in rows:
        stored_results = row["matched_rules_json"]
        if isinstance(stored_results, str):
            try:
                stored_results = json.loads(stored_results)
            except json.JSONDecodeError as error:
                raise RuntimeError(
                    f"Assessment {row['assessment_id']} has invalid result JSON"
                ) from error
        if not isinstance(stored_results, dict):
            raise RuntimeError(
                f"Assessment {row['assessment_id']} has invalid result data"
            )

        factors = {
            code: row[column]
            for code, column in ASSESSMENT_FACTOR_COLUMNS.items()
        }
        for code, value in factors.items():
            if hasattr(value, "isoformat"):
                factors[code] = value.isoformat()

        assessed_at = row["assessed_at"]
        completed_at = row["completed_at"]
        history.append({
            "assessment_id": row["assessment_id"],
            "assessment_code": row["assessment_code"],
            "patient": {
                "patient_id": row["person_id"],
                "patient_code": row["person_code"],
                "full_name": row["full_name"] or "ไม่ระบุชื่อ",
                "birth_date": (
                    row["birth_date"].isoformat()
                    if row["birth_date"]
                    else None
                ),
                "phone": row["phone"],
                "gender": row["gender"],
                "age": row["age"],
            },
            "factors": factors,
            "summary": stored_results.get("summary", {}),
            "results": stored_results.get("results", []),
            "assessed_at": assessed_at.isoformat() if assessed_at else None,
            "completed_at": completed_at.isoformat() if completed_at else None,
        })
    return {"history": history}


@router.post("/")
def assessment(data: AssessmentRequest):
    first_name = data.patient.first_name.strip()
    last_name = data.patient.last_name.strip()
    if not first_name or not last_name:
        raise HTTPException(
            status_code=422,
            detail="Patient first and last names are required"
        )
    full_name = f"{first_name} {last_name}"
    if len(full_name) > 150:
        raise HTTPException(
            status_code=422,
            detail="Combined patient name must not exceed 150 characters",
        )
    birth_date = data.patient.birth_date
    age = _calculate_age(birth_date)
    phone = _normalize_phone(data.patient.phone)
    submitted_factors = {**data.factors, "AGE": age}

    try:
        inference = run_inference(submitted_factors)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error

    gender = inference["factors"].get("GENDER")
    if gender is None:
        raise HTTPException(status_code=422, detail="GENDER is required")

    results = [
        {
            "disease_id": result["disease_id"],
            "disease_code": result["disease_code"],
            "disease_name": result["disease_name"],
            "is_positive": result["is_positive"],
            "matched_rules": [
                {
                    "rule_code": rule["rule_code"],
                    "support": float(rule["support"]),
                    "confidence": float(rule["confidence"]),
                    "cf": float(rule["cf"]),
                }
                for rule in result["matched_rules"]
            ],
            "final_cf": float(result["final_cf"]),
            "risk_level": result["risk_level"],
            "diagnosis": result["diagnosis"],
        }
        for result in inference["results"]
    ]
    assessment_code = f"AS-{uuid4().hex[:16].upper()}"
    matched_rules_json = json.dumps(
        {
            "summary": inference["summary"],
            "results": results,
        },
        ensure_ascii=False,
        allow_nan=False,
    )
    factor_columns = list(ASSESSMENT_FACTOR_COLUMNS.values())
    factor_values = [
        inference["factors"].get(code)
        for code in ASSESSMENT_FACTOR_COLUMNS
    ]
    disease_values = []
    for disease_code, columns in DISEASE_COLUMNS.items():
        result = next(
            (
                item
                for item in inference["results"]
                if item["disease_code"] == disease_code
            ),
            None,
        )
        if result is None:
            disease_values.extend([None, None, None])
        else:
            disease_values.extend([
                result["risk_level"],
                result["final_cf"],
                result["diagnosis"],
            ])
    disease_columns = [
        column
        for columns in DISEASE_COLUMNS.values()
        for column in columns
    ]

    connection = get_connection()
    cursor = connection.cursor()
    patient_code_lock_acquired = False

    try:
        cursor.execute(
            "SELECT GET_LOCK(%s, 10)",
            ("diabetess_expert_system_patient_code",),
        )
        lock_result = cursor.fetchone()
        if not lock_result or lock_result[0] != 1:
            raise HTTPException(
                status_code=503,
                detail="Could not allocate a patient code; please try again",
            )
        patient_code_lock_acquired = True

        cursor.execute("""
            SELECT COALESCE(
                MAX(CAST(SUBSTRING(person_code, 3) AS UNSIGNED)),
                0
            )
            FROM assessed_persons
            WHERE person_code REGEXP '^HN[0-9]+$'
        """)
        patient_code = f"HN{int(cursor.fetchone()[0]) + 1:04d}"

        cursor.execute("""
            INSERT INTO assessed_persons
                (person_code, full_name, birth_date, gender, phone)
            VALUES (%s, %s, %s, %s, %s)
        """, (patient_code, full_name, birth_date, gender, phone))
        person_id = cursor.lastrowid

        history_columns = [
            "assessment_code", "person_id", *factor_columns, *disease_columns,
            "matched_rules_json", "assessment_status", "completed_at",
        ]
        history_values = [
            assessment_code, person_id, *factor_values, *disease_values,
            matched_rules_json, "Completed",
        ]
        placeholders = ["%s"] * len(history_values) + ["NOW()"]
        cursor.execute(
            f"INSERT INTO assessment_history ({', '.join(history_columns)}) "
            f"VALUES ({', '.join(placeholders)})",
            tuple(history_values),
        )
        assessment_id = cursor.lastrowid

        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        if patient_code_lock_acquired:
            cursor.execute(
                "SELECT RELEASE_LOCK(%s)",
                ("diabetess_expert_system_patient_code",),
            )
            cursor.fetchone()
        cursor.close()
        connection.close()

    return {
        "assessment_id": assessment_id,
        "patient": {
            "patient_id": person_id,
            "patient_code": patient_code,
            "first_name": first_name,
            "last_name": last_name,
            "gender": gender,
            "birth_date": birth_date.isoformat(),
            "phone": phone,
            "age": age,
        },
        "summary": inference["summary"],
        "results": results,
    }
