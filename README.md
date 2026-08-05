# Objective selection module

The T-800's objective selection module. The cyborg control unit posts a radar sweep and the chosen
attack modes; the module answers with the single position to attack next and the targets in it,
hardest-hitting first.

Rails 7.2, API only, fully dockerized. No database is involved — a request goes in, an answer comes
out, nothing is stored.

## Run it

```bash
docker compose up -d          # http://localhost:3000
docker compose down
```

```bash
curl -s -H 'Content-Type: application/json' -X POST localhost:3000/radar -d '{
  "attack-mode": ["closest-first"],
  "radar": [
    {"position": {"x": 0, "y": 40}, "targets": [
      {"type": "T1-9", "damage": 80}, {"type": "HK-Tank", "damage": 20}, {"type": "Human"}]},
    {"position": {"x": 2, "y": 60}, "targets": [{"type": "T1-9", "damage": 40}]}
  ]}'

{"position":{"x":0,"y":40},"targets":["T1-9","HK-Tank"]}
```

## Test it

```bash
docker compose run --rm web bundle exec rspec   # 67 examples
./test_attack.sh                                # the shipped battery, server must be up
docker compose run --rm web bin/rubocop
```

`spec/requests/radar_spec.rb` reads `test_cases.json` and compares raw response bodies, so it runs
the same seven cases `test_attack.sh` does — a green suite means a green script.

## The endpoint

`POST /radar`

```jsonc
{
  "attack-mode": ["closest-first", "priorize-t-x"],   // chained, order does not matter
  "radar": [
    { "position": { "x": 0, "y": 40 },
      "targets": [ { "type": "T-X", "damage": 80 }, { "type": "Human" } ] }
  ]
}
```

| response | when |
|---|---|
| `200` `{"position":{"x":0,"y":40},"targets":["T-X"]}` | an objective was found |
| `200` `{}` | nothing left to attack — empty radar, or every area ruled out |
| `400` `{"error":"malformed JSON body"}` | the body is not JSON |
| `422` `{"error":"unknown attack mode: …"}` | no such mode |
| `422` `{"error":"conflicting attack modes: …"}` | opposites chained, e.g. `closest-first` + `furthest-first` |

Modes: `closest-first`, `furthest-first`, `avoid-crossfire`, `priorize-t-x`.

Humans are never returned as attack targets, whether or not `avoid-crossfire` is in play. That mode
is about not firing *near* one, which is a different question.

## How it works

Five steps, one service each, in the order the briefing draws them:

```
parse request → build candidate areas → apply attack modes → select winner → build response
```

Every attack mode answers three questions — may this area be attacked, how should areas be ordered,
how should the targets inside be ordered — so chaining modes is just asking all of them. Step 3
filters and scores, step 4 settles whatever the modes left tied.

- [docs/LOGIC.md](docs/LOGIC.md) — the selection rules, `axis` vs `priority`, and the judgement calls
  the briefing left open.
- [docs/WORKFLOW.md](docs/WORKFLOW.md) — the pipeline diagram and one request traced end to end.
- [docs/CAVEMAN.md](docs/CAVEMAN.md) — the five steps in words of one syllable, for when it is late
  and the sort keys have stopped making sense.

```
app/controllers/radar_controller.rb          raw body in, status codes out
app/services/objective_selector.rb           the five steps, in order, and nothing else
app/services/objective_selection/            one file per step
  parse_request.rb                           1. JSON, unwrap, resolve the modes
  build_candidates.rb                        2. readings to areas, drop the useless
  apply_modes.rb                             3. filter, then score with the mode ranks
  select_winner.rb                           4. lowest key wins, ties broken the same way every time
  build_response.rb                          5. position, and the target types in order
app/models/attack_mode.rb                    registry; refuses unknown and opposite modes
app/models/attack_mode/base.rb               the three questions, with neutral defaults
app/models/attack_mode/*.rb                  one file per mode
app/models/radar/{area,target}.rb            parsing a sweep, surviving a garbled reading
```

## Adding an attack mode

Skynet keeps building. A new mode is one file plus one line in `AttackMode.registry`:

```ruby
module AttackMode
  class SpareTheHospitals < Base
    def self.key = "spare-the-hospitals"

    def allows?(area) = !area.holds?("Hospital")
  end
end
```

Nothing else changes — not the pipeline, not the controller. Override `area_rank` to have it steer
which area is chosen, `target_rank` to have it steer the reported order, and give it an `axis` only
once a mode that contradicts it exists.
