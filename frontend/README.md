# Diabetes Expert System

Flutter frontend backed by a FastAPI service and a MySQL database.

## Database and API

Configure the database connection in `backend/.env`:

```dotenv
DB_HOST=localhost
DB_PORT=3306
DB_USER=your_mysql_user
DB_PASSWORD=your_mysql_password
DB_NAME=diabetess_expert_system
```

Keep the `.env` file private; it is excluded from version control.

From the project root, install the backend dependencies, then run the API from
the `backend` directory:

```powershell
python -m pip install -r backend/requirements.txt
Set-Location backend
npm run dev
```

The API is available at `http://127.0.0.1:8000`, with interactive docs at
`http://127.0.0.1:8000/docs`.

Run the Flutter app from `frontend`:

```powershell
flutter pub get
flutter run
```

The assessment form loads diseases and supported risk-factor columns from the
database. Each submission is evaluated against active `rules` records and their
`conditions_json` for every disease, including Diabetes, Hypertension, and
Heart Disease. Unanswered factors do not match rules that require them. Each
submission creates an identity record in `assessed_persons` and a linked result
record in `assessment_history`, including submitted factors, per-disease scores
and summaries, and matched-rule Support, Confidence, and CF in
`matched_rules_json`.
Each result also returns the matched rules' Support, Confidence, and CF values,
plus one overall summary identifying the disease with the highest CF among
matched rules and one recommendation for that disease. The binary screening
status is based on the database rules: one or more matched positive rules means
"เข้าข่าย"; no matched rules means there is no database rule supporting that
disease from the submitted values. The UI displays only diseases with a
matched positive rule. If none match, the summary reports no disease as
qualifying. This is not a clinical diagnosis or proof that a person does not
have a disease. Support and Confidence describe patterns in the rule dataset;
CF and the displayed risk level are screening scores, not clinically
calibrated probabilities.

Each assessment requires the person's first name, last name, gender, phone
number, date of birth, and BMI. Age is calculated from the date of birth by the
API. The API creates unique sequential `HN0001`-style patient codes and unique
`AS-...` assessment codes; repeat visits create a new linked history record.

The assessment options endpoint is `GET /api/assessment/options`. Submit
patient and factor values to `POST /api/assessment/` as
`{"patient": {"first_name": "Ada", "last_name": "Example",
"birth_date": "1980-01-01", "phone": "0812345678"},
"factors": {"GENDER": "Female", "BMI": 28.5}}`. Birth date, phone, gender,
and BMI are required; age is calculated from the birth date and other factors
may be omitted.
The app guides users through separate patient-information, health-assessment,
and assessment-result screens. Users can return to edit the assessment or
start a new one from the result screen.
Use the History tab in the app to view the latest 100 saved assessments and
open an entry to see its summary, per-disease results, and submitted factors.
The history endpoint is `GET /api/assessment/history`.

Run backend tests from `backend`:

```powershell
Set-Location backend
python -m unittest discover -s tests -v
```
