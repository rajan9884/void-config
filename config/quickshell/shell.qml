//@ pragma UseQApplication
import Quickshell
import "plugins/clipboard" as ClipboardPlugin
import "plugins/webapps" as WebappsPlugin

ShellRoot {
    VolumeOsd {}
    SysOsd {}
    OpacityMenu {}
    NetworkPanel {}
    DisplayPanel {}
    AudioPanel {}
    Settings {}
    ThemeCarousel {}
    Notifications {}
    PowerMenu {}
    Launcher {}
    ClipboardPlugin.Clipboard {}
    WebappsPlugin.Webapps {}
    Emoji {}
    Cheatsheet {}
    Bar {}
    Todo {}
    Wheel {}
}