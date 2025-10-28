/// Pine Labs Terminal Configuration
/// 
/// ⚠️ IMPORTANT: Replace these values with your actual Pine Labs credentials
/// You can get these from:
/// 1. Pine Labs merchant dashboard
/// 2. Pine Labs support team
/// 3. Your merchant onboarding documentation
class PineLabsConfig {
  // Your Pine Labs merchant credentials
  static const String applicationId = "4adbc6d7e174411e85174d2fa329919f";
  
  // Your Pine Labs user ID
  static const String userId = "enke";
  
  // These values are standard and typically don't need to change
  static const String methodId = "1001";
  static const String versionNo = "1.0";
  
  // Transaction Types (as per Pine Labs documentation)
  static const int transactionTypeSale = 4001;
  static const int transactionTypeRefund = 4002;
  static const int transactionTypeVoid = 4004;
  
  /// Get the standard transaction header
  static Map<String, dynamic> getTransactionHeader() {
    return {
      "ApplicationId": applicationId,
      "MethodId": methodId,
      "UserId": userId,
      "VersionNo": versionNo,
    };
  }
  
  /// Validate if credentials are configured
  static bool areCredentialsConfigured() {
    return applicationId != "YOUR_ACTUAL_APPLICATION_ID_HERE" &&
        userId != "YOUR_ACTUAL_USER_ID_HERE" &&
        applicationId.isNotEmpty &&
        userId.isNotEmpty;
  }
}
