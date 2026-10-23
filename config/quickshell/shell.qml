//@ pragma UseQApplication
import Quickshell
import "plugins/clipboard" as ClipboardPlugin
import "plugins/webapps" as WebappsPlugin

ShellRoot {
    VolumeOsd {}
    SysOsd {}
    OpacityMenu {}
    ThemeCarousel {}
    Notifications {}
    Launcher {}
    ClipboardPlugin.Clipboard {}
    WebappsPlugin.Webapps {}
    Emoji {}
    Cheatsheet {}
    Bar {}
    Todo {}
    Wheel {}
}
