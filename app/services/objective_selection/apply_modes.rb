module ObjectiveSelection
  # Step 3 — apply the attack mode rules.
  #
  # A mode does one or both of two things: it rules areas out, and it ranks the
  # ones left. Filtering happens here; ranking is scored here and settled in
  # step 4, so each surviving area travels on with the ranks the modes gave it.
  #
  # The modes arrive already sorted by priority, so mode_ranks reads most
  # significant first and comparing two of them elementwise compares the modes
  # in the order they are meant to decide.
  class ApplyModes
    Ranked = Struct.new(:area, :mode_ranks)

    def initialize(areas, modes)
      @areas = areas
      @modes = modes
    end

    def call
      areas.select { |area| modes.all? { |mode| mode.allows?(area) } }
           .map { |area| Ranked.new(area, modes.map { |mode| mode.area_rank(area) }) }
    end

    private

    attr_reader :areas, :modes
  end
end
