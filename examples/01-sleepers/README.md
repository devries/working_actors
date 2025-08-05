# Sample spawning Workers

This sample spawns a group of 5 workers. Each worker will run the `noisy_sleep`
function with an argument specified in the `l` list which is the number of
milliseconds to sleep.

Each worker will indicate how long it will sleep and when it has finished
sleeping along with the process id of the actor running it.

## Development

```sh
gleam run   # Run the sample
```
