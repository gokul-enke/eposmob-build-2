# Pine Labs Terminal Integration Setup Guide

## 🚨 Issue: Invalid Application Id (ResponseCode: 14)

If you're getting this error:
```json
{
  "ResponseCode": 14,
  "ResponseMsg": "Invalid Application Id"
}
```

This means you're using **demo credentials** instead of your actual Pine Labs merchant credentials.

## 📋 How to Get Your Pine Labs Credentials

### Method 1: Pine Labs Merchant Dashboard
1. Log in to your Pine Labs merchant portal
2. Navigate to **Settings** → **API Credentials** or **Integration Settings**
3. Look for:
   - **Application ID** (32-character hexadecimal string)
   - **User ID** (your merchant user ID)

### Method 2: Contact Pine Labs Support
Contact Pine Labs technical support and request:
- Your **Application ID**
- Your **User ID**
- Integration documentation for Plutus Smart terminals

**Pine Labs Support:**
- Email: support@pinelabs.com
- Phone: Check your merchant agreement for support number
- Website: https://www.pinelabs.com/support

### Method 3: Check Your Onboarding Documentation
Review the documentation you received when you signed up for Pine Labs services. Your credentials should be included there.

## ⚙️ Configuring Your Credentials

### Step 1: Update Configuration File

Open: `lib/config/pine_labs_config.dart`

Replace these placeholders with your actual credentials:

```dart
class PineLabsConfig {
  // Replace with YOUR actual Application ID
  static const String applicationId = "YOUR_ACTUAL_APPLICATION_ID_HERE";
  
  // Replace with YOUR actual User ID
  static const String userId = "YOUR_ACTUAL_USER_ID_HERE";
  
  // ... rest of the file
}
```

### Example (with dummy values - DO NOT USE):
```dart
class PineLabsConfig {
  static const String applicationId = "abc123def456789012345678901234ab";
  static const String userId = "MERCHANT_12345";
  // ... rest
}
```

## ✅ Verify Your Setup

After updating the credentials:

1. **Rebuild your app:**
   ```bash
   flutter clean
   flutter build apk
   ```

2. **Test the integration:**
   - Try processing a small test transaction (1 or 10)
   - Check the logs for successful binding and transaction

3. **Expected success logs:**
   ```
   ✅ [PineLabs] Binding SUCCESS
   💳 [PineLabs] Processing sale: 10, Ref: REF-xxx
   📥 [PineLabs] Transaction result: {"Response":{"ResponseCode":0, ...}}
   ```

## 🔒 Security Best Practices

### ⚠️ DO NOT:
- Commit your actual credentials to version control
- Share your Application ID publicly
- Use production credentials in debug/test builds

### ✅ RECOMMENDED:
1. **For multiple environments**, use build flavors:
   ```dart
   // lib/config/pine_labs_config_dev.dart (test credentials)
   // lib/config/pine_labs_config_prod.dart (production credentials)
   ```

2. **Add to `.gitignore`:**
   ```
   lib/config/pine_labs_config.dart
   ```

3. **Use environment variables** (for advanced setups):
   ```dart
   static const String applicationId = String.fromEnvironment(
     'PINE_LABS_APP_ID',
     defaultValue: 'YOUR_ACTUAL_APPLICATION_ID_HERE',
   );
   ```

## 🧪 Testing Checklist

- [ ] Credentials obtained from Pine Labs
- [ ] Configuration file updated with actual values
- [ ] App rebuilt after configuration changes
- [ ] Service binding successful (no errors)
- [ ] Test transaction (small amount) successful
- [ ] Response parsing working correctly
- [ ] Production testing on actual terminal device

## 📞 Need Help?

If you're still having issues:

1. **Check your logs** for detailed error messages
2. **Verify terminal connectivity** (Pine Labs app installed and working)
3. **Contact Pine Labs support** with your merchant ID
4. **Check terminal compatibility** (Plutus Smart terminals only)

## 🔗 Additional Resources

- [Pine Labs Developer Portal](https://www.pinelabs.com/developers)
- [Plutus Smart Integration Guide](https://www.pinelabs.com/plutus-smart)
- Your Pine Labs account manager

---

**Note:** The demo Application ID `78d73040662d412d9dfdc5b9ce532d19` will ONLY work with Pine Labs demo/test environments. For production use, you MUST use your actual merchant credentials.
