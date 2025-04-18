.PHONY: all com copy run
COPY_TARGET = /Volumes/MSXDOS2

all:
	mkdir -p gen bin
	java -jar tools/glass.jar -I lib/neonlib/src src/COM.asm bin/asciixf.com gen/asciixf.com.sym

copy: all
	cp bin/*.com $(COPY_TARGET)/
	diskutil umount $(COPY_TARGET)

dist: all
	rm -f gen/asciixf.zip
	zip -j gen/asciixf.zip bin/asciixf.com README.md CHANGES.md LICENSE

run: all
	openmsx -machine Panasonic_FS-A1GT -ext ide -ext slotexpander -ext ASCII16-X_Mapper_XL -ext ASCII16-X_Mapper_XL -script openmsx.tcl
