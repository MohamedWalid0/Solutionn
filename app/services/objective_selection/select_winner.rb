module ObjectiveSelection
  # Step 4 — select the winning area.
  #
  # One sort key per area, arrays compared element by element, lowest wins. The
  # modes hold the front of the key and decide first. Whatever they leave tied
  # goes to the most dangerous area — the same rule BuildResponse uses on the
  # targets, and the only measure of importance the briefing offers. Radar order
  # closes the last door, so the module never answers a coin flip.
  #
  # Returns nil when nothing survived the modes, which is not an error.
  class SelectWinner
    def initialize(ranked)
      @ranked = ranked
    end

    def call
      ranked.min_by { |candidate| key(candidate) }&.area
    end

    private

    attr_reader :ranked

    def key(candidate)
      area = candidate.area
      [ *candidate.mode_ranks, -area.total_damage, area.index ]
    end
  end
end
