class FirestorePaths {
  static String user(String uid) => 'users/$uid';

  static String team(String teamId) => 'teams/$teamId';
  static String teamInvites(String teamId) => 'teams/$teamId/invites';
  static String teamInvite(String teamId, String inviteId) =>
      'teams/$teamId/invites/$inviteId';

  static String teamMembers(String teamId) => 'teams/$teamId/members';
  static String teamMember(String teamId, String memberUid) =>
      'teams/$teamId/members/$memberUid';

  static String teamClients(String teamId) => 'teams/$teamId/clients';
  static String teamClient(String teamId, String clientId) =>
      'teams/$teamId/clients/$clientId';

  static String teamQuotes(String teamId) => 'teams/$teamId/quotes';
  static String teamQuote(String teamId, String quoteId) =>
      'teams/$teamId/quotes/$quoteId';

  static String teamRequests(String teamId) => 'teams/$teamId/requests';
  static String teamRequest(String teamId, String requestId) =>
      'teams/$teamId/requests/$requestId';

  static String teamJobs(String teamId) => 'teams/$teamId/jobs';
  static String teamJob(String teamId, String jobId) =>
      'teams/$teamId/jobs/$jobId';

  static String jobVisits(String teamId, String jobId) =>
      'teams/$teamId/jobs/$jobId/visits';
  static String jobVisit(String teamId, String jobId, String visitId) =>
      'teams/$teamId/jobs/$jobId/visits/$visitId';

  static String teamInvoices(String teamId) => 'teams/$teamId/invoices';
  static String teamInvoice(String teamId, String invoiceId) =>
      'teams/$teamId/invoices/$invoiceId';
}

