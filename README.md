## Synopsis

This project provides extension classes for **Dave WoodCom's XCGLogger**.

## Notice

This repository was created to share the idea with **Dave WoodCom**. Hopefully these features will become part of next version of the original **XCGLogger** implementation. **When this happens, this repository will be removed from github.**

## Motivation

There are few disadvantages to original Dave WoodCom's XCGLogger implementation:
- Multiple loggers configured to log to same file will lead to non-ordered log file. Each logger uses its own FileHandle class that has internal caching.
- Automatic rolling of log files is not available.

## Installation

Use carthage to embed this into your project

## API Reference

Main features are:
- XCGLoggerFactory capable of instantianting XCGLogger objects based on JSON configuration.
- OrderedFileDestination class - enables multiple logger instances to share single FileHandle and thus log into same file in ordered manner.
- RollFileDestination class - enables multiple logger instances to log into single FileHandle with automatic file rolling based on provided configuration. 

## License

MIT, see LICENSE.txt

