import unittest
from unittest.mock import patch

from app.database import ensure_assessment_schema


class FakeCursor:
    def __init__(self, columns):
        self.executed = []
        self.closed = False
        self.columns = columns

    def execute(self, query):
        self.executed.append(query)

    def fetchall(self):
        return self.columns

    def close(self):
        self.closed = True


class FakeConnection:
    def __init__(self, columns):
        self.fake_cursor = FakeCursor(columns)
        self.committed = False
        self.rolled_back = False
        self.closed = False

    def cursor(self):
        return self.fake_cursor

    def commit(self):
        self.committed = True

    def rollback(self):
        self.rolled_back = True

    def close(self):
        self.closed = True


class EnsureAssessmentSchemaTests(unittest.TestCase):
    @patch("app.database.get_connection")
    def test_accepts_the_expected_database_tables(self, get_connection):
        connection = FakeConnection([
            (table, column)
            for table, columns in {
                "assessed_persons": [
                    "person_id", "person_code", "full_name", "birth_date",
                    "gender", "phone",
                ],
                "assessment_history": [
                    "assessment_id", "assessment_code", "person_id", "age",
                    "gender", "bmi", "glucose", "systolic_bp",
                    "diastolic_bp", "cholesterol", "fatigue", "headache",
                    "dizziness", "chest_pain", "shortness_of_breath",
                    "nausea", "blurred_vision", "frequent_urination",
                    "excessive_thirst", "palpitations", "diabetes_risk_level",
                    "diabetes_score", "diabetes_summary",
                    "hypertension_risk_level", "hypertension_score",
                    "hypertension_summary", "heart_disease_risk_level",
                    "heart_disease_score", "heart_disease_summary",
                    "matched_rules_json", "assessment_status", "completed_at",
                ],
                "dataset_records": [
                    "age", "gender", "bmi", "glucose", "systolic_bp",
                    "diastolic_bp", "cholesterol", "fatigue", "headache",
                    "dizziness", "chest_pain", "shortness_of_breath",
                    "nausea", "blurred_vision", "frequent_urination",
                    "excessive_thirst", "palpitations",
                ],
                "diseases": ["disease_id", "disease_code", "disease_name"],
                "rules": [
                    "rule_id", "disease_id", "rule_code", "rule_level",
                    "rule_category", "conditions_json", "conclusion",
                    "support", "confidence", "cf", "is_active",
                ],
            }.items()
            for column in columns
        ])
        get_connection.return_value = connection

        ensure_assessment_schema()

        self.assertEqual(len(connection.fake_cursor.executed), 1)
        self.assertFalse(connection.rolled_back)
        self.assertTrue(connection.fake_cursor.closed)
        self.assertTrue(connection.closed)

    @patch("app.database.get_connection")
    def test_reports_missing_tables_without_changing_schema(self, get_connection):
        connection = FakeConnection([])
        get_connection.return_value = connection

        with self.assertRaisesRegex(
            RuntimeError, "Database schema is incompatible"
        ):
            ensure_assessment_schema()

        self.assertEqual(len(connection.fake_cursor.executed), 1)
        self.assertFalse(connection.rolled_back)
        self.assertTrue(connection.fake_cursor.closed)
        self.assertTrue(connection.closed)


if __name__ == "__main__":
    unittest.main()
