@{
  # App URL passed to Flutter as BASE_URL for both store builds.
  BaseUrl = "https://eeezeeerp.cloudposai.com"

  GooglePlay = @{
    PackageName        = "com.enke.cloudposai"
    Track              = "production" # e.g. internal, alpha, beta, production
    ReleaseStatus      = "completed"  # e.g. draft, inProgress, completed
    # ServiceAccountJson = "C:\\secure\\google-play-service-account.json"
    # Or set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON instead.
  }

  MicrosoftStore = @{
    # These identifiers are safe to keep here, but environment variables also work:
    # MS_STORE_TENANT_ID, MS_STORE_CLIENT_ID, MS_STORE_SELLER_ID.
    TenantId = ""
    ClientId = ""
    SellerId = ""
    # Always set the secret in the MS_STORE_CLIENT_SECRET environment variable.
  }

  GoogleDrive = @{
    # Name of an authenticated rclone Google Drive remote (without the colon).
    Remote = "gdrive"
    Folder = "CloudPOS/releases"
  }
}
