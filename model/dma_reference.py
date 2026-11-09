"""Executable specification for the DMA descriptor admission rules."""
from dataclasses import dataclass
from enum import IntEnum

SRAM_START = 0x1000
SRAM_END = 0x8000  # exclusive
U32_LIMIT = 1 << 32
DESCRIPTOR_BYTES = 20
MAX_DESCRIPTORS = 256

class Error(IntEnum):
    NONE = 0
    DESC_ALIGN = 1
    DESC_RANGE = 2
    SRC_ALIGN = 3
    DST_ALIGN = 4
    ZERO_LENGTH = 5
    LENGTH_ALIGN = 6
    SRC_RANGE = 7
    DST_RANGE = 8
    OVERLAP = 9
    DESC_LIMIT = 10
    CONTROL = 11

@dataclass(frozen=True)
class Descriptor:
    src_addr: int
    dst_addr: int
    length: int
    next_desc: int = 0
    control: int = 0


def range_inside_sram(start: int, length: int) -> bool:
    if not (0 <= start < U32_LIMIT) or length < 0:
        return False
    end = start + length  # Python integer is widened; no 32-bit wrap.
    return start >= SRAM_START and start < SRAM_END and end > start and end <= SRAM_END and end <= U32_LIMIT


def validate_descriptor_pointer(address: int) -> Error:
    if address & 3:
        return Error.DESC_ALIGN
    if not range_inside_sram(address, DESCRIPTOR_BYTES):
        return Error.DESC_RANGE
    return Error.NONE


def validate_descriptor(desc: Descriptor) -> Error:
    if desc.control != 0:
        return Error.CONTROL
    if desc.next_desc != 0 and (desc.next_desc & 3):
        return Error.DESC_ALIGN
    if desc.next_desc != 0 and not range_inside_sram(desc.next_desc, DESCRIPTOR_BYTES):
        return Error.DESC_RANGE
    if desc.src_addr & 3:
        return Error.SRC_ALIGN
    if desc.dst_addr & 3:
        return Error.DST_ALIGN
    if desc.length == 0:
        return Error.ZERO_LENGTH
    if desc.length & 3:
        return Error.LENGTH_ALIGN
    if not range_inside_sram(desc.src_addr, desc.length):
        return Error.SRC_RANGE
    if not range_inside_sram(desc.dst_addr, desc.length):
        return Error.DST_RANGE
    src_end = desc.src_addr + desc.length
    dst_end = desc.dst_addr + desc.length
    if desc.src_addr < dst_end and desc.dst_addr < src_end:
        return Error.OVERLAP
    return Error.NONE


def validate_run(desc_base: int, desc_limit: int) -> Error:
    pointer_error = validate_descriptor_pointer(desc_base)
    if pointer_error != Error.NONE:
        return pointer_error
    if not 1 <= desc_limit <= MAX_DESCRIPTORS:
        return Error.DESC_LIMIT
    return Error.NONE
