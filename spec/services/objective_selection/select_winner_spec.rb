require "rails_helper"

# The order the key resolves in, one example per rung. Reaching these through
# the front door would mean staging a whole radar sweep for each; here the mode
# ranks are handed over directly, which is all step 4 ever sees of them.
RSpec.describe ObjectiveSelection::SelectWinner do
  def area(x, y, damage: 20, index: 0)
    Radar::Area.from(
      { "position" => { "x" => x, "y" => y }, "targets" => [ { "type" => "T-X", "damage" => damage } ] },
      index: index
    )
  end

  def ranked(area, *mode_ranks)
    ObjectiveSelection::ApplyModes::Ranked.new(area, mode_ranks)
  end

  def winner(*candidates)
    described_class.new(candidates).call
  end

  it "reports nothing when the modes left nothing standing" do
    expect(described_class.new([]).call).to be_nil
  end

  it "lets the modes decide before anything else does" do
    preferred = ranked(area(0, 90, damage: 20), 0)
    dangerous = ranked(area(0, 10, damage: 200), 1)

    expect(winner(preferred, dangerous).y).to eq(90)
  end

  it "asks the modes in turn, most significant first" do
    first_mode_wins = ranked(area(0, 90), 0, 1)
    second_mode     = ranked(area(0, 10), 1, 0)

    expect(winner(first_mode_wins, second_mode).y).to eq(90)
  end

  it "goes for the most dangerous area once the modes are tied" do
    quiet = ranked(area(0, 10, damage: 20), 0)
    loud  = ranked(area(0, 90, damage: 200), 0)

    expect(winner(quiet, loud).y).to eq(90)
  end

  it "settles two equally dangerous areas on radar order" do
    first  = ranked(area(0, 10, index: 0), 0)
    second = ranked(area(10, 0, index: 1), 0)

    expect(winner(first, second).index).to eq(0)
  end
end
