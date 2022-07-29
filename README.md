# Contenful Listener

This is some experimental/pseudo code of how we could populate GOV.UK Publishing API in response to [Contentful webhooks](https://www.contentful.com/developers/docs/concepts/webhooks/).

There's some bare bones of a potential system in app.rb and some example stuff in lib/test-script.rb

The rough idea I have is:

* We adjust the special route schema to accept any JSON (or create a new accept any JSON schema)
* We adjust the Publishing API to associate a content item with an array of ids - these will represent Contentful ids of components
* We listen for all changes on Contentful webhooks
* When an entity is changed/published/deleted we query the Publishing API to see if there is a content item that uses that ID
* If so we look-up the root entity and rebuild the model
* We then update the Publishing API
