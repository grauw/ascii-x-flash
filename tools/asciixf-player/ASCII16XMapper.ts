export const BLOCK_SIZE = 0x1000;
export const MAX_BLOCKS = 0x4000;

const BLOCK_SHIFT = Math.log2(BLOCK_SIZE);
const LOGICAL_BLOCK_BASES = [0x8000, 0x5000, 0xa000, 0x7000];

export interface MappedAddress {
  logicalAddress: number;
  bankAddress: number;
  bankData: number;
  block: number;
  bank: number;
}

export function mapPhysicalAddress(physicalAddress: number): MappedAddress {
  if (!Number.isInteger(physicalAddress) || physicalAddress < 0) {
    throw new RangeError(`Invalid physical address: ${physicalAddress}`);
  }
  const block = physicalAddress >> BLOCK_SHIFT;
  if (block >= MAX_BLOCKS) {
    throw new RangeError(`Physical address exceeds ASCII16-X range: ${physicalAddress.toString(16)}`);
  }

  const offset = physicalAddress & (BLOCK_SIZE - 1);
  const bank = block >> 2;
  const blockInBank = block & 3;
  const bankBaseAddress = (blockInBank == 0 || blockInBank == 2) ? 0x7000 : 0x6000;

  return {
    logicalAddress: LOGICAL_BLOCK_BASES[blockInBank] + offset,
    bankAddress: bankBaseAddress | ((bank >> 8) << 8),
    bankData: bank & 0xff,
    block,
    bank
  };
}
