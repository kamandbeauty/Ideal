; پارسی‌گو — Inno Setup 6 script (classic Setup.exe around the portable build)
;
;   windows\build-portable.bat          -> dist\Parsigo-1.1.0-windows-x64\
;   windows\build-installer.bat         -> dist\Parsigo-Setup-1.1.0.exe
;
; The wizard is in English (Inno Setup ships no Persian translation); the app
; itself is Persian. Everything is installed per-user, so no admin prompt and
; no writes to Program Files: the model and your audio data live in
; %LOCALAPPDATA%\Parsigo, which is what desktop/paths.py picks when the
; portable.txt marker is absent (this script deliberately does not install it).

#define AppName "Parsigo"
#define AppNameFa "پارسی‌گو"
#define AppVersion "1.1.0"
#define AppPublisher "Parsigo"
#define AppExe "Parsigo.exe"

#ifndef AppDir
  #define AppDir "..\dist\Parsigo-" + AppVersion + "-windows-x64"
#endif
#define SourceDir AppDir

[Setup]
AppId={{9C0B5A11-3C4E-4B77-9F0C-6F1B2B6A7D31}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppNameFa} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppNameFa}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=Parsigo-Setup-{#AppVersion}
SetupIconFile=..\desktop\assets\parsigo.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppNameFa} ({#AppName})
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
InfoAfterFile={#SourceDir}\README-FIRST.txt
MinVersion=10.0
DiskSpanning=no
AllowNoIcons=yes
DisableWelcomePage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "autostart"; Description: "Start Parsigo when I sign in"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "portable.txt,data\*,model\*"
; (portable.txt is excluded above: the marker would put the model and your
;  audio inside the install folder, which Inno's copy is not meant to grow)

[InstallDelete]
Type: files; Name: "{app}\portable.txt"

[Icons]
Name: "{group}\{#AppNameFa}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\desktop\assets\parsigo.ico"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#AppNameFa}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppNameFa}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\desktop\assets\parsigo.ico"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userstartup}\{#AppNameFa}"; Filename: "{app}\{#AppExe}"; Tasks: autostart

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppNameFa}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; the app recreates these; leaving them would keep stale bytecode after an update
Type: filesandordirs; Name: "{app}\python\Lib\site-packages\__pycache__"
Type: dirifempty; Name: "{app}\data"
Type: dirifempty; Name: "{app}\model"

[Code]
// The model (~470MB) is downloaded on first run, so an upgrade must not wipe
// it: it lives outside {app} anyway, but users who changed PARSIGO_MODEL_DIR
// will also be fine. Nothing to do beyond not shipping it.
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
