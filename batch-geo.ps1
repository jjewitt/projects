# Install Required Modules if not installed
if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
    Install-Module MSAL.PS -Scope CurrentUser -Force
}

# Define API Details
$tenantId = "YOUR_TENANT_ID"  # Replace with your actual Tenant ID
$csvFilePath = "C:\path\to\your\file.csv"

# Function to Get Authentication Token using Interactive Login
function Get-AuthToken {
    $scopes = @("https://api.security.microsoft.com/.default")
    $authContext = Get-MsalToken -ClientId "d3590ed6-52b3-4102-aeff-aad2292ab01c" -TenantId $tenantId -Scopes $scopes
    return $authContext.AccessToken
}

# Function to Query MDE Live Response API for Geolocation
function Query-Device-Geolocation {
    param ($machineId, $token)

    $scriptContent = @"
Add-Type -AssemblyName System.Device
\$geoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher

# Enable High Accuracy Mode
\$geoWatcher.MovementThreshold = 0  # Ensures any detected movement triggers an update
\$geoWatcher.Start()

# Wait up to 15 seconds for GPS Lock
\$maxWaitTime = 15
\$elapsedTime = 0

while ((\$geoWatcher.Status -ne "Ready" -or \$geoWatcher.Position.Location.IsUnknown) -and (\$elapsedTime -lt \$maxWaitTime)) {
    Start-Sleep -Seconds 1
    \$elapsedTime++
}

\$geoData = \$geoWatcher.Position.Location

if (\$geoData.IsUnknown) {
    Write-Output "Error: Location Unknown"
} else {
    Write-Output "Lat:\$($geoData.Latitude), Lon:\$($geoData.Longitude), Accuracy:\$($geoData.HorizontalAccuracy) meters"
}
"@

    $body = @{
        script      = $scriptContent
        comment     = "Retrieve device geolocation"
        machineId   = $machineId
        timeout     = 60
    } | ConvertTo-Json -Depth 3

    $uri = "https://api.security.microsoft.com/api/machines/$machineId/runScript"
    $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
        return $response.result
    } catch {
        return "Error: $($_.Exception.Message)"
    }
}

# Function to Get Country from Latitude & Longitude
function Get-Country-From-Geolocation {
    param ($latitude, $longitude)

    $geoApiUrl = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude"

    try {
        $geoResponse = Invoke-RestMethod -Uri $geoApiUrl -Method Get
        return $geoResponse.address.country
    } catch {
        return "Error: $($_.Exception.Message)"
    }
}

# Read CSV File
$csvData = Import-Csv -Path $csvFilePath

# Get Defender API Token via Interactive Authentication
$authToken = Get-AuthToken

# Process Each Row
foreach ($row in $csvData) {
    if ([string]::IsNullOrWhiteSpace($row.Response) -or $row.Response -match "Error") {
        # Query Device Geolocation
        $geoResponse = Query-Device-Geolocation -machineId $row.MachineID -token $authToken
        $row.Response = $geoResponse

        # Extract Lat
