# eth-zvm

An implementation of the Ethereum virtual machine in pure Zig.

## Scope

For now, this is a just-for-fun experiment to learn more about Zig and Ethereum.

## Run VM

```bash
zig build run
```

In verbose mode:

```bash
zig build run -- -v
```

For max speed:

```bash
zig build run -Doptimize=ReleaseFast
```

## Run unit tests

```bash
zig build test --summary all
```
