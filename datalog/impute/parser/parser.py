#! /usr/bin/env python3
import copy
import sys
from collections import defaultdict

from pyparsing import *

SimpleFields = (
    "Fingerprint",
    "SerialNumber",
    "NotBefore",
    "NotAfter",
    "CommonName",
    "SanExt",
    "SanCritical",
    "San",
    "Issuer",
    "SignatureAlgorithm",
    "BasicConstraintsExt",
    "BasicConstraintsCritical",
    "IsCA",
    "PathLimit",
    "KeyUsageExt",
    "KeyUsageCritical",
    "ExtendedKeyUsageExt",
    "ExtendedKeyUsageCritical",
    "StapledOcspValid",
    "StapledOcspVerified",
    "StapledOcspExpired",
    "OcspResponder",
    "OcspValid",
    "OcspVerified",
    "OcspExpired",
    "OcspStatus",
)
ListFields = (
    "SubjectiveAlternativeNames",
    "KeyUsage",
    "ExtendedKeyUsage",
)


def topo_sort(nodes, adj):
    output = []
    fresh = set(nodes.keys())

    def dfs(node):
        fresh.remove(node)
        for child in adj[node]:
            if child in fresh:
                dfs(child)
        output.append(node)

    for node in nodes:
        if node in fresh:
            dfs(node)
    return output


########### Transformation methods #############################################
def fix_head_clause(rule, to_remove, to_put):
    head_clause = rule["head_clause"]
    for rem in to_remove or {"Cert"}:
        try:
            head_clause["terms"].remove({"variables": [rem]})
        except ValueError:
            pass
    
    constituents = list(next(iter(x.values())) for x in head_clause["terms"])
    for t in to_put:
        if t not in constituents:
            head_clause["terms"].append({"variables": [t]})


def prepend_terms(clause, prefix):
    for i, term in enumerate(clause["terms"]):
        for k, v in term.items():
            if not clause["terms"][i][k][0].startswith(prefix):
                clause["terms"][i][k][0] = prefix + v[0] 


def fix_rule(rule):
    added = set()
    removed = set()
    for i, clause in enumerate(rule["clauses"]):
        if type(clause) == str:
            continue
        if (
            len(clause["predicate"]["atoms"]) == 2
            and clause["predicate"]["atoms"][0] == "certs"
        ):
            field = clause["predicate"]["atoms"][1]
            field = field[0].upper() + field[1:]
            value = next(iter(clause["terms"][1].values()))[0]
            container = next(iter(clause["terms"][0].values()))[0]
            var = container + field
            removed.add(container)
            if field in SimpleFields:
                rule["clauses"][i] = f"{var} = {value}"
                added.add(var)
            elif field in ListFields:
                if value == "none":
                    rule["clauses"][i] = f"{var} = []"
                else:
                    rule["clauses"][i] = f"member({value}, {var})"
                added.add(var)
    return removed, added

def fix_calls(key, head_clause, nodes, adj, added):
    for pred in adj[key]:
        for rule_to_fix in nodes[pred]:
            for i, clause in enumerate(rule_to_fix["clauses"]):
                if type(clause) != str and key == ":".join(clause["predicate"]["atoms"]):
                    prefix = next(iter(clause["terms"][0].values()))[0]
                    new_clause = copy.deepcopy(head_clause)
                    prepend_terms(new_clause, prefix)
                    rule_to_fix["clauses"][i] = new_clause
                
            fix_head_clause(rule_to_fix, None, added)
            key2 = ":".join(rule_to_fix["head_clause"]["predicate"]["atoms"])
            # fix_calls(key, rule_to_fix["head_clause"], nodes, adj, added)
     

########### Print methods ######################################################
def dump_clause(clause):
    if type(clause) == str:
        return clause
    else:
        terms = []
        for term in clause["terms"]:
            for k, v in term.items():
                terms.append(f'"{v[0]}"' if k == "strings" else v[0])
    pred = ":".join(clause["predicate"]["atoms"])
    return f'{pred}({", ".join(sorted(terms))})'


def dump_rule(rule):
    return "".join(
        [
            dump_clause(rule["head_clause"]),
            ":-\n\t",
            ",\n\t".join(map(dump_clause, rule["clauses"])),
            ".",
        ]
    )


def dump_fact(fact):
    return dump_clause(fact["clauses"][0]) + "."


########### Parser patterns ####################################################
comment = ("%" + restOfLine).suppress()
number = Word(nums + "-")("ints*")
atom = Word(alphas.lower(), alphanums + "_")("atoms*")
variable = Word(alphas.upper(), alphanums)("variables*")
string = QuotedString('"')("strings*")
term = Group(number | atom | variable | string)("terms*")
arity = atom + "/" + Word(nums)
module_directive = LineStart() + ":-" + "module" + "(" + term + "," + "[" + delimitedList(arity) + "]" + ")" + "."
directive = module_directive | (LineStart() + ":-" + restOfLine)

predicate = Group(Optional("\+") + Optional(atom + Suppress(":")) + atom)("predicate")
# arguments= Group(Suppress('(') + delimitedList(term) + Suppress(')'))('arguments*')

head_clause = Group(
    predicate
    + Suppress("(")
    + delimitedList(term)
    + Suppress(")")
    + Suppress(":")
    + Suppress("-")
)("head_clause")
clause = Group(predicate + Suppress("(") + delimitedList(term) + Suppress(")"))(
    "clauses*"
)

fact = Group(clause + Suppress("."))("facts*")
rule = Group(head_clause + delimitedList(clause) + Suppress("."))("rules*")

sentence = fact | rule | directive
prolog = OneOrMore(sentence)

########### Transformation #####################################################
if __name__ == "__main__":
    # read input file
    # sys.argv = ["", "./datalog/impute/input.pl"]
    with open(sys.argv[1]) as f:
        toparse = comment.transformString(f.read())

    code = prolog.parseString(toparse, parseAll=True).asDict()
    # exit()

    # build graph for topological sort
    nodes = defaultdict(list)
    for rule in code["rules"]:
        nodes[":".join(rule["head_clause"]["predicate"]["atoms"])].append(rule)

    dep = defaultdict(set)
    dep_rev = defaultdict(set)
    for a, rules in nodes.items():
        for rule in rules:
            for b in rule["clauses"]:
                b = ":".join(b["predicate"]["atoms"])
                if b in nodes and a != b:
                    dep[a].add(b)
                    dep_rev[b].add(a)

    sorted_preds = topo_sort(nodes, dep)

    for fact in code["facts"]:
        print(dump_fact(fact))


    # fix rules
    for i, pred in enumerate(sorted_preds):
        added = set()
        removed = set()
        for rule in nodes[pred]:
            rem, add = fix_rule(rule)
            added.update(add)
            removed.update(rem)

        for rule in nodes[pred]:
            fix_head_clause(rule, removed, added)

        if added:
            rule = next(iter(nodes[pred]))
            key = ":".join(rule["head_clause"]["predicate"]["atoms"])
            fix_calls(key, rule["head_clause"], nodes, dep_rev, added)


        for rule in nodes[pred]:
            print(dump_rule(rule))
            print()
        
