# Contenful Listener API

An application that keeps content managed in a [Contentful][] CMS instance in-sync with the GOV.UK Publishing API. It listens for Contentful webhooks and updates GOV.UK content accordingly.

[Contentful]: https://www.contentful.com/

## Technical documentation

This application is built using the [Sinatra](https://sinatrarb.com/) microframework for Ruby HTTP applications.

You can use the [GOV.UK Docker environment](https://github.com/alphagov/govuk-docker) to run the application and its tests with the GOV.UK dependencies. Follow [the usage instructions](https://github.com/alphagov/govuk-docker#usage) to get started.

### Running the test suite

```
bundle exec rake
```

### Running the app with Contentful

While you can run this app with GOV.UK Docker in the regular way, this doesn't integrate with Contentful so will be of limited use. To use this application locally with a Contentful instance you will need to do some additional configuration both locally and in Contentful.

In Contentful you need to [create API access tokens][access-tokens] for the spaces you need to access (see [access_tokens configuration](config/access_tokens.yaml.erb) for the space ids and environment variable names). You should scope the access token to a [sandbox environment][] you have created to avoid changing any of the live content.

You then need software that can expose your local application to the public internet, so that Contentful can communicate with it. [Ngrok](https://ngrok.com/) is a good option.

You can then start the application with GOV.UK Docker:

```
$ govuk-docker run -p 9292:9292 \
-e CONTENTFUL_ENVIRONMENT=<environment name> \
-e <environment variable prefix for your space>_DRAFT_ACCESS_TOKEN=<draft access token> \
-e <envrionment variable prefix for your space>_LIVE_ACCESS_TOKEN=<live access token> \
contentful-listener-api-app \
bundle exec puma
```

You can then expose this to the internet with `$ ngrok http 9292`. This will output a forwarding URL.

To complete the set-up you need to [create a webhook][] in Contentful and point it to send POST requests to the /listen path of your forwarding URL.

You should then see requests come through when you make changes in the Contentful UI. You can see a log of the attempts to call the endpoint in the Contentful web interface with the webhook settings.

Once complete you should go into the Contentful web interface and delete your webhook, your sandbox environment and your access token.

[access-tokens]:https://www.contentful.com/developers/docs/references/authentication/#the-content-delivery-and-preview-api
[sandbox environment]: https://www.contentful.com/developers/docs/concepts/multiple-environments/
[create a webhook]: https://www.contentful.com/developers/docs/concepts/webhooks/#create-and-configure-a-webhook

## Further documentation

- [How this application works](docs/how-this-application-works.md)
- [Configuring a content item](docs/configuring-a-content-item.md)
- [Integration limitations](docs/integration-limitations.md)
- [Architectural decision records](docs/adr)

## Licence

[MIT License](LICENCE)
