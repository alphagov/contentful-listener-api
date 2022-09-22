# How this application works

This tool acts as a relatively simple adapter between a [Contentful](https://www.contentful.com/) CMS instance and GOV.UK's Publishing API. It acts as a HTTP endpoint for [Contentful Webhooks](https://www.contentful.com/developers/docs/concepts/webhooks/) and uses this to initiate a process of updating GOV.UK content with data from Contentful.

Contentful relies upon a [link system between entries][contentful-entries] as a way to produce complex data structures. For this reason it is expected that a single page on GOV.UK, that is populated with Contentful data, will utilise a number of Contentful entries. Content will need to be updated on GOV.UK when any one of these entities are updated.

[contentful-entries]: https://www.contentful.com/developers/docs/concepts/links/

## Updating draft content

```mermaid
sequenceDiagram
    actor Publisher
    participant Contentful
    participant ListenerApi as Contentful Listener API
    participant PublishingApi as Publishing API
    Publisher->>+Contentful: Drafts changes in UI
    Contentful-->>-Publisher: Feedbacks change saved
    Contentful->>+ListenerApi: Webhook change notification
    ListenerApi->>+PublishingApi: Identify affected GOV.UK content
    PublishingApi-->>-ListenerApi: List of content
    ListenerApi->>+PublishingApi: Load current GOV.UK draft content
    PublishingApi-->>-ListenerApi: GOV.UK draft content
    ListenerApi->>+Contentful: Fetch draft content
    Contentful-->>-ListenerApi: Draft content
    ListenerApi->>+PublishingApi: Update GOV.UK draft content
    PublishingApi-->>-ListenerApi: Update outcome
    ListenerApi-->>-Contentful: Webhook outcome
```

The process to update draft GOV.UK content occurs whenever a publisher saves a change to the data stored in Contentful. When this occurs a webhook is generated, this webhook will include information on the entity that was changed and how it was changed. For example, if a publisher updates a title field in Contentful then a webhook is produced to describe the save event that occurred behind that title change.

This application, Contentful Listener API, is configured to receive webhooks from the Contentful instance. When it receives one it will query the GOV.UK Publishing API to determine if there are content items that utilise this entity and are thusly affected by the change the webhook is communicating.

Contentful Listener API will then loop through any items it found in the Publishing API that are affected. For each one it will attempt to update the draft content of each of these.

The update process involves accessing the current content in the GOV.UK Publishing API. This allows recording a lock version number to utilise [Publishing API's optimistic locking][optimistic-locking] which is used to prevent concurrency problems. It then uses the Contentful API to load the page data from Contentful, by loading every linked entity and representing them as JSON. This data is assembled as a payload for the Publishing API. The current content is compared against this payload and, if the data is different, the Publishing API is updated with the new draft content, which it will use to update the GOV.UK draft stack.

Once all the content has been updated a summary of the work done will be returned in the webhook response.

[optimistic-locking]: https://github.com/alphagov/publishing-api/blob/main/docs/api.md#optimistic-locking-previous_version

## Updating live content

```mermaid
sequenceDiagram
    actor Publisher
    participant Contentful
    participant ListenerApi as Contentful Listener API
    participant PublishingApi as Publishing API
    Publisher->>+Contentful: Publishes changes in UI
    Contentful-->>-Publisher: Feedbacks change saved
    Contentful->>+ListenerApi: Webhook change notification
    ListenerApi->>+PublishingApi: Identify affected GOV.UK content
    PublishingApi-->>-ListenerApi: List of content
    ListenerApi->>+PublishingApi: Load current GOV.UK live content
    PublishingApi-->>-ListenerApi: GOV.UK live content
    ListenerApi->>+Contentful: Fetch published content
    Contentful-->>-ListenerApi: Published content
    ListenerApi->>+PublishingApi: Update GOV.UK draft content
    PublishingApi-->>-ListenerApi: Update outcome
    ListenerApi->>+PublishingApi: Publish GOV.UK content
    PublishingApi-->>-ListenerApi: Publish outcome
    ListenerApi->>+PublishingApi: Load current GOV.UK draft content
    PublishingApi-->>-ListenerApi: GOV.UK draft content
    ListenerApi->>+Contentful: Fetch Draft content
    Contentful-->>-ListenerApi: Draft content
    ListenerApi->>+PublishingApi: Update GOV.UK draft content
    PublishingApi-->>-ListenerApi: Update outcome
    ListenerApi-->>-Contentful: Webhook outcome
```

The updating live content process is very similar to the draft one with additional steps and involves updating the live content on GOV.UK. This process occurs when a publisher makes a change in the Contentful user interface which affects published content. Examples of this could be publuishing, archiving or deleting content.

When a webhook indicates that a change is made to live content, a process begins that attempts to update the live content on GOV.UK and, if necessary, reset the draft content afterwards.

In order to put content live on GOV.UK it is necessary that the Publishing API draft version of this content exists and this is then promoted to become live content. As GOV.UK content that is assembled from Contentful entries may contain a mixture of draft and published entries, it is necessary to first reset any existing draft on GOV.UK to only be assembed from published entries. Once this content is made live the draft GOV.UK content may no longer be in sync with the Contentful draft data. Therefore it is necessary to update the GOV.UK draft content with draft Contentful content.
