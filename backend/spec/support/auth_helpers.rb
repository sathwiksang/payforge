module AuthHelpers
  def auth_headers_for(user)
    post "/api/v1/auth/sign_in",
      params: { user: { email: user.email, password: "SecurePass12!!" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    token = response.headers["Authorization"]
    raise "JWT auth failed (status=#{response.status}): #{response.body}" unless token
    { "Authorization" => token }
  end

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
