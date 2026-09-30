param([ValidateSet('sales', 'combined', 'return')][string]$DocumentGroup)
$ErrorActionPreference = 'Stop'
$taskPlan = Get-Content -LiteralPath 'build/receipt_live_audit/2026-09-29_thermal_control_sweep_plan.json' -Raw | ConvertFrom-Json
$taskPython = 'C:/Users/gokul/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
foreach ($taskGroup in ($taskPlan | Where-Object { $_.group -eq $DocumentGroup })) {
    $taskLog = "build/receipt-thermal-control-$($taskGroup.group)-$($taskGroup.case).log"
    $taskArguments = @('test', 'test/receipt_output_matrix_test.dart',
        '--dart-define=RECEIPT_OUTPUT_MATRIX=true',
        "--dart-define=RECEIPT_CONFIG_SNAPSHOT=$($taskGroup.snapshot)",
        "--dart-define=RECEIPT_DOCUMENT_FILTER=$($taskGroup.document)",
        '--dart-define=RECEIPT_CONTROL_SWEEP=true',
        '--dart-define=RECEIPT_CONTROL_KIND=thermal',
        '--dart-define=RECEIPT_TRACE_THERMAL=true')
    if ($DocumentGroup -eq 'return') {
        $taskArguments += @('--dart-define=RECEIPT_RETURN_BUILDER=true',
                            '--dart-define=RECEIPT_RETURN_STORE_FIXTURE=true')
    }
    Write-Output "Rendering $($taskGroup.document) / $($taskGroup.case): $($taskGroup.expected_outputs) outputs"
    & 'C:/src/flutter/bin/flutter.bat' @taskArguments *> $taskLog
    if ($LASTEXITCODE -ne 0) { throw "Thermal render failed: $taskLog" }
    $taskManifest = Get-Content -LiteralPath "$($taskGroup.root)/manifest.json" -Raw | ConvertFrom-Json
    if ($taskManifest.Count -ne $taskGroup.expected_outputs) { throw 'Incomplete thermal manifest' }
    $taskAuditLog = "build/receipt-thermal-control-$($taskGroup.group)-$($taskGroup.case)-audit.log"
    & $taskPython -X utf8 tool/verify_thermal_control_sweep.py $taskGroup.root $taskGroup.snapshot $taskGroup.document *> $taskAuditLog
    if ($LASTEXITCODE -ne 0) { throw "Thermal audit failed: $taskAuditLog" }
    Get-Content -LiteralPath $taskAuditLog -Tail 1
}
