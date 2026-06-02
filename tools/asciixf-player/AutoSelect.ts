import { hex } from './Format.ts';

export class AutoSelect {
  public readonly buffer = new Uint8Array(0x10);

  public get manufacturer(): number {
    return this.buffer[0];
  }

  public get hasValidManufacturer(): boolean {
    let manufacturer = this.manufacturer;
    let parity = 0;
    while (manufacturer) {
      parity ^= manufacturer & 1;
      manufacturer >>= 1;
    }
    return parity == 1;
  }

  public get device1(): number {
    return this.buffer[1];
  }

  public get protected(): number {
    return this.buffer[2];
  }

  public get indicator(): number {
    return this.buffer[3];
  }

  public get software(): number {
    return this.buffer[12] | (this.buffer[13] << 8);
  }

  public get device2(): number {
    return this.buffer[14];
  }

  public get device3(): number {
    return this.buffer[15];
  }

  public get deviceId(): string {
    return this.device1 == 0x7e
      ? `${hex(this.device1, 2)} ${hex(this.device2, 2)} ${hex(this.device3, 2)}`
      : hex(this.device1, 2);
  }
}
