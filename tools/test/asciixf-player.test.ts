import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { mapPhysicalAddress } from '../asciixf-player/ASCII16XMapper.ts';
import { Application } from '../asciixf-player/Application.ts';
import { CLI } from '../asciixf-player/CLI.ts';
import { CFIQuery } from '../asciixf-player/CFIQuery.ts';
import { FlashCommand } from '../asciixf-player/FlashCommand.ts';

class MockPlayer {
  public received: { bufferAddress: number; data: Uint8Array }[] = [];
  public transfers: { address: number; length: number; bufferAddress: number }[] = [];
  private mode?: 'cfi' | 'autoSelect';
  private powered = false;
  private selectedPrimary = 1;
  private selectedSecondary?: number;
  private buffers = new Map<number, Uint8Array>();
  private programmed = new Map<string, Map<number, number>>();
  private cfi = makeProgramCfiRaw();
  private autoSelect = makeAutoSelectRaw();

  public async powerOn(): Promise<string[]> {
    this.powered = true;
    return [];
  }

  public async powerOff(): Promise<string[]> {
    this.powered = false;
    return [];
  }

  public isPowered(): boolean {
    return this.powered;
  }

  public async close(): Promise<void> {
  }

  public async setLoopCount(): Promise<string[]> {
    return [];
  }

  public async selectSlot(slot: number): Promise<string[]> {
    this.selectedPrimary = slot;
    this.selectedSecondary = undefined;
    return [];
  }

  public async detectExpandedSlot(): Promise<boolean> {
    return false;
  }

  public async selectSecondarySlot(slot: number): Promise<string[]> {
    this.selectedSecondary = slot;
    return [];
  }

  public async writeMemory(address: number, data: number): Promise<string[]> {
    if (address == 0x40aa && data == 0x98) {
      this.mode = 'cfi';
    } else if (address == 0x4aaa && data == 0x90) {
      this.mode = 'autoSelect';
    } else if (address == 0x4000 && data == 0xf0) {
      this.mode = undefined;
    }
    return [];
  }

  public async readMemory(address: number): Promise<number> {
    if (this.mode == 'cfi' && address >= 0x4000 && ((address - 0x4000) & 1) == 0) {
      return this.cfi[(address - 0x4000) / 2] ?? 0xff;
    }
    if (this.mode == 'autoSelect' && address >= 0x4000 && ((address - 0x4000) & 1) == 0) {
      return this.autoSelect[(address - 0x4000) / 2] ?? 0xff;
    }
    return this.programmedForSlot().get(address) ?? 0xff;
  }

  public async receiveBuffer(address: number, data: Uint8Array): Promise<string[]> {
    const buffer = new Uint8Array(data);
    this.received.push({ bufferAddress: address, data: buffer });
    this.buffers.set(address, buffer);
    return [];
  }

  public async sendBuffer(address: number, data: Uint8Array): Promise<string[]> {
    return [];
  }

  public async transferSlotToBuffer(): Promise<string[]> {
    return [];
  }

  public async transferBufferToSlot(address: number, length: number, bufferAddress: number): Promise<string[]> {
    this.transfers.push({ address, length, bufferAddress });
    for (let index = 0; index < length; index++) {
      this.programmedForSlot().set(address + index, this.readBufferByte(bufferAddress + index));
    }
    return [];
  }

  public programmedBytes(slot: number): Map<number, number> {
    return this.programmed.get(`${slot}`) ?? new Map<number, number>();
  }

  private readBufferByte(address: number): number {
    for (const [base, buffer] of this.buffers) {
      const offset = address - base;
      if (offset >= 0 && offset < buffer.length) {
        return buffer[offset];
      }
    }
    throw new Error(`No mock buffer byte at ${address.toString(16)}`);
  }

  private programmedForSlot(): Map<number, number> {
    const key = this.selectedSecondary == undefined ? `${this.selectedPrimary}` : `${this.selectedPrimary}-${this.selectedSecondary}`;
    let programmed = this.programmed.get(key);
    if (programmed == undefined) {
      programmed = new Map<number, number>();
      this.programmed.set(key, programmed);
    }
    return programmed;
  }
}

