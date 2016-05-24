
terminal-emu-best
=================
Normalize option syntax and features for popular terminal emulators.


Mission scope
-------------

general:
  * Spawn a new terminal window (nor a tab), manage UI clutter visibility
  * Was it `--option=value` or `--option value`?

xfce4-terminal:
  * Off-by-one errors in `--geometry`

gnome-terminal:
  * `Option "--title" is no longer supported in this version of gnome-terminal.`
  * `Failed to parse arguments: Unknown option --hold`
  * Forgo that `--disable-factory` if it would
    [prevent startup](https://bugzilla.gnome.org/show_bug.cgi?id=707899)
    ([not a bug][gnome-commits-list-05584])

sakura:
  * Safely tunnel arguments through `--xterm-execute` even if they start
    with `--`. (Also you don't have to remember to add the `xterm-`.)

Suggestions and PRs welcome!


Supported terminal emulators
----------------------------
  * xfce4-terminal
  * gnome-terminal
  * sakura




-----
  [gnome-commits-list-05584]: https://mail.gnome.org/archives/commits-list/2013-September/msg05584.html
