param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
$prefs = Get-Content -LiteralPath "$env:APPDATA\com.enke\pos_machine\shared_preferences.json" -Raw | ConvertFrom-Json
$base = $prefs.'flutter.app_url'.TrimEnd('/')
if (([uri]$base).Host -ne 'eposdemo.yougoit.in') {
    throw 'App tenant host does not match this verification task'
}
$headers = @{ Authorization = 'Bearer ' + $prefs.'flutter.access_token'; 'X-Tenant' = $prefs.'flutter.api_key'; Accept = 'application/json' }
$url = $base + '/api/v1/document/document-configs?store_id=' + $prefs.'flutter.active_store_id'
try {
    $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing
} catch {
    throw ('Receipt API request failed: HTTP ' + [int]$_.Exception.Response.StatusCode)
}
$data = $response.Content | ConvertFrom-Json
$selected = [ordered]@{}
foreach ($type in @('Bill','Bill A4','Sales and Return Bill','Sales and Return Bill A4','Return Bill')) {
    $config = $data.document_configurations.$type
    if (!$config) { throw "Missing document: $type" }
    $selected[$type] = $config
}
$data.document_configurations = $selected
$absolute = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($absolute)) | Out-Null
[System.IO.File]::WriteAllText($absolute, ($data | ConvertTo-Json -Depth 50))
foreach ($type in $selected.Keys) {
    [pscustomobject]@{ Type = $type; Id = $selected[$type].id; Language = $selected[$type].language; Theme = $selected[$type].theme }
}
