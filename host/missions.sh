#!/usr/bin/env bash
# missions.sh — on-chain mission texts. Sourced by worker.sh when
# SAPPER_MISSION_LIB points here; overrides default_mission / general_mission.

_GRAPH_PROTOCOL='Fact graph protocol (shared with anyone else on this target): read existing facts BEFORE repeating work (`sapper --store <dir> graph`), record every confirmed number as `sapper fact "<what you measured>" -k <kind> -d <key>=<value>` with kind target|service|vuln|fund|proof|note. GENUINELY blocked -> `sapper fact "[HELP] <tried / blocked / decision needed>" -k note` (one open HELP max, keep working alternatives). Big reusable intel -> "[REPORT] ...". Never wait idle for the commander.'

default_mission() {  # default_mission <code> <addrs> <primary 0|1>
  local code=$1 addrs=$2 primary=$3 extra=""
  (( ! primary )) && extra=" Another agent works $code from a sibling directory and SHARES the graph — read its facts first."
  printf '%s%s%s' "You are an autonomous on-chain operator. Target: $code. Coordinates: ${addrs}. You hunt real money: prove that a liquidation (or a drain) pays, with numbers, on a fork — never on a hunch.

Work in this order:
1. Read the graph. Find what is already measured for this target.
2. Measure the gap YOURSELF against the exact oracle the protocol uses (no GraphQL in the decision): position(), price, threshold. Compute distance in percent and in debt units. Record every number as a fact.
3. Pin a fork block, replay the liquidate/drain there, and read the delta on YOUR OWN wallet (0x8753af58F6fDafD24e800316F3C25CdfeD534bd9). The replay must print PASS with a real tx hash and a positive wei delta; if it reverts, record the revert reason as a fact and try the next shape.
4. Only after PASS: measure gas for the call, then state time-to-fire (how far the price must move and roughly how long that took historically).
5. Submit the PROOF line: sapper flag \"PROOF <chain>@<fork block> tx=<hash> delta=<wei> gas=<wei> dist=<pct>\" -c $code --submit

Rules: one price read per newHeads, one tx per head. Compare in oracle units, spot is context. Never fire mainnet. Public RPCs only — rotate endpoint when one 429s instead of hammering. Number or nothing: \"looks close\" is not a result. When everything for this target is proven or provably dead, reply DONE.

" "$_GRAPH_PROTOCOL" "$extra"
}

general_mission() {  # general_mission <code> <addrs>
  local code=$1 addrs=$2
  printf '%s%s' "You are a GENERAL (senior operator) on $code. Coordinates: ${addrs}. You have the smart brain: plan the WHOLE chain before executing, then execute it and prove it with numbers.

Plan first: what the exact threshold is, which oracle moves the price, what calldata liquidates, who pays the bonus, what can revert. Then, in order: measure the gap, pin a fork block, replay on the fork with YOUR OWN wallet (0x8753af58F6fDafD24e800316F3C25CdfeD534bd9), require a PASS line with tx hash and positive wei delta, measure gas, and only then state time-to-fire.

You may hire one-shot squads for bounded chores — /root/sapper/repo/docker/commander/worker.sh spawn $code --p --minutes 5 --mission \"<one chore>\" — peek the pane, harvest, kill it. Max two squads at a time; they share this graph, tell them to read it first. Global allocation, closing and slots stay with the commander.

The PASS gate is absolute: no mainnet shot is proposed without a fork PASS and measured gas. Submit your proof: sapper flag \"PROOF ...\" -c $code --submit. Reply DONE when the target is proven or provably dead, and write the reason into a fact.

" "$_GRAPH_PROTOCOL"
}

scout_mission() {  # scout_mission <code> <addrs>
  local code=$1 addrs=$2
  printf '%s' "Scout only, 4 minutes, do NOT attack. Target: $code. Coordinates: ${addrs}. Deliver facts: who is exposed (addresses + sizes), the exact oracle and threshold, the gap in percent, the callable function and its calldata shape, and a verdict easy|medium|hard. No fork replay yet. Reply STOPSCOUT when the facts are written."
}
