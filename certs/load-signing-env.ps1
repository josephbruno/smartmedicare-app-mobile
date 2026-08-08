# Auto-generated â€” loads Maran local signing credentials into this PowerShell session.
# Dot-source before building:  . .\certs\load-signing-env.ps1
$env:MARAN_SIGN_PFX_PATH = 'D:\\bestwaveinnovation\\Projects\\maran-clinic\\maran-billing-flutter-app\\certs\\maran-codesign.pfx'
$env:MARAN_SIGN_PFX_PASSWORD = Get-Content -LiteralPath 'D:\\bestwaveinnovation\\Projects\\maran-clinic\\maran-billing-flutter-app\\certs\\maran-codesign.password' -Raw
$env:MARAN_SIGN_PFX_PASSWORD = $env:MARAN_SIGN_PFX_PASSWORD.Trim()
$env:MARAN_SIGN_TIMESTAMP_URL = 'http://timestamp.digicert.com'
$env:MARAN_SIGN_SELF_SIGNED = '1'
Write-Host "Loaded signing env from certs\ (self-signed). SmartScreen may still warn on other PCs."
