import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import working_actors

pub fn main() -> Nil {
  let urls = [
    "https://google.com",
    "https://youtube.com",
    "https://facebook.com",
    "https://instagram.com",
    "https://chatgpt.com",
    "https://x.com",
    "https://whatsapp.com",
    "https://reddit.com",
    "https://wikipedia.org",
    "https://amazon.com",
    "https://pagethatdoesnotexist.org",
  ]

  working_actors.spawn_workers(5, urls, get_url)
  |> list.each(fn(page_response) {
    case page_response {
      Ok(r) ->
        io.println(
          r.url
          <> ": "
          <> int.to_string(string.length(r.page_response.body))
          <> " characters",
        )
      Error(url) -> io.println("Error retrieving " <> url)
    }
  })
}

type PageResponse {
  PageResponse(url: String, page_response: response.Response(String))
}

fn get_url(url: String) -> Result(PageResponse, String) {
  use req <- result.try(request.to(url) |> result.replace_error(url))

  use resp <- result.map(
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.dispatch(req)
    |> result.replace_error(url),
  )

  PageResponse(url, resp)
}
