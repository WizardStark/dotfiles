#Requires AutoHotkey v2.0
#SingleInstance Force

~LAlt::Send("{Blind}{vkE8}")

FocusOrRun(exePath, runCommand := "") {
    static prevWindow := 0
    target := "ahk_exe " exePath

    if WinExist(target) {
        if WinActive(target) {
            if WinExist("ahk_id " prevWindow)
                WinActivate("ahk_id " prevWindow)
        } else {
            prevWindow := WinExist("A")
            WinActivate(target)
        }
    } else {
        if (runCommand = "")
            Run exePath
        else
            Run runCommand
    }
}

#^!+n::FocusOrRun("neovide.exe", "neovide.exe --wsl --frame none")
#^!+i::FocusOrRun("opera.exe")
#^!+c::FocusOrRun("chrome.exe")
#^!+s::FocusOrRun("Discord.exe", "Discord.exe --processStart Discord.exe")
#^!+m::FocusOrRun("Spotify.exe")
#^!+g::FocusOrRun("steam.exe", "C:\Program Files (x86)\Steam\steam.exe")
#^!+f::FocusOrRun("WindowsTerminal.exe", "wt.exe")
