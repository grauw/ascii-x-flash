export function hex(value: number, width = 0): string {
  if (!Number.isInteger(value) || value < 0) {
    throw new RangeError(`Expected a non-negative integer, got ${value}`);
  }
  return value.toString(16).toUpperCase().padStart(width, '0');
}

export function parseHex(value: string, label: string): number {
  if (typeof value != 'string' || value.length == 0) {
    throw new Error(`Missing ${label}`);
  }
  const normalized = value.replace(/^0x/i, '').replaceAll("'", '');
  if (!/^[0-9a-f]+$/i.test(normalized)) {
    throw new Error(`Invalid ${label}: ${value}`);
  }
  return Number.parseInt(normalized, 16);
}

export function assertByte(value: number, label: string): void {
  if (!Number.isInteger(value) || value < 0 || value > 0xff) {
    throw new RangeError(`${label} must be a byte, got ${value}`);
  }
}

export function assertWord(value: number, label: string): void {
  if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
    throw new RangeError(`${label} must be a 16-bit value, got ${value}`);
  }
}
