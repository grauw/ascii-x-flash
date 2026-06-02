import { BLOCK_SIZE, mapPhysicalAddress } from './ASCII16XMapper.ts';
import { AutoSelect } from './AutoSelect.ts';
import { CFIQuery } from './CFIQuery.ts';
import { FlashCommand, type FlashCommandPlayer } from './FlashCommand.ts';
import { hex } from './Format.ts';

export const STAGING_BUFFER_ADDRESS = 0xc000;
export const STAGING_BUFFER_SIZE = 0x1000;

interface FlashDevicePlayer extends FlashCommandPlayer {
  selectSlot(slot: number): Promise<unknown>;
  selectSecondarySlot(slot: number): Promise<unknown>;
  receiveBuffer(address: number, data: Uint8Array): Promise<unknown>;
  sendBuffer(address: number, data: Uint8Array): Promise<unknown>;
  transferSlotToBuffer(address: number, length: number, bufferAddress: number): Promise<unknown>;
}

export interface FlashDeviceSlot {
  primary: number;
  secondary?: number;
}

export class FlashDevice {
  private player: FlashDevicePlayer;
  private command: FlashCommand;
  private slot: FlashDeviceSlot;
  private autoSelect = new AutoSelect();
  private cfiQuery = new CFIQuery();
  public capabilityFlash = false;
  public capabilityProtect = false;
  public continuity = 0;
  public capacity = 0;
  public bufferPageMask = 0;

  public constructor(player: FlashDevicePlayer, slot: FlashDeviceSlot) {
    this.player = player;
    this.command = new FlashCommand(player);
    this.slot = slot;
  }

  public async initialize(): Promise<void> {
    await this.select();
    await this.resetMapper();
    await this.command.reset();
    await this.constructCFIQuery();
    await this.constructAutoSelect();
    if (this.autoSelect.hasValidManufacturer && this.cfiQuery.hasSignature) {
      this.constructCapabilities();
      await this.constructContinuity();
      this.constructCapacity();
      this.constructBufferPageMask();
    }
  }

  private async constructCFIQuery(): Promise<void> {
    await this.command.cfiQuery();
    await this.command.readParameterBlock(0x4000, this.cfiQuery.buffer);
    await this.command.reset();
  }

  private async constructAutoSelect(): Promise<void> {
    await this.command.autoSelect();
    await this.command.readParameterBlock(0x4000, this.autoSelect.buffer);
    await this.command.reset();
  }

  private constructCapabilities(): void {
    if (!this.cfiQuery.hasSignature) {
      return;
    }
    this.capabilityFlash = true;
    if (this.cfiQuery.supportsDynamicProtection) {
      this.capabilityProtect = true;
    }
  }

  private async constructContinuity(): Promise<void> {
    this.continuity = 1;
    if (this.supportsContinuity()) {
      this.continuity = await this.command.checkContinuity();
    }
  }

  private constructCapacity(): void {
    this.capacity = this.cfiQuery.capacity;
  }

  private constructBufferPageMask(): void {
    const mask = this.cfiQuery.bufferPageMask;
    this.bufferPageMask = mask < 32 - 1 ? 0 : mask;
  }

  public async print(verbose = false): Promise<void> {
    console.log('FlashROM information:');
    if (this.supportsContinuity()) {
      this.printContinuity();
    }
    console.log(`- Manufacturer ID: ${hex(this.autoSelect.manufacturer, 2)}`);
    console.log(`- Device ID: ${this.autoSelect.deviceId}`);
    const cfi = this.cfiQuery;
    if (!cfi.hasSignature) {
      console.log('- Warning: CFI signature not found; flash operations are disabled.');
      return;
    }
    console.log(`- CFI device size: ${formatSize(1 << Math.min(cfi.deviceSize, 30))}${cfi.deviceSize > 30 ? '+' : ''}`);
    console.log(`- Capacity used by mapper: ${formatSize(this.capacity * BLOCK_SIZE)}`);
    console.log(`- Write buffer: ${this.bufferPageMask ? `${this.bufferPageMask + 1} bytes` : 'not used'}`);
    if (verbose) {
      console.log(`- Primary vendor ID: ${hex(cfi.primaryVendorID, 4)}`);
      console.log(`- Primary query offset: ${hex(cfi.primaryVendorQuery, 4)}`);
      console.log(`- Region count: ${cfi.regions.length}`);
      for (const [index, region] of cfi.regions.entries()) {
        console.log(`  ${index + 1}. ${region.count} x ${formatSize(region.size)}`);
      }
    }
  }

  public async chipErase(): Promise<void> {
    await this.select();
    this.assertProgrammable();
    await this.command.chipErase();
    await this.command.reset();
  }

  public async sectorErase(block: number): Promise<void> {
    await this.select();
    if (block >= this.capacity || !this.isSectorAligned(block)) {
      return;
    }
    const { logicalAddress } = await this.selectBlock(block);
    await this.unprotectSector(logicalAddress);
    await this.command.sectorErase(logicalAddress);
    await this.protectSector(logicalAddress);
  }

