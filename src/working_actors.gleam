import gleam/dict
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string

pub fn main() -> Nil {
  url_test()
  time_test()
}

pub fn time_test() -> Nil {
  let l = [5000, 10_000, 5000, 10_000, 2000]

  let responded = spawn_workers(5, l, noisy_sleep)
  io.println("Number of responses: " <> int.to_string(list.length(responded)))
}

pub fn noisy_sleep(i: Int) -> Nil {
  io.println(
    "Starting sleep for "
    <> int.to_string(i)
    <> " seconds. Pid: "
    <> string.inspect(process.self()),
  )
  process.sleep(i)
  io.println(
    "Ending sleep for "
    <> int.to_string(i)
    <> " seconds. Pid: "
    <> string.inspect(process.self()),
  )
}

pub fn url_test() -> Nil {
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

  spawn_workers(5, urls, get_url)
  |> list.each(fn(page_response) {
    case page_response {
      Ok(r) ->
        io.println(
          r.url <> ": " <> int.to_string(string.length(r.page_response.body)),
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

// pub fn 
//
// Worker Process
//

pub type WorkerMessage(a, b) {
  DoWork(input: a, reply_to: process.Subject(ResponseMessage(b)))
  Shutdown
}

pub fn worker_handle_message(
  state: fn(a) -> b,
  message: WorkerMessage(a, b),
) -> actor.Next(fn(a) -> b, WorkerMessage(a, b)) {
  case message {
    DoWork(input, reply_to) -> {
      let reply = state(input)
      actor.send(reply_to, SubmitWork(reply, process.self()))
      actor.continue(state)
    }
    Shutdown -> actor.stop()
  }
}

pub type ResponseMessage(b) {
  SubmitWork(fn_respose: b, pid: process.Pid)
}

//
// Worker Functionality
//

pub fn spawn_workers(
  n_workers: Int,
  tasks: List(a),
  work_function: fn(a) -> b,
) -> List(b) {
  let workers =
    list.range(1, n_workers)
    |> list.map(fn(_) {
      actor.new(work_function)
      |> actor.on_message(worker_handle_message)
      |> actor.start
      |> result.map(fn(started) { #(started.pid, started.data) })
    })
    |> result.values
    |> dict.from_list

  let idle_workers = workers |> dict.values

  use_workers(tasks, workers, idle_workers, [], process.new_subject())
}

pub fn use_workers(
  tasks: List(a),
  workers: dict.Dict(process.Pid, process.Subject(WorkerMessage(a, b))),
  idle_workers: List(process.Subject(WorkerMessage(a, b))),
  function_responses: List(b),
  reply_to: process.Subject(ResponseMessage(b)),
) -> List(b) {
  // io.println("Task List Length: " <> int.to_string(list.length(tasks)))
  // io.println(
  //   "Idle Worker List Length: " <> int.to_string(list.length(idle_workers)),
  // )
  // io.println("Workers Running: " <> int.to_string(dict.size(workers)))
  // io.println("")

  case tasks, idle_workers, dict.size(workers) {
    [first_task, ..rest_tasks], [first_worker, ..rest_workers], _ -> {
      actor.send(first_worker, DoWork(first_task, reply_to))
      use_workers(
        rest_tasks,
        workers,
        rest_workers,
        function_responses,
        reply_to,
      )
    }
    [], [first_worker, ..rest_workers], _ -> {
      actor.send(first_worker, Shutdown)
      let new_workers =
        dict.filter(workers, keeping: fn(_, v) { v != first_worker })
      use_workers([], new_workers, rest_workers, function_responses, reply_to)
    }
    [first_task, ..rest_tasks], [], _ -> {
      case process.receive_forever(reply_to) {
        SubmitWork(fn_response, pid) -> {
          let assert Ok(worker_subject) = dict.get(workers, pid)
          actor.send(worker_subject, DoWork(first_task, reply_to))
          use_workers(
            rest_tasks,
            workers,
            [],
            [fn_response, ..function_responses],
            reply_to,
          )
        }
      }
    }
    [], [], 0 -> function_responses
    [], [], _ -> {
      case process.receive_forever(reply_to) {
        SubmitWork(fn_response, pid) -> {
          let assert Ok(worker_subject) = dict.get(workers, pid)
          actor.send(worker_subject, Shutdown)
          let new_workers = dict.delete(workers, pid)
          use_workers(
            [],
            new_workers,
            [],
            [fn_response, ..function_responses],
            reply_to,
          )
        }
      }
    }
  }
}
