param([string]$ApiBaseUrl=$env:API_BASE_URL)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$file=Join-Path $root 'server/.dev.vars'
$names=@('CLOUDINARY_CLOUD_NAME','CLOUDINARY_API_KEY','CLOUDINARY_API_SECRET','GOOGLE_SERVICE_ACCOUNT_JSON','FIREBASE_APP_ID','FIREBASE_WEB_CONFIG')
if(Test-Path -LiteralPath $file){
  $content=Get-Content -LiteralPath $file
  foreach($name in $names){
    $found=$content | Where-Object {$_ -match ('^'+[regex]::Escape($name)+'\s*=\s*\S+')}
    Write-Output "$name : $(if($found){'PRESENT (value hidden)'}else{'MISSING'})"
  }
}else{Write-Output 'server/.dev.vars: MISSING. Copy .dev.vars.example and configure locally.'}
if(-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)){
  $uri=[Uri]$ApiBaseUrl
  if($uri.Scheme -ne 'https' -and -not $uri.IsLoopback){throw 'Use HTTPS for a remote Worker.'}
  $health=Invoke-RestMethod -Uri ($ApiBaseUrl.TrimEnd('/')+'/health') -TimeoutSec 20
  if($health.status -ne 'ok'){throw 'Health check did not pass.'}
  Write-Output 'Worker health: PASS (does not verify providers, auth, or D1 CRUD)'
  try{Invoke-WebRequest -Uri ($ApiBaseUrl.TrimEnd('/')+'/api/v1/me') -TimeoutSec 20 | Out-Null;throw 'Protected route accepted an anonymous request.'}
  catch{if($_.Exception.Response.StatusCode.value__ -ne 401){throw};Write-Output 'Anonymous /me: 401 PASS'}
}else{Write-Output 'Worker URL: MISSING; live verification remains BLOCKED_REAL_VERIFICATION.'}
& (Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe') devices
