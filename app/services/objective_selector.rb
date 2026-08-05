# Picks the next position to attack out of one radar reading.
#
# The briefing draws the module as a pipeline and this is it, one step per
# service, each named after the box it implements:
#
#   parse → build candidates → apply modes → pick winner → build response
#
# Nothing here decides anything. Read a step's own file to see what it does.
class ObjectiveSelector
  def initialize(body)
    @body = body
  end

  def call
    request    = ObjectiveSelection::ParseRequest.new(body).call
    candidates = ObjectiveSelection::BuildCandidates.new(request.radar).call
    ranked     = ObjectiveSelection::ApplyModes.new(candidates, request.modes).call
    winner     = ObjectiveSelection::SelectWinner.new(ranked).call

    ObjectiveSelection::BuildResponse.new(winner, request.modes).call
  end

  private

  attr_reader :body
end
