$ErrorActionPreference = 'Stop'
$taskPython = 'C:/Users/gokul/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
foreach ($taskCase in @('en', 'ar', 'both', 'empty_en', 'table_en')) {
    $taskSnapshot = "build/receipt_live_audit/2026-09-29_sales_$taskCase.json"
    $taskRoot = "build/receipt_live_render_2026-09-29_sales_$($taskCase)_b2c_thermal_control_sweep_filtered_showInvoiceTitle_thermal_trace_only_Bill"
    $taskLog = "build/receipt-thermal-b2c-title-$taskCase.log"
    Write-Output "Rendering active B2C title baseline/off: $taskCase"
    & 'C:/src/flutter/bin/flutter.bat' test test/receipt_output_matrix_test.dart `
        --dart-define=RECEIPT_OUTPUT_MATRIX=true `
        "--dart-define=RECEIPT_CONFIG_SNAPSHOT=$taskSnapshot" `
        '--dart-define=RECEIPT_DOCUMENT_FILTER=Bill' `
        --dart-define=RECEIPT_CUSTOMER_TYPE=B2C `
        --dart-define=RECEIPT_CONTROL_SWEEP=true `
        --dart-define=RECEIPT_CONTROL_KIND=thermal `
        --dart-define=RECEIPT_TRACE_THERMAL=true `
        --dart-define=RECEIPT_CONTROL_FILTER=showInvoiceTitle *> $taskLog
    if ($LASTEXITCODE -ne 0) { throw "B2C thermal title render failed: $taskLog" }
    $taskAuditLog = "build/receipt-thermal-b2c-title-$taskCase-audit.log"
    & $taskPython -X utf8 tool/verify_thermal_control_sweep.py $taskRoot $taskSnapshot 'Bill' *> $taskAuditLog
    if ($LASTEXITCODE -ne 0) { throw "B2C thermal title audit failed: $taskAuditLog" }
    $taskAudit = Get-Content -LiteralPath "$taskRoot/thermal_control_audit.json" -Raw | ConvertFrom-Json
    if ($taskAudit.unwitnessed -ne 0 -or $taskAudit.outputs -ne 34) { throw 'Missing active B2C title witness' }
    Get-Content -LiteralPath $taskAuditLog -Tail 1
}
