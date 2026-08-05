module AttackMode
  # Attack the nearest areas.
  class ClosestFirst < Base
    def self.key = "closest-first"
    def self.axis = :distance
    def self.priority = 20

    def area_rank(area) = area.distance_squared
  end
end
