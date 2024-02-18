# eth-zvm

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/mtlynch/eth-zvm/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/mtlynch/eth-zvm/tree/master)
[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](LICENSE)

An implementation of the Ethereum virtual machine in pure Zig.

## Scope

For now, this is a just-for-fun experiment to learn more about Zig and Ethereum.

## Run VM

```bash
$ echo '60016000526001601ff3' | xxd -r -p | zig build run
EVM gas used:    18
execution time:  351.821µs
0x01
```

In verbose mode:

```bash
$ echo '60016000526001601ff3' | xxd -r -p | zig build run -- -v
PUSH1 0x01
  Stack: push 0x01
---
PUSH1 0x00
  Stack: push 0x00
---
  Stack: pop 0x00
  Stack: pop 0x01
MSTORE offset=0, value=1
  Memory: 0x00000000000000000000000000000001
---
PUSH1 0x01
  Stack: push 0x01
---
PUSH1 0x1f
  Stack: push 0x1f
---
  Stack: pop 0x1f
  Stack: pop 0x01
RETURN offset=31, size=1
  Return value: 0x01
---
EVM gas used:    18
execution time:  830.530µs
0x01
```

For max speed:

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
