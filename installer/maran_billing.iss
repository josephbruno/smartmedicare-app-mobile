; Inno Setup script for Maran Billing (Flutter Windows).
; Prefer building via: scripts\build-windows-installer.ps1
; Version/defines can be overridden: ISCC /DMyAppVersion=1.0.0 ...

#ifndef MyAppName
  #define MyAppName "Maran Billing"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "Bestwave Innovation"
#endif
#ifndef MyAppURL
  #define MyAppURL "https://bestwaveinnovation.com"
#endif
#ifndef MyAppExeName
  #define MyAppExeName "mobile.exe"
#endif
; Stable AppId — do not change between releases (upgrades rely on this).
#ifndef MyAppId
  #define MyAppId "{{8F3C2A1B-6D4E-4B9A-9C1F-2E7A5D0B8F31}}"
#endif
#ifndef FlutterReleaseDir
  #define FlutterReleaseDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist\windows"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
; Per-user install (Local AppData) so auto-update does not need UAC/admin.
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=MaranBilling-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
UsedUserAreasWarning=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Full Flutter Windows release bundle (exe + DLLs + data/)
Source: "{#FlutterReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; In-app updater (also staged into Release by build-zip-upload-update.bat)
Source: "..\updater\Update.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\updater\Update.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
