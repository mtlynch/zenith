# eth-zvm

An implementation of the Ethereum virtual machine in pure Zig.

## Scope

For now, this is a just-for-fun experiment to learn more about Zig and Ethereum.

## Comparing to other implementations

```bash
$ ./evm run --code '60016000526001601ff3' --statdump
EVM gas used:    18
execution time:  130.547µs
allocations:     29
allocated bytes: 3560
0x01
```
