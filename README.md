# eth-zvm

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/mtlynch/eth-zvm/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/mtlynch/eth-zvm/tree/master)
[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](LICENSE)

An implementation of the Ethereum virtual machine in pure Zig.

## Scope

For now, this is a just-for-fun experiment to learn more about Zig and Ethereum.

## Run VM

Run basic operation:

```bash
$ echo '60016000526001601ff3' | xxd -r -p | zig build run
EVM gas used:    18
execution time:  351.821µs
0x01
```

Run in verbose mode:

```bash
$ echo '60016000526001601ff3' | xxd -r -p | zig build run -- -v
PUSH1 0x01
  Stack: push 0x1
---
PUSH1 0x00
  Stack: push 0x0
---
MSTORE
  Stack: pop 0x0
  Stack: pop 0x1
  Memory: Writing value=0x1 to memory offset=0
  Memory: 0x00000000000000000000000000000001
---
PUSH1 0x01
  Stack: push 0x1
---
PUSH1 0x1f
  Stack: push 0x1f
---
RETURN
  Stack: pop 0x1f
  Stack: pop 0x1
  Memory: reading size=1 bytes from offset=31
  Return value: 0x01
---
EVM gas used:    18
execution time:  700.022µs
0x01
```

Run with maximum performance:

```bash
$ echo '60016000526001601ff3' | xxd -r -p | zig build run -Doptimize=ReleaseFast
EVM gas used:    18
execution time:  56.443µs
0x01
```

## Run unit tests

```bash
zig build test --summary all
```
