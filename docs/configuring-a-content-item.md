# Configuring a content item

For this application to utilise content produced by Contentful there needs to be a mapping configured. This mapping is between a GOV.UK content item and an [entry][] in Contentful. Once configured any updates to that entry, or associations to it, will result in an attempt to synchronise data with the GOV.UK Publishing API. This document describes the configuration steps.

[entry]: https://www.contentful.com/help/adding-new-entry/

## 1. Create an entry in Contentful

The first step towards configuring a mapping is to have an entry created in Contenful that will serve as the root entry for the content item.

You will have to decide whether to create the entry in an existing [space](https://www.contentful.com/help/spaces-and-organizations/) or a new one, and whether to create or reuse a [content model](https://www.contentful.com/help/content-modelling-basics/).

Once the entry is created you will need to make a note of the entry ID and the space ID (these can be retrieved from the entry URL, for example `/spaces/q15b851vpa2y/entries/Jid87gJxnMjLQlww1a4WF` describes a space ID of `q15b851vpa2y` and an entry ID of `Jid87gJxnMjLQlww1a4WF`).

## 2. Define a mapping configuration

Your next step is to configure the mapping in [config/content_items.yaml](../config/content_items.yaml). This can be done by using the below example as reference.

If you are creating a new piece of content for GOV.UK, you will need to [generate a content ID](https://www.uuidtools.com/v4), if you are replacing a piece of content you should re-use the content ID it is assigned.

```yaml
- contentful_space_id: q15b851vpa2y # required, contentful space id you determined earlier
  contentful_entry_id: Jid87gJxnMjLQlww1a4WF # required, contentful entry id you determined
  content_id: 616486d4-59af-4d23-b302-d35270a9e032 # required, generated or reused content id
  draft_only: false # optional, defaults to false, setting this to true will mean content is not pushed to live GOV.UK even if the Contentful entry is published, useful for testing
  publishing_api_attributes: # required, a hash of fields included in the Publishing API put content request
    base_path: /path-on-gov-uk # required
    locale: en # optional, defaults to en
    rendering_app: frontend # required
    schema_name: special_route # optional, defaults to `special_route`
    document_type: special_route # optional, defaults to `special_route`
    update_type: major # optional, defaults to major meaning every update will result in the GOV.UK public_updated_at timestamp being updated
    title: ~ # optional, will use a `title` field on the root Contentful entry if available - Publishing API will reject the request if there is no title
    description: ~ # optional, will use a `description` field on the root Contentful entry if available
    routes: # optional, will default to setting a route based on the base_path
      - path: /path-on-gov-uk
        type: exact
```

### Space configuration

Contentful issues [access tokens][] to specific spaces. If your entry involved the creation of a new space you will need to configure access tokens for that space. This will involve adding new environment variables for the application and configuring a new webhook.

To add a new space configuration, or check which existing ones are there, see [config/access_tokens.yaml.erb](../config/access_tokens.yaml.erb).

[access tokens]: https://www.contentful.com/developers/docs/references/authentication/#the-content-delivery-and-preview-api

## 3. Use the rake task to put the content item on GOV.UK

Once the application is deployed with the new configuration any edits to the referenced Contentful entry will attempt to update the Publishing API.

However you don't need to edit the entry to cause the initial write, there is also a rake task that can do this:

```
bundle exec rake content_item:sync[<content_id>, <locale, defaults to "en">]
```

You can provide an optional `RESERVE_PATH=yes` option to have this application reserve the content item's path in the Publishing API. This is useful when migrating an existing page to this application.

For example:

```
bundle exec rake content_item:sync[31681f08-9e4d-4709-b995-840a695ed54c] RESERVE_PATH=yes
```
