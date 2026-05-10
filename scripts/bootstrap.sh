#!/bin/zsh
set -euo pipefail

swift build
swift run cybermac init-home
swift run cybermac doctor
