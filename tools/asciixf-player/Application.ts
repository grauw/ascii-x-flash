import fs, { stat } from 'node:fs/promises';
import { BLOCK_SIZE, MAX_BLOCKS } from './ASCII16XMapper.ts';
import { FlashDevice, type FlashDeviceSlot, STAGING_BUFFER_SIZE } from './FlashDevice.ts';
import { MSXPlayer } from './MSXPlayer.ts';

interface ApplicationPlayer {
  powerOn(): Promise<unknown>;
  powerOff(): Promise<unknown>;
  isPowered(): boolean;
  close(): Promise<unknown>;
  setLoopCount(count: number): Promise<unknown>;
  selectSlot(slot: number): Promise<unknown>;
  detectExpandedSlot(): Promise<boolean>;
  selectSecondarySlot(slot: number): Promise<unknown>;
  writeMemory(address: number, data: number): Promise<unknown>;
  readMemory(address: number): Promise<number>;
  receiveBuffer(address: number, data: Uint8Array): Promise<unknown>;
  sendBuffer(address: number, data: Uint8Array): Promise<unknown>;
  transferSlotToBuffer(address: number, length: number, bufferAddress: number): Promise<unknown>;
  transferBufferToSlot(address: number, length: number, bufferAddress: number): Promise<unknown>;
}

export interface ApplicationOptions {
  slots: FlashDeviceSlot[];
  port?: string;
  baudRate?: number;
  fileStart: number;
  addressStart: number;
  addressEnd?: number;
  bufferPageMask?: number;
  chipErase?: boolean;
  erase?: boolean;
  program?: boolean;
  verify?: boolean;
  dump?: boolean;
  info?: boolean;
  path?: string;
}

export class Application {
  private flashDevices: FlashDevice[];
  private options: ApplicationOptions;
  private player?: ApplicationPlayer;

  public constructor(options: ApplicationOptions, player?: ApplicationPlayer) {
    this.flashDevices = [];
    this.options = options;
    this.player = player;
  }

  public async run(): Promise<void> {
    const player = await this.constructPlayer();
    try {
      await player.powerOn();
      await player.setLoopCount(0xffff);
      await this.constructFlashDevices(player);
      await this.runOperations();
    } finally {
      if (player.isPowered()) {
        await player.powerOff().catch(() => {});
      }
      if (this.player == undefined) {
        await player.close();
      }
    }
  }

  private async runOperations(): Promise<void> {
    if (this.options.info) {
      for (const flash of this.flashDevices) {
        await flash.print(true);
      }
    }

    const addressEnd = await this.constructAddressEnd();
    if (this.options.chipErase) {
      console.log('Erasing chip...');
      await this.chipErase();
    }
    if (this.options.erase) {
      console.log('Erasing...');
      await this.erase(addressEnd);
    }
    if (this.options.program) {
      console.log('Programming...');
      await this.program(addressEnd);
    }
    if (this.options.verify) {
      console.log('Verifying...');
      await this.verify(addressEnd);
      console.log('Verify successful.');
    }
    if (this.options.dump) {
      console.log('Dumping...');
      await this.dump(addressEnd);
    }
  }

  private async constructPlayer(): Promise<ApplicationPlayer> {
    if (this.player != undefined) {
      return this.player;
    }
    if (this.options.port == undefined) {
      throw new Error('Missing port.');
    }
    return MSXPlayer.open(this.options.port, { baudRate: this.options.baudRate ?? 115200 });
  }

  private async constructFlashDevices(player: ApplicationPlayer): Promise<void> {
    this.flashDevices = [];
    for (const slot of this.options.slots) {
      await player.selectSlot(slot.primary);
      await this.configureExpandedSlot(player, slot);
      const flash = new FlashDevice(player, slot);
      await flash.initialize();
      flash.bufferPageMask &= this.options.bufferPageMask ?? 0xff;
      this.flashDevices.push(flash);
    }
  }

  private async configureExpandedSlot(player: ApplicationPlayer, slot: FlashDeviceSlot): Promise<void> {
    const expanded = await player.detectExpandedSlot();
    if (expanded && slot.secondary == undefined) {
      throw new Error(`SSEL slot ${slot.primary} is expanded. Specify a secondary slot as ${slot.primary}-0 through ${slot.primary}-3.`);
    }
    if (!expanded && slot.secondary != undefined) {
      throw new Error(`SSEL slot ${slot.primary} is not expanded. Do not specify a secondary slot.`);
    }
    if (slot.secondary != undefined) {
      await player.selectSecondarySlot(slot.secondary);
    }
  }

