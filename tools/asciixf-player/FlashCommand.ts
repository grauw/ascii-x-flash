import { mapPhysicalAddress } from './ASCII16XMapper.ts';
import { hex } from './Format.ts';
import { type CommandQueueMode, MSXCommand, TransferBufferToSlotCommand, WriteMemoryCommand } from './MSXCommand.ts';

export interface FlashCommandPlayer {
  commandQueueMode?: CommandQueueMode;
  writeMemory(address: number, data: number): Promise<unknown>;
  readMemory(address: number): Promise<number>;
  transferBufferToSlot(address: number, length: number, bufferAddress: number): Promise<unknown>;
  executeQueuedCommands?(commands: MSXCommand[]): Promise<unknown>;
}

const UNLOCK1 = 0x4aaa;
const UNLOCK2 = 0x4555;
const CFI_QUERY_ADDRESS = 0x40aa;
const EXTENDED_STATUS_ADDRESS = 0x4aaa;
const CONTINUITY_ADDRESS1 = 0x15554ab;
const CONTINUITY_ADDRESS2 = 0x2aaab54;

export class FlashCommand {
  private player: FlashCommandPlayer;

  public constructor(player: FlashCommandPlayer) {
    this.player = player;
  }

  public async reset(): Promise<void> {
    await this.player.writeMemory(0x4000, 0xf0);
  }

  private async abortReset(): Promise<void> {
    await this.player.writeMemory(UNLOCK1, 0xaa);
    await this.player.writeMemory(UNLOCK2, 0x55);
    await this.player.writeMemory(UNLOCK1, 0xf0);
  }

  public async cfiQuery(): Promise<void> {
    await this.player.writeMemory(CFI_QUERY_ADDRESS, 0x98);
  }

  public async autoSelect(): Promise<void> {
    await this.unlock();
    await this.player.writeMemory(UNLOCK1, 0x90);
  }

  public async readParameterBlock(address: number, data: Uint8Array): Promise<void> {
    for (let index = 0; index < data.length; index++) {
      data[index] = await this.player.readMemory(address + index * 2);
    }
  }

  public async chipErase(): Promise<void> {
    await this.unlock();
    await this.player.writeMemory(UNLOCK1, 0x80);
    await this.unlock();
    await this.player.writeMemory(UNLOCK1, 0x10);
    await this.poll(0x4000, 0xff, 120000);
  }

  public async sectorErase(logicalAddress: number): Promise<void> {
    await this.unlock();
    await this.player.writeMemory(UNLOCK1, 0x80);
    await this.unlock();
    await this.player.writeMemory(logicalAddress, 0x30);
    await this.poll(logicalAddress, 0xff, 30000);
  }

  public async programByte(logicalAddress: number, data: number): Promise<void> {
    await this.unlock();
    await this.player.writeMemory(UNLOCK1, 0xa0);
    await this.player.writeMemory(logicalAddress, data);
    await this.poll(logicalAddress, data, 5000);
  }

  public async programBuffer(logicalAddress: number, bufferAddress: number, length: number, expectedLastByte: number): Promise<void> {
    if (this.player.executeQueuedCommands != undefined && this.player.commandQueueMode != 'off') {
      await this.player.executeQueuedCommands([
        new WriteMemoryCommand(UNLOCK1, 0xaa),
        new WriteMemoryCommand(UNLOCK2, 0x55),
        new WriteMemoryCommand(logicalAddress, 0x25),
        new WriteMemoryCommand(logicalAddress, length - 1),
        new TransferBufferToSlotCommand(logicalAddress, length, bufferAddress),
        new WriteMemoryCommand(logicalAddress + length - 1, 0x29)
      ]);
    } else {
      await this.unlock();
      await this.player.writeMemory(logicalAddress, 0x25);
      await this.player.writeMemory(logicalAddress, length - 1);
      await this.player.transferBufferToSlot(logicalAddress, length, bufferAddress);
      await this.player.writeMemory(logicalAddress + length - 1, 0x29);
    }
    await this.poll(logicalAddress + length - 1, expectedLastByte, 5000);
  }

