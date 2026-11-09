import random
import unittest
from model.dma_reference import (
    Descriptor, Error, SRAM_START, SRAM_END, MAX_DESCRIPTORS,
    validate_descriptor, validate_descriptor_pointer, validate_run,
)

class DescriptorTests(unittest.TestCase):
    def test_valid_minimum(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x3000,4)), Error.NONE)
    def test_valid_max_boundary(self):
        self.assertEqual(validate_descriptor(Descriptor(0x1000,0x7ffc,4)), Error.NONE)
    def test_src_alignment(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2001,0x3000,4)), Error.SRC_ALIGN)
    def test_dst_alignment(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x3001,4)), Error.DST_ALIGN)
    def test_zero_length(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x3000,0)), Error.ZERO_LENGTH)
    def test_non_word_length(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x3000,6)), Error.LENGTH_ALIGN)
    def test_src_below_sram(self):
        self.assertEqual(validate_descriptor(Descriptor(0x0ffc,0x3000,4)), Error.SRC_RANGE)
    def test_dst_beyond_sram(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x7ffc,8)), Error.DST_RANGE)
    def test_src_end_boundary_crossing(self):
        self.assertEqual(validate_descriptor(Descriptor(0x7ffc,0x3000,8)), Error.SRC_RANGE)
    def test_32bit_destination_end_overflow(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0xfffffffc,8)), Error.DST_RANGE)
    def test_32bit_source_end_overflow(self):
        self.assertEqual(validate_descriptor(Descriptor(0xfffffffc,0x3000,8)), Error.SRC_RANGE)
    def test_overlap(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x2004,16)), Error.OVERLAP)
    def test_adjacent_not_overlap(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x2010,16)), Error.NONE)
    def test_control_reserved(self):
        self.assertEqual(validate_descriptor(Descriptor(0x2000,0x3000,4,control=1)), Error.CONTROL)
    def test_descriptor_pointer_alignment(self):
        self.assertEqual(validate_descriptor_pointer(0x1001), Error.DESC_ALIGN)
    def test_descriptor_crosses_boundary(self):
        self.assertEqual(validate_descriptor_pointer(0x7ff0), Error.DESC_RANGE)
    def test_last_descriptor_fits(self):
        self.assertEqual(validate_descriptor_pointer(0x7fec), Error.NONE)
    def test_run_limit_zero(self):
        self.assertEqual(validate_run(0x1000,0), Error.DESC_LIMIT)
    def test_run_limit_max(self):
        self.assertEqual(validate_run(0x1000,MAX_DESCRIPTORS), Error.NONE)
    def test_run_limit_over_max(self):
        self.assertEqual(validate_run(0x1000,MAX_DESCRIPTORS+1), Error.DESC_LIMIT)
    def test_bad_descriptor_base(self):
        self.assertEqual(validate_run(0x7ff0,4), Error.DESC_RANGE)

    def test_random_valid_disjoint_ranges(self):
        rng = random.Random(20261109)
        for _ in range(1000):
            words = rng.randint(1, 128)
            length = words * 4
            src = rng.randrange(0x1000, 0x7000 - length, 4)
            dst = rng.randrange(0x1000, 0x7000 - length, 4)
            if src < dst + length and dst < src + length:
                continue
            self.assertEqual(validate_descriptor(Descriptor(src,dst,length)), Error.NONE)

    def test_misaligned_next_descriptor_pointer(self):
        d = Descriptor(SRAM_START, SRAM_START + 0x100, 4, next_desc=SRAM_START + 1)
        self.assertEqual(validate_descriptor(d), Error.DESC_ALIGN)

    def test_next_descriptor_must_fit_sram(self):
        d = Descriptor(SRAM_START, SRAM_START + 0x100, 4, next_desc=SRAM_END - 16)
        self.assertEqual(validate_descriptor(d), Error.DESC_RANGE)

    def test_last_valid_next_descriptor_pointer(self):
        d = Descriptor(SRAM_START, SRAM_START + 0x100, 4, next_desc=SRAM_END - 20)
        self.assertEqual(validate_descriptor(d), Error.NONE)

    def test_random_out_of_range_destinations_rejected(self):
        rng = random.Random(77)
        for _ in range(500):
            length = rng.choice([4,8,16,64,256])
            dst = rng.randrange(0x8000, 0xfffffff0, 4)
            self.assertEqual(validate_descriptor(Descriptor(0x2000,dst,length)), Error.DST_RANGE)

if __name__ == '__main__':
    unittest.main(verbosity=2)
