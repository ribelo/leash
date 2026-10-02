#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location("async_harness", Path(__file__).with_name("harness.py"))
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)

class AccountingTests(unittest.TestCase):
    def gate(self, before, after, calls=1, cost=.02, idle=True):
        g=h.Gate.__new__(h.Gate);g.failures=[];g.learning_before=before;g.learning_number=2
        status={"learning":{"pending":0 if idle else 1,"sites":[{"site":"google.com","learning_calls":calls,"learning_cost":cost}]}}
        g.wait_learning=lambda number:(idle,status,after)
        return g
    def row(self,g):
        return g.accounting({"model_calls":2,"model_cost":.01,"data":{"model_calls_by_kind":{"operator":2},"reported_cost":.01,"cost_unreported":0}})
    def state(self,mtime,calls=1,cost=.02):
        return {"mtime_ns":mtime,"state":{"account:google.com":{"model_calls":calls,"model_cost":cost}}}
    def test_new_account_billed_once(self):
        g=self.gate({"mtime_ns":None,"state":{}},self.state(2));a=self.row(g)
        self.assertEqual(a["total_calls"],3);self.assertAlmostEqual(a["total_cost_usd"],.03);self.assertEqual(g.failures,[])
    def test_unchanged_last_work_not_rebilled(self):
        a=self.row(self.gate(self.state(2),self.state(2)))
        self.assertEqual(a["learning_calls"],0);self.assertEqual(a["total_cost_usd"],.01)
    def test_identical_rewritten_account_still_billed(self):
        a=self.row(self.gate(self.state(2),self.state(3)))
        self.assertEqual(a["learning_calls"],1)
    def test_install_state_write_not_billed(self):
        after={"mtime_ns":3,"state":{"fail:google.com:slug":0,**self.state(2)["state"]}}
        a=self.row(self.gate(self.state(2),after));self.assertEqual(a["learning_calls"],0)
    def test_unknown_learning_cost_stays_unknown(self):
        a=self.row(self.gate({"mtime_ns":None,"state":{}},self.state(2,cost=None),cost=None))
        self.assertEqual(a["total_calls"],3);self.assertIsNone(a["learning_cost_usd"]);self.assertIsNone(a["total_cost_usd"])
    def test_pending_work_does_not_count_as_free(self):
        a=self.row(self.gate(self.state(2),self.state(2),idle=False))
        self.assertIsNone(a["learning_calls"]);self.assertIsNone(a["total_cost_usd"])
    def test_status_state_disagreement_rejected(self):
        g=self.gate({"mtime_ns":None,"state":{}},self.state(2),calls=4);self.row(g)
        self.assertIn("Status and learning.json last-work meter disagree",g.failures)
    def test_poll_waits_for_zero(self):
        g=self.gate(self.state(2),self.state(2));del g.wait_learning
        statuses=iter([{"learning":{"pending":1}},{"learning":{"pending":0}}]);saved=[]
        g.cli=lambda *args,**kwargs:(next(statuses),0,{})
        g.learning_state=lambda:self.state(2);g.save=lambda name,value:saved.append(value)
        sleep=h.time.sleep;h.time.sleep=lambda seconds:None
        try:idle,_,_=g.wait_learning(2)
        finally:h.time.sleep=sleep
        self.assertTrue(idle);self.assertEqual([s["pending"] for s in saved[0]["history"]],[1,0]);self.assertEqual(saved[0]["bound_seconds"],900)

if __name__=="__main__":unittest.main()
