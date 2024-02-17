# eth-zvm

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/mtlynch/eth-zvm/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/mtlynch/eth-zvm/tree/master)
[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](LICENSE)

An implementation of the Ethereum virtual machine in pure Zig.

## Scope

For now, this is a just-for-fun experiment to learn more about Zig and Ethereum.

## Run VM

```bash
echo '60016000526001601ff3' | xxd -r -p | zig build run
```

In verbose mode:

```bash
echo '60016000526001601ff3' | xxd -r -p | zig build run -- -v
```

For max speed:

```bash
echo '60016000526001601ff3' | xxd -r -p | zig build run -Doptimize=ReleaseFast
```

## Run unit tests

```bash
zig build test --summary all
```
