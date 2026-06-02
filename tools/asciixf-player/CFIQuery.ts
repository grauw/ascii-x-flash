import { MAX_BLOCKS, BLOCK_SIZE } from './ASCII16XMapper.ts';
import { AMD_QUERY_VENDOR_ID, AMDQuery } from './AMDQuery.ts';

export interface CFIRegion {
  count: number;
  size: number;
}

export class CFIQuery {
  public readonly buffer = new Uint8Array(0x80);

  public get hasSignature(): boolean {
    return this.buffer[0x10] == 0x51 && this.buffer[0x11] == 0x52 && this.buffer[0x12] == 0x59;
  }

  public get primaryVendorID(): number {
    return this.word(0x13);
  }

  public get primaryVendorQuery(): number {
    return this.word(0x15);
  }

  public get deviceSize(): number {
    return this.buffer[0x27];
  }

  public get deviceInterface(): number {
    return this.word(0x28);
  }

  public get regions(): CFIRegion[] {
    const regionCount = this.buffer[0x2c];
    const regions = [];
    for (let index = 0; index < Math.min(regionCount, 4); index++) {
      const offset = 0x2d + index * 4;
      const countMinusOne = this.word(offset);
      const sizeUnits = this.word(offset + 2);
      regions.push({
        count: countMinusOne + 1,
        size: sizeUnits == 0 ? 128 : sizeUnits * 256
      });
    }
    return regions;
  }

  public get amdQuery(): AMDQuery | undefined {
    if (this.primaryVendorID != AMD_QUERY_VENDOR_ID) {
      return undefined;
    }
    const query = new AMDQuery(this.buffer.subarray(this.primaryVendorQuery));
    return query.hasSignature ? query : undefined;
  }

  public get capacity(): number {
    if (!this.hasSignature || this.deviceSize < 12) {
      return 0;
    }
    return Math.min(MAX_BLOCKS, 1 << Math.min(this.deviceSize - 12, 14));
  }

  public get bufferPageMask(): number {
    return this.hasSignature ? ((1 << this.buffer[0x2a]) - 1) & 0xff : 0;
  }

  public get supportsDynamicProtection(): boolean {
    return this.amdQuery?.sectorProtectScheme == 8;
  }

  public isSectorAligned(block: number): boolean {
    if (block == 0) {
      return true;
    }
    let cursor = 0;
    for (const region of this.regions) {
      for (let sector = 0; sector < region.count; sector++) {
        cursor += region.size / BLOCK_SIZE;
        if (cursor == block) {
          return true;
        }
        if (cursor > block) {
          return false;
        }
      }
    }
    return false;
  }

  private word(offset: number): number {
    return this.buffer[offset] | this.buffer[offset + 1] << 8;
  }
}
