import { Application, type ApplicationOptions } from './Application.ts';
import { BLOCK_SIZE, MAX_BLOCKS } from './ASCII16XMapper.ts';
import { parseHex } from './Format.ts';

export interface SlotSpec {
  primary: number;
  secondary?: number;
}

const HELP = `ASCII-X flash tool for MSXPLAYer

Usage:
  asciixf-player --port <serial-port> --slot <1|2[-0..3]>... [options] <file.rom>

Options:
  --port <path>              Serial port exposed by MSXPLAYer
  --baud <rate>              Serial baud rate (default: 115200)
  --slot, -s <slot>          SSEL slot 1 or 2, optionally with secondary slot 0-3; may repeat
  --erase, -e                Erase flash sectors in range
  --chip-erase, -ec          Erase the whole flash chip
  --program, -p              Program flash from file
  --program-buffer, -pb <n>  Program buffer size as 2^n bytes, 0-8
  --verify, -v               Verify flash against file
  --dump, -d                 Dump flash to file
  --info, -i                 Display FlashROM information
  --file-start, -fs <hex>    File start offset
  --address-start, -as <hex> Address start byte offset, 1000h-aligned
  --address-end, -ae <hex>   Address end byte offset, exclusive and 1000h-aligned
  --help, -h                 Show this help

Short options also accept / instead of -, for compatibility with the MSX-DOS tool.

With a file and no operation, the default is --erase --program --verify.`;

interface ShortOption {
  name: string;
  value?: string;
}

export class CLI implements ApplicationOptions {
  public help = false;
  public erase = false;
  public chipErase = false;
  public program = false;
  public verify = false;
  public dump = false;
  public info = false;
  public path?: string;
  public fileStart = 0;
  public addressStart = 0;
  public addressEnd?: number;
  public bufferPageMask = 0xff;
  public slots: SlotSpec[] = [];
  public port?: string;
  public baudRate = 115200;

  public constructor(argv: string[]) {
    this.parse(argv);
    this.trySetDefaultOperations();
    this.verifyOptions();
  }

  private parse(argv: string[]): void {
    for (let index = 0; index < argv.length; index++) {
      const arg = argv[index];
      const short = this.parseShortOption(arg);
      if (arg == '--help' || this.isShortFlag(short, 'h')) {
        this.help = true;
      } else if (arg == '--port') {
        this.port = this.requireValue(argv, ++index, arg);
      } else if (arg == '--baud') {
        this.baudRate = Number(this.requireValue(argv, ++index, arg));
      } else if (arg == '--slot' || this.isShortOption(short, 's')) {
        const slot = this.parseSlot(short?.value ?? this.requireValue(argv, ++index, arg));
        if (slot != undefined) {
          this.addSlot(slot);
        }
      } else if (arg == '--chip-erase' || this.isShortFlag(short, 'ec')) {
        this.chipErase = true;
      } else if (arg == '--erase' || this.isShortFlag(short, 'e')) {
        this.erase = true;
      } else if (arg == '--program' || this.isShortFlag(short, 'p')) {
        this.program = true;
      } else if (arg == '--program-buffer' || this.isShortOption(short, 'pb')) {
        this.bufferPageMask = this.parseBufferPageMask(short?.value ?? this.requireValue(argv, ++index, arg));
      } else if (arg == '--verify' || this.isShortFlag(short, 'v')) {
        this.verify = true;
      } else if (arg == '--dump' || this.isShortFlag(short, 'd')) {
        this.dump = true;
      } else if (arg == '--info' || this.isShortFlag(short, 'i')) {
        this.info = true;
      } else if (arg == '--file-start' || this.isShortOption(short, 'fs')) {
        this.fileStart = parseHex(short?.value ?? this.requireValue(argv, ++index, arg), 'file start');
      } else if (arg == '--address-start' || this.isShortOption(short, 'as')) {
        this.addressStart = this.parseAddress(short?.value ?? this.requireValue(argv, ++index, arg), 'address start');
      } else if (arg == '--address-end' || this.isShortOption(short, 'ae')) {
        this.addressEnd = this.parseAddress(short?.value ?? this.requireValue(argv, ++index, arg), 'address end');
      } else if (arg.startsWith('-') || arg.startsWith('/')) {
        throw new Error(`Unknown option: ${arg}`);
      } else if (!this.path) {
        this.path = arg;
      } else {
        throw new Error(`Can not specify more than one file: ${arg}`);
      }
    }
  }

  public async run(): Promise<void> {
    if (this.help || (!this.path && !this.hasOperation())) {
      console.log(HELP);
    } else {
      const application = new Application(this);
      await application.run();
    }
  }

