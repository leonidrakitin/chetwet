class Crm::Yclients::Api::BaseClient
  include HTTParty

  BASE_URL = 'https://api.yclients.com/api/v1/'.freeze

  class ApiError < StandardError
    attr_reader :code, :response

    def initialize(message = nil, code = nil, response = nil)
      @code = code
      @response = response
      super(message)
    end
  end

  def initialize(partner_token, user_token)
    @partner_token = partner_token
    @user_token = user_token
  end

  def get(path, params = {})
    response = self.class.get("#{BASE_URL}#{path}", query: params, headers: headers)
    handle_response(response)
  end

  def post(path, body = {})
    response = self.class.post("#{BASE_URL}#{path}", body: body.to_json, headers: headers)
    handle_response(response)
  end

  def put(path, body = {})
    response = self.class.put("#{BASE_URL}#{path}", body: body.to_json, headers: headers)
    handle_response(response)
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/vnd.yclients.v2+json',
      'Authorization' => "Bearer #{@partner_token}, User #{@user_token}"
    }
  end

  def handle_response(response)
    case response.code
    when 200..299
      parse_response(response)
    else
      error_message = "YClients API error: #{response.code} - #{response.body}"
      Rails.logger.error error_message
      raise ApiError.new(error_message, response.code, response)
    end
  rescue JSON::ParserError, TypeError => e
    raise ApiError.new("Failed to parse YClients API response: #{e.message}", response&.code, response)
  end

  def parse_response(response)
    body = response.parsed_response
    return body unless body.is_a?(Hash)

    unless body['success']
      error_message = body['meta']&.dig('message') || body['message'] || 'Unknown API error'
      raise ApiError.new(error_message, response.code, response)
    end

    body['data']
  end
end
