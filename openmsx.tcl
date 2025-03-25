source lib/neonlib/tools/symbols.tcl
source lib/neonlib/tools/profile.tcl

debug set_watchpoint read_io 0x2E

symbols::load gen/asciixf.com.sym

debug set_bp -once 0xFEDA {} {  # H.STKE
	lassign [get_selected_slot 3] ram_ps ram_ss
	variable pc_in_ram_slot "\[pc_in_slot $ram_ps $ram_ss\]"

	debug set_bp [symbol System_ThrowExceptionWithMessage] $pc_in_ram_slot
}

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
