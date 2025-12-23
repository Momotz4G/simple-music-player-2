@echo off
echo ====================================
echo Creating Clean ZIP for macOS Transfer
echo ====================================
echo.

cd /d "c:\Users\MEKEW\source\repos\Simple_Music_Player_New_Gen\simple_music_player_2"

REM Use a new filename to avoid conflicts
set ZIPNAME=simple_music_player_2_macOS_%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%.zip
set ZIPNAME=%ZIPNAME: =0%

echo.
echo Step 1: Creating temporary clean copy...
if exist ..\simple_music_player_2_temp rmdir /S /Q ..\simple_music_player_2_temp
robocopy . ..\simple_music_player_2_temp /E /XD build .dart_tool android\.gradle android\app\build ios\Pods ios\.symlinks macos\Pods windows\build linux\build .idea .vscode /NFL /NDL /NJH /NJS /nc /ns /np

echo.
echo Step 2: Creating ZIP file...
powershell -Command "Compress-Archive -Path '..\simple_music_player_2_temp\*' -DestinationPath '..\%ZIPNAME%' -CompressionLevel Optimal -Force"

echo.
echo Step 3: Cleaning up temporary files...
rmdir /S /Q ..\simple_music_player_2_temp

echo.
echo Step 4: Verifying ZIP...
powershell -Command "if (Test-Path '..\%ZIPNAME%') { $size = (Get-Item '..\%ZIPNAME%').Length / 1MB; Write-Host 'SUCCESS! ZIP Size:' ([math]::Round($size, 2)) 'MB'; Write-Host 'Location: ..\%ZIPNAME%' } else { Write-Host 'ERROR: ZIP not created!' }"

echo.
echo ====================================
echo DONE!
echo ====================================
echo.
pause
