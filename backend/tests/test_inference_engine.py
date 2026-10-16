import unittest
from unittest.mock import patch

from app.services.inference_engine import (
    _condition_matches,
    _factor_definitions_from_columns,
    _parse_condition,
    run_inference,
)


DATASET_COLUMNS = [
    {"column_name": code.lower()}
    for code in (
        "AGE",
        "GENDER",
        "BMI",
        "GLUCOSE",
        "SYSTOLIC_BP",
        "CHOLESTEROL",
        "PALPITATIONS",
    )
]

DISEASES = [
    {"disease_id": 1, "disease_code": "DIABETES", "disease_name": "Diabetes"},
    {"disease_id": 2, "disease_code": "HYPERTENSION",
     "disease_name": "Hypertension"},
    {"disease_id": 3, "disease_code": "HEART_DISEASE",
     "disease_name": "Heart Disease"},
]

RULE_ROWS = [
    {
        "rule_id": 1, "disease_id": 1, "rule_code": "D01", "rule_level": 1,
        "rule_category": "clinical", "conclusion": "Diabetes",
        "support": 0.5, "confidence": 0.8, "cf": 0.4,
        "conditions_json": '["Glucose >= 126"]',
    },
    {
        "rule_id": 2, "disease_id": 2, "rule_code": "H01", "rule_level": 1,
        "rule_category": "clinical", "conclusion": "Hypertension",
        "support": 0.5, "confidence": 0.8, "cf": 0.3,
        "conditions_json": '["Systolic_BP >= 140"]',
    },
    {
        "rule_id": 3, "disease_id": 3, "rule_code": "C01", "rule_level": 1,
        "rule_category": "clinical", "conclusion": "Heart Disease",
        "support": 0.5, "confidence": 0.8, "cf": 0.5,
        "conditions_json": '["Cholesterol >= 240"]',
    },
    {
        "rule_id": 4, "disease_id": 3, "rule_code": "C02", "rule_level": 1,
        "rule_category": "clinical", "conclusion": "Heart Disease",
        "support": 0.4, "confidence": 0.7, "cf": 0.4,
        "conditions_json": '["Palpitations=1"]',
    },
]


class FakeCursor:
    def __init__(self):
        self.rows = []

    def execute(self, query):
        if "information_schema.COLUMNS" in query:
            self.rows = DATASET_COLUMNS
        elif "FROM diseases" in query:
            self.rows = DISEASES
        else:
            self.rows = RULE_ROWS

    def fetchall(self):
        return self.rows

    def close(self):
        pass


class FakeConnection:
    def cursor(self, dictionary=False):
        return FakeCursor()

    def close(self):
        pass


class RunInferenceTests(unittest.TestCase):
    @patch("app.services.inference_engine.get_connection", return_value=FakeConnection())
    def test_evaluates_rules_for_all_diseases_from_database(self, _get_connection):
        result = run_inference({
            "AGE": 65,
            "GENDER": "Male",
            "BMI": 31.5,
            "GLUCOSE": 130,
            "SYSTOLIC_BP": 150,
            "CHOLESTEROL": 250,
            "PALPITATIONS": 1,
        })

        self.assertEqual(
            [item["disease_code"] for item in result["results"]],
            ["DIABETES", "HYPERTENSION", "HEART_DISEASE"],
        )
        self.assertEqual(
            [item["matched_rules"][0]["rule_code"] for item in result["results"]],
            ["D01", "H01", "C01"],
        )
        self.assertEqual(result["results"][2]["final_cf"], 0.5)
        self.assertTrue(all(item["is_positive"] for item in result["results"]))
        self.assertEqual(result["results"][0]["matched_rules"][0]["support"], 0.5)
        self.assertEqual(
            result["results"][0]["matched_rules"][0]["confidence"],
            0.8,
        )
        self.assertEqual(result["summary"]["disease_code"], "HEART_DISEASE")
        self.assertEqual(result["summary"]["final_cf"], 0.5)
        self.assertIn("1669", result["summary"]["recommendation"])

    @patch("app.services.inference_engine.get_connection", return_value=FakeConnection())
    def test_unanswered_factors_do_not_match_rules(self, _get_connection):
        result = run_inference({"AGE": 40, "GENDER": "Female", "BMI": 22})

        self.assertTrue(all(
            not disease["matched_rules"] and not disease["is_positive"]
            for disease in result["results"]
        ))
        self.assertIsNone(result["summary"]["disease_code"])
        self.assertIn("ไม่พบกฎสนับสนุน", result["summary"]["recommendation"])

    @patch("app.services.inference_engine.get_connection", return_value=FakeConnection())
    def test_requires_age_and_bmi(self, _get_connection):
        with self.assertRaisesRegex(ValueError, "AGE and BMI are required"):
            run_inference({"AGE": 50})

    @patch("app.services.inference_engine.get_connection", return_value=FakeConnection())
    def test_requires_gender_for_patient_registration(self, _get_connection):
        with self.assertRaisesRegex(ValueError, "GENDER is required"):
            run_inference({"AGE": 50, "BMI": 25})

    @patch("app.services.inference_engine.get_connection", return_value=FakeConnection())
    def test_rejects_unknown_factor_codes(self, _get_connection):
        with self.assertRaisesRegex(ValueError, "Unknown risk factor"):
            run_inference({
                "AGE": 50,
                "GENDER": "Male",
                "BMI": 25,
                "UNKNOWN": 1,
            })

    def test_supports_the_rules_table_conditions_json_range_syntax(self):
        factor_definitions = _factor_definitions_from_columns(
            ["systolic_bp", "gender"]
        )
        by_code = {
            factor["factor_code"]: factor
            for factor in factor_definitions
        }
        range_condition = _parse_condition(
            "114 < Systolic_BP < 137", by_code, "H01"
        )
        gender_condition = _parse_condition("Gender=Male", by_code, "H01")

        self.assertTrue(_condition_matches(
            range_condition, {"SYSTOLIC_BP": 130}, by_code
        ))
        self.assertFalse(_condition_matches(
            range_condition, {"SYSTOLIC_BP": 140}, by_code
        ))
        self.assertTrue(_condition_matches(
            gender_condition, {"GENDER": "Male"}, by_code
        ))


if __name__ == "__main__":
    unittest.main()
