[Setup]
AppName=AL SAKR
AppVersion=1.0.2
DefaultDirName={autopf}\AL-SAKR
DefaultGroupName=AL SAKR
OutputDir=.\build\windows\installer
OutputBaseFilename=AlSakr_Setup
SetupIconFile=.\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; ينسخ الملفات من مجلد الـ Release
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; اختصار قائمة ابدأ بالإنجليزية
Name: "{group}\AL SAKR"; Filename: "{app}\al_sakr.exe"
; اختصار سطح المكتب بالإنجليزية وكبير
Name: "{autodesktop}\AL SAKR"; Filename: "{app}\al_sakr.exe"; Tasks: desktopicon

[Run]
; تشغيل البرنامج بعد التثبيت
Filename: "{app}\al_sakr.exe"; Description: "{cm:LaunchProgram,AL SAKR}"; Flags: nowait postinstall skipifsilent
