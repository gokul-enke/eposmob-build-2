; Local Inno Setup script for CLOUDPOS (x64)
; Prefer building from repo root with: iscc inno_setup.iss
; This file mirrors the same packaging rules for local/manual builds.

#define MyAppName "CLOUDPOS"
#define MyAppVersion "1.0"
#define MyAppPublisher "ENKE"
#define MyAppURL "https://enke.ae/"
#define MyAppExeName "cloudpos.exe"

[Setup]
AppId={{5A15344D-601E-49CD-AD46-C2F1C2B21F3D}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UsePreviousAppDir=no
DisableProgramGroupPage=yes
OutputDir=installers
OutputBaseFilename=EposMachine
SolidCompression=yes
WizardStyle=modern
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb,*.lib,*.exp,*.ilk"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
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
