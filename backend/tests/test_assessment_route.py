import json
import unittest
from datetime import date
from unittest.mock import patch

from fastapi import HTTPException

from app.routes.assessment import (
    AssessmentRequest,
    PatientRequest,
    _calculate_age,
    assessment,
    assessment_history,
)


class FakeCursor:
    def __init__(self):
        self.lastrowid = None
        self.rows = []
        self.executed = []
        self.executemany_calls = []
        self.fetchone_result = None
        self.events = []

    def execute(self, query, params=None):
        self.events.append(("execute", query))
        self.executed.append((query, params))
        if "GET_LOCK" in query:
            self.fetchone_result = (1,)
        elif "MAX(CAST(SUBSTRING" in query:
            self.fetchone_result = (0,)
        elif "RELEASE_LOCK" in query:
            self.fetchone_result = (1,)
        if "INSERT INTO assessed_persons" in query:
            self.lastrowid = 7
        elif "INSERT INTO assessment_history" in query:
            self.lastrowid = 8

    def fetchone(self):
        self.events.append(("fetchone", None))
        return self.fetchone_result

    def executemany(self, query, params):
        self.executemany_calls.append((query, list(params)))

    def fetchall(self):
        return self.rows

    def close(self):
        pass


class FakeConnection:
    def __init__(self):
        self.fake_cursor = FakeCursor()
        self.committed = False
        self.rolled_back = False
        self.closed = False

    def cursor(self, dictionary=False):
        return self.fake_cursor

    def commit(self):
        self.committed = True

    def rollback(self):
        self.rolled_back = True

    def close(self):
        self.closed = True


