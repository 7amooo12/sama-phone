@echo off
setlocal enabledelayedexpansion

echo Fixing import paths in smartbiztracker_new
echo Replacing 'package:flutter_multi_role_app/' with 'package:smartbiztracker_new/'

:: Find all Dart files in the lib directory
for /r lib %%f in (*.dart) do (
  echo Processing file: %%f
  
  :: Create a temporary file
  type "%%f" > temp.txt
  
  :: Replace flutter_multi_role_app with smartbiztracker_new in import statements
  powershell -Command "(Get-Content temp.txt) -replace 'package:flutter_multi_role_app/', 'package:smartbiztracker_new/' | Set-Content '%%f'"
  
  :: Replace charts_flutter with charts_flutter_updated
  powershell -Command "(Get-Content '%%f') -replace 'package:charts_flutter/', 'package:charts_flutter_updated/' | Set-Content '%%f'"
)

:: Remove temporary file
if exist temp.txt del temp.txt

echo Import paths fixed successfully!

:: Check for remaining flutter_multi_role_app references
echo.
echo Checking for any remaining references to flutter_multi_role_app:
powershell -Command "Get-ChildItem -Path .\lib -Filter *.dart -Recurse | Select-String -Pattern 'flutter_multi_role_app' -List | Select-Object Path | Format-Table -HideTableHeaders"
if %ERRORLEVEL% NEQ 0 echo No remaining references found.

:: Check for remaining charts_flutter references
echo.
echo Checking for any remaining references to charts_flutter:
powershell -Command "Get-ChildItem -Path .\lib -Filter *.dart -Recurse | Select-String -Pattern 'charts_flutter' -List | Select-Object Path | Format-Table -HideTableHeaders"
if %ERRORLEVEL% NEQ 0 echo No remaining references to charts_flutter found.

echo.
echo Script completed. Please run 'flutter pub get' to update dependencies.

cd %~dp0
flutter run -d flutter-tester fix_imports.dart
pause 