  private verifyOptions(): void {
    if (this.help || (!this.path && !this.hasOperation())) {
      return;
    }
    if (!this.port) {
      throw new Error('Missing --port.');
    }
    if (this.slots.length == 0) {
      throw new Error('Missing or invalid --slot. MSXPLAYer SSEL accepts slot 1 or 2.');
    }
    if (this.slots.length > 8) {
      throw new Error('Can not specify more than 8 slots.');
    }
    if (this.dump && this.slots.length > 1) {
      throw new Error('Can not dump multiple slots.');
    }
    if (this.dump && (this.erase || this.chipErase || this.program || this.verify)) {
      throw new Error('Can not combine dump with erase, program or verify.');
    }
    if ((this.program || this.verify || this.dump) && !this.path) {
      throw new Error('No file specified.');
    }
    if (!this.program && !this.verify && !this.dump && this.path) {
      throw new Error('No file operation specified.');
    }
    if (!Number.isInteger(this.baudRate) || this.baudRate <= 0) {
      throw new Error(`Invalid baud rate: ${this.baudRate}`);
    }
    if (this.addressEnd != undefined && this.addressEnd <= this.addressStart) {
      throw new Error('Address end must be greater than address start.');
    }
  }

  private hasOperation(): boolean {
    return this.erase || this.chipErase || this.program || this.verify || this.dump || this.info;
  }

  private trySetDefaultOperations(): void {
    if (this.path && !this.hasOperation()) {
      this.erase = true;
      this.program = true;
      this.verify = true;
    }
  }

  private parseAddress(value: string, label: string): number {
    const address = parseHex(value, label);
    if ((address & (BLOCK_SIZE - 1)) != 0) {
      throw new Error(`Invalid ${label}: must be aligned to 1000h`);
    }
    const block = address / BLOCK_SIZE;
    if (block < 0 || block > MAX_BLOCKS) {
      throw new Error(`Invalid ${label}: outside ASCII16-X range`);
    }
    return block;
  }

  private parseSlot(value: string): SlotSpec | undefined {
    const match = value.match(/^([0-9])(?:-([0-9]))?$/);
    if (!match) {
      return undefined;
    }
    const primary = Number.parseInt(match[1], 10);
    const secondary = match[2] == undefined ? undefined : Number.parseInt(match[2], 10);
    if (!this.isSselSlot(primary) || (secondary != undefined && !this.isSecondarySlot(secondary))) {
      return undefined;
    }
    return secondary == undefined ? { primary } : { primary, secondary };
  }

  private isSselSlot(value: SlotSpec | number | undefined): boolean {
    if (typeof value == 'object') {
      value = value.primary;
    }
    return value == 1 || value == 2;
  }

  private isSecondarySlot(value: number): boolean {
    return value >= 0 && value <= 3;
  }

  private addSlot(slot: SlotSpec): void {
    if (this.slots.some((entry) => entry.primary == slot.primary && entry.secondary == slot.secondary)) {
      throw new Error(`Can not specify the same slot twice: ${this.formatSlot(slot)}`);
    }
    if (this.slots.length >= 8) {
      throw new Error('Can not specify more than 8 slots.');
    }
    this.slots.push(slot);
  }

  private parseShortOption(arg: string): ShortOption | undefined {
    if (arg.startsWith('--') || !arg.match(/^[-/][A-Za-z]/)) {
      return undefined;
    }

    const body = arg.slice(1);
    for (const name of ['fs', 'as', 'ae', 'ec', 'pb', 's', 'e', 'p', 'v', 'd', 'i', 'h']) {
      if (body == name) {
        return { name };
      }
      if (body.startsWith(name) && this.optionTakesValue(name)) {
        return { name, value: body.slice(name.length) };
      }
    }

    return undefined;
  }

  private isShortFlag(option: ShortOption | undefined, name: string): boolean {
    return option?.name == name && option.value == undefined;
  }

  private isShortOption(option: ShortOption | undefined, name: string): boolean {
    return option?.name == name;
  }

  private optionTakesValue(name: string): boolean {
    return name == 's' || name == 'fs' || name == 'as' || name == 'ae' || name == 'pb';
  }

  private parseBufferPageMask(value: string): number {
    if (!value.match(/^[0-8]$/)) {
      throw new Error(`Invalid program buffer size: ${value}`);
    }
    return (1 << Number.parseInt(value, 10)) - 1;
  }

  private requireValue(argv: string[], index: number, option: string): string {
    if (index >= argv.length) {
      throw new Error(`Missing value for ${option}`);
    }
    return argv[index];
  }

  private formatSlot(slot: SlotSpec): string {
    return slot.secondary == undefined ? `${slot.primary}` : `${slot.primary}-${slot.secondary}`;
  }
}
