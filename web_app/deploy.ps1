# Build Flutter web (release) and deploy to Firebase Hosting.
# Project: daao-a20c6
# Site: professor-profiling-test -> https://professor-profiling-test.web.app
# (Requires Hosting site "professor-profiling-test" to exist in that project — see below.)
#
# Do not commit secrets. Example:
#   $env:SUPABASE_URL = "https://YOUR_PROJECT.supabase.co"
#   $env:SUPABASE_ANON_KEY = "eyJ..."   # Project Settings -> API -> anon public
#   .\deploy.ps1

param(
  [string] $SupabaseUrl = $env:SUPABASE_URL,
  [string] $SupabaseAnonKey = $env:SUPABASE_ANON_KEY,
  [string] $FirebaseProject = "daao-a20c6",
  [string] $HostingTarget = "profiling"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
  Write-Error "Set SUPABASE_URL and SUPABASE_ANON_KEY (Supabase Dashboard -> API), then run again."
}

flutter build web --release `
  "--dart-define=SUPABASE_URL=$SupabaseUrl" `
  "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ([string]::IsNullOrWhiteSpace($HostingTarget)) {
  firebase deploy --only hosting --project $FirebaseProject
} else {
  firebase deploy --only "hosting:$HostingTarget" --project $FirebaseProject
}
