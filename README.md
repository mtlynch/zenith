# eth-zvm

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/mtlynch/eth-zvm/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/mtlynch/eth-zvm/tree/master)
[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](LICENSE)

An implementation of the Ethereum virtual machine in pure Zig.

## Scope

For now, this is a just-for-fun experiment to learn more about Zig and Ethereum.

## Run VM

Run with maximum performance:

```bash
$ echo '60016000526001601ff3' | xxd -r -p | zig build run -Doptimize=ReleaseFast
EVM gas used:    18
execution time:  56.443µs
0x01
```

Run in debug mode:

```bash
$ echo '60016000526001601ff3' | xxd -r -p | zig build run
debug: PUSH1 0x01
debug:   Stack: push 0x1
debug: ---
debug: PUSH1 0x00
debug:   Stack: push 0x0
debug: ---
debug: MSTORE
debug:   Stack: pop 0x0
debug:   Stack: pop 0x1
debug:   Memory: Writing value=0x1 to memory offset=0
debug:   Memory: 0x00000000000000000000000000000001
debug: ---
debug: PUSH1 0x01
debug:   Stack: push 0x1
debug: ---
debug: PUSH1 0x1f
debug:   Stack: push 0x1f
debug: ---
debug: RETURN
debug:   Stack: pop 0x1f
debug:   Stack: pop 0x1
debug:   Memory: reading size=1 bytes from offset=31
debug:   Return value: 0x01
debug: ---
EVM gas used:    18
execution time:  688.900µs
0x01
```

## Run unit tests

```bash
zig build test --summary all
```
