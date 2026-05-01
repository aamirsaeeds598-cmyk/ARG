enum JobStatus {
  open('open'),
  assigned('assigned'),
  inProgress('in_progress'),
  done('done');

  const JobStatus(this.value);
  final String value;

  static JobStatus fromValue(String? v) {
    return JobStatus.values.firstWhere(
      (s) => s.value == v,
      orElse: () => JobStatus.open,
    );
  }
}

