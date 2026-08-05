module ObjectiveSelection
  # Step 5 — build the response.
  #
  # The position of the winning area and the types inside it, ordered by the
  # same modes that chose the area and, once they are done, hardest hitting
  # first. Damage is what the control unit told us; it is not sent back.
  class BuildResponse
    def initialize(area, modes)
      @area = area
      @modes = modes
    end

    def call
      return {} if area.nil?

      { position: { x: area.x, y: area.y }, targets: target_types }
    end

    private

    attr_reader :area, :modes

    def target_types
      area.attackable_targets
          .sort_by.with_index { |target, index| key(target, index) }
          .map(&:type)
    end

    # sort_by is not stable, so the reading's own position ends the key the way
    # the radar index ends the one in step 4.
    def key(target, index)
      [ *modes.map { |mode| mode.target_rank(target) }, -target.damage, index ]
    end
  end
end
