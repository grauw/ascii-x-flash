import { SerialPort } from 'serialport';
import { hex, assertByte, assertWord } from './Format.ts';
import { type CommandQueueMode, MSXCommand } from './MSXCommand.ts';
import { SerialLine } from './SerialLine.ts';

const DEFAULT_TIMEOUT_MS = 30000;

interface OpenOptions {
  baudRate?: number;
  traceSerial?: boolean;
  commandQueueMode?: CommandQueueMode;
}

interface CommandOptions {
  timeoutMs?: number;
}

export class MSXPlayer {
  public static async open(path: string, { baudRate = 115200, traceSerial = false, commandQueueMode = 'erroff' }: OpenOptions = {}): Promise<MSXPlayer> {
    const port = new SerialPort({ path, baudRate, autoOpen: false });
    await new Promise<void>((resolve, reject) => port.open((error) => error ? reject(error) : resolve()));
    return new MSXPlayer(port, traceSerial, commandQueueMode);
  }

  public commandQueueMode: CommandQueueMode;
  private port: SerialPort;
  private line: SerialLine;
  private traceSerial: boolean;
  private powered = false;

  public constructor(port: SerialPort, traceSerial = false, commandQueueMode: CommandQueueMode = 'erroff') {
    this.port = port;
    this.line = new SerialLine(port);
    this.traceSerial = traceSerial;
    this.commandQueueMode = commandQueueMode;
  }

  public async close(): Promise<void> {
    if (!this.port.isOpen) {
      return;
    }
    await new Promise<void>((resolve, reject) => this.port.close((error) => error ? reject(error) : resolve()));
  }

  public async command(command: string, { timeoutMs = DEFAULT_TIMEOUT_MS }: CommandOptions = {}): Promise<string[]> {
    await this.writeCommand(command);
    const lines = [];
    while (true) {
      const line = await this.readLine(timeoutMs);
      if (/^OK$/i.test(line)) {
        return lines;
      }
      if (/^FAIL$/i.test(line)) {
        throw new Error(`MSXPLAYer command failed: ${command}${lines.length ? `\n${lines.join('\n')}` : ''}`);
      }
      lines.push(line);
    }
  }

  public async executeQueuedCommands(commands: MSXCommand[], options: CommandOptions = {}): Promise<string[]> {
    let lines;
    if (this.commandQueueMode == 'plain') {
      lines = await this.executePlainQueuedCommands(commands, options);
    } else {
      lines = await this.executeErroffQueuedCommands(commands, options);
    }
    for (const line of lines) {
      for (const command of commands) {
        if (command.readResponse(line)) {
          break;
        }
      }
    }
    return lines;
  }

  private async executeErroffQueuedCommands(commands: MSXCommand[], options: CommandOptions): Promise<string[]> {
    await this.writeCommands([
      'ERROFF',
      ...commands.map((command) => command.toString())
    ]);
    return this.command('ERRON', options);
  }

  private async executePlainQueuedCommands(commands: MSXCommand[], options: CommandOptions): Promise<string[]> {
    await this.writeCommands(commands.map((command) => command.toString()));
    const allLines = [];
    for (const command of commands) {
      this.trace(`? ${command.toString()}`);
      const lines = await this.readStatus(command.toString(), options);
      allLines.push(...lines);
    }
    return allLines;
  }

  public async receiveBuffer(address: number, data: Uint8Array, options: CommandOptions = {}): Promise<string[]> {
    assertWord(address, 'Buffer address');
    if (data.length > 0xffff) {
      throw new RangeError(`Buffer receive length too large: ${data.length}`);
    }
    await this.writeCommand(`BRCV,${hex(address, 4)},${hex(data.length, 4)}`);
    await this.writeBytes(data);
    return this.readStatus(`BRCV`, options);
  }

  public async sendBuffer(address: number, data: Uint8Array, options: CommandOptions = {}): Promise<string[]> {
    assertWord(address, 'Buffer address');
    assertWord(data.length, 'Buffer send length');
    await this.writeCommand(`BSND,${hex(address, 4)},${hex(data.length, 4)}`);
    await this.line.readBytes(data, options.timeoutMs ?? DEFAULT_TIMEOUT_MS);
    this.trace(`< binary ${data.length} bytes`);
    return this.readStatus('BSND', options);
  }

  public async selectSlot(slot: number): Promise<string[]> {
    return this.command(`SSEL,${hex(slot, 2)}`);
  }

