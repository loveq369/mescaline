#!/bin/bash

args="-XScopedTypeVariables"
ghci-6.12.3 $args -Iinclude -isrc -idist/build/autogen -hide-package transformers -hide-package monads-tf
