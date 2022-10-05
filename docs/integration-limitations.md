# Integration limitations

There are a number of areas where integrating Contentful with GOV.UK hasn't been explored or is expected to be problematic, this document attempts to capture the known ones with contextual information.

## No integration with Asset Manager

When GOV.UK content requires supporting binary files (for example: images and PDF's) these are typically uploaded to and served by the GOV.UK application, [Asset Manager](https://github.com/alphagov/asset-manager).

However, this Contentful integration does not make any use of Asset Manager and instead embeds the Contentful URL's of assets in the JSON sent to the publishing API. This has been done for three reasons.

1. Necessity - the initial scope of this Contentful integration does not utilise binary files, so we've not needed to determine whether there are problems hosting them with Contentful.
2. Simplicity - It's complex to develop a mapping system to co-ordinate the lifecycle of assets between Contentful and Asset Manager.
3. Flexibility - hosting the images on Asset Manager would prevent the use of Contentful's [Image API][], which provides dynamic resize options.

It is expected that it would be relatively straight forward to utilise assets hosted by Contentful on GOV.UK. To do so we'd have to:

- modify the shared [GOV.UK content security policy](https://github.com/alphagov/govuk_app_config/blob/main/lib/govuk_app_config/govuk_content_security_policy.rb) for the appropriate Contentful hostnames.
- accept that the uploaded GOV.UK assets would be hosted on a URL with a hostname GOV.UK do not control
- accept the risk that any Contentful CDN downtime could result in a reduced GOV.UK page experience

[Image API]: https://www.contentful.com/developers/docs/references/images-api/

## No Integration with GOV.UK Search API

We've not explored configuring the GOV.UK Search API to index content published by this application and thus it will not be findable via [www.gov.uk/search](https://www.gov.uk/search).

We expect that this functionality can be achieved with relatively low difficulty however it will need additional configuration. The low difficulty route is based on an idea that we can create a single field for the Search API, similar to Smart Answer's [hidden_search_terms][], and index that.

[hidden_search_terms]: https://github.com/alphagov/smart-answers/blob/a73a79f3f6ad1f641a65100667ad1aa7856fc3c6/app/presenters/content_item_presenter.rb#L17

## Embedded data in Contentful rich text input

Contentful provides a [rich text][] input format which allows the ability to embed content. We have not configured this application to populate this embedded data when constructing a payload for the Publishing API. So usage of this field would not result in ability to access the referenced data.

This field has not been configured as we were not anticipating the use of rich text in early tests of this tool (since it produces a complex JSON output that needs to be reconstructed). It is unlikely to be particularly difficult to add this functionality if rich text content embedded is embraced.

[rich text]: https://www.contentful.com/developers/docs/concepts/rich-text/

## Content in multiple languages

Contentful supports the ability to translate entries to languages. We have not explored this functionality and expect extra development would be required to utilise it.

## Utilising the Publishing API link system

The GOV.UK Publishing API provides a [link system][pub-api-links] that allows GOV.UK content to reference other GOV.UK content. This Contentful integration does not provide any means to embrace this system and would require additional development and configuration to use it.

This has not been explored as it was not a required feature for the initial use-case. There is an expectation that content published by this tool will be self-contained and, therefore, not need it.

[pub-api-links]: https://github.com/alphagov/publishing-api/blob/main/docs/link-expansion.md

## Ability to create new GOV.UK content items dynamically

This integration has been designed to support managing single pages on GOV.UK - specifically those which have bespoke needs - where each page is individually configured.

It is not intended to allow for a content type to be produced by Contentful and create new GOV.UK content items (for example, creating news articles). Additional development would be required to support this feature.

## Publishing life-cycle metadata

GOV.UK's internal CMS tools have bespoke metadata features that Contentful doesn't have. This limits the ability to mirror GOV.UK's metadata. Specifically, it would be challenging to have features such as minor/major update types and the ability to store a change history.

We've taken the approach of, by default, treating every change that is made to content as a major change as this will update the `public_updated_at` timestamp which expresses when the content was last updated (in contrast, only using minor updates and never updating the value of`public_updated_at` seems dishonest).

## Automatic removal of content

The process to remove content that is published by this application is for a developer to [manually run a rake task](./removing-a-content-item.md). Removing the root entry from Contentful will not remove the content from GOV.UK.

Contentful doesn't allow content to be associated with metadata and the point of removal in the way GOV.UK does. GOV.UK uses this metadata to replace the URL of the content with either a redirect or an appropriate status code. Therefore it is unlikely that this feature will be developed.
