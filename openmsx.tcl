source lib/neonlib/tools/symbols.tcl
source lib/neonlib/tools/profile.tcl

debug set_watchpoint read_io 0x2E

symbols::load gen/asciixf.com.sym

diskmanipulator create /tmp/asciixf.dsk 32M
virtual_drive /tmp/asciixf.dsk
diskmanipulator format virtual_drive
diskmanipulator import virtual_drive bin/
virtual_drive eject
hda /tmp/asciixf.dsk

profile_osd t
set maxframeskip 100
set throttle off
after time 11 "set throttle on"