class ContinuityPlayer {
  public writes: { address: number; data: number }[] = [];
  private statuses: number[];

  public constructor(statuses: number[]) {
    this.statuses = statuses;
  }

  public async writeMemory(address: number, data: number): Promise<string[]> {
    this.writes.push({ address, data });
    return [];
  }

  public async readMemory(address: number): Promise<number> {
    assert.equal(address, 0x4000);
    return this.statuses.shift() ?? 0;
  }

  public async transferBufferToSlot(address: number, length: number, bufferAddress: number): Promise<string[]> {
    assert.fail(`Unexpected transferBufferToSlot ${address} ${length} ${bufferAddress}`);
  }
}

class PollPlayer {
  public writes: { address: number; data: number }[] = [];
  private reads: number[];

  public constructor(reads: number[]) {
    this.reads = reads;
  }

  public async writeMemory(address: number, data: number): Promise<string[]> {
    this.writes.push({ address, data });
    return [];
  }

  public async readMemory(address: number): Promise<number> {
    assert.equal(address, 0x8000);
    const value = this.reads.shift();
    if (value == undefined) {
      throw new Error('Unexpected poll read');
    }
    return value;
  }

  public async transferBufferToSlot(address: number, length: number, bufferAddress: number): Promise<string[]> {
    assert.fail(`Unexpected transferBufferToSlot ${address} ${length} ${bufferAddress}`);
  }
}

test('maps ASCII16-X physical addresses like the Z80 implementation', () => {
  assert.deepEqual(mapPhysicalAddress(0x0000000), {
    logicalAddress: 0x8000,
    bankAddress: 0x7000,
    bankData: 0x00,
    block: 0x0000,
    bank: 0x000
  });
  assert.deepEqual(mapPhysicalAddress(0x0001000), {
    logicalAddress: 0x5000,
    bankAddress: 0x6000,
    bankData: 0x00,
    block: 0x0001,
    bank: 0x000
  });
  assert.equal(mapPhysicalAddress(0x03fc000).logicalAddress, 0x8000);
  assert.equal(mapPhysicalAddress(0x03fc000).bankAddress, 0x7000);
  assert.equal(mapPhysicalAddress(0x03fc000).bankData, 0xff);
  assert.equal(mapPhysicalAddress(0x0400000).bankAddress, 0x7100);
  assert.equal(mapPhysicalAddress(0x3fff000).logicalAddress, 0x7000);
  assert.equal(mapPhysicalAddress(0x3fff000).bankAddress, 0x6f00);
  assert.equal(mapPhysicalAddress(0x3fff000).bankData, 0xff);
});

test('parses dash short options and converts byte addresses to 4K blocks', () => {
  const cli = new CLI([
    '--port', '/dev/tty.usbmodem1',
    '-s1',
    '-fs4000',
    '-as1000',
    '-ae9000',
    '-pb6',
    '-p',
    'game.rom'
  ]);
  assert.equal(cli.baudRate, 115200);
  assert.equal(cli.fileStart, 0x4000);
  assert.equal(cli.addressStart, 1);
  assert.equal(cli.addressEnd, 9);
  assert.equal(cli.bufferPageMask, 0x3f);
  assert.equal(cli.port, '/dev/tty.usbmodem1');
  assert.deepEqual(cli.slots, [{ primary: 1 }]);
  assert.equal(cli.program, true);
  assert.equal(cli.path, 'game.rom');
});

test('still accepts slash-prefixed short options', () => {
  const cli = new CLI([
    '--port', '/dev/tty.usbmodem1',
    '/s', '2',
    '/pb', '5',
    '/ec',
    '/v',
    'game.rom'
  ]);
  assert.equal(cli.baudRate, 115200);
  assert.equal(cli.fileStart, 0);
  assert.equal(cli.addressStart, 0);
  assert.equal(cli.bufferPageMask, 0x1f);
  assert.equal(cli.port, '/dev/tty.usbmodem1');
  assert.deepEqual(cli.slots, [{ primary: 2 }]);
  assert.equal(cli.chipErase, true);
  assert.equal(cli.verify, true);
  assert.equal(cli.path, 'game.rom');
});

