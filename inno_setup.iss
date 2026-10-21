; Flutter Windows installer for CLOUDPOS (x64)
; Used by GitHub Actions Release CI and local packaging.

; Branding: scripts/build_brand.ps1 passes these from brands/<id>/brand.json.
; The defaults are the CloudPOS brand. Never change them: the AppId, exe name
; and data folder identify existing installs.
#ifndef MyAppName
#define MyAppName "CLOUDPOS"
#endif
#ifndef MyAppId
#define MyAppId "5A15344D-601E-49CD-AD46-C2F1C2B21F3D"
#endif
#ifndef MyAppExeName
#define MyAppExeName "cloudpos.exe"
#endif
#ifndef MyInstallerName
#define MyInstallerName "cloudpos"
#endif
#ifndef MyAppIcon
#define MyAppIcon ".\windows\runner\resources\app_icon.ico"
#endif
; %APPDATA% subfolder: CompanyName\ProductName from the exe version info.
#ifndef MyDataDir
#define MyDataDir "com.enke\pos_machine"
#endif
; GitHub Actions supplies /DMyAppVersion=<pubspec version>.
; Keep a local fallback when compiling this script directly.
#ifndef MyAppVersion
#define MyAppVersion "1.0"
#endif
#ifndef MyAppPublisher
#define MyAppPublisher "ENKE"
#endif
#ifndef MyAppURL
#define MyAppURL "https://enke.ae/"
#endif

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; Expands to the historical "{{GUID}}" spelling; the trailing "}}" is part of
; the registered id ("{GUID}}_is1"), so keep it for upgrades to match.
AppId={{{#MyAppId}}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
; Flutter Windows builds are x64 — install into native 64-bit Program Files
; (not Program Files (x86), which previously caused Bad Image / DLL load issues).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Do not reuse an old (x86) install path on upgrade.
UsePreviousAppDir=no
DisableProgramGroupPage=yes
OutputBaseFilename={#MyInstallerName}-{#MyAppVersion}
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
MinVersion=10.0
; Do not interrupt routine app updates with a restart prompt after the
; VC++ Redistributable runs. Pending changes finish on the next normal reboot.
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Ship the full Release output (exe + all plugin DLLs + data).
; Excludes debug symbols that are not needed at runtime.
; The build always produces cloudpos.exe; each brand installs it under its own name.
Source: ".\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "\cloudpos.exe,*.pdb,*.lib,*.exp,*.ilk,*.msix"
Source: ".\build\windows\x64\runner\Release\cloudpos.exe"; DestDir: "{app}"; DestName: "{#MyAppExeName}"; Flags: ignoreversion
; Use Microsoft's signed installer instead of app-local runtime DLL copies.
Source: ".\installer-assets\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ runtime..."; Flags: waituntilterminated runhidden
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[InstallDelete]
; Remove runtime DLLs bundled by older releases. The official x64
; Redistributable installed above now supplies these system-wide.
Type: files; Name: "{app}\msvcp140.dll"
Type: files; Name: "{app}\vcruntime140.dll"
Type: files; Name: "{app}\vcruntime140_1.dll"
; Clean only products and categories cache when installing/upgrading
; This preserves cart_items, saved_orders, and confirmed_orders
Type: files; Name: "{userappdata}\{#MyDataDir}\epos\hive_data\products.hive"
Type: files; Name: "{userappdata}\{#MyDataDir}\epos\hive_data\products.lock"
Type: files; Name: "{userappdata}\{#MyDataDir}\epos\hive_data\categories.hive"
Type: files; Name: "{userappdata}\{#MyDataDir}\epos\hive_data\categories.lock"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\{#MyDataDir}\epos\hive_data"
Type: dirifempty; Name: "{userappdata}\{#MyDataDir}\epos"
Type: dirifempty; Name: "{userappdata}\{#MyDataDir}"

[Code]
// Remove leftover 32-bit Program Files (x86)\CLOUDPOS from older installers
// so clients do not keep loading a corrupt/stale printer plugin DLL.
procedure CurStepChanged(CurStep: TSetupStep);
var
  OldDir: String;
begin
  if CurStep = ssInstall then
  begin
    OldDir := ExpandConstant('{pf32}\{#MyAppName}');
    if DirExists(OldDir) then
      DelTree(OldDir, True, True, True);
  end;
end;
