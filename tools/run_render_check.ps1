param(
    [Parameter(Mandatory)][string]$Script,
    [Parameter(Mandatory)][string]$Name,
    [string[]]$UserArgs = @(),
    [int]$TimeoutSeconds = 40,
    [Nullable[int]]$ScreenIndex = $null
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$screenCount = [System.Windows.Forms.Screen]::AllScreens.Count
if ($screenCount -lt 1) { throw 'No Windows screens are available for the render check.' }
if ($null -ne $ScreenIndex -and ($ScreenIndex -lt 0 -or $ScreenIndex -ge $screenCount)) {
    throw "ScreenIndex $ScreenIndex is out of range for $screenCount Windows screen(s)."
}
$selectedScreenIndex = if ($null -ne $ScreenIndex) { [int]$ScreenIndex } elseif ($screenCount -gt 1) { 1 } else { 0 }
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$logDirectory = Join-Path $projectRoot 'docs\verification'
$stdoutPath = Join-Path $logDirectory "$Name.stdout.log"
$stderrPath = Join-Path $logDirectory "$Name.stderr.log"
$arguments = @('--path', ('"' + $projectRoot + '"'), '--screen', [string]$selectedScreenIndex, '--script', $Script)
if ($UserArgs.Count -gt 0) { $arguments += @('--') + $UserArgs }
$checkProcess = Start-Process -FilePath 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
if (-not $checkProcess.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $checkProcess.Id
    throw "$Name timed out; only verification process $($checkProcess.Id) was stopped."
}
$checkProcess.Refresh()
$outputLines = @(Get-Content -LiteralPath $stdoutPath) + @(Get-Content -LiteralPath $stderrPath)
$outputLines | Write-Output
if ($checkProcess.ExitCode -ne 0 -or ($outputLines | Select-String -Pattern '^(SCRIPT ERROR|ERROR|WARNING|FAIL):')) {
    throw "$Name failed (exit $($checkProcess.ExitCode))."
}
Write-Output "PASS $Name (exit 0; screen index $selectedScreenIndex of $screenCount Windows screen(s); original editor untouched)"
