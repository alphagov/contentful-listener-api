require "rack/test"

RSpec.describe "healthchecks" do
  include Rack::Test::Methods
  include StubConfig

  def app
    Sinatra::Application
  end

  describe "GET /healthcheck/live" do
    it "returns a 200 response" do
      get "/healthcheck/live"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("OK")
    end
  end

  describe "GET /healthcheck/ready" do
    it "returns a 200 response when healthy" do
      stub_access_tokens_config(space_id: "space-1")
      body = { sys: { type: "space", id: "space-1" } }
      stub_request(:get, /contentful\.com\/spaces/).to_return(body: body.to_json)

      get "/healthcheck/ready"

      expect(last_response.status).to eq(200)
    end

    it "returns a 500 response when unhealthy" do
      stub_access_tokens_config(space_id: "space-1")
      stub_request(:get, /contentful\.com\/spaces/).to_return(status: 403)

      get "/healthcheck/ready"

      expect(last_response.status).to eq(500)
    end
  end
end
