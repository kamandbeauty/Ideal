"""Phase 3.6 model-only fairness checks. These run the Python models, not the game.

They guard the ranking models against accidental regressions in their own inputs:
  - every combined attack stays under the damage bounds below, at both hit-probability bounds;
  - the beginner profile survives the campaign with the current Repair and Airdrop values for every
    threshold and reaction time tried, including a 6 s craft gap.
Run:  PYTHONPATH=/home/user/pylibs python3 -m unittest -v test_model_fairness.py
"""
import unittest

import campaign_support_model as camp
import combined_attacks as ca
import combat_sim as cs


class CombinedAttackFairness(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cs.LEAD_AIRCRAFT = True  # the shipped behaviour
        cls.ttk = ca.best_ttk()

    def test_every_scenario_under_worst_case_bound(self):
        # Worst case (every hit lands): no scenario removes half the emplacement.
        for name, units in ca.SCENARIOS.items():
            total, _, _, _ = ca.run_scenario(units, self.ttk, 1.0)
            self.assertLess(total, 0.5 * ca.EMPLACEMENT_HP, name)

    def test_every_scenario_under_realistic_bound(self):
        # Assumed hit probability 0.3: no scenario removes a quarter of the emplacement.
        for name, units in ca.SCENARIOS.items():
            total, _, _, _ = ca.run_scenario(units, self.ttk, 0.3)
            self.assertLess(total, 0.25 * ca.EMPLACEMENT_HP, name)

    def test_every_type_has_a_kill_weapon(self):
        for target, (time, weapon) in self.ttk.items():
            self.assertIsNotNone(weapon, target)
            self.assertLess(time, 30.0, target)


class CampaignSupportMargin(unittest.TestCase):
    def test_beginner_survives_with_current_supports(self):
        profile = camp.proto.PROFILES["beginner"]
        for threshold in (2500.0, 3000.0, 4000.0, 4500.0):
            for react in (3.0, 6.0, 10.0):
                res = camp.run_campaign(profile, 6.0, camp.BASE_REPAIR, camp.BASE_AIRDROP, threshold, react)
                self.assertTrue(res["survived"], "T=%.0f react=%.0f" % (threshold, react))
                self.assertGreater(res["min_hp"], 1000.0, "T=%.0f react=%.0f" % (threshold, react))

    def test_beginner_needs_support(self):
        profile = camp.proto.PROFILES["beginner"]
        res = camp.run_campaign(profile, 6.0, dict(camp.BASE_REPAIR, charges=0), dict(camp.BASE_AIRDROP, charges=0), 0.0, 0.0)
        self.assertFalse(res["survived"])


if __name__ == "__main__":
    unittest.main()