test('sets default file operations during construction', () => {
  const cli = new CLI([
    '--port', '/dev/tty.usbmodem1',
    '-s1',
    'game.rom'
  ]);
  assert.equal(cli.erase, true);
  assert.equal(cli.program, true);
  assert.equal(cli.verify, true);
});

test('accepts SSEL slots 1-2 with optional secondary slot', () => {
  const slot1 = new CLI([
    '--port', '/dev/tty.usbmodem1',
    '-s1',
    '-i'
  ]);
  assert.equal(slot1.baudRate, 115200);
  assert.equal(slot1.fileStart, 0);
  assert.equal(slot1.addressStart, 0);
  assert.equal(slot1.port, '/dev/tty.usbmodem1');
  assert.deepEqual(slot1.slots, [{ primary: 1 }]);
  assert.equal(slot1.info, true);

  assert.deepEqual(new CLI([
    '--port', '/dev/tty.usbmodem1',
    '-s2',
    '-i'
  ]).slots, [{ primary: 2 }]);

  assert.deepEqual(new CLI([
    '--port', '/dev/tty.usbmodem1',
    '-s1-2',
    '-i'
  ]).slots, [{ primary: 1, secondary: 2 }]);

  assert.deepEqual(new CLI([
    '--port', '/dev/tty.usbmodem1',
    '/s2-0',
    '-i'
  ]).slots, [{ primary: 2, secondary: 0 }]);

});

test('rejects invalid slots during construction', () => {
  for (const slot of ['-s0', '-s3', '-sx', '-s1-4']) {
    assert.throws(() => new CLI([
      '--port', '/dev/tty.usbmodem1',
      slot,
      '-i'
    ]), /Missing or invalid --slot/);
  }
});

test('accepts repeated slots for bulk flashing', () => {
  const cli = new CLI([
    '--port', '/dev/tty.usbmodem1',
    '-s1-0',
    '/s1-1',
    '--slot', '2-3',
    '-p',
    'game.rom'
  ]);
  assert.deepEqual(cli.slots, [
    { primary: 1, secondary: 0 },
    { primary: 1, secondary: 1 },
    { primary: 2, secondary: 3 }
  ]);
});

test('rejects duplicate slots', () => {
  assert.throws(() => new CLI([
    '--port', '/dev/tty.usbmodem1',
    '-s1-2',
    '/s1-2',
    '-i'
  ]), /same slot twice/);
});

test('parses CFI capacity, write buffer and AMD protection scheme', () => {
  const raw = new Uint8Array(0x80);
  writeAscii(raw, 0x10, 'QRY');
  raw[0x13] = 0x02;
  raw[0x14] = 0x00;
  raw[0x15] = 0x40;
  raw[0x16] = 0x00;
  raw[0x27] = 23;
  raw[0x2a] = 8;
  raw[0x2c] = 1;
  raw[0x2d] = 0x7f;
  raw[0x2e] = 0x00;
  raw[0x2f] = 0x00;
  raw[0x30] = 0x01;
  writeAscii(raw, 0x40, 'PRI');
  raw[0x49] = 8;

  const cfi = new CFIQuery();
  cfi.buffer.set(raw);
  assert.equal(cfi.hasSignature, true);
  assert.equal(cfi.primaryVendorID, 0x0002);
  assert.equal(cfi.primaryVendorQuery, 0x0040);
  assert.equal(cfi.deviceSize, 23);
  assert.equal(cfi.deviceInterface, 0);
  assert.equal(cfi.bufferPageMask, 0xff);
  assert.deepEqual(cfi.regions, [{ count: 128, size: 0x10000 }]);
  assert.equal(cfi.amdQuery?.sectorProtectScheme, 8);
});

test('checks flash continuity through extended status', async () => {
  const player = new ContinuityPlayer([0, 1]);
  const result = await new FlashCommand(player).checkContinuity();
  assert.equal(result, 1);
  assert.deepEqual(player.writes, [
    { address: 0x6500, data: 0x55 },
    { address: 0x7a00, data: 0xaa },
    { address: 0x4aaa, data: 0x71 },
    { address: 0x4aaa, data: 0x70 },
    { address: 0x54ab, data: 0xff },
    { address: 0xab54, data: 0x00 },
    { address: 0x4aaa, data: 0x70 },
    { address: 0x6000, data: 0x00 },
    { address: 0x7000, data: 0x00 }
  ]);
});