class AssessmentRouteTests(unittest.TestCase):
    @patch("app.routes.assessment.get_connection")
    def test_returns_saved_assessments_for_history(self, get_connection):
        connection = FakeConnection()
        cursor = connection.fake_cursor
        cursor.rows = [{
            "assessment_id": 12,
            "assessment_code": "AS-EXAMPLE",
            "person_id": 4,
            "person_code": "PT-EXAMPLE",
            "full_name": "Ada Example",
            "birth_date": date(1980, 1, 1),
            "phone": "0812345678",
            "age": 45,
            "gender": "Female",
            "bmi": 25.5,
            "glucose": 110,
            "systolic_bp": 120,
            "diastolic_bp": 80,
            "cholesterol": 190,
            "fatigue": 0,
            "headache": None,
            "dizziness": None,
            "chest_pain": None,
            "shortness_of_breath": None,
            "nausea": None,
            "blurred_vision": None,
            "frequent_urination": None,
            "excessive_thirst": None,
            "palpitations": None,
            "diabetes_risk_level": "ระดับต่ำ",
            "diabetes_score": 0.1,
            "diabetes_summary": "ผลคัดกรอง",
            "hypertension_risk_level": "ระดับต่ำ",
            "hypertension_score": 0.0,
            "hypertension_summary": "ผลคัดกรอง",
            "heart_disease_risk_level": "ระดับต่ำ",
            "heart_disease_score": 0.0,
            "heart_disease_summary": "ผลคัดกรอง",
            "matched_rules_json": json.dumps({
                "summary": {
                    "disease_id": 1,
                    "disease_code": "DIABETES",
                    "disease_name": "Diabetes",
                    "risk_level": "ระดับต่ำ",
                    "final_cf": 0.1,
                    "recommendation": "ติดตามสุขภาพ",
                },
                "results": [{
                    "disease_id": 1,
                    "disease_code": "DIABETES",
                    "disease_name": "Diabetes",
                    "is_positive": True,
                    "matched_rules": [],
                    "final_cf": 0.1,
                    "risk_level": "ระดับต่ำ",
                    "diagnosis": "ผลคัดกรอง",
                }],
            }),
            "assessed_at": None,
            "completed_at": None,
        }]
        get_connection.return_value = connection

        response = assessment_history()

        self.assertEqual(len(response["history"]), 1)
        item = response["history"][0]
        self.assertEqual(item["assessment_id"], 12)
        self.assertEqual(item["patient"]["full_name"], "Ada Example")
        self.assertEqual(item["patient"]["phone"], "0812345678")
        self.assertEqual(item["factors"]["BMI"], 25.5)
        self.assertEqual(item["summary"]["disease_code"], "DIABETES")
        self.assertEqual(item["results"][0]["disease_code"], "DIABETES")
        self.assertIn("JOIN assessed_persons", cursor.executed[0][0])
        self.assertTrue(connection.closed)

    @patch("app.routes.assessment.run_inference")
    @patch("app.routes.assessment.get_connection")
    def test_saves_all_disease_results_in_one_transaction(
        self,
        get_connection,
        run_inference
    ):
        connection = FakeConnection()
        get_connection.return_value = connection
        run_inference.return_value = {
            "factors": {
                "AGE": _calculate_age(date(1980, 1, 1)),
                "GENDER": "Female",
                "BMI": 31.25,
                "GLUCOSE": 130,
            },
            "summary": {
                "disease_id": 3,
                "disease_code": "HEART_DISEASE",
                "disease_name": "Heart Disease",
                "risk_level": "ระดับสูง",
                "final_cf": 0.4,
                "recommendation": "โทร 1669",
            },
            "results": [
                {
                    "disease_id": 1, "disease_code": "DIABETES",
                    "disease_name": "Diabetes",
                    "is_positive": True,
                    "matched_rules": [
                        {
                            "rule_id": 2, "rule_code": "R02", "cf": 0.4,
                            "support": 0.08, "confidence": 0.7,
                        }
                    ],
                    "final_cf": 0.4, "risk_level": "ระดับสูง",
                    "diagnosis": "พบปัจจัยเสี่ยงต่อ Diabetes",
                },
                {
                    "disease_id": 2, "disease_code": "HYPERTENSION",
                    "disease_name": "Hypertension",
                    "is_positive": False,
                    "matched_rules": [],
                    "final_cf": 0.0, "risk_level": "ระดับต่ำ",
                    "diagnosis": "ไม่พบกฎที่ตรงกับข้อมูลสำหรับ Hypertension",
                },
                {
                    "disease_id": 3, "disease_code": "HEART_DISEASE",
                    "disease_name": "Heart Disease",
                    "is_positive": True,
                    "matched_rules": [
                        {
                            "rule_id": 22, "rule_code": "R22", "cf": 0.3,
                            "support": 0.04, "confidence": 0.65,
                        }
                    ],
                    "final_cf": 0.3, "risk_level": "ระดับสูง",
                    "diagnosis": "พบปัจจัยเสี่ยงต่อ Heart Disease",
                },
            ],
        }

        response = assessment(AssessmentRequest(
            patient=PatientRequest(
                first_name="Ada",
                last_name="Example",
                birth_date="1980-01-01",
                phone="081-234-5678",
            ),
            factors={
                "GENDER": "Female",
                "BMI": 31.25,
                "GLUCOSE": 130,
            },
        ))
        run_inference.assert_called_once_with({
            "GENDER": "Female",
            "BMI": 31.25,
            "GLUCOSE": 130,
            "AGE": _calculate_age(date(1980, 1, 1)),
        })

        self.assertEqual(response["patient"]["patient_id"], 7)
        self.assertEqual(response["assessment_id"], 8)
        self.assertEqual(response["patient"]["patient_code"], "HN0001")
        self.assertEqual(response["patient"]["first_name"], "Ada")
        self.assertEqual(response["patient"]["gender"], "Female")
        self.assertEqual(
            response["patient"]["age"],
            _calculate_age(date(1980, 1, 1)),
        )
        self.assertEqual(response["patient"]["birth_date"], "1980-01-01")
        self.assertEqual(response["patient"]["phone"], "0812345678")
        self.assertEqual(
            response["summary"]["disease_code"],
            "HEART_DISEASE",
        )
        self.assertEqual(response["summary"]["recommendation"], "โทร 1669")
        self.assertEqual(
            [result["disease_code"] for result in response["results"]],
            ["DIABETES", "HYPERTENSION", "HEART_DISEASE"],
        )
        self.assertEqual(
            [result["is_positive"] for result in response["results"]],
            [True, False, True],
        )
        self.assertEqual(
            response["results"][0]["matched_rules"][0],
            {
                "rule_code": "R02",
                "support": 0.08,
                "confidence": 0.7,
                "cf": 0.4,
            },
        )
        self.assertTrue(all(
            "recommendations" not in result
            for result in response["results"]
        ))
        self.assertTrue(connection.committed)
        self.assertFalse(connection.rolled_back)
        self.assertTrue(connection.closed)
        person_insert, history_insert = [
            statement
            for statement in connection.fake_cursor.executed
            if "INSERT INTO" in statement[0]
        ]
        self.assertIn("INSERT INTO assessed_persons", person_insert[0])
        self.assertEqual(person_insert[1], (
            "HN0001",
            "Ada Example",
            date(1980, 1, 1),
            "Female",
            "0812345678",
        ))
        self.assertIn("INSERT INTO assessment_history", history_insert[0])
        self.assertIn("assessment_status", history_insert[0])
        self.assertTrue(history_insert[1][0].startswith("AS-"))
        self.assertEqual(
            history_insert[1][1:4],
            (7, response["patient"]["age"], "Female"),
        )
        self.assertEqual(history_insert[1][-1], "Completed")
        saved_data = json.loads(history_insert[1][-2])
        self.assertEqual(len(saved_data["results"]), 3)
        self.assertEqual(
            saved_data["results"][0]["matched_rules"][0]["rule_code"],
            "R02",
        )
        self.assertIn("glucose", history_insert[0])
        self.assertIn("diabetes_score", history_insert[0])
        self.assertEqual(connection.fake_cursor.executemany_calls, [])
        self.assertTrue(any(
            "RELEASE_LOCK" in query
            for query, _ in connection.fake_cursor.executed
        ))
        release_lock_index = next(
            index
            for index, (event, query) in enumerate(
                connection.fake_cursor.events
            )
            if event == "execute" and "RELEASE_LOCK" in query
        )
        self.assertEqual(
            connection.fake_cursor.events[release_lock_index + 1][0],
            "fetchone",
        )

    def test_calculates_age_from_birth_date(self):
        self.assertEqual(_calculate_age(
            date(2000, 10, 14),
            date(2026, 10, 13),
        ), 25)
        self.assertEqual(_calculate_age(
            date(2000, 10, 13),
            date(2026, 10, 13),
        ), 26)

    def test_rejects_future_birth_date(self):
        with self.assertRaisesRegex(
            HTTPException, "Birth date cannot be in the future"
        ):
            _calculate_age(date.today().replace(year=date.today().year + 1))

    def test_rejects_patients_younger_than_one_year(self):
        with self.assertRaisesRegex(
            HTTPException, "Patient must be at least 1 year old"
        ):
            _calculate_age(date.today(), date.today())


if __name__ == "__main__":
    unittest.main()
