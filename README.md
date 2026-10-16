# Q-Health: Hospital Queue Management with Random Forest

**Two queues, not one. That is why the estimates drift.**

An Android app for government clinic outpatient departments that tells each patient how long
they will actually wait. The patient journey is split into the two queues a real clinic has,
**screening** (blood pressure, BMI) and **doctor consultation**, and a separate Random Forest
Regression model predicts the waiting time for each. Staff run both queues from the same app,
every change syncs in real time through Supabase, and patients get a push notification shortly
before their turn so they do not have to sit in the waiting room.

Final Year Project, Bachelor of Electronic Engineering, Universiti Tun Hussein Onn Malaysia
(2025/2026). **Gold Medal, Final Year Project Industry Award.**

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/patient_dashboard.jpg" width="230" alt="Patient queue dashboard"></td>
    <td align="center"><img src="docs/screenshots/staff_screening.jpg" width="230" alt="Staff screening dashboard"></td>
    <td align="center"><img src="docs/screenshots/push_notification.jpg" width="230" alt="Push notification"></td>
  </tr>
  <tr>
    <td align="center">The patient sees their queue number and a live countdown</td>
    <td align="center">Staff see every patient, their estimate and the longest wait</td>
    <td align="center">A push notification arrives when the turn is near</td>
  </tr>
</table>

> The models are trained on a public Kaggle dataset of about 30,000 outpatient visits from
> November 2019, not on Malaysian hospital records. This is a proof of concept, not a system
> running in a real clinic.

## Why

Most clinic queue systems hand out a number such as "1001" and nothing else. Patients do not
know whether they will wait ten minutes or two hours, so they stay in a crowded waiting room
the whole time ("blind waiting anxiety"), which is also where infections spread. Government
clinics also run a two-step flow: vitals screening first, then the doctor. A single estimate
for the whole visit cannot tell a patient when each step will happen.

This project does three things that earlier systems in the literature did separately:

| | Mobile app | ML prediction | Real-time notification | Two-stage queue | Security check |
|---|:-:|:-:|:-:|:-:|:-:|
| Soman et al. (2020) | Yes | No | Yes | No | No |
| Li et al. (2021) | No | Yes | No | No | No |
| Al-Mousa et al. (2024) | No | Yes | No | Yes | No |
| **This project** | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** |

The AI server lives in its own repository:
[qhealth-ai-server](https://github.com/amirulfahmiii920-beep/qhealth-ai-server) (Flask + the two
trained models).

## What it does

| Feature | How |
|---|---|
| Two-stage queue | Each ticket has a `screening_status` and a `consult_status` (Waiting, In Progress, Completed, No Show) in one Supabase table |
| Wait-time prediction | Two Random Forest models on a Flask server: one for screening, one for the doctor queue |
| Live updates | The patient dashboard and both staff dashboards read the same Supabase table, so a change by staff shows on the patient's phone without a refresh |
| Automatic hand-over | When staff mark screening as done, the patient moves to the consultation queue and gets a new estimate from the second model |
| Dynamic re-estimation | If a patient finishes early, everyone behind them gets a shorter estimate; staff can also add delay minutes to the whole queue |
| Scheduled push alerts | OneSignal `send_after` delivers "3 minutes left" at the right moment, plus an instant "It's your turn" when staff call the patient |
| Time manipulation check | Opening hours (8:00 am to 4:30 pm) are checked against Malaysia network time, not the phone clock |
| AI assistant | A Gemini chatbot that answers indoor navigation questions (pharmacy, café, convenience store) |
| Accounts | Patient sign-in with email or Google, a separate staff portal, English and Bahasa Melayu, dark mode |

## How it works

```mermaid
flowchart LR
    subgraph App["Flutter app (Android)"]
        direction TB
        P[Patient screens]
        S[Staff screens]
    end
    T[timeapi.io<br/>Malaysia time] -- "open hours check" --- P
    App -- "hour, day, type" --> AI["Flask AI server<br/>Model 1: screening wait<br/>Model 2: doctor wait"]
    App <-- "live queue table" --> DB[(Supabase<br/>Postgres + Auth)]
    S -- "call and scheduled alerts" --> OS[OneSignal] -- push --> P
    P -- questions --> G[Gemini<br/>AI assistant]
```

### One patient's visit

