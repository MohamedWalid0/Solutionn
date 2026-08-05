# Selection logic

How the module gets from a radar sweep to one objective.

## The shape of the problem

Reading the four attack modes side by side, every one of them turns out to be doing one or more of
only three things:


|                       | what it does                                                                       |
| --------------------- | ---------------------------------------------------------------------------------- |
| **Rule areas out**    | `avoid-crossfire` refuses any area holding a human                                 |
| **Order the areas**   | `closest-first`, `furthest-first`, and `priorize-t-x` each prefer a different area |
| **Order the targets** | `priorize-t-x` wants the T-X reported first                                        |


So a mode is an object answering three questions, and chaining modes is just asking all of them:

```ruby
allows?(area)        # false rules the area out
area_rank(area)      # lower is attacked first
target_rank(target)  # lower is reported first
```

`AttackMode::Base` answers `true`, `0`, `0`. A mode overrides only what it cares about, and the
neutral `0` means a mode that does not order anything never disturbs one that does.

## The two sort keys

Selection is one filter and two sorts. Both keys are arrays compared element by element, ascending,
lowest wins:

```ruby
# ObjectiveSelection::SelectWinner
area_key   = [ *modes.map { |m| m.area_rank(area) },     -area.total_damage, radar_index ]

# ObjectiveSelection::BuildResponse
target_key = [ *modes.map { |m| m.target_rank(target) }, -target.damage,     target_index ]
```

The tail of each key is the part no mode controls: one rule, stated once, applied at both levels —
with nothing else to go on, go for the most dangerous thing. `damage` is the only measure of
importance the briefing hands us, *"Damage the target may cause"*, and case 4 forces it on the
targets already: `(0,70)` holds `T-X 20`, `T7-T 90`, `HK-Bomber 80` and the expected answer is
`["T7-T","HK-Bomber","T-X"]` — damage descending, not the order the radar listed them. Ranking areas
the same way means the module has one idea rather than two.

It is also what picks the area in case 4, where `avoid-crossfire` is the only mode and so ranks
nothing: `(0,20)` is refused for the human in it, and `(0,70)` carries 190 damage against `(0,80)`'s
20.

`radar_index` closes the last door — two areas identical down to the damage resolve on the order they
arrived in — so the module never answers a coin flip. `sort_by` is not stable in Ruby, hence
`target_index`. `min_by` does return the first minimum, so `radar_index` is belt and braces, but it
says the rule out loud instead of leaning on a library detail, and keeps the two keys symmetric.

## `axis` and `priority`

Two separate declarations on each mode class, easy to confuse:

`**axis` — the decision the mode owns.** Two modes sharing an axis are opposites and cannot be
chained; `AttackMode.build` raises `ConflictingModes` and the request is refused with `422`. This is
the briefing's *"you should not chain opposite attack modes"*. `closest-first` and `furthest-first`
both own `:distance`, so they collide. `nil` means the mode has no opposite yet: `avoid-crossfire`
only filters, and `priorize-t-x` would clash only with a future `deprioritize-t-x` — never with a
sibling like a hypothetical `priorize-hk-tank`, which would simply stack.

`**priority` — who ranks areas first.** Lower is more significant, and `AttackMode.build` sorts the
modes by it before any key is built. `priorize-t-x` is `10` and the distance modes are `20`, which is
what makes *"the attack must **always** priorize objectives of type T-X"* literally true rather than
a tie-breaker:

```
["closest-first", "priorize-t-x"]  ->  ordered as [priorize-t-x, closest-first]

area_key = [ tx_rank, distance², -total_damage, index ]
             ↑        ↑
        priorize   closest

(0,50) with a T-X     ->  [0, 2500, ...]   <= chosen, though it is further away
(0,10) without one    ->  [1,  100, ...]
```

Element 0 decides: `0 < 1`. Reverse the priorities and distance would decide first, demoting T-X to a
tie-break between equidistant areas. The numbering leaves gaps so a new mode can slot in between
without renumbering the others. Why the list is read this way rather than as an order of application
is the first judgement call below.

## Five judgement calls

The briefing leaves these open. Each is settled by something the briefing does say, or by the
shipped battery.

**1. A chained mode's position in the list means nothing.**
The briefing prints exactly one example of chaining:

```json
{ "attack-­mode": [ "closest­-first", "priorize­-t-­x" ], "radar": ... }
```

and two lines above it: *"**priorize-t-x**: The attack must **always** priorize objectives of type
T-X."* Read the list as an order of application — the first mode ranks, later ones break its ties —
and that example demotes T-X to a tie-breaker between equidistant areas, making *always* false in the
briefing's own illustration.

So the list is read as a *set*. Each mode declares its own `priority`, `priorize-t-x` outranks the
distance modes wherever the control unit put it, and `["closest-first","priorize-t-x"]` and its
reverse are the same request. The cost is that ordering the list is not a control the caller has,
which is the point: a rule the briefing calls *always* should not be switchable by reordering a JSON
array.

**2. Ties go to the most dangerous area.**
The briefing names no tie-break at all, and two areas can reach the end of the mode ranks level. The
choice has to come from somewhere, and `damage` is the only measure of importance in the payload —
the briefing defines it as *"Damage the target may cause"*. The battery already forces that reading
one level down, on the targets inside the chosen area (case 4), so the same rule is used for the
areas rather than inventing a second one.

The alternative worth naming: break ties on distance instead. It was rejected because a request
carrying only `avoid-crossfire` never asked for the nearest area, and answering with it would apply
`closest-first` on the caller's behalf.

**3. A target is attackable only if it is not a human and reports numeric `damage`.**
Two rules, and both are needed. *Not a human* is the briefing's own note — humans are never returned
as attack targets — and it holds even for the human the vision module one day reports with a damage
figure. *Numeric damage* is what discards the malformed `{"type":"mech","number":20}` in cases 6 and
7, and it is how a human arrives today: test case 1 sends `{"type": "Human"}` with no damage, and the
expected answer omits it while still attacking the area it sits in. An area left with nothing
attackable is dropped in step 2, before any mode sees it.

`avoid-crossfire` is the exception that proves the rule: refusing to fire *near* a human is a
different question from listing one as a target, so it looks at the type, over the unfiltered list.

**4. Distance is measured squared, from the origin.**
`x² + y²`, no square root. Distances are only ever compared with each other, and squaring preserves
that order exactly while keeping the arithmetic in integers. Case 5 confirms the cyborg sits at
`(0,0)`: `(3,10)` wins over `(0,11)`.

**5. Bad input is refused, bad readings are survived.**
An unknown mode or a pair of opposites is a programming error in the control unit and returns `422`;
an unparseable body returns `400`. Both are raised in step 1 and mapped to a status code by
`RadarController`. A single garbled *area*, though, is just a bad sensor reading — `Radar::Area.from`
returns `nil` for it and the sweep continues, which cases 6 and 7 depend on: both carry a reading
whose `targets` is a lone object, and both still expect a normal answer. Nothing left to attack is
not an error either: the answer is `{}` with `200`.

## Adding a mode

One file and one line:

```ruby
# app/models/attack_mode/spare_the_hospitals.rb
module AttackMode
  class SpareTheHospitals < Base
    def self.key = "spare-the-hospitals"

    def allows?(area) = !area.holds?("Hospital")
  end
end
```

then add it to `AttackMode.registry`. Neither the pipeline nor the controller changes — the new mode
joins the key automatically. Give it an `axis` only when its opposite actually exists.