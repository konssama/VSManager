@echo off
setlocal enabledelayedexpansion
set "version=1.1"

if not exist %USERPROFILE%\.vscode\profiles.json goto initialise

set "jsonFile=%USERPROFILE%\.vscode\profiles.json"
for /f "usebackq delims=" %%i in (`jq -r ".settings.profilesFolder" %jsonFile%`) do set profilesFolder=%%i

if "%~1"=="open" goto open
if "%~1"=="open-empty" goto open-empty
if "%~1"=="add" goto add
if "%~1"=="create" goto create
if "%~1"=="delete" goto delete
if "%~1"=="edit" goto edit-project

if "%~1"=="create-profile" goto create-profile
if "%~1"=="delete-profile" goto delete-profile
if "%~1"=="clone-profile" goto clone-profile

if "%~1"=="list" goto list

if "%~1"=="help" goto help
if "%~1"=="--help" goto help
if "%~1"=="" goto help

goto error-UnkownCommand

:open
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%.projectPath" %jsonFile%`) do set projectPath=%%i
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%.profilePath" %jsonFile%`) do set profilePath=%%i

code %projectPath% --user-data-dir=%profilePath%\data --extensions-dir=%profilePath%\extensions
goto close


:open-empty
if "%~2"=="" (goto error-NameNotProvided) else (set "profile=%~2")
code --user-data-dir=%profilesFolder%\%profile%\data --extensions-dir=%profilesFolder%\%profile%\extensions
goto close


:add
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%" %jsonFile%`) do set alreadyExists=%%i

set /p projectPath=Enter path to the project folder:
set /p profile=Enter project profile:
set "profilePath=%profilesFolder%\%profile%"

set "projectPath=!projectPath:\=\\!"
set "profilePath=!profilePath:\=\\!"

if "%alreadyExists%"=="null" (
  jq -r ".projects += { \"%name%\":{ projectPath: \"%projectPath%\", profile: \"%profile%\", profilePath: \"%profilePath%\" } }" %jsonFile% > %jsonFile%.tmp && move /y %jsonFile%.tmp %jsonFile% > nul
  echo Project "%name%" added to projects.json.
) else (
  echo "%name%" already exists as a project
)
goto end


:create
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%" %jsonFile%`) do set alreadyExists=%%i

set /p projectPath=Enter path for the folder to be created in:
set "projectPath=%projectPath%\%name%"
set /p profile=Enter project profile:
set "profilePath=%profilesFolder%\%profile%"

set "projectPath=!projectPath:\=\\!"
set "profilePath=!profilePath:\=\\!"

if "%alreadyExists%"=="null" (
  md %projectPath%
  jq -r ".projects += { \"%name%\":{ projectPath: \"%projectPath%\", profile: \"%profile%\", profilePath: \"%profilePath%\" } }" %jsonFile% > %jsonFile%.tmp && move /y %jsonFile%.tmp %jsonFile% > nul
  echo Project "%name%" was created.
) else (
  echo "%name%" already exists as a project
)
goto end


:delete
if "%~2"=="--permanent" goto delete-permanent
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%" %jsonFile%`) do set alreadyExists=%%i

if "%alreadyExists%"=="null" (
  echo Project "%name%" does not exist in projects.json
) else (
  jq "del(.projects.%name%)" %jsonFile% > %jsonFile%.tmp && move /y %jsonFile%.tmp %jsonFile% > nul
  echo Project "%name%" removed from projects.json.
)
goto end


:delete-permanent
if "%~3"=="" (goto error-NameNotProvided) else (set "name=%~3")
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%" %jsonFile%`) do set alreadyExists=%%i
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%.projectPath" %jsonFile%`) do set projectPath=%%i

if %alreadyExists%=="null" (
  echo Project "%name%" does not exist in projects.json
) else (
  if exist %projectPath% (
    rmdir %projectPath%
    jq "del(.projects.%name%)" %jsonFile% > %jsonFile%.tmp && move /y %jsonFile%.tmp %jsonFile% > nul
    echo Project "%name%" was deleted.
  ) else (
    jq "del(.projects.%name%)" %jsonFile% > %jsonFile%.tmp && move /y %jsonFile%.tmp %jsonFile% > nul
    echo Folder "%projectPath%" was not found, but project "%name%" was removed from projects.json.
  )
)
goto end


:edit-project
goto error-BrokenCommand
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%" %jsonFile%`) do set alreadyExists=%%i
for /f "usebackq delims=" %%i in (`jq -r ".projects.%name%.projectPath" %jsonFile%`) do set oldProjectPath=%%i

