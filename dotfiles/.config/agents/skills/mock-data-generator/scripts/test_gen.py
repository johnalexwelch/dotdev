#!/usr/bin/env python3
"""Smoke test: FK integrity, row counts, determinism, SQL export."""
import os, tempfile, sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_mock_data import generate, to_sql

SCHEMA={"tables":[
 {"name":"users","rows":50,"fields":{
   "id":{"type":"sequence","start":1},"email":{"type":"email"},
   "name":{"type":"name"},"plan":{"type":"choice","values":["free","plus"],"weights":[0.8,0.2]},
   "created_at":{"type":"date","start":"2024-01-01","end":"2025-12-31"}}},
 {"name":"orders","rows":200,"fields":{
   "id":{"type":"sequence","start":1},
   "user_id":{"type":"fk","table":"users","field":"id"},
   "amount":{"type":"float","min":5,"max":200,"round":2},
   "status":{"type":"choice","values":["paid","refunded"],"weights":[0.9,0.1]}}}]}

def run():
    d=generate(SCHEMA, seed=42)
    assert len(d["users"])==50, "user row count"
    assert len(d["orders"])==200, "order row count"
    valid={u["id"] for u in d["users"]}
    assert all(o["user_id"] in valid for o in d["orders"]), "FK integrity broken"
    assert len({u["id"] for u in d["users"]})==50, "sequence must be unique"
    # determinism
    d2=generate(SCHEMA, seed=42)
    assert [o["user_id"] for o in d["orders"]]==[o["user_id"] for o in d2["orders"]], "not deterministic"
    # cycle detection
    cyc={"tables":[
      {"name":"a","rows":1,"fields":{"b_id":{"type":"fk","table":"b","field":"id"}}},
      {"name":"b","rows":1,"fields":{"a_id":{"type":"fk","table":"a","field":"id"}}}]}
    try:
        generate(cyc); raise AssertionError("cycle not detected")
    except ValueError as e:
        assert "cycle" in str(e).lower()
    # SQL export
    with tempfile.TemporaryDirectory() as t:
        p=os.path.join(t,"orders.sql"); to_sql("orders",d["orders"],p,"postgres")
        sql=open(p).read()
        assert sql.startswith('INSERT INTO "orders"') and sql.count("INSERT")==200, "sql export"
    print("ALL TESTS PASSED (FK integrity, counts, determinism, cycle-detect, SQL export)")

if __name__=="__main__": run()
