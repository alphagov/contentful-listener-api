module StubContentful
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
