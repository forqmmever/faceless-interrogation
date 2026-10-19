# Run a Godot scene without letting its window sit on top / steal focus.
# User request (2026-10-19): "if you need to open the game window for screenshots
# or debugging, do not keep it in the foreground."
# Pure ASCII on purpose (Windows + non-ASCII paths = garbled output).
param(
  [Parameter(Mandatory = $true)][string]$Scene,
  [string]$ProjectDir = "D:\workbuddy\2026-10-11-09-19-59",
  [string]$Godot = "D:\WorkBuddy\godot\Godot_v4.3-stable_win64.exe",
  [string]$Log = ""
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32NoFocus {
  [DllImport("user32.dll")]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")]
  public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
    int X, int Y, int cx, int cy, uint uFlags);
}
"@

$HWND_BOTTOM = [IntPtr]1
$SWP_NOSIZE = 0x0001
$SWP_NOMOVE = 0x0002
$SWP_NOACTIVATE = 0x0010
$SW_SHOWNOACTIVATE = 4

if ($Log -ne "") {
  $proc = Start-Process -FilePath $Godot -ArgumentList @("--path", $ProjectDir, $Scene) `
    -PassThru -RedirectStandardOutput $Log -RedirectStandardError "$Log.err"
} else {
  $proc = Start-Process -FilePath $Godot -ArgumentList @("--path", $ProjectDir, $Scene) -PassThru
}
Write-Host "started pid=$($proc.Id) scene=$Scene"

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 80; $i++) {
  Start-Sleep -Milliseconds 250
  $proc.Refresh()
  if ($proc.HasExited) { break }
  if ($proc.MainWindowHandle -ne 0) { $hwnd = $proc.MainWindowHandle; break }
}

if ($hwnd -ne [IntPtr]::Zero) {
  # push to the bottom of the z-order and show it without activating
  [Win32NoFocus]::SetWindowPos($hwnd, $HWND_BOTTOM, 0, 0, 0, 0,
    ($SWP_NOSIZE -bor $SWP_NOMOVE -bor $SWP_NOACTIVATE)) | Out-Null
  [Win32NoFocus]::ShowWindow($hwnd, $SW_SHOWNOACTIVATE) | Out-Null
  Write-Host "window pushed to back (hwnd=$hwnd)"
} else {
  Write-Host "no main window found (headless scene?)"
}

$proc.WaitForExit()
Write-Host "exit=$($proc.ExitCode)"
