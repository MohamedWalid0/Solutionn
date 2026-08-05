class RadarController < ApplicationController
  rescue_from JSON::ParserError, with: :malformed_body
  rescue_from AttackMode::Error, with: :unusable_attack_mode

  # The body is handed over raw: parsing it is the pipeline's first step, and
  # the two failures it can raise are mapped to status codes below.
  def create
    render json: ObjectiveSelector.new(request.raw_post).call
  end

  private

  def malformed_body(_error)
    render json: { error: "malformed JSON body" }, status: :bad_request
  end

  def unusable_attack_mode(error)
    render json: { error: error.message }, status: :unprocessable_content
  end
end
