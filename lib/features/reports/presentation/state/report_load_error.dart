/// Why a report has no fresh data on screen.
enum ReportLoadError {
  /// From is after To; nothing was requested.
  invertedRange,

  /// The request failed or returned an invalid response.
  failed,
}
