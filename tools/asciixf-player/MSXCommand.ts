import { assertByte, assertWord, hex } from './Format.ts';

export type CommandQueueMode = 'off' | 'plain' | 'erroff';

export abstract class MSXCommand {
  public abstract toString(): string;

  public readResponse(line: string): boolean {
    return false;
  }
}

export class WriteMemoryCommand extends MSXCommand {
  private address: number;
  private data: number;

  public constructor(address: number, data: number) {
    super();
    assertWord(address, 'Slot memory address');
    assertByte(data, 'Slot memory data');
    this.address = address;
    this.data = data;
  }

  public override toString(): string {
    return `SMWR,${hex(this.address, 4)},${hex(this.data, 2)}`;
  }
}

export class ReadMemoryCommand extends MSXCommand {
  private address: number;
  public value?: number;

  public constructor(address: number) {
    super();
    assertWord(address, 'Slot memory address');
    this.address = address;
  }

  public override toString(): string {
    return `SMRD,${hex(this.address, 4)}`;
  }

  public override readResponse(line: string): boolean {
    const match = line.match(/^\s*[0-9a-f]{1,4}\s*:\s*([0-9a-f]{1,2})\s*$/i);
    if (match) {
      this.value = Number.parseInt(match[1], 16);
      return true;
    }
    return false;
  }
}

export class TransferBufferToSlotCommand extends MSXCommand {
  private address: number;
  private length: number;
  private bufferAddress: number;

  public constructor(address: number, length: number, bufferAddress: number) {
    super();
    assertWord(address, 'Slot memory address');
    assertWord(length, 'Slot transfer length');
    assertWord(bufferAddress, 'Buffer address');
    this.address = address;
    this.length = length;
    this.bufferAddress = bufferAddress;
  }

  public override toString(): string {
    return `SMTW,${hex(this.address, 4)},${hex(this.length, 4)},${hex(this.bufferAddress, 4)}`;
  }
}
