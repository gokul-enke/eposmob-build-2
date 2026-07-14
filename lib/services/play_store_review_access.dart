class PlayStoreReviewAccess {
  const PlayStoreReviewAccess._();

  static const String reviewerEmail = String.fromEnvironment(
    'PLAY_STORE_REVIEWER_EMAIL',
    defaultValue: 'playstoresaeles@funzcart.in',
  );

  static const String tenantKey = String.fromEnvironment(
    'PLAY_STORE_REVIEWER_API_KEY',
    defaultValue: 'DEMO_FUNZCART_vqguo7a24ezI8a69o2q0FlQsPXPZRzrw',
  );

  static bool matchesEmail(String email) =>
      email.trim().toLowerCase() == reviewerEmail.toLowerCase();
}
