require "rails_helper"

RSpec.describe AttackMode do
  def target(type, damage = nil)
    Radar::Target.from(damage.nil? ? { "type" => type } : { "type" => type, "damage" => damage })
  end

  def area(x: 0, y: 0, targets: [ { "type" => "T-X", "damage" => 20 } ])
    Radar::Area.from({ "position" => { "x" => x, "y" => y }, "targets" => targets }, index: 0)
  end

  describe ".registry" do
    it "answers to every mode the briefing lists" do
      expect(described_class.registry.keys)
        .to match_array(%w[closest-first furthest-first avoid-crossfire priorize-t-x])
    end

    it "registers classes that all honour the Base contract" do
      described_class.registry.each_value do |mode_class|
        expect(mode_class.ancestors).to include(AttackMode::Base)
        expect(mode_class.key).to be_a(String)
        expect(mode_class.priority).to be_a(Integer)
      end
    end
  end

  describe ".build" do
    it "builds one instance per requested mode" do
      expect(described_class.build([ "avoid-crossfire" ]).map(&:key)).to eq([ "avoid-crossfire" ])
    end

    it "orders modes so the most significant one ranks areas first" do
      built = described_class.build([ "closest-first", "priorize-t-x" ])

      expect(built.map(&:key)).to eq([ "priorize-t-x", "closest-first" ])
    end

    it "treats a missing attack-mode list as no modes at all" do
      expect(described_class.build(nil)).to eq([])
    end

    it "refuses a mode it does not know" do
      expect { described_class.build([ "scorched-earth" ]) }
        .to raise_error(AttackMode::UnknownMode, /scorched-earth/)
    end

    it "refuses opposite modes chained together" do
      expect { described_class.build([ "closest-first", "furthest-first" ]) }
        .to raise_error(AttackMode::ConflictingModes, /closest-first.*furthest-first/)
    end

    it "allows modes that steer different decisions to be chained" do
      expect { described_class.build([ "furthest-first", "avoid-crossfire", "priorize-t-x" ]) }
        .not_to raise_error
    end
  end

  describe AttackMode::Base do
    subject(:mode) { Class.new(described_class).new }

    it "allows every area and stays neutral in both orderings" do
      expect(mode.allows?(area)).to be(true)
      expect(mode.area_rank(area)).to eq(0)
      expect(mode.target_rank(target("T-X", 20))).to eq(0)
    end

    it "insists on a key" do
      expect { described_class.key }.to raise_error(NotImplementedError)
    end
  end

  describe AttackMode::ClosestFirst do
    subject(:mode) { described_class.new }

    it "ranks the nearer area first" do
      expect(mode.area_rank(area(x: 0, y: 10))).to be < mode.area_rank(area(x: 0, y: 50))
    end

    it "conflicts with furthest-first over the same decision" do
      expect(mode.axis).to eq(AttackMode::FurthestFirst.axis)
    end
  end

  describe AttackMode::FurthestFirst do
    subject(:mode) { described_class.new }

    it "ranks the further area first" do
      expect(mode.area_rank(area(x: 0, y: 50))).to be < mode.area_rank(area(x: 0, y: 10))
    end
  end

  describe AttackMode::AvoidCrossfire do
    subject(:mode) { described_class.new }

    it "rules out an area holding a human" do
      humans = [ { "type" => "T-X", "damage" => 20 }, { "type" => "Human" } ]

      expect(mode.allows?(area(targets: humans))).to be(false)
    end

    it "allows an area with no human in it" do
      expect(mode.allows?(area)).to be(true)
    end

    it "leaves both orderings alone" do
      expect(mode.area_rank(area)).to eq(0)
      expect(mode.axis).to be_nil
    end
  end

  describe AttackMode::PriorizeTX do
    subject(:mode) { described_class.new }

    it "ranks an area holding a T-X ahead of one without" do
      without = [ { "type" => "T7-T", "damage" => 90 } ]

      expect(mode.area_rank(area)).to be < mode.area_rank(area(targets: without))
    end

    it "ranks the T-X ahead of the other targets in the area" do
      expect(mode.target_rank(target("T-X", 20))).to be < mode.target_rank(target("T7-T", 90))
    end

    it "outranks the distance modes so a T-X is always priorized" do
      expect(mode.priority).to be < AttackMode::ClosestFirst.priority
    end
  end
end
