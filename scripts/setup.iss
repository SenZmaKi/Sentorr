#ifndef AppVersion
  #define AppVersion "3.0.0"
#endif
#ifndef AppArchitecture
  #define AppArchitecture "x64"
#endif
#ifndef SourceDir
  #define SourceDir AddBackslash(SourcePath) + "..\\build\\windows\\" + AppArchitecture + "\\runner\\Release"
#endif
#ifndef OutputDir
  #define OutputDir AddBackslash(SourcePath) + "..\\build\\release\\windows"
#endif

#define AppName "Sentorr"
#define AppPublisher "Sentorr"
#define AppUrl "https://github.com/SenZmaKi/Sentorr"
#define AppExeName "sentorr.exe"
#define AppDataDir "{userappdata}\\com.sentorr.sentorr\\Sentorr\\SentorrData"

#if AppArchitecture == "arm64"
  #define AllowedArchitectures "arm64"
#elif AppArchitecture == "x64"
  #define AllowedArchitectures "x64compatible and not arm64"
#else
  #error Unsupported AppArchitecture. Expected x64 or arm64.
#endif

[Setup]
AppId={{CA87E71C-663D-422E-930E-181CB50C0021}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
ArchitecturesAllowed={#AllowedArchitectures}
ArchitecturesInstallIn64BitMode={#AllowedArchitectures}
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=Sentorr-windows-{#AppArchitecture}-setup
SetupIconFile={#SourcePath}\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  RemoveAppData: Boolean;

function HasCommandLineParameter(const Name: String): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 1 to ParamCount do
  begin
    if CompareText(ParamStr(Index), Name) = 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if (CurStep = ssPostInstall) and HasCommandLineParameter('/LAUNCH') then
  begin
    if not Exec(
      ExpandConstant('{app}\{#AppExeName}'),
      '',
      '',
      SW_SHOWNORMAL,
      ewNoWait,
      ResultCode
    ) then
      Log(Format('Could not relaunch Sentorr. Error code: %d', [ResultCode]));
  end;
end;

function InitializeUninstall(): Boolean;
begin
  if HasCommandLineParameter('/REMOVEAPPDATA') then
    RemoveAppData := True
  else if UninstallSilent or HasCommandLineParameter('/KEEPAPPDATA') then
    RemoveAppData := False
  else
    RemoveAppData :=
      MsgBox(
        'Also remove Sentorr settings, tracked anime, login sessions, cache, and logs?' + #13#10 + #13#10 +
        'Downloaded anime will not be removed.',
        mbConfirmation,
        MB_YESNO or MB_DEFBUTTON2
      ) = IDYES;
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usPostUninstall) and RemoveAppData then
  begin
    if not DelTree(ExpandConstant('{#AppDataDir}'), True, True, True) then
      MsgBox(
        'Some Sentorr application data could not be removed.',
        mbError,
        MB_OK
      );
  end;
end;
