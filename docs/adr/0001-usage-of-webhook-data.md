# 1. Usage of Webhook data

Date: 2022-09-22

## Context

This application is informed that the GOV.UK Publishing API requires updating via [Contentful webhooks][]. These webhooks contain information on the data that changed and the type of event. For example, there could be an auto-save event that informs that a title changed from "VAT Rates" to "VAT Rates in England".

We considered two options for how we could react to these webhook events and subsequently update GOV.UK:

1. Use the information within the webhook to update the part of content that needed updating
2. Use the information in the webhook as an indication that data needed re-assembling and retrieve all the relevant page data from Contentful to achieve that.

[Contentful webhooks]: https://www.contentful.com/developers/docs/concepts/webhooks/

## Decision

We chose to take option 2.

We felt that this:

- provided an opportunity for simpler code, as there would be no need to write an algorithm to determine the data changed
- reduced the risk of inconsistency should a webhook fail or be received out-of-order, as the next webhook received would retrieve the latest state
- reduced the harm a malicious actor could do if they were able to send a request to this application pretending to be a Contentful webhook in an attempt to put malicious content onto GOV.UK. Under this pattern, the latest content is always retrieved from the configured Contentful source.

## Status

Accepted

## Consequences

We will make API calls to Contentful following every webhook to retrieve the full data of the content. This could present an issue for API quota usage were there to be significant quantities of content, however we anticipate that in practice the usage will have a negligible impact on quotas.

There is a risk that API calls to retrieve the full data [produce a stale response from Contentful's CDN][stale-response]. If we experience this we may need to rethink our approach.

We will not consider a thorough authentication system for access to this tool, we will instead make use of [HTTP Basic Authentication Scheme][basic-auth] over TLS.

[stale-response]: https://www.contentful.com/faq/webhooks/#if-i-received-a-publish-event-why-do-i-get-an-old-version-in-the-cda
[basic-auth]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#basic_authentication_scheme
