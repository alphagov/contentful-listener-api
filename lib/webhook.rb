# A class to make it abstract the questions we want to ask of a Contentful
# Webhook payload
class Webhook
  attr_reader :topic, :payload

  def initialize(topic, payload)
    @topic = topic.to_s
    @payload = payload
  end

  # Note: It's unclear what we should do if someone archives/unpublishes/deletes the root
  # item
  def event_of_interest?
    %w[create save auto_save archive unarchive publish unpublish delete].include?(cms_event)
  end

  def entity_id
    space_id = payload.dig("sys", "space", "sys", "id")
    type = payload.dig("sys", "type")
    entity_id = payload.dig("sys", "id")

    raise "Unable to identify entity id" unless space_id && type && entity_id

    "#{space_id}:#{type}:#{entity_id}"
  end

  # Work out whether this change represents a change to the live version
  # as many will only affect the draft
  def live_change?
    %w[archive unarchive publish unpublish delete].include?(cms_event)
  end

  def environment
    payload.dig("sys", "environment", "sys", "id")
  end

  def expected_environment?
    environment == ENV.fetch("CONTENTFUL_ENVIRONMENT", "master")
  end

private

  def cms_event
    split_topic = topic.split(".")
    return if split_topic[0] != "ContentManagement" || !%w[Entry Asset].include?(split_topic[1])

    split_topic[2]
  end
end
