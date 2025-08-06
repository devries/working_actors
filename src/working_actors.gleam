//// working_actors is a simple library for spawning a group of actors
//// as workers to run a specific function with one of a list of input
//// arguments and collect the function output into a new list.
////
//// Note that the output list is not necessarily in the same order as
//// the input list, so if it is necessary you should return a record with
//// both the input argument and the output from the worker function.
////

import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/result

//
// Worker Process
//

type WorkerMessage(a, b) {
  DoWork(input: a, reply_to: process.Subject(ResponseMessage(b)))
  Shutdown
}

fn worker_handle_message(
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

type ResponseMessage(b) {
  SubmitWork(fn_respose: b, pid: process.Pid)
}

//
// Worker Functionality
//

/// Spawn `n_workers` worker processes, each ready to run the work
/// function `work_function`. A list of arguments to the `work_function`
/// is provided as the `tasks` list. The functions will be called in
/// parallel until the `work_function` has been run with every argument
/// in the `tasks` list. A new list of the function return values will
/// be returned when all the tasks have run. This list will be in an
/// arbitrary order.
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

fn use_workers(
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
    _, _, 0 -> function_responses
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
