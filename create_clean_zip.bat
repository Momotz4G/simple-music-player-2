@echo off
echo ====================================
echo Creating Clean ZIP for macOS Transfer
echo ====================================
echo.

cd /d "c:\Users\MEKEW\source\repos\Simple_Music_Player_New_Gen\simple_music_player_2"

REM Delete old ZIP if exists
if exist ..\simple_music_player_2_clean.zip (
    echo Deleting old ZIP...
    del ..\simple_music_player_2_clean.zip
)

REM Delete old temp if exists
if exist ..\simple_music_player_2_temp (
    echo Deleting old temp folder...
    rmdir /S /Q ..\simple_music_player_2_temp
)

echo.
echo Step 1: Creating temporary clean copy...
robocopy . ..\simple_music_player_2_temp /E /XD build .dart_tool android\.gradle android\app\build ios\Pods ios\.symlinks macos\Pods windows\build linux\build .idea .vscode /NFL /NDL /NJH /NJS /nc /ns /np

echo.
echo Step 2: Creating ZIP file...
powershell -Command "Compress-Archive -Path '..\simple_music_player_2_temp\*' -DestinationPath '..\simple_music_player_2_clean.zip' -CompressionLevel Optimal"

echo.
echo Step 3: Cleaning up temporary files...
rmdir /S /Q ..\simple_music_player_2_temp

echo.
echo Step 4: Verifying ZIP...
powershell -Command "if (Test-Path '..\simple_music_player_2_clean.zip') { $size = (Get-Item '..\simple_music_player_2_clean.zip').Length / 1MB; Write-Host 'ZIP Size:' ([math]::Round($size, 2)) 'MB' } else { Write-Host 'ERROR: ZIP not created!' }"

echo.
echo ====================================
echo DONE! 
echo ZIP Location: ..\simple_music_player_2_clean.zip
echo ====================================
echo.
pause
