module ObjectiveSelection
  # Step 2 — turn the radar into the areas we could attack.
  #
  # Every reading becomes one area carrying its position, its targets and its
  # place in the sweep. Two kinds never make it out: the garbled, which
  # Radar::Area.from reports as nil, and the ones holding nothing we may fire
  # at, which would only produce an objective with an empty target list.
  class BuildCandidates
    def initialize(radar)
      @radar = radar
    end

    def call
      radar.each_with_index
           .filter_map { |raw, index| Radar::Area.from(raw, index:) }
           .select(&:attackable?)
    end

    private

    attr_reader :radar
  end
end