set /p projectPath=Enter new path to the project folder:
set "projectPath=%projectPath%\%name%"
set /p profile=Enter new project profile:
set "profilePath=%profilesFolder%\%profile%"

set "projectPath=!projectPath:\=\\!"
set "profilePath=!profilePath:\=\\!"

if "%alreadyExists%"=="null" (
  echo Project "%name%" does not exist in projects.json
) else (
  jq -r ".projects += { \"%name%\":{ projectPath: \"%projectPath%\", profile: \"%profile%\", profilePath: \"%profilePath%\" } }" %jsonFile% > %jsonFile%.tmp && move /y %jsonFile%.tmp %jsonFile% > nul
  if not "%oldProjectPath%"=="%projectPath%" (
    md %projectPath%
    xcopy /l /i %oldProjectPath% %projectPath% /E
    rmdir /s /q %oldProjectPath%
  )
)
goto end


:create-profile
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")

if not exist %profilesFolder%\%name% (
  md %profilesFolder%\%name%
  md %profilesFolder%\%name%\data
  md %profilesFolder%\%name%\extensions
  echo Profile %name% created.
) else (
  echo Profile %name% already exists.
)
goto end


:delete-profile
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")

echo WARNING: YOU ARE ABOUT TO DELETE AN EXTENSION PROFILE.
set /p warning=Enter "delete %name%" if you wish to continue:

if exist %profilesFolder%\%name% (
  if "%warning%"=="delete %name%" (
    rmdir /s /q %profilesFolder%\%name%
    echo Profile %name% deleted.
  )
) else (
  echo Profile %name% does not exist
)
goto end


:clone-profile
if "%~2"=="" (goto error-NameNotProvided) else (set "name=%~2")

set /p newName=Enter the name of %name%'s new clone:

if exist %profilesFolder%\%name% (
  echo Cloning...
  md %profilesFolder%\%newName%

  xcopy /E /I /Q /Y "%profilesFolder%\%name%\extensions" "%profilesFolder%\%newName%\extensions" > nul
  xcopy /E /I /Q /Y "%profilesFolder%\%name%\data\User" "%profilesFolder%\%newName%\data\User" > nul
  echo Created profile %newName%
) else (
  echo Profile %name% does not exists.
)
goto end


:list
jq ".projects" %jsonFile%
goto end


:alias
jq -r ".projects += { \"%name%\":{ projectPath: \"%projectPath%\", profile: \"%profile%\", profilePath: \"%profilePath%\" } }" %jsonFile% > %jsonFile%.tmp && move /y %jsonFile%.tmp %jsonFile% > nul
goto end


:initialise
rem check if jq/vscode are installed

set "jsonFile=%USERPROFILE%\.vscode\profiles.json"

set /p profilesFolder=Enter an empty folder path for the profiles to be stored:
if not exist %profilesFolder% (md %profilesFolder%)
set "profilesFolder=!profilesFolder:\=\\!"

echo { > %jsonFile%
echo   "projects": {}, >> %jsonFile%
echo   "settings": { >> %jsonFile%
echo     "profilesFolder": "%profilesFolder%" >> %jsonFile%
echo   } >> %jsonFile%
echo } >> %jsonFile%

goto help


:error-UnkownCommand
echo Unkown command "%~1"
echo Use "vsmanager help" to see all available commands
goto end


:error-NameNotProvided
echo Error: name not provided. Use profiles --help to see the structure of all commands.
goto end

:error-BrokenCommand
echo This command is curenntly broken.
goto end


:help
echo Welcome to VS Manager.
echo Version: %version%

echo Available commands:
echo "open <project>"
echo Opens a project in vscode with the correct profile.

echo "open-empty <profile>"
echo Opens vscode in said profile, without opening a folder.

echo "add <project>"
echo Registers an already existing folder to the manager.

echo "create <project>"
echo Creates a new folder <project> and registers it to the manager.

echo "delete <project>"
echo Remove a projects from the manager. Use the --permanent flag to delete the entire project.

echo "edit <project>"
echo Allows you to edit change the path and profile of the project. editing the path WILL MOVE THE FOLDER TO SAID PATH.

echo "create-profile <profile>"
Creates a new profile that can be used in many projects.

echo "delete-profile <profile>"
echo Deletes a profile

echo "clone-profile <profile>"
echo Clones profile <profile> and gives it a new name.

echo "list"
echo Prints the json file with all the registered projects.

goto end

:close
exit
:end