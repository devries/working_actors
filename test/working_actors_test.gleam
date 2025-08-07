import gleam/erlang/process
import gleam/order
import gleam/time/duration
import gleam/time/timestamp
import gleeunit
import working_actors

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn two_tasks_sequentially_test() {
  let start = timestamp.system_time()
  let _ =
    working_actors.spawn_workers(1, [10, 10], fn(sleep_time) {
      process.sleep(sleep_time)
      Nil
    })
  let end = timestamp.system_time()

  assert duration.compare(
      timestamp.difference(start, end),
      duration.milliseconds(15),
    )
    == order.Gt
}

pub fn two_tasks_simultaneously_test() {
  let start = timestamp.system_time()
  let _ =
    working_actors.spawn_workers(2, [10, 10], fn(sleep_time) {
      process.sleep(sleep_time)
      Nil
    })
  let end = timestamp.system_time()

  assert duration.compare(
      timestamp.difference(start, end),
      duration.milliseconds(15),
    )
    == order.Lt
}
