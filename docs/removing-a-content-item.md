# Removing a content item

If you need to remove an item from GOV.UK that was published using this application there is a rake task you can use. However before running it you should remove the configuration for the content item from [config/content_items.yaml](../config/content_items.yaml) and deploy - otherwise any edits in Contentful would cause the content to re-appear.

Once the configuration is removed you can run the rake task with

```
bundle exec rake content_item:unpublish[<content_id>, <locale, defaults to "en">]
```

This will cause GOV.UK to return a 410 (Gone) status code when attempting to access the content.

This unpublishing can be a customised in a number of ways:

- You can provide an explanation on the page explaining the content is gone: `bundle exec rake content_item:sync[31681f08-9e4d-4709-b995-840a695ed54c] EXPLANATION='This content was removed due to it being published in error'`

- You can replace the change with a redirect: `bundle exec rake content_item:sync[31681f08-9e4d-4709-b995-840a695ed54c] TYPE=redirect URL=/new-destination`
- You can replace the change with a 404 response: `bundle exec rake content_item:sync[31681f08-9e4d-4709-b995-840a695ed54c] TYPE=vanish`