test('poll falls back from value polling to DQ6 polling', async () => {
  const player = new PollPlayer([
    ...repeatByte(0x00, 128),
    0x40, 0x00,
    0x00, 0x00,
    0xa5
  ]);
  await new FlashCommand(player).poll(0x8000, 0xa5, 5000);
  assert.deepEqual(player.writes, []);
});

test('programming stages a block in the MSXPLAYer buffer at C000', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'asciixf-player-'));
  try {
    const path = join(directory, 'page.rom');
    const data = makeAscendingBytes(32);
    await writeFile(path, data);

    const player = new MockPlayer();
    const application = new Application({
      slots: [{ primary: 1 }],
      bufferPageMask: 0xff,
      fileStart: 0,
      addressStart: 0,
      addressEnd: 1,
      program: true,
      path
    }, player);
    const log = console.log;
    const write = process.stdout.write;
    console.log = () => {};
    process.stdout.write = (() => true) as typeof process.stdout.write;
    try {
      await application.run();
    } finally {
      console.log = log;
      process.stdout.write = write;
    }

    assert.equal(player.received.length, 1);
    assert.equal(player.received[0].bufferAddress, 0xc000);
    assertBytesEqual(player.received[0].data, data);
    assert.deepEqual(player.transfers, [
      { address: 0x8000, length: 32, bufferAddress: 0xc000 }
    ]);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('programming writes each block to all selected flash devices', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'asciixf-player-'));
  try {
    const path = join(directory, 'page.rom');
    const data = makeAscendingBytes(32);
    await writeFile(path, data);

    const player = new MockPlayer();
    const application = new Application({
      slots: [{ primary: 1 }, { primary: 2 }],
      bufferPageMask: 0xff,
      fileStart: 0,
      addressStart: 0,
      addressEnd: 1,
      program: true,
      path
    }, player);
    const log = console.log;
    const write = process.stdout.write;
    console.log = () => {};
    process.stdout.write = (() => true) as typeof process.stdout.write;
    try {
      await application.run();
    } finally {
      console.log = log;
      process.stdout.write = write;
    }

    assert.equal(player.received.length, 2);
    assert.equal(player.received[0].bufferAddress, 0xc000);
    assert.equal(player.received[1].bufferAddress, 0xc000);
    assertBytesEqual(player.received[0].data, data);
    assertBytesEqual(player.received[1].data, data);
    assert.deepEqual(player.transfers, [
      { address: 0x8000, length: 32, bufferAddress: 0xc000 },
      { address: 0x8000, length: 32, bufferAddress: 0xc000 }
    ]);
    for (const slot of [1, 2]) {
      for (let offset = 0; offset < data.length; offset++) {
        assert.equal(player.programmedBytes(slot).get(0x8000 + offset), data[offset]);
      }
    }
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

function makeProgramCfiRaw(): Uint8Array {
  const raw = new Uint8Array(0x80);
  writeAscii(raw, 0x10, 'QRY');
  raw[0x27] = 12;
  raw[0x2a] = 5;
  return raw;
}

function makeAutoSelectRaw(): Uint8Array {
  const raw = new Uint8Array(0x10);
  raw[0] = 0x01;
  raw[1] = 0x20;
  return raw;
}

function makeAscendingBytes(length: number): Uint8Array {
  const bytes = new Uint8Array(length);
  for (let index = 0; index < length; index++) {
    bytes[index] = index;
  }
  return bytes;
}

function repeatByte(value: number, length: number): number[] {
  return Array.from({ length }, () => value);
}

function writeAscii(target: Uint8Array, offset: number, value: string): void {
  for (let index = 0; index < value.length; index++) {
    target[offset + index] = value.charCodeAt(index);
  }
}

function assertBytesEqual(actual: Uint8Array, expected: Uint8Array): void {
  assert.deepEqual(Array.from(actual), Array.from(expected));
}
