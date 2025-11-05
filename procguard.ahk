; procguard.ahk
; Version: 2.0.0
; Ensures a list of processes are always running, based on a configuration file.
; It checks each process at its specified interval and launches it if it's not found.

#NoTrayIcon
#SingleInstance Force
SetBatchLines, -1

; --- Log file ---
logFile := A_ScriptDir "\procguard.log"
enableLog := FileExist(logFile)

log(msg) {
    global enableLog, logFile
    if (enableLog) {
        timeStamp := A_Now
        FormatTime, timeStr, %timeStamp%, yyyy-MM-dd HH:mm:ss
        newLine := "[" timeStr "] " msg "`r`n"
        FileAppend, %newLine%, %logFile%
    }
}

; --- Task Storage ---
global tasks := []

LoadConfig() {
    global tasks
    configFile := A_ScriptDir "\procguard.conf"
    if (!FileExist(configFile)) {
        log("❌ Configuration file not found: " configFile ". Exiting.")
        MsgBox, 48, ProcGuard Error, Configuration file not found:`n%configFile%
        ExitApp
    }

    log("⚙️ Reading configuration from: " configFile)
    newTasks := []
    Loop, Read, %configFile%
    {
        line := A_LoopReadLine
        if (RegExMatch(line, "^\s*(#|$)")) ; Skip comments and empty lines
            continue

        parts := StrSplit(line, ",")
        if (parts.Length() < 2) {
            log("⚠️ Invalid config line (skipping, not enough parts): " line)
            continue
        }

        processName := Trim(parts[1])
        intervalSeconds := Trim(parts[parts.Length()])

        ; Reconstruct the command from the middle parts
        runCommand := ""
        Loop, % parts.Length() - 2 {
            runCommand .= parts[A_Index + 1] . (A_Index < parts.Length() - 2 ? "," : "")
        }
        runCommand := Trim(runCommand)
        
        ; If there are only 2 parts, the command is the same as the process name
        if (parts.Length() = 2) {
            runCommand := processName
        }


        if !(processName && runCommand && IsNumber(intervalSeconds) && intervalSeconds > 0) {
            log("⚠️ Invalid config line (skipping, invalid data): " line)
            continue
        }
        
        ; Check if task already exists to preserve its lastCheck time
        found := false
        for i, existingTask in tasks {
            if (existingTask.name = processName) {
                existingTask.command := runCommand
                existingTask.interval := intervalSeconds * 1000
                newTasks.Push(existingTask)
                found := true
                break
            }
        }
        if (!found) {
            newTasks.Push({name: processName, command: runCommand, interval: intervalSeconds * 1000, lastCheck: 0})
        }
    }
    tasks := newTasks
    log("✅ Configuration loaded. " tasks.Length() " tasks found.")
}

; --- Main ---
log("🚀 ProcGuard starting up.")
LoadConfig()

; Use a timer to reload config periodically without blocking the main loop
SetTimer, LoadConfig, 60000 ; Reload config every 60 seconds

if (tasks.Length() = 0) {
    log("No valid tasks found in configuration. Idling.")
}

Loop {
    currentTime := A_TickCount
    for index, task in tasks
    {
        if ((currentTime - task.lastCheck) >= task.interval)
        {
            task.lastCheck := currentTime
            
            Process, Exist, % task.name
            processPID := ErrorLevel

            if (processPID = 0) {
                log("❗ Process not found: " task.name ". Launching...")
                Run, % task.command
                log("🚀 Launched: " task.command)
            }
        }
    }
    Sleep, 1000 ; Main loop sleeps for 1 second to avoid busy-looping
}

return ; End of auto-execute section