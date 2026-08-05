require "rails_helper"

RSpec.describe "POST /radar", type: :request do
  def post_radar(body)
    post "/radar", params: body, headers: { "CONTENT_TYPE" => "application/json" }
  end

  def target(type, damage = nil)
    damage.nil? ? { "type" => type } : { "type" => type, "damage" => damage }
  end

  def area(x, y, targets)
    { "position" => { "x" => x, "y" => y }, "targets" => targets }
  end

  # The battery shipped with the challenge, run exactly the way test_attack.sh
  # runs it: one "<request>|<expected response>" per line, compared as raw
  # strings, so key order and spacing count as much as the selection itself.
  describe "the battery shipped with the challenge" do
    cases = Rails.root.join("test_cases.json").readlines.filter_map.with_index do |line, offset|
      next if line.strip.empty? || line.start_with?("#")

      input, expected = line.split("|", 2).map(&:strip)
      { number: offset + 1, input: input, expected: expected }
    end

    it "reads the cases out of test_cases.json" do
      expect(cases).not_to be_empty
    end

    cases.each do |test_case|
      it "picks the right objective for case #{test_case[:number]}" do
        post_radar(test_case[:input])

        expect(response.body).to eq(test_case[:expected])
      end
    end
  end

  it "accepts the array-wrapped request shown in the briefing" do
    post_radar([ {
      "attack-mode" => [ "closest-first" ],
      "radar" => [
        area(0, 40, [ target("T1-9", 80), target("HK-Tank", 20), target("Human") ]),
        area(2, 60, [ target("T1-9", 40) ])
      ]
    } ].to_json)

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq('{"position":{"x":0,"y":40},"targets":["T1-9","HK-Tank"]}')
  end

  describe "when there is nothing left to attack" do
    it "answers with an empty objective for an empty radar" do
      post_radar({ "attack-mode" => [ "closest-first" ], "radar" => [] }.to_json)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("{}")
    end

    it "answers with an empty objective when every area is ruled out" do
      post_radar({
        "attack-mode" => [ "avoid-crossfire" ],
        "radar" => [ area(0, 10, [ target("T-X", 20), target("Human") ]) ]
      }.to_json)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("{}")
    end
  end

  describe "when the attack-mode list is unusable" do
    it "rejects a mode it does not know" do
      post_radar({ "attack-mode" => [ "scorched-earth" ], "radar" => [] }.to_json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("scorched-earth")
    end

    it "rejects opposite modes chained together" do
      post_radar({ "attack-mode" => [ "closest-first", "furthest-first" ], "radar" => [] }.to_json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("closest-first", "furthest-first")
    end
  end

  it "rejects a body it cannot parse" do
    post_radar("{not json")

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to be_present
  end
end
