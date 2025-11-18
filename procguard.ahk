; FIXME:
; - Why this does not show in the Task Manager?

; procguard.ahk
; Version: 2.1.0
; Monitor target processes and run specific EXEs based on mode (normal or reverse)
#NoEnv
#SingleInstance, Force
#Persistent
SetBatchLines, -1
SetTitleMatchMode, 2

; --- Hidden 1x1 GUI so Windows treats it as an App (for Task Manager visibility) ---
Gui, +LastFound +AlwaysOnTop +ToolWindow -Caption
Gui, Show, w1 h1, ProcGuardHidden

; --- Paths ---
scriptDir := A_ScriptDir
confFile := scriptDir "\procguard.conf"
logFile := scriptDir "\procguard.log"
enableLog := FileExist(logFile)
; enableLog := true  ; always enable logging
maxLogSize := 1024 * 512 ; 0.5 MB

; --- Logging function (newest logs at top, rolling, efficient) ---
log(msg) {
    global enableLog, logFile, maxLogSize
    if (!enableLog)
        return

    ; Prepare new line
    timeStamp := A_Now
    FormatTime, timeStr, %timeStamp%, yyyy-MM-dd HH:mm:ss
    newLine := "[" timeStr "] " msg "`r`n"

    ; Read only the last maxLogSize bytes (newest portion)
    oldContent := ""
    if FileExist(logFile) {
        file := FileOpen(logFile, "r")
        if IsObject(file) {
            file.Seek(0, 2)  ; go to end
            fileSize := file.Pos
            readPos := (fileSize > maxLogSize) ? fileSize - maxLogSize : 0
            file.Seek(readPos)
            oldContent := file.Read(fileSize - readPos)
            file.Close()
        }
    }

    ; Prepend new line (newest at top)
    newContent := newLine . oldContent

    ; Truncate to maxLogSize if necessary
    if StrLen(newContent) > maxLogSize {
        newContent := SubStr(newContent, 1, maxLogSize)
        ; Optional: trim to last complete line
        pos := InStr(newContent, "`n", false, 0)
        if (pos)
            newContent := SubStr(newContent, 1, pos - 1)
    }

    ; Overwrite file
    FileDelete, %logFile%
    FileAppend, %newContent%, %logFile%
}

; --- Arrays ---
checkProcs := []     ; the process names to check
runCmds := []        ; full command to execute based on mode
intervals := []      ; in ms
lastChecks := []     ; last tick count
modes := []          ; "normal" (default) or "reverse"
lastConfTime := 0

; --- Load config (hot reload) ---
ReloadConfig() {
    global checkProcs, runCmds, intervals, lastChecks, modes, confFile

    checkProcs := []
    runCmds := []
    intervals := []
    lastChecks := []
    modes := []

    Loop, Read, %confFile%
    {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line,1,1) = "#")
            continue

        parts := StrSplit(line, ",")

        ; Need at least process name and command
        if (parts.Length() < 2)
            continue

        checkName := Trim(parts[1])
        runCmd := Trim(parts[2])

        ; Optional third field: interval in seconds (numeric)
        interval := 10
        if (parts.Length() >= 3) {
            third := Trim(parts[3])
            if RegExMatch(third, "^\d+$")
                interval := third
        }

        ; Optional fourth field: mode ("reverse" or default)
        mode := "normal"
        if (parts.Length() >= 4) {
            extra := Trim(parts[4])
            StringLower, extraLower, extra
            if (extraLower = "reverse")
                mode := "reverse"
        }

        checkProcs.Push(checkName)
        runCmds.Push(runCmd)
        intervals.Push(interval * 1000)
        lastChecks.Push(0)
        modes.Push(mode)

        if (mode = "reverse") {
            log("🔄 [Hot-Reload] Monitoring " checkName " (reverse) → will run [" runCmd "] every " interval "s WHEN running")
        } else {
            log("🔄 [Hot-Reload] Monitoring " checkName " → will run [" runCmd "] every " interval "s WHEN missing")
        }
    }
}

; --- Initial config load ---
if !FileExist(confFile) {
    log("❌ Config file missing. Exiting.")
    MsgBox, 16, ProcGuard, Config file procguard.conf not found. Exiting.
    ExitApp
}
ReloadConfig()

; --- Timer ---
SetTimer, MonitorProcesses, 1000
return

; --- Monitoring loop ---
MonitorProcesses:
now := A_TickCount

; --- Hot reload config ---
FileGetTime, modTime, %confFile%, M
if (modTime != lastConfTime) {
    lastConfTime := modTime
    ReloadConfig()
}

Loop % checkProcs.Length()
{
    i := A_Index
    if (now - lastChecks[i] < intervals[i])
        continue
    lastChecks[i] := now

    checkName := checkProcs[i]
    runCmd := runCmds[i]
    mode := modes[i]

    SplitPath, checkName, checkBase
    StringLower, checkBase, checkBase

    ProcessExists := false
    debugFound := ""

    try {
        wmi := ComObjGet("winmgmts:\\.\root\CIMV2")
        q := "Select * from Win32_Process where Name='" checkBase "'"
        for p in wmi.ExecQuery(q)
        {
            ProcessExists := true
            debugFound := p.Name
            break
        }
    } catch {
        log("⚠️ WMI query failed for " checkName ". Fallback to Process, Exist.")
        Process, Exist, %checkBase%
        debugFound := ErrorLevel ? checkBase : ""
        if (ErrorLevel)
            ProcessExists := true
    }

    log("🔎 Checking: " checkName " | Found: " debugFound " | Mode: " mode)

    ; --- Behavior based on mode ---
    if (mode = "reverse") {
        ; Reverse logic: run when process DOES exist
        if ProcessExists {
            log("✅ " checkName " running. Reverse-mode: executing [" runCmd "].")
            Run, %runCmd%, , Hide, newPID
            Sleep, 100
            if newPID
                log("✅ [reverse] Started PID " newPID " for " checkName)
            else
                log("⚠️ [reverse] Failed to start " runCmd)
        } else {
            log("⏭️ " checkName " not running. Reverse-mode: skipping [" runCmd "].")
        }
    } else {
        ; Normal logic (existing behavior): run when process is NOT running
        if ProcessExists {
            log("✅ " checkName " running. Skip [" runCmd "].")
        } else {
            log("🚀 Launching: " runCmd)
            Run, %runCmd%, , Hide, newPID
            Sleep, 100
            if newPID
                log("✅ Started PID " newPID " for " checkName)
            else
                log("⚠️ Failed to start " runCmd)
        }
    }
}
return

; --- Tray ---
Menu, Tray, Tip, ProcGuard - Monitoring Processes
Menu, Tray, Add, Exit, ExitProc
return

ExitProc:
log("🏁 ProcGuard exiting.")
ExitApp