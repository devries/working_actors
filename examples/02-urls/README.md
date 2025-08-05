# URL retrieval sample

This sample takes a list of URLs to retrieve and spawns 5 worker processes to
retrieve them using the `get_url` function. The `get_url` function returns the
retrieved URL as well as the full response object. Note that the returned
values are not necessarily in the same order as the urls appear in the task
list.

After each retrieval the length of characters for the response to each url is
returned, or an error is returned if the retrieval was unsuccessful.

## Development

```sh
gleam run   # Run the project
```