  public async programBlock(block: number, data: Uint8Array): Promise<void> {
    await this.select();
    if (block >= this.capacity || data.length == 0) {
      return;
    }
    const { logicalAddress } = await this.selectBlock(block);
    await this.player.receiveBuffer(STAGING_BUFFER_ADDRESS, data);
    await this.unprotectSector(logicalAddress);
    for (let offset = 0; offset < data.length;) {
      const remaining = data.length - offset;
      if (this.bufferPageMask && remaining > this.bufferPageMask && ((logicalAddress + offset) & this.bufferPageMask) == 0) {
        const bufferSize = this.bufferPageMask + 1;
        await this.command.programBuffer(
          logicalAddress + offset,
          STAGING_BUFFER_ADDRESS + offset,
          bufferSize,
          data[offset + bufferSize - 1]
        );
        offset += bufferSize;
      } else {
        await this.command.programByte(logicalAddress + offset, data[offset]);
        offset++;
      }
    }
    await this.protectSector(logicalAddress);
  }

  public async verifyBlock(block: number, expected: Uint8Array): Promise<void> {
    await this.select();
    if (block >= this.capacity) {
      return;
    }
    const actual = new Uint8Array(expected.length);
    await this.readBlock(block, actual);
    for (let index = 0; index < expected.length; index++) {
      if (actual[index] != expected[index]) {
        throw new Error(`Verify failed at block ${hex(block, 4)} (${hex(block * BLOCK_SIZE, 6)})`);
      }
    }
  }

  public async readBlock(block: number, data: Uint8Array): Promise<void> {
    await this.select();
    const { logicalAddress } = await this.selectBlock(block);
    await this.player.transferSlotToBuffer(logicalAddress, data.length, STAGING_BUFFER_ADDRESS);
    await this.player.sendBuffer(STAGING_BUFFER_ADDRESS, data);
  }

  public async protectChip(): Promise<void> {
    await this.select();
    if (!this.capabilityProtect) {
      return;
    }
    for (let block = 0; block < this.capacity; block++) {
      if (this.isSectorAligned(block)) {
        const { logicalAddress } = await this.selectBlock(block);
        await this.protectSector(logicalAddress);
      }
    }
  }

  public async unprotectChip(): Promise<void> {
    await this.select();
    if (!this.capabilityProtect) {
      return;
    }
    for (let block = 0; block < this.capacity; block++) {
      if (this.isSectorAligned(block)) {
        const { logicalAddress } = await this.selectBlock(block);
        await this.unprotectSector(logicalAddress);
      }
    }
  }

  public async resetMapper(): Promise<void> {
    await this.select();
    await this.player.writeMemory(0x6000, 0);
    await this.player.writeMemory(0x7000, 0);
  }

  public async resetFlash(): Promise<void> {
    await this.select();
    await this.command.reset();
  }

  public isProgrammable(): boolean {
    return (this.capabilityFlash && this.capacity != 0) || ((this.continuity & 1) != 0);
  }

  public assertProgrammable(): void {
    if (!this.isProgrammable()) {
      throw new Error('No programmable CFI FlashROM detected.');
    }
  }

  public isSectorAligned(block: number): boolean {
    return this.cfiQuery.isSectorAligned(block);
  }

  private async selectBlock(block: number) {
    const mapped = mapPhysicalAddress(block * BLOCK_SIZE);
    await this.player.writeMemory(mapped.bankAddress, mapped.bankData);
    return mapped;
  }

  private async protectSector(logicalAddress: number): Promise<void> {
    if (this.capabilityProtect) {
      await this.command.setSectorDynamicProtect(logicalAddress, 0);
    }
  }

  private async unprotectSector(logicalAddress: number): Promise<void> {
    if (this.capabilityProtect) {
      await this.command.setSectorDynamicProtect(logicalAddress, 1);
    }
  }

  private async select(): Promise<void> {
    await this.player.selectSlot(this.slot.primary);
    if (this.slot.secondary != undefined) {
      await this.player.selectSecondarySlot(this.slot.secondary);
    }
  }

  private supportsContinuity(): boolean {
    if (this.autoSelect.manufacturer != 0x01 || this.autoSelect.device1 != 0x7e) {
      return false;
    }
    const device2 = this.autoSelect.device2;
    if (device2 == 0x10) {
      return this.autoSelect.device3 == 0x00;
    }
    if (device2 == 0x0c || device2 == 0x13 || device2 == 0x23) {
      return this.autoSelect.device3 == 0x01;
    }
    return false;
  }

  private printContinuity(): void {
    if (this.continuity == 1) {
      console.log('- Continuity: OK');
    } else if (this.continuity == 0) {
      console.log('- Continuity: BAD. Check pins for bridges.');
    } else {
      console.log('- Continuity: BAD status.');
    }
  }
}

function formatSize(bytes: number): string {
  if (bytes >= 1024 * 1024) {
    return `${bytes / (1024 * 1024)} MB`;
  }
  if (bytes >= 1024) {
    return `${bytes / 1024} kB`;
  }
  return `${bytes} bytes`;
}
