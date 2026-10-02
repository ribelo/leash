#!/usr/bin/env python3
"""L53 harness checks, entirely offline: never launch Leash or call models."""
import copy
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location("l53", Path(__file__).with_name("live-acceptance-l53.py"))
l53 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(l53)


class AcceptanceChecks(unittest.TestCase):
    def gate(self):
        gate = l53.Gate.__new__(l53.Gate)
        gate.args = SimpleNamespace(gate="books")
        gate.failures = []
        gate.results = []
        gate.save = lambda *args: None
        return gate

    def test_redacts_structured_and_escaped_capabilities(self):
        gate = self.gate()
        gate.root = Path("/tmp/private-fixture")
        gate.secrets = ["synthetic-key"]
        value = {"tab": "fixture-tab", "log": "synthetic-key /tmp/private-fixture/profile s_t_" + "a" * 32}
        redacted = gate.redact(value)
        self.assertEqual(redacted["tab"], "[redacted capability]")
        self.assertEqual(redacted["log"], "[redacted] <PRIVATE_ROOT>/profile [redacted capability]")

    def test_done_is_not_page_verification(self):
        gate = self.gate()
        self.assertFalse(gate.goal({"status": "done"}, "Mystery Add to basket"))
        self.assertTrue(gate.goal({"final": {"url": "https://books.toscrape.com/catalogue/category/books/mystery_3/index.html"}}, "Mystery Add to basket"))

    def test_learning_cost_uses_total_reply_not_run_only_data(self):
        value = l53.Gate.accounting({"model_calls": 4, "model_cost": 0.5, "data": {"model_calls_by_kind": {"operator": 2}, "reported_cost": 0.2, "cost_unreported": 0}})
        self.assertEqual(value["learning_calls"], 2)
        self.assertAlmostEqual(value["learning_cost_usd"], 0.3)
        self.assertEqual(sum(value["total_calls_by_kind"].values()), 4)
        self.assertTrue(value["total_cost_fully_reported"])

    def test_unknown_learning_cost_cannot_be_hidden_by_complete_run_meter(self):
        value = l53.Gate.accounting({"model_calls": 3, "model_cost": None, "data": {"model_calls_by_kind": {"operator": 2}, "reported_cost": 0.2, "cost_unreported": 0}})
        self.assertFalse(value["total_cost_fully_reported"])
        self.assertIsNone(value["learning_cost_usd"])

    def test_flights_currency_picker_alone_is_not_destination_prices(self):
        gate = self.gate()
        gate.args.gate = "flights"
        reply = {"final": {"url": "https://www.google.com/travel/explore"}}
        self.assertFalse(gate.goal(reply, "Explore Flights only PLN Loading"))
        self.assertTrue(gate.goal(reply, "Explore Munich PLN 299 Venice PLN 400"))
        self.assertTrue(gate.goal(reply, "Explore Munich 299 zł"))

    def fixtures(self):
        proc = {"slug": "mystery", "provenance": {"traces": ["one", "two"], "gate": "replay", "repeatable": True}}
        draft = {"procedures": [proc]}
        empty = {"installed": [], "proposed": []}
        states = [empty, {"installed": [], "proposed": [draft]}, {"installed": [draft], "proposed": []}, {"installed": [draft], "proposed": []}]
        selected = {"slug": "draft:mystery", "planned": False, "choice": {"key": "draft:mystery"}, "outcome": "verified", "expectations": [{"passed": True}]}
        installed = {**selected, "slug": "mystery", "choice": {"key": "mystery"}}
        replies = [{"procedures": [], "installed": []}, {"procedures": [], "installed": []}, {"procedures": [selected], "installed": ["fixture-book"]}, {"procedures": [installed], "installed": []}]
        return copy.deepcopy(states), copy.deepcopy(replies)

    def replay(self, states, replies, coverage=0):
        gate = self.gate()
        def mission(number, *unused):
            gate.results.append({"reply": replies[number - 1], "model_cost_usd": [2, 2, 1, 0.5][number - 1], "cost_unreported": coverage})
            return True
        gate.mission = mission
        gate.state = lambda stage: states[int(stage.rsplit("-", 1)[1]) - 1]
        gate.replay()
        self.last_gate = gate
        return gate.failures

    def test_only_full_generated_learning_loop_passes(self):
        states, replies = self.fixtures()
        self.assertEqual(self.replay(states, replies), [])

    def test_done_only_with_lower_cost_cannot_pass(self):
        states = [{"installed": [], "proposed": []}] * 4
        replies = [{"status": "done", "procedures": [], "installed": []}] * 4
        failures = self.replay(states, replies)
        self.assertTrue(any("no actual generated draft" in f for f in failures))
        self.assertEqual(len(self.last_gate.results), 2, "Stop at first useful missing-draft evidence; no doomed third/fourth model calls")

    def test_failed_expectations_cannot_install_acceptance(self):
        states, replies = self.fixtures()
        replies[2]["procedures"][0]["expectations"][0]["passed"] = False
        self.assertTrue(any("Third mission" in f for f in self.replay(states, replies)))

    def test_fourth_use_must_match_installed_slug(self):
        states, replies = self.fixtures()
        replies[3]["procedures"][0]["slug"] = "unrelated"
        replies[3]["procedures"][0]["choice"]["key"] = "unrelated"
        self.assertTrue(any("Fourth mission: installed procedure" in f for f in self.replay(states, replies)))

    def test_unreported_cost_cannot_show_savings(self):
        states, replies = self.fixtures()
        self.assertTrue(any("fully-reported model cost" in f for f in self.replay(states, replies, coverage=1)))


if __name__ == "__main__":
    unittest.main()
