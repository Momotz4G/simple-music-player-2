
Add-Type -AssemblyName System.Drawing
$files = @("assets/badges/android.png", "assets/badges/windows.png", "assets/badges/macos.png")
foreach ($f in $files) {
    if (Test-Path $f) {
        $img = [System.Drawing.Image]::FromFile((Resolve-Path $f))
        Write-Host "$f : $($img.Width) x $($img.Height)"
        $img.Dispose()
    } else {
        Write-Host "$f not found"
    }
}
