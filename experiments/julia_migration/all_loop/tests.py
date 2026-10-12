"""Comparator regression: continuous JSON spelling never relaxes action identity."""
import unittest
from .measure import compare


class ComparisonTests(unittest.TestCase):
    def test_continuous_quantity_spelling(self):
        compare({'strain':1,'reserve':0},{'strain':1.0,'reserve':0.0})
        with self.assertRaises(AssertionError):compare({'strain':1},{'strain':.9})

    def test_discrete_values_remain_strict(self):
        for a,b in [({'chosen':1},{'chosen':1.0}),({'stock':[1]},{'stock':[True]}),
                    ({'action':'walk'},{'action':'rest'}),({'clear':True},{'clear':1})]:
            with self.assertRaises(AssertionError):compare(a,b)

    def test_missing_evidence_rejected(self):
        with self.assertRaises(AssertionError):compare({'trace':[1]},{'trace':[]})
        with self.assertRaises(AssertionError):compare({'state':{}},{})


if __name__=='__main__':unittest.main()
