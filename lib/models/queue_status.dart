// Status of one stage (screening or consultation) of a queue ticket.
// [value] is the exact text stored in the hospital_queue table.
enum QueueStatus {
  none('None'),
  waiting('Waiting'),
  inProgress('In Progress'),
  completed('Completed'),
  noShow('No Show');

  const QueueStatus(this.value);

  final String value;

  // Unknown or missing values are treated as none
  static QueueStatus fromValue(String? value) => QueueStatus.values.firstWhere(
    (status) => status.value == value,
    orElse: () => QueueStatus.none,
  );

  // Waiting or already in the room
  bool get isActive => this == waiting || this == inProgress;
}
