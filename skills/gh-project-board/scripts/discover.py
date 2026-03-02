#!/usr/bin/env python3
"""Discover available tasks from a GitHub Project board.

Usage:
    gh project item-list <num> --owner <owner> --limit 100 --format json | \
        python3 discover.py --platform iOS --status Todo --unlocked

    gh project item-list <num> --owner <owner> --limit 100 --format json | \
        python3 discover.py --agent-owner "iOS Agent" --was-blocked
"""

import json
import sys
import argparse


def main():
    parser = argparse.ArgumentParser(description="Discover tasks from GitHub Projects")
    parser.add_argument("--platform", help="Filter by platform (e.g., iOS, Android, Web, Backend)")
    parser.add_argument("--status", help="Filter by status (e.g., Todo, In Progress, Done)")
    parser.add_argument("--unlocked", action="store_true", help="Only show unlocked tasks")
    parser.add_argument("--unowned", action="store_true", help="Only show tasks with no agent owner")
    parser.add_argument("--agent-owner", help="Filter by agent owner name")
    parser.add_argument("--was-blocked", action="store_true", help="Show previously blocked tasks that are now unblocked")
    parser.add_argument("--priority", help="Filter by priority (P0, P1, P2)")
    parser.add_argument("--format", choices=["table", "json", "ids"], default="table", help="Output format")
    args = parser.parse_args()

    data = json.load(sys.stdin)
    items = data.get("items", [])
    results = []

    for item in items:
        status = item.get("status", "")
        platform = item.get("platform", "")
        lock = item.get("execution Lock", "") or item.get("executionLock", "")
        agent_owner = item.get("agent Owner", "") or item.get("agentOwner", "")
        blocked = item.get("blocked", "")
        priority = item.get("priority", "")
        number = item.get("content", {}).get("number", "")
        title = item.get("title", "")
        item_id = item.get("id", "")

        # Apply filters
        if args.status and status != args.status:
            continue
        if args.platform and platform != args.platform:
            continue
        if args.unlocked and lock == "Locked":
            continue
        if args.unowned and agent_owner:
            continue
        if args.agent_owner and agent_owner != args.agent_owner:
            continue
        if args.was_blocked and blocked != "No":
            continue
        if args.was_blocked and status != "In Progress":
            continue
        if args.priority and priority != args.priority:
            continue

        results.append({
            "number": number,
            "title": title,
            "item_id": item_id,
            "status": status,
            "platform": platform,
            "priority": priority,
            "blocked": blocked,
            "lock": lock,
            "agent_owner": agent_owner,
        })

    # Sort by priority: P0 > P1 > P2 > unset
    priority_order = {"P0": 0, "P1": 1, "P2": 2}
    results.sort(key=lambda x: priority_order.get(x["priority"], 99))

    if args.format == "json":
        print(json.dumps(results, indent=2))
    elif args.format == "ids":
        for r in results:
            print(f"{r['number']}\t{r['item_id']}")
    else:
        if not results:
            print("No tasks found matching criteria.")
            return

        print(f"Found {len(results)} task(s):\n")
        print(f"{'#':>5} | {'Priority':>8} | {'Status':>12} | {'Blocked':>7} | {'Lock':>8} | Title")
        print("-" * 90)
        for r in results:
            print(
                f"#{r['number']:>4} | {r['priority'] or '—':>8} | {r['status']:>12} | "
                f"{r['blocked'] or '—':>7} | {r['lock'] or '—':>8} | {r['title'][:40]}"
            )


if __name__ == "__main__":
    main()
