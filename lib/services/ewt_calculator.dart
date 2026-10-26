// Estimated waiting time (EWT) rules for both queues.
// Kept free of Flutter and Supabase so they can be unit tested.

// Used when the AI server cannot be reached or returns an error
const int defaultScreeningBaseMinutes = 25;
const int defaultConsultBaseMinutes = 20;

// When nobody is ahead, the patient is told 5 minutes
const int emptyQueueMinutes = 5;

// Extra minutes added on top of the longest wait already in the queue
const int screeningStepMinutes = 5;
const int consultStepMinutes = 15;

// Push notification goes out 3 minutes before the patient's turn
const int reminderLeadSeconds = 180;

// SCREENING EWT FOR A NEW PATIENT
int calculateScreeningEwt({
  required int patientsAhead,
  required int maxExistingEwt,
  required int aiBaseMinutes,
}) {
  if (patientsAhead == 0) return emptyQueueMinutes;

  final int stepped = maxExistingEwt + screeningStepMinutes;
  return stepped < aiBaseMinutes ? aiBaseMinutes : stepped;
}

// DOCTOR EWT FOR A PATIENT WHO HAS JUST FINISHED SCREENING
int calculateDoctorEwt({
  required int patientsWaiting,
  required int maxConsultEwt,
  required int aiBaseMinutes,
}) {
  if (patientsWaiting == 0) return emptyQueueMinutes;

  // Nobody has a doctor EWT yet, so the AI estimate is all we have
  if (maxConsultEwt == 0) return aiBaseMinutes;

  // Second patient onwards: add a buffer to the longest wait
  final int stepped = maxConsultEwt + consultStepMinutes;
  return stepped < aiBaseMinutes ? aiBaseMinutes : stepped;
}

// SECONDS FROM NOW UNTIL THE "YOUR TURN IS NEAR" NOTIFICATION
// Zero or less means it is too late to schedule one.
int reminderDelaySeconds(int ewtMinutes) =>
    (ewtMinutes * 60) - reminderLeadSeconds;
