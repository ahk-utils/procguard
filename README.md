# ProcGuard

![Version](https://img.shields.io/badge/version-2.1.0-blue)

A persistent, configuration-driven process manager for Windows. It ensures a list of specified applications are always running. If a monitored process is not found, ProcGuard will automatically launch it.

It is written in [AutoHotkey](https://www.autohotkey.com/).

## Features

- **Persistent Process Monitoring**: Runs silently in the background to ensure your essential applications are always active.
- **Configuration-Driven**: Manage which applications to monitor and how often using a simple `.conf` file.
- **Flexible Launch Commands**: For each process, you can specify a simple executable name or a full command with a path and arguments.
- **Live Configuration Reload**: Automatically reloads the configuration file, allowing you to change settings without restarting the script.
- **Optional Logging**: Create an empty `procguard.log` file in the same directory to enable detailed logging of the script's actions.
- **Normal or Reverse Mode**: For each entry, choose whether to run the command when the process is missing (default) or when it is present (reverse mode).

## Usage

There are no command-line arguments for now. All configuration is handled by the `procguard.conf` file.

1.  **Configure**: Create and edit the `procguard.conf` file in the same directory as `procguard.ahk`.
2.  **Run**: Simply execute `procguard.ahk`. It will run silently in the background.

## Configuration (`procguard.conf`)

Create a text file named `procguard.conf` in the same directory as the executable. The script will not run without it.

- Each line represents one process to monitor.
- Lines starting with `#` are ignored as comments.

### Format

The format for each line is a comma-separated list:

```
ProcessName.exe,PathToExecutable [with arguments],IntervalSeconds[,Mode]
```

- `ProcessName.exe`: The name of the process to check for (e.g., `notepad.exe`).
- `PathToExecutable [with arguments]`: The full command to run based on the chosen mode. This can include a full path and any command-line arguments.
- `IntervalSeconds`: The number of seconds to wait between checks for this specific process.
- `Mode` (optional): Controls when the command is executed. Supported values:
  - *(omitted)* or any value other than `reverse`: **normal mode** – run the command when the process is **not running**.
  - `reverse`: **reverse mode** – run the command when the process **is running**.

### Example `procguard.conf`

```ini
# =======
# Follow the format below to set the configuration
# Executable binary name to be checked, path to the exe to be started, interval (seconds), optional mode
# Mode:
#   (omitted or anything except "reverse") → run when process is NOT running
#   "reverse" → run when process IS running
# =======

# Ensure GoldenDict is running, check every 10 minutes (600 seconds)
# Normal mode (default): if GoldenDict.exe is missing, start it
GoldenDict.exe,C:\Path\to\GoldenDict\GoldenDict.exe,600

# Ensure Listary is running, check every 10 minutes
Listary.exe,C:\Path\to\ListaryPortable\Listary.exe,600

# Run a command with arguments, check every 4 hours (14400 seconds)
WeaselDeployer.exe,C:\Path\to\RimeIMEPortable\weasel\WeaselDeployer.exe /sync,14400

# Keep a simple background utility active, check every minute
CoffeeBean.exe,C:\Path\to\CoffeeBean.exe,60

# Reversed behavior
# When Everything.exe IS running, execute the command every 10 minutes
Everything.exe,C:\Path\to\Everything.exe -reindex -startup,3600,reverse
```

## Building from Source

To compile the `procguard.ahk` script into `procguard.exe`, you will need the [AutoHotkey compiler (Ahk2Exe)](https://www.autohotkey.com/docs/v1/lib/Ahk2Exe.htm), which is included with the standard AutoHotkey v1.1 installation.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