  private async constructAddressEnd(): Promise<number> {
    const capacity = this.getMaxCapacity();
    if (this.options.addressEnd != undefined) {
      return Math.min(capacity, this.options.addressEnd);
    }
    if (this.options.path && (this.options.program || this.options.verify)) {
      const info = await stat(this.options.path);
      const bytes = Math.max(0, info.size - this.options.fileStart);
      return Math.min(capacity, MAX_BLOCKS, this.options.addressStart + Math.ceil(bytes / BLOCK_SIZE));
    }
    return capacity;
  }

  private async erase(addressEnd: number): Promise<void> {
    this.assertProgrammable();
    await this.withProtectedChip(async () => {
      for (let block = this.options.addressStart; block < addressEnd; block++) {
        for (const flash of this.flashDevices) {
          await flash.sectorErase(block);
        }
        this.printProgress(block + 1);
      }
    });
    await this.resetMappers();
    process.stdout.write('\n');
  }

  private async chipErase(): Promise<void> {
    this.assertProgrammable();
    for (const flash of this.flashDevices) {
      await flash.chipErase();
    }
  }

  private async program(addressEnd: number): Promise<void> {
    this.assertProgrammable();
    const file = await fs.open(this.requirePath(), 'r');
    try {
      let position = this.options.fileStart;
      await this.withProtectedChip(async () => {
        for (let block = this.options.addressStart; block < addressEnd; block++) {
          const buffer = new Uint8Array(STAGING_BUFFER_SIZE);
          const { bytesRead } = await file.read(buffer, 0, STAGING_BUFFER_SIZE, position);
          if (bytesRead == 0) {
            break;
          }
          for (const flash of this.flashDevices) {
            await flash.programBlock(block, buffer.subarray(0, bytesRead));
          }
          position += bytesRead;
          this.printProgress(block + 1);
        }
      });
      await this.resetMappers();
      process.stdout.write('\n');
    } finally {
      await file.close();
    }
  }

  private async verify(addressEnd: number): Promise<void> {
    const file = await fs.open(this.requirePath(), 'r');
    try {
      let position = this.options.fileStart;
      for (let block = this.options.addressStart; block < addressEnd; block++) {
        const expected = new Uint8Array(STAGING_BUFFER_SIZE);
        const { bytesRead } = await file.read(expected, 0, STAGING_BUFFER_SIZE, position);
        if (bytesRead == 0) {
          break;
        }
        for (const flash of this.flashDevices) {
          await flash.verifyBlock(block, expected.subarray(0, bytesRead));
        }
        position += bytesRead;
        this.printProgress(block + 1);
      }
      await this.resetMappers();
      process.stdout.write('\n');
    } finally {
      await file.close();
    }
  }

  private async dump(addressEnd: number): Promise<void> {
    if (this.options.addressEnd == undefined) {
      throw new Error('Dump requires an address end. Use --address-end / /ae.');
    }
    const file = await fs.open(this.requirePath(), 'w');
    try {
      const data = new Uint8Array(BLOCK_SIZE);
      for (let block = this.options.addressStart; block < addressEnd; block++) {
        await this.flashDevices[0].readBlock(block, data);
        await file.write(data);
        this.printProgress(block + 1);
      }
      await this.resetMappers();
      process.stdout.write('\n');
    } finally {
      await file.close();
    }
  }

  private async withProtectedChip(action: () => Promise<void>): Promise<void> {
    for (const flash of this.flashDevices) {
      await flash.protectChip();
    }
    try {
      await action();
    } finally {
      for (const flash of this.flashDevices) {
        await flash.unprotectChip();
        await flash.resetFlash();
      }
    }
  }

  private async resetMappers(): Promise<void> {
    for (const flash of this.flashDevices) {
      await flash.resetMapper();
    }
  }

  private assertProgrammable(): void {
    if (!this.flashDevices.some((flash) => flash.isProgrammable())) {
      throw new Error('No programmable CFI FlashROM detected.');
    }
  }

  private getMaxCapacity(): number {
    return Math.max(0, ...this.flashDevices.map((flash) => flash.capacity));
  }

  private printProgress(block: number): void {
    if ((block & 0x0f) == 0) {
      process.stdout.write('.');
    }
  }

  private requirePath(): string {
    if (this.options.path == undefined) {
      throw new Error('No file specified.');
    }
    return this.options.path;
  }
}