```mermaid
sequenceDiagram
    actor Patient
    participant App as Flutter app
    participant Time as timeapi.io
    participant AI as AI server
    participant DB as Supabase
    actor Staff
    participant Push as OneSignal

    Patient->>App: Tap "Get Queue"
    App->>Time: Current Malaysia time
    Time-->>App: 10:42, inside 8:00 to 16:30
    App->>DB: Count patients waiting for screening
    App->>AI: /predict_ewt (hour, day, patient type)
    AI-->>App: Base estimate in minutes
    App->>DB: Insert ticket Q-xxxx with screening_ewt
    App-->>Patient: Queue number + countdown
    Staff->>DB: Call patient (screening In Progress)
    Staff->>Push: "It's your turn"
    Push-->>Patient: Notification
    Staff->>AI: Screening done, ask doctor-queue estimate
    AI-->>Staff: Base estimate in minutes
    Staff->>DB: screening Completed, consult Waiting, doctor_ewt
    Staff->>Push: Schedule "3 minutes left" with send_after
    DB-->>App: Live update, stage = Consultation
    Push-->>Patient: Notification 3 minutes before the doctor
    Staff->>DB: Consultation Completed
```

The original two-stage design from the report:

![Two-stage queue flowchart](docs/screenshots/flowchart_two_stage.jpg)

### How an estimate is built

The model gives a base estimate from the time and day. The app then combines it with the live
queue, so the estimate is never shorter than what the people ahead already need:

| Stage | Nobody ahead | People ahead | If the AI server is unreachable |
|---|---|---|---|
| Screening | 5 min | the longest current estimate + 5 min, but at least the model's estimate | 25 min base |
| Doctor | 5 min | the longest current estimate + 15 min, but at least the model's estimate | 20 min base |

When staff mark a patient as done early, the next patient's estimate drops to 5 minutes and the
time saved is taken off everyone behind them. A scheduled notification is sent 3 minutes before
the new estimate runs out:

```dart
// Notify 3 minutes before the doctor is ready
int delayConsult = (newDoctorEwt * 60) - 180;
if (delayConsult > 0) {
  sendScheduledPushNotification(patientId, "Doctor Consultation Ready",
      "Only 3 minutes left to see the doctor. Please get ready.", delayConsult);
}
```

## The two models

```mermaid
flowchart LR
    A[Kaggle CSV<br/>~30,000 visits<br/>Nov 2019] --> B[Clean currency fields,<br/>fix overnight visits]
    B --> C[Split each visit into<br/>screening wait + doctor wait]
    C --> D1[Queue 1 table<br/>Entry hour, day,<br/>patient type]
    C --> D2[Queue 2 table<br/>Screening end hour, day,<br/>doctor type, patient type]
    D1 --> E1[Chronological split<br/>70 / 15 / 15]
    D2 --> E2[Chronological split<br/>70 / 15 / 15]
    E1 --> F1[Random Forest<br/>100 trees] --> G1[model_q1_screening.joblib]
    E2 --> F2[Random Forest<br/>100 trees] --> G2[model_q2_doctor.joblib]
```

1. **Data.** 29,998 outpatient encounters after cleaning: entry, consultation and completion
   timestamps, patient type, financial class and doctor type.
