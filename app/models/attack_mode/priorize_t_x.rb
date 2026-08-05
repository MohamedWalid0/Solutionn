module AttackMode
  # The attack must always priorize objectives of type T-X: the area holding one
  # is chosen first, and inside it the T-X is reported first.
  #
  # This ranks rather than filters, so a radar reading with no T-X at all still
  # yields an objective instead of nothing.
  class PriorizeTX < Base
    TYPE = "T-X".freeze

    def self.key = "priorize-t-x"
    def self.priority = 10

    def area_rank(area) = area.holds?(TYPE) ? 0 : 1
    def target_rank(target) = target.type == TYPE ? 0 : 1
  end
end
