#!/usr/bin/env node

import { parseHex } from './asciixf-player/Format.ts';
import { ReadMemoryCommand } from './asciixf-player/MSXCommand.ts';
import { MSXPlayer } from './asciixf-player/MSXPlayer.ts';

interface Options {
  port?: string;
  baudRate: number;
  slot: number;
  address: number;
  traceSerial: boolean;
}

const HELP = `Test whether SMRD emits data while ERROFF is active

Usage:
  node tools/test-erroff-read.ts --port <serial-port> --slot <1|2> [options]

Options:
  --port <path>              Serial port exposed by MSXPLAYer
  --baud <rate>              Serial baud rate (default: 115200)
  --slot, -s <slot>          SSEL slot 1 or 2
  --address, -a <hex>        Slot address to read (default: 8000)
  --trace-serial, -ts        Trace serial communication to stderr
  --help, -h                 Show this help`;

async function main(argv: string[]): Promise<void> {
  const options = parseArgs(argv);
  if (options.port == undefined) {
    throw new Error('Missing --port.');
  }

  const player = await MSXPlayer.open(options.port, {
    baudRate: options.baudRate,
    traceSerial: options.traceSerial
  });

  try {
    await player.powerOn();
    await player.selectSlot(options.slot);

    const normal = await player.readMemory(options.address);
    console.log(`Normal SMRD: ${normal.toString(16).padStart(2, '0')}`);

    const readMemory = new ReadMemoryCommand(options.address);
    const lines = await player.executeQueuedCommands([readMemory]);
    console.log('Queued ERROFF/SMRD/ERRON lines:');
    for (const line of lines) {
      console.log(line);
    }
    console.log(`Queued SMRD parsed value: ${formatByte(readMemory.value)}`);
  } finally {
    if (player.isPowered()) {
      await player.powerOff().catch(() => {});
    }
    await player.close();
  }
}

function formatByte(value: number | undefined): string {
  return value == undefined ? 'undefined' : value.toString(16).padStart(2, '0');
}

function parseArgs(argv: string[]): Options {
  const options: Options = {
    baudRate: 115200,
    slot: 1,
    address: 0x8000,
    traceSerial: false
  };

  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    if (arg == '--help' || arg == '-h' || arg == '/h') {
      console.log(HELP);
      process.exit(0);
    } else if (arg == '--port') {
      options.port = requireValue(argv, ++index, arg);
    } else if (arg == '--baud') {
      options.baudRate = Number(requireValue(argv, ++index, arg));
    } else if (arg == '--slot' || arg == '-s' || arg == '/s') {
      options.slot = parseSlot(requireValue(argv, ++index, arg));
    } else if (arg.startsWith('-s') || arg.startsWith('/s')) {
      options.slot = parseSlot(arg.slice(2));
    } else if (arg == '--address' || arg == '-a' || arg == '/a') {
      options.address = parseHex(requireValue(argv, ++index, arg), 'address');
    } else if (arg.startsWith('-a') || arg.startsWith('/a')) {
      options.address = parseHex(arg.slice(2), 'address');
    } else if (arg == '--trace-serial' || arg == '-ts' || arg == '/ts') {
      options.traceSerial = true;
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  if (!Number.isInteger(options.baudRate) || options.baudRate <= 0) {
    throw new Error(`Invalid baud rate: ${options.baudRate}`);
  }
  return options;
}

function parseSlot(value: string): number {
  const slot = Number.parseInt(value, 10);
  if (value.match(/^[0-9]+$/) && (slot == 1 || slot == 2)) {
    return slot;
  }
  throw new Error(`Invalid slot: ${value}`);
}

function requireValue(argv: string[], index: number, option: string): string {
  if (index >= argv.length) {
    throw new Error(`Missing value for ${option}`);
  }
  return argv[index];
}

main(process.argv.slice(2)).catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
