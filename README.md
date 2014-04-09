# TDI

Test Driven Infrastructure acceptance helpers for validating your deployed
infrastructure and external dependencies.

## Installation

Add this line to your application's Gemfile:

    gem 'tdi'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tdi

## Usage

    $ tdi -h

Usage:

    tdi [options] test_plan_file

Examples:

    tdi tdi.json
    tdi --plan admin tdi.json
    tdi --plan admin::acl tdi.json
    tdi -p admin::acl,admin::file tdi.json
    tdi --nofail tdi.json
    tdi --shred tdi.json
    tdi -v tdi.json
    tdi -vv tdi.json
    tdi -vvv tdi.json

Options:

    -n, --nofail       No fail mode.
    -p, --plan         Test plan list.
    -s, --shred        Wipe out the test plan, leaving no trace behind.
    -v, --verbose      Verbose mode.
    -h, --help         Display this help message.
