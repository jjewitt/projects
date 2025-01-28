param (
    [string]$OutputFolder = "C:\\Screenshots",
    [int]$Quality = 50,
    [int]$Interval
)

function Capture-Screenshots {
    param (
        [string]$OutputFolder,
        [int]$Quality = 50
    )

    Add-Type -AssemblyName System.Drawing

    # Ensure the output folder exists
    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory | Out-Null
    }

    # Get screen bounds
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $index = 1

    foreach ($screen in $screens) {
        $bounds = $screen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

        # Save screenshot to file
        $jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)

        $fileName = "$OutputFolder\\Screenshot_$index_$timestamp.jpg"
        #$fileName = "C:\\Screenshots\\Screenshot.jpg"
        $bitmap.Save($fileName, $jpegEncoder, $encoderParams)

        $graphics.Dispose()
        $bitmap.Dispose()
        $index++
    }
}

function Start-ScreenshotCapture {
    param (
        [string]$OutputFolder,
        [int]$IntervalSeconds = 3600,  # Interval in seconds
        [int]$Quality = 50
    )

    while ($true) {
        Capture-Screenshots -OutputFolder $OutputFolder -Quality $Quality
        Start-Sleep -Seconds $IntervalSeconds
    }
}

# Main logic
if ($Interval) {
    # Start recurring screenshot capture if interval is provided
    Start-ScreenshotCapture -OutputFolder $OutputFolder -IntervalSeconds $Interval -Quality $Quality
} else {
    # Capture a single screenshot if no interval is provided
    Capture-Screenshots -OutputFolder $OutputFolder -Quality $Quality
}
