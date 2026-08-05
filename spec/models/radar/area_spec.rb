require "rails_helper"

RSpec.describe Radar::Area do
  def build(raw, index: 0)
    described_class.from(raw, index: index)
  end

  def reading(x: 0, y: 0, targets: [])
    { "position" => { "x" => x, "y" => y }, "targets" => targets }
  end

  describe ".from" do
    it "reads the position and the targets" do
      area = build(reading(x: 3, y: 10, targets: [ { "type" => "T-X", "damage" => 20 } ]))

      expect(area.x).to eq(3)
      expect(area.y).to eq(10)
      expect(area.targets.map(&:type)).to eq([ "T-X" ])
    end

    it "copes with a lone target object where a list is expected" do
      area = build(reading(targets: { "type" => "mech", "number" => 20 }))

      expect(area.targets.map(&:type)).to eq([ "mech" ])
    end

    it "copes with an area that reports no targets at all" do
      expect(build({ "position" => { "x" => 1, "y" => 2 } }).targets).to eq([])
    end

    it "gives up on a reading with no usable position" do
      expect(build({ "targets" => [] })).to be_nil
      expect(build(reading(x: "far", y: 2))).to be_nil
      expect(build("noise")).to be_nil
    end
  end

  describe "what can be attacked" do
    it "keeps only the targets whose damage the vision module could read" do
      area = build(reading(targets: [
        { "type" => "T-X", "damage" => 80 },
        { "type" => "Human" },
        { "type" => "mech", "number" => 20 }
      ]))

      expect(area.attackable_targets.map(&:type)).to eq([ "T-X" ])
      expect(area).to be_attackable
    end

    it "never attacks a human, not even one reported with damage" do
      area = build(reading(targets: [
        { "type" => "T-X", "damage" => 20 },
        { "type" => "Human", "damage" => 50 }
      ]))

      expect(area.attackable_targets.map(&:type)).to eq([ "T-X" ])
    end

    it "is not worth attacking when nothing in it can be" do
      expect(build(reading(targets: [ { "type" => "Human" } ]))).not_to be_attackable
    end
  end

  describe "#humans?" do
    it "spots a human even though it is not an attackable target" do
      area = build(reading(targets: [ { "type" => "T-X", "damage" => 20 }, { "type" => "Human" } ]))

      expect(area).to be_humans
    end

    it "is false for an area of machines" do
      expect(build(reading(targets: [ { "type" => "T-X", "damage" => 20 } ]))).not_to be_humans
    end
  end

  describe "#holds?" do
    subject(:area) { build(reading(targets: [ { "type" => "T-X", "damage" => 20 } ])) }

    it { expect(area.holds?("T-X")).to be(true) }
    it { expect(area.holds?("HK-Tank")).to be(false) }
  end

  describe "#total_damage" do
    it "adds up the damage the area may cause" do
      area = build(reading(targets: [
        { "type" => "T-X", "damage" => 20 },
        { "type" => "T7-T", "damage" => 90 },
        { "type" => "Human" }
      ]))

      expect(area.total_damage).to eq(110)
    end
  end

  describe "#distance_squared" do
    it "measures from the cyborg at the origin" do
      expect(build(reading(x: 3, y: 4)).distance_squared).to eq(25)
    end

    it "orders areas the same way the real distance would" do
      expect(build(reading(x: 3, y: 10)).distance_squared)
        .to be < build(reading(x: 0, y: 11)).distance_squared
    end
  end
end
