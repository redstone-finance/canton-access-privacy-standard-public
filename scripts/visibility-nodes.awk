# Copyright (c) 2026 RedStone. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Reads the plain-text transaction listing of one test and prints one JSON
# object per node. The listing looks like this:
#
#   TX 10 1970-01-01T00:02:00Z (Test.CoreTest:118:3)
#   #10:0
#   │   disclosed to (since): 'Operator-d4d95138' (10), 'Reader-1df42503' (10),
#                             'Publisher-fb9a0f58' (10)
#   └─> 'Publisher-fb9a0f58' exercises RoundHead_CreateRound on #8:6 (...)
#       children:
#       #10:1
#       ...
#
# A role is a party's allocation hint without its trailing digits, so
# Auditor1 and Auditor2 are both Auditor.

/^ *TX [0-9]+ / {
  finish_node()
  transaction = $2
  next
}

/^ *#[0-9]+:[0-9]+ *$/ {
  finish_node()
  node = $1
  top_level = index($0, "#") == 3
  next
}

index($0, "│") { reading = index($0, "disclosed to") ? "parties" : "" }
index($0, "└─>") { reading = "action" }

reading == "parties" { add_roles($0) }
reading == "action" && action == "" {
  if (top_level) add_actors($0)
  action = find_action()
}

END { finish_node() }

# The parties of an action line stand before its verb, on that line or, a
# long list, on the lines above it.
function add_actors(line,    party) {
  sub(/ (exercises?|creates?|fetch(es)?) .*/, "", line)
  while (match(line, /'[A-Za-z0-9]+-[0-9a-f]+'/)) {
    party = substr(line, RSTART + 1, RLENGTH - 2)
    sub(/-.*/, "", party)
    sub(/[0-9]+$/, "", party)
    actors[party] = 1
    line = substr(line, RSTART + RLENGTH)
  }
}

function add_roles(line,    party) {
  while (match(line, /'[A-Za-z0-9]+-[0-9a-f]+' \(/)) {
    party = substr(line, RSTART + 1, RLENGTH - 1)
    sub(/-.*/, "", party)
    sub(/[0-9]+$/, "", party)
    roles[party] = 1
    line = substr(line, RSTART + RLENGTH)
  }
}

function find_action(    i) {
  for (i = 1; i < NF; i++) {
    if ($i == "exercise" || $i == "exercises") return "exercise " $(i + 1)
    if ($i == "create" || $i == "creates") return "create " template($(i + 1))
    if ($i == "fetch" || $i == "fetches") return "fetch " template($(i + 2))
  }
  return ""
}

function template(id) {
  sub(/@.*/, "", id)
  sub(/.*:/, "", id)
  return id
}

function finish_node() {
  if (node != "" && action != "") {
    if (top_level) {
      root = action
      root_actors = json_list(actors)
    }
    printf "{\"test\":\"%s\",\"tx\":%d,\"node\":\"%s\",\"root\":\"%s\",\"actors\":[%s],\"label\":\"%s\",\"disclosedTo\":[%s]}\n", \
      test, transaction, node, root, root_actors, action, json_list(roles)
  }
  node = ""
  action = ""
  reading = ""
  clear(roles)
  clear(actors)
}

function json_list(set,    item, list) {
  list = ""
  for (item in set) list = list (list == "" ? "" : ",") "\"" item "\""
  return list
}

function clear(set,    item) {
  for (item in set) delete set[item]
}
