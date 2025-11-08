# API Response Logger Documentation

## Overview
The API Response Logger automatically captures and logs all API requests and responses to a beautifully formatted HTML file. This makes it easy to debug API issues, track request/response data, and monitor API interactions in real-time.

## Features
✅ **Automatic Logging** - All API responses are automatically logged to `index.html`  
✅ **Beautiful HTML UI** - Color-coded responses with syntax-highlighted JSON  
✅ **Request Tracking** - Logs request body, endpoint, method, and response  
✅ **Error Logging** - Captures and logs errors with full stack traces  
✅ **Status Badges** - Visual indicators for HTTP status codes (200, 201, 400, 500, etc.)  
✅ **Method Badges** - Color-coded HTTP methods (GET, POST, PUT, DELETE)  
✅ **Timestamp** - Each log entry includes precise timestamp  
✅ **JSON Syntax Highlighting** - Formatted and color-coded JSON responses  

## File Location
The API logs are stored at:
```
{ApplicationDocumentsDirectory}/api_responses/index.html
```

On different platforms:
- **Android**: `/data/data/com.example.app/files/api_responses/index.html`
- **iOS**: `{Documents}/api_responses/index.html`
- **Windows**: `{AppData}/api_responses/index.html`

## Usage

### 1. Automatic Logging (Already Integrated)
The `addToOrderAPI` method in `CartProvider` automatically logs all responses:

```dart
// In cart_provider.dart - addToOrderAPI method
await ApiResponseLogger().logApiResponse(
  endpoint: url.toString(),
  method: 'POST',
  requestBody: apiBodyData,
  statusCode: response.statusCode,
  responseBody: response.body,
);
```

### 2. Manual Logging
You can manually log API responses in any provider:

```dart
import '../utils/api_response_logger.dart';

// Log a successful response
await ApiResponseLogger().logApiResponse(
  endpoint: 'https://api.example.com/orders',
  method: 'POST',
  requestBody: {'order_id': 123},
  statusCode: 200,
  responseBody: jsonEncode({'success': true, 'data': {...}}),
);

// Log an error response
await ApiResponseLogger().logApiResponse(
  endpoint: 'https://api.example.com/orders',
  method: 'POST',
  requestBody: {'order_id': 123},
  statusCode: 400,
  responseBody: '{}',
  error: 'Invalid order ID',
);
```

### 3. Helper Functions
Use `ApiLoggerHelper` for common operations:

```dart
import '../utils/api_logger_helper.dart';

// Open logs in browser
await ApiLoggerHelper.openApiLogs();

// Get log file path
String path = await ApiLoggerHelper.getLogFilePath();

// Print log file path to console
await ApiLoggerHelper.printLogFilePath();

// Clear all logs
await ApiLoggerHelper.clearApiLogs();

// Get log file size
String size = await ApiLoggerHelper.getLogFileSize();

// Print log file info
await ApiLoggerHelper.printLogFileInfo();
```

### 4. In Flutter App
Add a debug button to your app to open logs:

```dart
import '../utils/api_logger_helper.dart';

FloatingActionButton(
  onPressed: () async {
    await ApiLoggerHelper.openApiLogs();
  },
  child: Icon(Icons.bug_report),
  tooltip: 'View API Logs',
)
```

## HTML Log File Structure

The generated `index.html` file contains:

```html
<!DOCTYPE html>
<html>
<head>
    <!-- Styling with gradient background, cards, badges -->
</head>
<body>
    <div class="header">
        <h1>🔍 API Response Logger</h1>
    </div>
    
    <!-- Multiple response entries -->
    <div class="response-entry">
        <div class="response-header">
            <span class="method-badge method-post">POST</span>
            <span class="status-badge status-200">200</span>
            <span class="timestamp">2024-01-15 14:30:45</span>
        </div>
        <div class="response-content">
            <div class="section">
                <div class="section-title">📍 Endpoint</div>
                <div class="endpoint-url">https://api.example.com/orders</div>
            </div>
            
            <div class="section">
                <div class="section-title">📤 Request Body</div>
                <div class="json-viewer">
                    <!-- Formatted JSON with syntax highlighting -->
                </div>
            </div>
            
            <div class="section">
                <div class="section-title">📥 Response Body</div>
                <div class="json-viewer">
                    <!-- Formatted JSON with syntax highlighting -->
                </div>
            </div>
        </div>
    </div>
</body>
</html>
```

## Styling Features

### Color Coding
- **HTTP Methods**:
  - POST: Green (#28a745)
  - GET: Blue (#007bff)
  - PUT: Yellow (#ffc107)
  - DELETE: Red (#dc3545)

- **Status Codes**:
  - 200, 201: Green (Success)
  - 400, 401, 403, 404, 500: Red (Error)

### JSON Syntax Highlighting
- **Keys**: Purple (#881391)
- **Strings**: Green (#0b7500)
- **Numbers**: Blue (#0000ff)
- **Booleans**: Red (#d73a49)
- **Null**: Purple (#6f42c1)

## Integration with Existing APIs

To add logging to other API methods, follow this pattern:

```dart
// In any provider method
try {
  final response = await http.post(url, body: json.encode(body), headers: headers);
  
  // Log the response
  await ApiResponseLogger().logApiResponse(
    endpoint: url.toString(),
    method: 'POST',
    requestBody: body,
    statusCode: response.statusCode,
    responseBody: response.body,
  );
  
  // Handle response...
} catch (e) {
  // Log error
  await ApiResponseLogger().logApiResponse(
    endpoint: url.toString(),
    method: 'POST',
    requestBody: body,
    statusCode: 0,
    responseBody: '{}',
    error: e.toString(),
  );
}
```

## Console Output
When an API response is logged, you'll see:
```
✅ API response logged to: /path/to/api_responses/index.html
```

When there's an error:
```
❌ Error logging API response: [error details]
```

## Clearing Logs
To clear all logs and start fresh:

```dart
await ApiResponseLogger().clearLogs();
// Output: ✅ API logs cleared
```

## Debugging Tips

1. **Check Console Output**: Look for "✅ API response logged to:" messages
2. **Monitor File Size**: Use `ApiLoggerHelper.getLogFileSize()` to check if logs are growing
3. **Open in Browser**: Use `ApiLoggerHelper.openApiLogs()` to view formatted logs
4. **Search Logs**: Use browser's Find feature (Ctrl+F) to search through logs
5. **Export Logs**: Copy the HTML file for sharing or archiving

## Performance Considerations

- Logs are written asynchronously to avoid blocking the app
- File operations are wrapped in try-catch to prevent crashes
- Logs accumulate in the file (use `clearLogs()` periodically)
- Each log entry is appended to the file (efficient for large numbers of requests)

## Troubleshooting

### Logs not appearing?
1. Check if `path_provider` dependency is installed
2. Verify file permissions on the device
3. Check console for error messages

### File not opening?
1. Ensure `url_launcher` dependency is installed
2. Check if file path is correct
3. Try opening file manually from file explorer

### Logs too large?
1. Use `ApiLoggerHelper.clearApiLogs()` to clear old logs
2. Consider implementing log rotation (clear logs daily/weekly)

## Dependencies Required
Make sure these are in your `pubspec.yaml`:
```yaml
dependencies:
  path_provider: ^2.0.0
  url_launcher: ^6.0.0
  http: ^0.13.0
  intl: ^0.17.0
```

## Future Enhancements
- [ ] Log rotation (auto-clear old logs)
- [ ] Search functionality in HTML
- [ ] Export logs to CSV/JSON
- [ ] Filter by endpoint/method/status
- [ ] Real-time log viewer widget
- [ ] Performance metrics
