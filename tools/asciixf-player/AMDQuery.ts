export const AMD_QUERY_VENDOR_ID = 0x0002;

export class AMDQuery {
  private buffer: Uint8Array;

  public constructor(buffer: Uint8Array) {
    this.buffer = buffer;
  }

  public get hasSignature(): boolean {
    return this.buffer[0x00] == 0x50 && this.buffer[0x01] == 0x52 && this.buffer[0x02] == 0x49;
  }

  public get sectorProtectScheme(): number {
    return this.buffer[0x09];
  }
}
