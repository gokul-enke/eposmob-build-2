$ErrorActionPreference = 'Stop'
$taskPlan = Get-Content -LiteralPath 'build/receipt_live_audit/2026-09-29_thermal_control_sweep_plan.json' -Raw | ConvertFrom-Json
foreach ($taskGroup in ($taskPlan | Where-Object { $_.group -in @('sales', 'combined') })) {
    $taskLog = "build/receipt-thermal-particulars-repair-$($taskGroup.group)-$($taskGroup.case).log"
    Write-Output "Repair rendering $($taskGroup.document) / $($taskGroup.case)"
    & 'C:/src/flutter/bin/flutter.bat' test test/receipt_output_matrix_test.dart `
        '--dart-define=RECEIPT_OUTPUT_MATRIX=true' `
        "--dart-define=RECEIPT_CONFIG_SNAPSHOT=$($taskGroup.snapshot)" `
        "--dart-define=RECEIPT_DOCUMENT_FILTER=$($taskGroup.document)" `
        '--dart-define=RECEIPT_CONTROL_SWEEP=true' `
        '--dart-define=RECEIPT_CONTROL_FILTER=showParticulars' `
        '--dart-define=RECEIPT_CONTROL_KIND=thermal' `
        '--dart-define=RECEIPT_TRACE_THERMAL=true' *> $taskLog
    if ($LASTEXITCODE -ne 0) { throw "Repair rendering failed: $taskLog" }
}
