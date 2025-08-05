# working_actors

[![Package Version](https://img.shields.io/hexpm/v/working_actors)](https://hex.pm/packages/working_actors)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/working_actors/)

```sh
gleam add working_actors@1
```

Below is a sample program which spawns 5 workers to call the `noisy_sleep`
function. This function simulates workers by sleeping for the number of
milliseconds in the argument. The function also announces when it starts,
when it stops, and what the process id of the actor that is running it is.

```gleam
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
```

Further documentation can be found at <https://hexdocs.pm/working_actors>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
