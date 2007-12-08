; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

[Setup]
AppCopyright=Copyright 2005-2007 Matt Mackall and others
AppName=Mercurial
AppVerName=Mercurial snapshot
InfoAfterFile=contrib/win32/postinstall.txt
LicenseFile=COPYING
ShowLanguageDialog=yes
AppPublisher=Matt Mackall and others
AppPublisherURL=http://www.selenic.com/mercurial
AppSupportURL=http://www.selenic.com/mercurial
AppUpdatesURL=http://www.selenic.com/mercurial
AppID={{4B95A5F1-EF59-4B08-BED8-C891C46121B3}
AppContact=mercurial@selenic.com
OutputBaseFilename=Mercurial-snapshot
DefaultDirName={pf}\Mercurial
SourceDir=..\..
VersionInfoDescription=Mercurial distributed SCM
VersionInfoCopyright=Copyright 2005-2007 Matt Mackall and others
VersionInfoCompany=Matt Mackall and others
InternalCompressLevel=max
SolidCompression=true
SetupIconFile=contrib\favicon.ico
AllowNoIcons=true
DefaultGroupName=Mercurial
PrivilegesRequired=none

[Files]
Source: contrib\mercurial.el; DestDir: {app}/Contrib
Source: contrib\vim\*.*; DestDir: {app}/Contrib/Vim
Source: contrib\zsh_completion; DestDir: {app}/Contrib
Source: contrib\win32\ReadMe.html; DestDir: {app}; Flags: isreadme
Source: contrib\win32\mercurial.ini; DestDir: {app}; DestName: Mercurial.ini; Flags: confirmoverwrite
Source: contrib\win32\postinstall.txt; DestDir: {app}; DestName: ReleaseNotes.txt
Source: dist\hg.exe; DestDir: {app}; AfterInstall: Touch('{app}\hg.exe.local')
Source: dist\library.zip; DestDir: {app}
Source: dist\mfc71.dll; DestDir: {app}
Source: dist\msvcr71.dll; DestDir: {app}
Source: dist\w9xpopen.exe; DestDir: {app}
Source: dist\add_path.exe; DestDir: {app}
Source: doc\*.txt; DestDir: {app}\Docs
Source: doc\*.html; DestDir: {app}\Docs
Source: templates\*.*; DestDir: {app}\Templates; Flags: recursesubdirs createallsubdirs
Source: CONTRIBUTORS; DestDir: {app}; DestName: Contributors.txt
Source: COPYING; DestDir: {app}; DestName: Copying.txt

[INI]
Filename: {app}\Mercurial.url; Section: InternetShortcut; Key: URL; String: http://www.selenic.com/mercurial/

[UninstallDelete]
Type: files; Name: {app}\Mercurial.url

[Icons]
Name: {group}\Uninstall Mercurial; Filename: {uninstallexe}
Name: {group}\Mercurial Command Reference; Filename: {app}\Docs\hg.1.html
Name: {group}\Mercurial Web Site; Filename: {app}\Mercurial.url

[Run]
Filename: "{app}\add_path.exe"; Parameters: "{app}"; Flags: postinstall; Description: "Add the installation path to the search path"

[UninstallRun]
Filename: "{app}\add_path.exe"; Parameters: "/del {app}"

[UninstallDelete]
Type: files; Name: "{app}\hg.exe.local"

[Code]
procedure Touch(fn: String);
begin
  SaveStringToFile(ExpandConstant(fn), '', False);
end;
