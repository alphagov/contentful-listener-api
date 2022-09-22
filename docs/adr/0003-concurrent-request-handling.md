# 3. Concurrent request handling

Date: 2022-09-22

## Context

This application is able to serve more than one webhook request at a time - by virtue of both being hosted on multiple machines and allowing concurrent request handling on an individual machine. This creates a risk that there could be concurrent attempts to update GOV.UK content which may produce undesirable results. For example, if there were two competing requests to update content, one draft and one live, it could lead to draft content accidentally being published live on GOV.UK.

We considered three approaches:

1. Use a datastore, such as [Redis][redis-locks], to provide a distributed lock to prevent concurrent processing
2. Utilise the GOV.UK Publishing API's [optimistic locking][] system, as a means to retry when a conflict occurs
3. Consider this scenario low risk and accept that risk

[redis-locks]: https://redis.io/docs/reference/patterns/distributed-locks/
[optimistic locking]: https://github.com/alphagov/publishing-api/blob/main/docs/api.md#optimistic-locking-previous_version

## Decision

We chose to take option 2 and use the Publishing API optimistic locking system

We chose this because:

- we felt that it was irresponsible to not consider the risk, but we didn't want to add a new software dependency overhead
- the risk of problems seemed unlikely in the early use of this software and therefore preferable to take an optimistic approach to locking
- the usage of a retry system meant the consequences of a conflict were relatively low

## Status

Accepted

## Consequences

We incur a greater risk of timeouts when processing a Contentful webhook if there is a conflict, as the request time will increase with these.

We accept a risk that a large quantity of concurrent requests could exhaust our number of retries (we have configured the application to retry 3 times) as we assume that concurrency issues are unlikely to exceed more than a couple of items.
