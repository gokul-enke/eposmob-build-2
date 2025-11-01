import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ApiResponseLogger {
  static final ApiResponseLogger _instance = ApiResponseLogger._internal();

  factory ApiResponseLogger() {
    return _instance;
  }

  ApiResponseLogger._internal();

  /// Write API response to index.html file
  Future<void> logApiResponse({
    required String endpoint,
    required String method,
    required Map<String, dynamic> requestBody,
    required int statusCode,
    required String responseBody,
    String? error,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/api_responses/index.html');

      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);

      // Read existing content or create new
      String htmlContent = '';
      if (await file.exists()) {
        htmlContent = await file.readAsString();
        // Remove closing body and html tags to append new content
        htmlContent = htmlContent.replaceAll('</body>\n</html>', '');
      } else {
        htmlContent = _getHtmlHeader();
      }

      // Parse response body
      Map<String, dynamic> parsedResponse = {};
      try {
        parsedResponse = json.decode(responseBody);
      } catch (e) {
        parsedResponse = {'raw_response': responseBody};
      }

      // Create response entry
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final responseEntry = _buildResponseEntry(
        timestamp: timestamp,
        endpoint: endpoint,
        method: method,
        requestBody: requestBody,
        statusCode: statusCode,
        responseBody: parsedResponse,
        error: error,
      );

      htmlContent += responseEntry;
      htmlContent += '</body>\n</html>';

      // Write to file
      await file.writeAsString(htmlContent);
      print('✅ API response logged to: ${file.path}');
    } catch (e) {
      print('❌ Error logging API response: $e');
    }
  }

  /// Build HTML header
  String _getHtmlHeader() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API Response Logger</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            background: white;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            color: #333;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #666;
            font-size: 14px;
        }
        
        .response-entry {
            background: white;
            border-radius: 8px;
            margin-bottom: 20px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            border-left: 5px solid #667eea;
        }
        
        .response-header {
            background: #f8f9fa;
            padding: 15px 20px;
            border-bottom: 1px solid #e9ecef;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
        }
        
        .response-title {
            font-weight: 600;
            color: #333;
            flex: 1;
        }
        
        .timestamp {
            color: #999;
            font-size: 12px;
        }
        
        .method-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            color: white;
        }
        
        .method-post {
            background: #28a745;
        }
        
        .method-get {
            background: #007bff;
        }
        
        .method-put {
            background: #ffc107;
            color: #333;
        }
        
        .method-delete {
            background: #dc3545;
        }
        
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            color: white;
        }
        
        .status-200, .status-201 {
            background: #28a745;
        }
        
        .status-400, .status-401, .status-403, .status-404, .status-500 {
            background: #dc3545;
        }
        
        .response-content {
            padding: 20px;
        }
        
        .section {
            margin-bottom: 20px;
        }
        
        .section-title {
            font-weight: 600;
            color: #333;
            margin-bottom: 10px;
            padding-bottom: 8px;
            border-bottom: 2px solid #667eea;
            display: inline-block;
        }
        
        .json-viewer {
            background: #f5f5f5;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 15px;
            overflow-x: auto;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            line-height: 1.5;
            color: #333;
        }
        
        .json-key {
            color: #881391;
            font-weight: 600;
        }
        
        .json-string {
            color: #0b7500;
        }
        
        .json-number {
            color: #0000ff;
        }
        
        .json-boolean {
            color: #d73a49;
        }
        
        .json-null {
            color: #6f42c1;
        }
        
        .error-section {
            background: #fff5f5;
            border-left: 4px solid #dc3545;
            padding: 15px;
            border-radius: 4px;
            margin-top: 10px;
        }
        
        .error-title {
            color: #dc3545;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .error-message {
            color: #721c24;
            font-size: 13px;
            word-break: break-word;
        }
        
        .endpoint-url {
            background: #f0f0f0;
            padding: 10px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            word-break: break-all;
            margin-top: 8px;
        }
        
        .divider {
            height: 1px;
            background: #e9ecef;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 API Response Logger</h1>
            <p>Real-time API request and response tracking</p>
        </div>
''';
  }

  /// Build individual response entry
  String _buildResponseEntry({
    required String timestamp,
    required String endpoint,
    required String method,
    required Map<String, dynamic> requestBody,
    required int statusCode,
    required Map<String, dynamic> responseBody,
    String? error,
  }) {
    final methodClass = 'method-${method.toLowerCase()}';
    final statusClass = 'status-$statusCode';
    final statusColor = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';

    String entry = '''
        <div class="response-entry">
            <div class="response-header">
                <div class="response-title">
                    <span class="method-badge $methodClass">$method</span>
                    <span class="status-badge $statusClass">$statusCode</span>
                    $statusColor
                </div>
                <div class="timestamp">$timestamp</div>
            </div>
            <div class="response-content">
                <div class="section">
                    <div class="section-title">📍 Endpoint</div>
                    <div class="endpoint-url">$endpoint</div>
                </div>
                
                <div class="divider"></div>
                
                <div class="section">
                    <div class="section-title">📤 Request Body</div>
                    <div class="json-viewer">${_formatJson(requestBody)}</div>
                </div>
                
                <div class="divider"></div>
                
                <div class="section">
                    <div class="section-title">📥 Response Body</div>
                    <div class="json-viewer">${_formatJson(responseBody)}</div>
                </div>
''';

    if (error != null && error.isNotEmpty) {
      entry += '''
                <div class="divider"></div>
                <div class="error-section">
                    <div class="error-title">⚠️ Error</div>
                    <div class="error-message">$error</div>
                </div>
''';
    }

    entry += '''
            </div>
        </div>
''';

    return entry;
  }

  /// Format JSON for HTML display
  String _formatJson(Map<String, dynamic> data) {
    final jsonString = json.encode(data);
    return _highlightJson(jsonString);
  }

  /// Highlight JSON syntax
  String _highlightJson(String jsonString) {
    // Escape HTML
    jsonString = jsonString
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    // Highlight JSON syntax
    jsonString = jsonString
        // Keys
        .replaceAllMapped(RegExp(r'"([^"]+)"\s*:'), (match) {
          return '<span class="json-key">"${match.group(1)}"</span>:';
        })
        // Strings
        .replaceAllMapped(RegExp(r':\s*"([^"]*)"'), (match) {
          return ': <span class="json-string">"${match.group(1)}"</span>';
        })
        // Numbers
        .replaceAllMapped(RegExp(r':\s*(\d+\.?\d*)'), (match) {
          return ': <span class="json-number">${match.group(1)}</span>';
        })
        // Booleans
        .replaceAll('true', '<span class="json-boolean">true</span>')
        .replaceAll('false', '<span class="json-boolean">false</span>')
        // Null
        .replaceAll('null', '<span class="json-null">null</span>');

    // Format with indentation
    return jsonString.replaceAll(',', ',<br>').replaceAll('{', '{<br>').replaceAll('}', '<br>}').replaceAll('[', '[<br>').replaceAll(']', '<br>]');
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/api_responses/index.html');
      if (await file.exists()) {
        await file.delete();
        print('✅ API logs cleared');
      }
    } catch (e) {
      print('❌ Error clearing logs: $e');
    }
  }

  /// Get log file path
  Future<String> getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/api_responses/index.html';
  }
}
