# 2. Synchronous updating of Publishing API

Date: 2022-09-22

## Context

This application is informed that the GOV.UK Publishing API requires updating via [Contentful webhooks][]. These webhooks act as an indication that this application has work to do.

We considered two approaches for when to do this work:

1. Update the Publishing API prior to producing a HTTP response to a webhook, therefore synchronously updating the Publishing API
2. Use background processing software (for example, [Sidekiq](https://sidekiq.org) to queue a job during the HTTP request and then update the Publishing API asynchronously

[Contentful webhooks]: https://www.contentful.com/developers/docs/concepts/webhooks/

## Decision

We chose to take option 1, synchronously updating the Publishing API

We felt that this:

- allowed a simpler architecture as background processing software would require additional processes to manage and software depenencies (such as Redis)
- would make debugging easier as we could use Contentful webhook responses as a way to record information of the work performed as a result of the webhook
- was unlikely to be a frequent source of HTTP timeout errors as Contentful seems to provide a [generous timeout window](https://www.contentfulcommunity.com/t/webhook-retry-on-failure/137/4)

## Status

Accepted

## Consequences

We accept that there is introduces a risk introduced that high volumes of work or poor performance of dependent systems may result in webhooks leading to HTTP timeouts.

We understand that by forgoing a retry system that is afforded by a background processing system, we rely on the retry mechanism provided by Contentful webhooks as a means to resolve any errors in our server side code. This increases the liklelihood that a problem may lead to the work expected from a webhook to not occur.
