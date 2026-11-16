"""Exercise edge trimming without cutting quiet attacks, decay or interior gaps."""
import sys
from pathlib import Path
import unittest

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from trim_silence import trim_bounds


class TrimBoundsTests(unittest.TestCase):
    def test_padding_at_both_ends(self):
        pcm = np.zeros((1000, 1))
        pcm[200:700] = 0.5
        start, end = trim_bounds(pcm, 1000)
        self.assertLessEqual(start, 195)
        self.assertGreaterEqual(end, 705)
        self.assertLess(end, 1000)
        self.assertGreater(start, 0)

    def test_any_channel_preserves_attack_and_decay(self):
        pcm = np.zeros((1000, 2))
        pcm[100, 1] = 0.01
        pcm[500:700, 0] = 0.5
        start, end = trim_bounds(pcm, 1000)
        self.assertLessEqual(start, 95)
        self.assertGreaterEqual(end, 705)

    def test_interior_pause_is_retained(self):
        pcm = np.zeros((1000, 1))
        pcm[10:30] = 0.5
        pcm[900:920] = 0.5
        start, end = trim_bounds(pcm, 1000)
        self.assertGreaterEqual(end - start, 920 - 10 + 10)

    def test_short_padding_is_unchanged(self):
        pcm = np.ones((1000, 1)) * 0.5
        pcm[:5] = 0
        pcm[-5:] = 0
        self.assertEqual(trim_bounds(pcm, 1000), (0, 1000))

    def test_silent_file_is_rejected(self):
        with self.assertRaises(ValueError):
            trim_bounds(np.zeros((1000, 1)), 1000)


if __name__ == "__main__":
    unittest.main()