  public async detectExpandedSlot(): Promise<boolean> {
    const previous = await this.readMemory(0xffff);
    const probe = 0x5a;
    await this.writeMemory(0xffff, probe);
    const result = await this.readMemory(0xffff);
    const expanded = result == (probe ^ 0xff);
    if (expanded) {
      await this.writeMemory(0xffff, previous ^ 0xff);
    }
    return expanded;
  }

  public async selectSecondarySlot(slot: number): Promise<void> {
    assertByte(slot, 'Secondary slot');
    const value = slot * 0x55;
    await this.writeMemory(0xffff, value);
    const result = await this.readMemory(0xffff);
    if (result != (value ^ 0xff)) {
      throw new Error(`Could not select secondary slot ${slot}; expanded slot register read ${hex(result, 2)}`);
    }
  }

  public async powerOn(): Promise<string[]> {
    const result = await this.command('SPON');
    this.powered = true;
    return result;
  }

  public async powerOff(): Promise<string[]> {
    const result = await this.command('SPOFF');
    this.powered = false;
    return result;
  }

  public isPowered(): boolean {
    return this.powered;
  }

  public async setLoopCount(count: number): Promise<string[]> {
    assertWord(count, 'Script loop count');
    return this.command(`LSCR,${hex(count, 4)}`);
  }

  public async readMemory(address: number): Promise<number> {
    assertWord(address, 'Slot memory address');
    const lines = await this.command(`SMRD,${hex(address, 4)}`);
    const line = lines.find((entry) => entry.includes(':'));
    const match = line?.match(/^\s*[0-9a-f]{1,4}\s*:\s*([0-9a-f]{1,2})\s*$/i);
    if (!match) {
      throw new Error(`Could not parse SMRD response: ${lines.join('\n')}`);
    }
    return Number.parseInt(match[1], 16);
  }

  public async writeMemory(address: number, data: number): Promise<string[]> {
    assertWord(address, 'Slot memory address');
    assertByte(data, 'Slot memory data');
    return this.command(`SMWR,${hex(address, 4)},${hex(data, 2)}`);
  }

  public async transferSlotToBuffer(address: number, length: number, bufferAddress: number): Promise<string[]> {
    assertWord(address, 'Slot memory address');
    assertWord(length, 'Slot transfer length');
    assertWord(bufferAddress, 'Buffer address');
    return this.command(`SMTR,${hex(address, 4)},${hex(length, 4)},${hex(bufferAddress, 4)}`);
  }

  public async transferBufferToSlot(address: number, length: number, bufferAddress: number): Promise<string[]> {
    assertWord(address, 'Slot memory address');
    assertWord(length, 'Slot transfer length');
    assertWord(bufferAddress, 'Buffer address');
    return this.command(`SMTW,${hex(address, 4)},${hex(length, 4)},${hex(bufferAddress, 4)}`);
  }

  private async readStatus(command: string, { timeoutMs = DEFAULT_TIMEOUT_MS }: CommandOptions = {}): Promise<string[]> {
    const lines = [];
    while (true) {
      const line = await this.readLine(timeoutMs);
      if (/^OK$/i.test(line)) {
        return lines;
      }
      if (/^FAIL$/i.test(line)) {
        throw new Error(`MSXPLAYer command failed: ${command}${lines.length ? `\n${lines.join('\n')}` : ''}`);
      }
      lines.push(line);
    }
  }

  private async writeCommand(command: string): Promise<void> {
    this.trace(`> ${command}`);
    await this.line.write(`${command}\r\n`);
  }

  private async writeCommands(commands: string[]): Promise<void> {
    for (const command of commands) {
      this.trace(`> ${command}`);
    }
    await this.line.write(commands.map((command) => `${command}\r\n`).join(''));
    this.trace(`> batch written (${commands.length} commands)`);
  }

  private async writeBytes(data: Uint8Array): Promise<void> {
    this.trace(`> binary ${data.length} bytes`);
    await this.line.write(data);
  }

  private async readLine(timeoutMs: number): Promise<string> {
    try {
      const line = await this.line.readLine(timeoutMs);
      this.trace(`< ${line}`);
      return line;
    } catch (error) {
      this.trace(`< ${error instanceof Error ? error.message : error}`);
      throw error;
    }
  }

  private trace(message: string): void {
    if (this.traceSerial) {
      process.stderr.write(`[serial] ${message}\n`);
    }
  }
}
