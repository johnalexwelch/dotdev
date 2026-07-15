#!/usr/bin/env python3
"""Generate referentially-consistent mock data from a schema.

CSV / JSON / SQL output, FK integrity via topological sort, deterministic with --seed.
Faker is used if installed; otherwise built-in providers (no hard dependency).
"""
import argparse, csv, json, os, random, re, string, sys, uuid
from datetime import date, timedelta

try:
    from faker import Faker  # optional
    _FAKE = Faker()
except Exception:
    _FAKE = None

_FIRST = ["Ava","Liam","Mia","Noah","Zoe","Eli","Ivy","Kai","Luna","Max","Nora","Owen","Ada","Leo","Maya"]
_LAST = ["Lee","Patel","Kim","Garcia","Khan","Silva","Cohen","Diaz","Park","Brown","Ali","Rossi","Vega","Wu","Hall"]

def _seed(field_seed): random.seed(field_seed)

def gen_value(spec, fake_seed):
    t = spec["type"]
    if t == "int":   return random.randint(spec.get("min",0), spec.get("max",1000))
    if t == "float":
        v = random.uniform(spec.get("min",0.0), spec.get("max",1000.0))
        return round(v, spec.get("round",2))
    if t == "bool":  return random.random() < spec.get("p",0.5)
    if t == "choice":
        vals, w = spec["values"], spec.get("weights")
        return random.choices(vals, weights=w, k=1)[0]
    if t == "uuid":  return str(uuid.UUID(int=random.getrandbits(128)))
    if t == "first_name":
        return _FAKE.first_name() if _FAKE else random.choice(_FIRST)
    if t == "name":
        return _FAKE.name() if _FAKE else f"{random.choice(_FIRST)} {random.choice(_LAST)}"
    if t == "email":
        if _FAKE: return _FAKE.email()
        return f"{random.choice(_FIRST).lower()}.{random.choice(_LAST).lower()}{random.randint(1,999)}@example.com"
    if t == "date":
        s = date.fromisoformat(spec.get("start","2020-01-01"))
        e = date.fromisoformat(spec.get("end","2025-12-31"))
        return (s + timedelta(days=random.randint(0,(e-s).days))).isoformat()
    if t == "pattern":
        out=[]
        for ch in spec["pattern"]:
            if ch=="#": out.append(random.choice(string.digits))
            elif ch=="?": out.append(random.choice(string.ascii_uppercase))
            else: out.append(ch)
        return "".join(out)
    raise ValueError(f"unknown field type: {t}")

def topo_sort(tables):
    by_name = {t["name"]: t for t in tables}
    deps = {t["name"]: {f["table"] for f in t["fields"].values() if f.get("type")=="fk"} for t in tables}
    order, seen, temp = [], set(), set()
    def visit(n):
        if n in seen: return
        if n in temp: raise ValueError(f"FK cycle detected at table '{n}'")
        temp.add(n)
        for d in deps.get(n,()):
            if d not in by_name: raise ValueError(f"fk references unknown table '{d}'")
            visit(d)
        temp.discard(n); seen.add(n); order.append(n)
    for t in tables: visit(t["name"])
    return [by_name[n] for n in order]

def generate(schema, seed=None):
    if seed is not None: random.seed(seed)
    data = {}
    for table in topo_sort(schema["tables"]):
        name, n, fields = table["name"], table.get("rows",10), table["fields"]
        seqs = {f: spec.get("start",1) for f,spec in fields.items() if spec["type"]=="sequence"}
        rows=[]
        for _ in range(n):
            row={}
            for fname, spec in fields.items():
                if spec["type"]=="sequence":
                    row[fname]=seqs[fname]; seqs[fname]+=1
                elif spec["type"]=="fk":
                    parent=data[spec["table"]]
                    if not parent: raise ValueError(f"fk parent '{spec['table']}' is empty")
                    row[fname]=random.choice(parent)[spec["field"]]
                else:
                    row[fname]=gen_value(spec, None)
            rows.append(row)
        data[name]=rows
    return data

# ---- exporters ----
def to_csv(rows, path):
    if not rows: open(path,"w").close(); return
    with open(path,"w",newline="") as f:
        w=csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

def to_json(rows, path):
    with open(path,"w") as f: json.dump(rows, f, indent=2, default=str)

_QUOTE={"postgres":'"',"sqlite":'"',"mysql":"`"}
def _sql_val(v):
    if v is None: return "NULL"
    if isinstance(v,bool): return "TRUE" if v else "FALSE"
    if isinstance(v,(int,float)): return str(v)
    return "'"+str(v).replace("'","''")+"'"
def to_sql(table, rows, path, dialect="postgres"):
    q=_QUOTE.get(dialect,'"')
    with open(path,"w") as f:
        if not rows: return
        cols=list(rows[0].keys()); collist=",".join(f"{q}{c}{q}" for c in cols)
        for r in rows:
            vals=",".join(_sql_val(r[c]) for c in cols)
            f.write(f"INSERT INTO {q}{table}{q} ({collist}) VALUES ({vals});\n")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--schema",required=True); ap.add_argument("--out",default="./fixtures")
    ap.add_argument("--format",choices=["csv","json","sql"],default="csv")
    ap.add_argument("--dialect",choices=["postgres","mysql","sqlite"],default="postgres")
    ap.add_argument("--seed",type=int,default=None)
    a=ap.parse_args()
    with open(a.schema) as f: schema=json.load(f)
    data=generate(schema, a.seed)
    os.makedirs(a.out,exist_ok=True)
    for name,rows in data.items():
        p=os.path.join(a.out,f"{name}.{a.format}")
        if a.format=="csv": to_csv(rows,p)
        elif a.format=="json": to_json(rows,p)
        else: to_sql(name,rows,p,a.dialect)
        print(f"  {name}: {len(rows)} rows -> {p}")
    print(f"done ({'faker' if _FAKE else 'builtin'} providers)")

if __name__=="__main__": main()