2. **Two queues from one.** The dataset records one flow per visit. To match a government clinic,
   each visit's waiting time was split into a screening wait and a doctor wait (see
   [Limitations](#limitations)).
3. **Features.** Screening: `Entry_Hour`, `Entry_Day`, `Patient Type`. Doctor:
   `Screening_End_Hour`, `Screening_End_Day`, `Doctor Type`, `Patient Type`. Categorical columns
   are one-hot encoded inside a scikit-learn `Pipeline`.
4. **Chronological split.** The first 70% of visits (20,998) train the model, the next 15%
   (4,500) validate it and the last 15% (4,500) test it. A random split would let the model
   see the future; this one tests on visits that happen after the training period, like a real
   deployment.
5. **Random Forest Regression**, 100 trees, chosen over Linear Regression (cannot follow morning
   peaks) and SVMs (too slow for a real-time backend). Each tree predicts a wait and the forest
   averages them.

![Random Forest schematic](docs/screenshots/random_forest.png)

### What the models learned

| Screening queue | Doctor queue |
|---|---|
| ![Feature importance, screening](docs/screenshots/feature_importance_screening.png) | ![Feature importance, consultation](docs/screenshots/feature_importance_consultation.png) |
| The hour of arrival carries about 0.8 of the importance and the day of the week most of the rest: early-morning arrivals wait longest | The hour screening ends carries about 0.55, then the doctor type: when you finish screening and which doctor you see decide the second wait |

### Example prediction

A patient arriving at 11:00 on a Monday:

| | |
|---|---|
| ![Screening prediction](docs/screenshots/prediction_screening.png) | ![Doctor prediction](docs/screenshots/prediction_consultation.png) |
| Screening: **8.5 minutes** | Doctor: **24.3 minutes**, total **32.8 minutes** |

## Screenshots

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/login.jpg" width="200" alt="Sign in"></td>
    <td align="center"><img src="docs/screenshots/patient_dashboard_updated.jpg" width="200" alt="Dashboard after update"></td>
    <td align="center"><img src="docs/screenshots/staff_consultation_queue.jpg" width="200" alt="Consultation queue"></td>
    <td align="center"><img src="docs/screenshots/staff_consultation_in_progress.jpg" width="200" alt="Consultation in progress"></td>
    <td align="center"><img src="docs/screenshots/chatbot.jpg" width="200" alt="AI assistant"></td>
  </tr>
  <tr>
    <td align="center">Sign in with email or Google; staff use a separate portal</td>
    <td align="center">The next patient's estimate after staff finished early</td>
    <td align="center">Patients move here automatically after screening</td>
    <td align="center">Staff mark the consultation as done</td>
    <td align="center">The AI assistant gives directions inside the hospital</td>
  </tr>
</table>

| | |
|---|---|
| ![Time check code](docs/screenshots/time_check.png) | ![Supabase queue table](docs/screenshots/supabase_queue_table.png) |
| Opening hours are checked against network time, so changing the phone's clock or time zone does not unlock a queue number | The `hospital_queue` table in Supabase that the app, staff screens and notifications all share |

## Testing

Functional user acceptance testing on the full system (app, Supabase and AI server together):

| ID | Module | Test | Expected | Result |
|---|---|---|---|---|
| UAT-01 | Patient authentication | Log in with valid credentials | Dashboard opens | Pass |
| UAT-02 | Queue dashboard | Open the app to check the queue | Live ticket number and data shown | Pass |
| UAT-03 | Time synchronisation | Change the phone time to get a number outside clinic hours | Request rejected | Pass |
| UAT-04 | Prediction engine | New registration sent through Supabase | Estimate returned without a crash | Pass |
| UAT-05 | Push notification | Queue reaches the calling threshold | Notification appears on the phone | Pass |

The models were checked for pipeline integrity (train and predict on the held-out test set
without errors), valid output (continuous minutes within operating limits) and independence of
the two stages.

## Run it

Requirements: Flutter SDK, Android Studio or VS Code, and an Android emulator or phone.

```bash
git clone https://github.com/amirulfahmiii920-beep/Hospital-Queue-Management-System-Using-Random-Forest.git
cd Hospital-Queue-Management-System-Using-Random-Forest
flutter pub get
cp .env.example .env      # then fill in the values below
flutter run
```

| Variable | What it is |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Your Supabase project with the `patients`, `staff` and `hospital_queue` tables |
| `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` | OneSignal app for push notifications |
| `GEMINI_API_KEY` | Google AI Studio key for the assistant |
| `AI_SERVER_URL` | Your deployment of [qhealth-ai-server](https://github.com/amirulfahmiii920-beep/qhealth-ai-server) |

Never commit `.env`; it is already in `.gitignore`.

## Project structure

```
lib/main.dart          the whole Flutter app: patient, staff, chatbot, notifications
assets/                images and the intro video
.env.example           the keys the app needs
docs/screenshots/      pictures used in this README

qhealth-ai-server      (separate repo)
  app.py               Flask API: /predict_ewt and /predict_consult_ewt
  model_q1_screening.joblib
  model_q2_doctor.joblib
```

## Limitations

- **The two-queue split is simulated.** The Kaggle data has one waiting time per visit. To create
  two queues, screening (5 to 12 min) and consultation (10 to 20 min) durations were drawn at
  random and the remaining wait was divided between the queues at a random 20 to 40% ratio. The
  models therefore learn the time-of-day pattern of the real data, but the exact split between
  the two queues is not measured.
- The data is from one month in 2019 and from outside Malaysia, so it does not know about local
  peaks, outbreaks or public holidays. It should be retrained on real clinic logs before use.
- The models only see time and patient or doctor type. They do not know how many doctors are on
  duty, so they cannot tell a busy day from an understaffed one.
- The features act as a proxy for crowd size; there are no sensors or cameras counting people.
- Security is at proof-of-concept level. Before handling real patient data, authentication,
  encryption and key handling would need to be hardened (for example, sending notifications from
  a server so no service keys ship inside the app).
- If the time service cannot be reached, the app refuses to issue a number rather than trust the
  phone clock.
- Android only; the iOS build is not tested.

## Next steps

1. Pilot in a real government clinic and retrain both models on live data.
2. An admin input for the number of doctors on duty, so estimates react to emergency leave.
3. Extend the assistant to clinic procedures, opening hours and registration documents (built
   separately as the [Clinic Procedure Assistant](https://github.com/amirulfahmiii920-beep/clinic-procedure-assistant)).

## Built with

Flutter (Dart), Supabase, Python, scikit-learn, Flask, OneSignal, Google Gemini, timeapi.io.
