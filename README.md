# ASCII-X flash tool

Copyright 2024 Laurens Holst

## Project information

  * Author: Laurens Holst <laurens@grauw.nl>
  * Site: <https://www.grauw.nl/projects/ascii-x-flash/>
  * Source: <https://hg.sr.ht/~grauw/ascii-x-flash>
  * License: MIT

Flash tool for ASCII-X FlashROM cartridges.

## System requirements

  * MSX, MSX2, MSX2+ or MSX turboR
  * 128K main RAM
  * 16K video RAM
  * MSX-DOS2

## Usage instructions

Run ASCIIXF from MSX-DOS 2, specifying the ROM file to flash on the command line.

Warning: Make sure to have a means to bypass booting the ROM so you can get back
to MSX-DOS2 to erase the cartridge. E.g. by implementing a boot bypass key in
your ROM, by using a slot expander with slot disable switches, or using Nyyrikki’s
[Boot Manager](https://www.msx.org/forum/msx-talk/software/boot-manager-10).

Usage:

    asciixf [options] <file.rom>

Options:

	* `/s` Slot number (required). Format: p or p-s.
	* `/e` Erase flash ROM.
	* `/p` Program flash ROM from file.
	* `/v` Verify flash ROM with file.
	* `/d` Dump flash ROM to file.
	* `/i` Display flash ROM information.

Example:

    asciixf /s2 /e /p /v example.rom

This erases, programs and verifies a ROM to the ASCII-X cartridge in slot 2.

## Development information

On macOS and Linux execute the `make` command to build the program. Test by
putting the MSX-DOS2 system files in the `bin/` directory and executing the
`make run` command to run the tool. OpenMSX 0.18.0 or later is recommended.

On Windows, execute the build commands from the Makefile manually.

Note that the [glass](http://www.grauw.nl/projects/glass/) assembler which is
embedded in the project requires [Java 8](https://adoptopenjdk.net/). To check
your Java version, invoke the `java -version` command.
