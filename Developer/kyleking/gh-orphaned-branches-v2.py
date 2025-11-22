#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich>=13.7.0",
#     "python-dateutil>=2.8.2",
# ]
# ///
"""
Find orphaned branches across GitHub repositories (v2 - Refactored).

This script identifies:
1. Branches that still exist after their PR was closed/merged
2. Branches without any associated PR (optionally filtered by age)

Usage:
    uv run gh-orphaned-branches-v2.py --namespace USERNAME
    uv run gh-orphaned-branches-v2.py -n ORG --stale-days 5
    uv run gh-orphaned-branches-v2.py -n USER --output json
"""

import sys
from pathlib import Path

# Add package to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from gh_orphaned_branches.cli import main

if __name__ == "__main__":
    main()
