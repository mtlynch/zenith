# zenith

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/mtlynch/zenith/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/mtlynch/zenith/tree/master)
[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](LICENSE)

An implementation of the Ethereum virtual machine in pure Zig.

## Project status

- [x] Execute basic EVM bytecode
- [ ] Support [EVMC interface](https://github.com/ethereum/evmc)
- [ ] Support all Ethereum opcodes (currently: [19 of 144](src/evm/opcodes.zig) supported)
- [ ] Support precompiled contracts
- [ ] Run [official Ethereum tests](https://github.com/ethereum/tests)

## Scope

For now, this is a just-for-fun experiment to learn more about Zig and Ethereum.

## Run VM

Run with maximum performance:

```bash
$ echo '60015f526001601ff3' | xxd -r -p | zig build run -Doptimize=ReleaseFast
EVM gas used:    17
execution time:  36.685µs
0x01
```

Run in debug mode:

```bash
$ echo '60015f526001601ff3' | xxd -r -p | zig build run
debug: PUSH1 0x01
debug:   Stack: push 0x01
debug:   Gas consumed: 3
debug: ---
debug: PUSH0
debug:   Stack: push 0x00
debug:   Gas consumed: 5
debug: ---
debug: MSTORE
debug:   Stack: pop 0x00
debug:   Stack: pop 0x01
debug:   Memory: Writing value=0x1 to memory offset=0
debug:   Gas consumed: 11
debug: ---
debug: PUSH1 0x01
debug:   Stack: push 0x01
debug:   Gas consumed: 14
debug: ---
debug: PUSH1 0x1f
debug:   Stack: push 0x1f
debug:   Gas consumed: 17
debug: ---
debug: RETURN
debug:   Stack: pop 0x1f
debug:   Stack: pop 0x01
debug:   Memory: reading size=1 bytes from offset=31
debug:   Return value: 0x01
debug:   Gas consumed: 17
debug: ---
EVM gas used:    17
execution time:  611.780µs
0x01
```

## Run unit tests

```bash
zig build test --summary all
```