  public async setSectorDynamicProtect(logicalAddress: number, value: number): Promise<void> {
    await this.unlock();
    await this.player.writeMemory(UNLOCK1, 0xe0);
    await this.player.writeMemory(logicalAddress, 0xa0);
    await this.player.writeMemory(logicalAddress, value);
    await this.player.writeMemory(logicalAddress, 0x90);
    await this.player.writeMemory(logicalAddress, 0x00);
  }

  public async checkContinuity(): Promise<number> {
    const mapped1 = await this.selectPhysicalAddress(CONTINUITY_ADDRESS1);
    const mapped2 = await this.selectPhysicalAddress(CONTINUITY_ADDRESS2);
    await this.clearExtendedStatus();
    if ((await this.readExtendedStatus()) & 1) {
      await this.resetMapper();
      return 2;
    } else {
      await this.player.writeMemory(mapped1.logicalAddress, 0xff);
      await this.player.writeMemory(mapped2.logicalAddress, 0x00);
      const continuity = (await this.readExtendedStatus()) & 1;
      await this.resetMapper();
      return continuity;
    }
  }

  public async poll(address: number, expected: number, timeoutMs: number): Promise<void> {
    if (!await this.pollValue(address, expected, 128)) {
      const status = await this.pollDQ6(address, timeoutMs);
      if ((status & 0x40) != 0) {
        if ((status & 0x02) != 0) {
          await this.abortReset();
        } else {
          await this.reset();
        }
        throw new Error(`Timed out polling ${hex(address, 4)} for ${hex(expected, 2)}; status was ${hex(status, 2)}`);
      } else {
        const value = await this.player.readMemory(address);
        if (value != expected) {
          throw new Error(`Timed out polling ${hex(address, 4)} for ${hex(expected, 2)}; last value was ${hex(value, 2)}`);
        }
      }
    }
  }

  private async pollValue(address: number, expected: number, count: number): Promise<boolean> {
    for (let attempt = 0; attempt < count; attempt++) {
      const value = await this.player.readMemory(address);
      if (value == expected) {
        return true;
      }
    }
    return false;
  }

  private async pollDQ6(address: number, timeoutMs: number): Promise<number> {
    const start = Date.now();
    while (true) {
      const status = await this.readStatus(address);
      if ((status & 0x40) == 0) {
        return status;
      }
      if ((status & 0x22) != 0) {
        return this.readStatus(address);
      }
      if (Date.now() - start > timeoutMs) {
        await this.reset();
        throw new Error(`Timed out waiting for DQ6 at ${hex(address, 4)}`);
      }
    }
  }

  private async readStatus(address: number): Promise<number> {
    const value1 = await this.player.readMemory(address);
    const value2 = await this.player.readMemory(address);
    return (value1 & 0x44) ^ value2;
  }

  private async unlock(): Promise<void> {
    await this.player.writeMemory(UNLOCK1, 0xaa);
    await this.player.writeMemory(UNLOCK2, 0x55);
  }

  private async selectPhysicalAddress(physicalAddress: number) {
    const mapped = mapPhysicalAddress(physicalAddress);
    await this.player.writeMemory(mapped.bankAddress, mapped.bankData);
    return mapped;
  }

  private async resetMapper(): Promise<void> {
    await this.player.writeMemory(0x6000, 0);
    await this.player.writeMemory(0x7000, 0);
  }

  private async clearExtendedStatus(): Promise<void> {
    await this.player.writeMemory(EXTENDED_STATUS_ADDRESS, 0x71);
  }

  private async readExtendedStatus(): Promise<number> {
    await this.player.writeMemory(EXTENDED_STATUS_ADDRESS, 0x70);
    return this.player.readMemory(0x4000);
  }
}
