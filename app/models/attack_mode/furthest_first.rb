module AttackMode
  # Attack the furthest areas.
  class FurthestFirst < Base
    def self.key = "furthest-first"
    def self.axis = :distance
    def self.priority = 20

    def area_rank(area) = -area.distance_squared
  end
end
