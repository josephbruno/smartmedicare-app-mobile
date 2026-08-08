# Maran Windows code-signing (local)

This folder holds a **self-signed** code-signing certificate for local/dev builds.

## Files (secret â€” do not commit)

| File | Purpose |
|------|---------|
| `maran-codesign.pfx` | Private key + cert (signing) |
| `maran-codesign.password` | PFX password |
| `load-signing-env.ps1` | Sets `MARAN_SIGN_*` for the current shell |
| `maran-codesign.cer` | Public cert only (optional trust on test PCs) |

## Usage

```powershell
cd maran-billing-flutter-app
. .\certs\load-signing-env.ps1
cd scripts
.\build-single-exe.bat
.\build-zip-upload-update.bat
```

Build scripts also auto-detect `certs\maran-codesign.pfx` if env vars are unset.

## Important

- Self-signed signatures **do not** remove Windows SmartScreen "Unknown publisher" on clinic PCs.
- For production, replace this PFX with a **CA-issued** Authenticode certificate (DigiCert, Sectigo, etc.).
- Never commit `.pfx` / `.password` / `load-signing-env.ps1` to git.
