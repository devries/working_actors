import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import working_actors

pub fn main() -> Nil {
  let l = [5000, 10_000, 5000, 10_000, 2000]

  let responded = working_actors.spawn_workers(5, l, noisy_sleep)
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
