# ASCII-X flash tool

Copyright 2024 Laurens Holst

## Project information

  * Author: Laurens Holst <laurens@grauw.nl>
  * Site: <https://www.grauw.nl/projects/ascii-x-flash/>
  * Source: <https://hg.sr.ht/~grauw/ascii-x-flash>
  * Support: <https://www.msx.org/forum/msx-talk/development/ascii-x-flashrom-cartridge>
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

  * `/s`  Slot number (required). Format: p or p-s.
  * `/h`  Show advanced options.

Example:

    asciixf /s2 example.rom

This erases, programs and verifies a ROM to the ASCII-X cartridge in slot 2.

Advanced options:

  * `/s`  Slot number (required). Format: p or p-s.
          Specify up to 8 for bulk flashing.
  * `/e`  Erase flash ROM.
  * `/ec` Erase flash ROM (chip erase).
  * `/p`  Program flash ROM from file.
  * `/pb` Program buffer size (2^n). Format: 0-8.
  * `/v`  Verify flash ROM with file.
  * `/d`  Dump flash ROM to file.
  * `/i`  Display flash ROM information.
  * `/h`  Show advanced options.
  * `/fs` File start offset.
  * `/as` Address range start.
  * `/ae` Address range end (exclusive).

Addresses are hex bytes aligned to `1000H`.
They can contain a `'` as digit separator.

## Development information

On macOS and Linux execute the `make` command to build the program. Test by
putting the MSX-DOS2 system files in the `bin/` directory and executing the
`make run` command to run the tool. OpenMSX 21.0 or later is recommended.

On Windows, execute the build commands from the Makefile manually.

Note that the [glass](http://www.grauw.nl/projects/glass/) assembler which is
embedded in the project requires [Java 8](https://adoptopenjdk.net/). To check
your Java version, invoke the `java -version` command.

## MSXPLAYer USB flashing

An experimental Node.js port for the MSXPLAYer Game Cassette Adapter lives in
`tools/asciixf-player/`. It talks to the USB serial command interface described
in `doc/com_command_en.md`, so flashing can be done from the host without
running the Z80 `.COM` program on an MSX.

It uses Node 24’s built-in TypeScript type stripping, so the tool source is
plain `.ts` and does not need a build step. Install the Node dependency once:

    npm install

Example:

    npx asciixf-player --port /dev/tty.usbmodem1101 --slot 1 example.rom

With a file and no operation flags, the Node tool performs erase, program and
verify, matching the default MSX-DOS tool flow. Short options use `-`, e.g.
`-s1`, but `/` is also accepted for compatibility. Use
`npx asciixf-player --help` for the full option list.

For expanded slots, specify the secondary slot with `-s1-0` through `-s2-3`.
The tool probes the expanded-slot register and rejects `-s1-2` when the slot is
not expanded, and rejects plain `-s1` when it is expanded.
