require "rails_helper"

RSpec.describe ObjectiveSelector do
  def target(type, damage = nil)
    damage.nil? ? { "type" => type } : { "type" => type, "damage" => damage }
  end

  def area(x, y, targets)
    { "position" => { "x" => x, "y" => y }, "targets" => targets }
  end

  # The pipeline starts at the raw body, so the whole of it runs here.
  def select(modes, radar)
    described_class.new({ "attack-mode" => modes, "radar" => radar }.to_json).call
  end

  describe "chaining modes" do
    # Not covered by the shipped battery, and the reason modes carry a priority:
    # "the attack must always priorize objectives of type T-X" has to win over
    # the distance mode it is chained with, not merely break its ties.
    it "priorizes a distant T-X over a near area without one" do
      near = area(0, 10, [ target("T7-T", 90) ])
      far  = area(0, 50, [ target("T-X", 20) ])

      expect(select([ "closest-first", "priorize-t-x" ], [ near, far ]))
        .to eq({ position: { x: 0, y: 50 }, targets: [ "T-X" ] })
    end

    it "falls back on the chained mode once the priorized ones are tied" do
      near = area(0, 10, [ target("T-X", 20) ])
      far  = area(0, 50, [ target("T-X", 20) ])

      expect(select([ "closest-first", "priorize-t-x" ], [ near, far ])[:position])
        .to eq({ x: 0, y: 10 })
    end

    it "picks among the areas a filtering mode left behind" do
      crossfire = area(0, 90, [ target("T-X", 20), target("Human") ])
      clear     = area(0, 50, [ target("T-X", 20) ])

      expect(select([ "furthest-first", "avoid-crossfire" ], [ crossfire, clear ])[:position])
        .to eq({ x: 0, y: 50 })
    end
  end

  describe "with no mode steering the choice" do
    it "goes for the most dangerous area" do
      loud  = area(0, 90, [ target("T7-T", 90), target("HK-Bomber", 80) ])
      quiet = area(0, 10, [ target("HK-Tank", 20) ])

      expect(select([], [ loud, quiet ])[:position]).to eq({ x: 0, y: 90 })
    end

    it "breaks a dead heat on radar order" do
      first  = area(0, 10, [ target("T-X", 20) ])
      second = area(10, 0, [ target("T-X", 20) ])

      expect(select([], [ first, second ])[:position]).to eq({ x: 0, y: 10 })
    end
  end

  describe "the targets it reports" do
    it "lists the hardest hitting first and leaves out what it cannot attack" do
      radar = [ area(0, 10, [ target("T-X", 20), target("Human"), target("T7-T", 90) ]) ]

      expect(select([], radar)[:targets]).to eq([ "T7-T", "T-X" ])
    end

    it "never reports a human, whatever the vision module claims about it" do
      radar = [ area(0, 10, [ target("T-X", 20), target("Human", 50) ]) ]

      expect(select([], radar)[:targets]).to eq([ "T-X" ])
    end

    it "puts the T-X first when the attack priorizes it" do
      radar = [ area(0, 10, [ target("T7-T", 90), target("T-X", 20), target("HK-Bomber", 80) ]) ]

      expect(select([ "priorize-t-x" ], radar)[:targets]).to eq([ "T-X", "T7-T", "HK-Bomber" ])
    end
  end

  describe "when there is no objective" do
    it "reports nothing for an empty radar" do
      expect(select([ "closest-first" ], [])).to eq({})
    end

    it "reports nothing once every area has been ruled out" do
      radar = [ area(0, 10, [ target("T-X", 20), target("Human") ]) ]

      expect(select([ "avoid-crossfire" ], radar)).to eq({})
    end

    it "reports nothing when no area holds anything attackable" do
      expect(select([], [ area(0, 10, [ target("Human") ]) ])).to eq({})
    end

    it "still refuses an unusable attack-mode list" do
      expect { select([ "closest-first", "furthest-first" ], []) }
        .to raise_error(AttackMode::ConflictingModes)
    end
  end

  describe "the shape of the request" do
    it "unwraps the array the briefing shows" do
      radar = [ area(0, 10, [ target("T-X", 20) ]) ]
      body  = [ { "attack-mode" => [ "closest-first" ], "radar" => radar } ].to_json

      expect(described_class.new(body).call[:position]).to eq({ x: 0, y: 10 })
    end

    it "refuses a body that is not JSON" do
      expect { described_class.new("{not json").call }.to raise_error(JSON::ParserError)
    end
  end

  it "shrugs off a garbled area instead of losing the whole sweep" do
    radar = [ { "position" => "somewhere", "targets" => [] }, area(0, 10, [ target("T-X", 20) ]) ]

    expect(select([ "closest-first" ], radar)[:position]).to eq({ x: 0, y: 10 })
  end
end
