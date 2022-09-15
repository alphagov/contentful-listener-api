module Healthcheck
  class ContentfulCheck
    def name
      :contentful
    end

    def status
      if spaces_with_problems.any?
        :critical
      elsif details[:space_connectivity].any?
        :ok
      else
        :warning
      end
    end

    def details
      @details ||= {}
      @details[:space_connectivity] ||= ContentfulClient.configured_spaces.map do |space_id|
        {
          space_id:,
          draft_communication: can_communicate?(ContentfulClient.draft_client(space_id)),
          live_communication: can_communicate?(ContentfulClient.live_client(space_id)),
        }
      end
      @details
    end

    def message
      if spaces_with_problems.any?
        space_problems = spaces_with_problems.map do |space|
          bad = []
          bad << "draft" unless space.dig(:draft_communication, :success)
          bad << "live" unless space.dig(:live_communication, :success)

          "space #{space[:space_id]} (#{bad.join(' and ')})"
        end

        "failed to connect to Contentful spaces: #{space_problems.join(', ')}"
      elsif details[:space_connectivity].any?
        "successfully connected to each Contentful space"
      else
        "no Contentful spaces configured"
      end
    end

  private

    def spaces_with_problems
      @spaces_with_problems ||= details[:space_connectivity].select do |space|
        !space.dig(:draft_communication, :success) || !space.dig(:live_communication, :success)
      end
    end

    def can_communicate?(contentful_client)
      contentful_client.space
      { success: true }
    rescue Contentful::Error => e
      { success: false, message: e.message }
    end
  end
end
