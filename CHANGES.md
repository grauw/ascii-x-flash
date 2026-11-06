# ASCII-X flash tool change log

For the complete list of changes please refer to the
[revision history](https://github.com/grauw/ascii-x-flash/commits).

## [1.3] — 2026-05-18

* Default to erase, program, verify when file is specified.
* Moved `/p` and `/v` to advanced options.
* Changed `/p` option to not erase prior to programming.
* Removed `/p!` option.
* Added `/pb` option to limit program buffer size.
* Added sector protection check.
* Improved flashing robustness with dynamic protection.
* Retry a few times when a flash operation fails.
* Print a `!` when a flash operation error occurs.
* Added check whether file exists before erasing.
* Print capacity warning only once.

## [1.2.2] — 2025-09-11

* Added checks for disk system and RAM slots.

## [1.2.1] — 2025-06-14

* Worked around Nextor 2.1.2 bug when dumping.

## [1.2] — 2025-05-25

* Changed `/p` option to erase prior to programming.
* Added `/p!` option to program without erase.
* Changed `/e` option to use sector erase and show progress.
* Added `/ec` option for chip erase.
* Added `/as` and `/ae` options to specify address range.
* Added `/fs` option to specify file offset.
* Added `/h` option for advanced help information.
* Improved FlashROM information.
* Improved handling of oversized ROM files.
* Added slot expansion check.
* Added manufacturer ID parity check.
* Added Micron M29W640G buffer programming support.
* Sped up dumping by pre-allocating file.

## [1.1] — 2025-05-12

* Support for bulk flashing multiple slots.
* Implemented dump function.
* Improved flash error handling.
* Warning when file exceeds FlashROM capacity.
* Reduced progress dot frequency (every 64K).
* Fixed programming files whose size is not multiple of 256.

## [1.0] — 2025-03-09

Initial release.

[1.3]: https://github.com/grauw/ascii-x-flash/commits/release-1.3
[1.2.2]: https://github.com/grauw/ascii-x-flash/commits/release-1.2.2
[1.2.1]: https://github.com/grauw/ascii-x-flash/commits/release-1.2.1
[1.2]: https://github.com/grauw/ascii-x-flash/commits/release-1.2
[1.1]: https://github.com/grauw/ascii-x-flash/commits/release-1.1
[1.0]: https://github.com/grauw/ascii-x-flash/commits/release-1.0
