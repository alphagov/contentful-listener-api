module StubConfig
  def stub_access_tokens_config(space_id:)
    allow(File).to receive(:read).with("config/access_tokens.yaml.erb").and_return <<~YAML
      - space_id: #{space_id}
        draft_access_token: draft-token
        live_access_token: live-token
    YAML
  end

  def stub_content_items_config(space_id:, entry_id:, content_id:, locale: "en")
    config = { "contentful_space_id" => space_id,
               "contentful_entry_id" => entry_id,
               "content_id" => content_id,
               "publishing_api_attributes" => { "locale" => locale } }

    allow(YAML).to receive(:load_file).and_call_original
    allow(YAML).to receive(:load_file).with("config/content_items.yaml").and_return([config])
  end

  def vcr_contentful_api_response(&block)
    contentful_request_match = lambda do |request_uri, _cassette_uri|
      URI(request_uri.uri).host =~ /contentful\.com/
    end

    VCR.use_cassette(
      "contentful_api_response",
      { record: :none, allow_playback_repeats: true, match_requests_on: [contentful_request_match] },
      &block
    )
  end
end
