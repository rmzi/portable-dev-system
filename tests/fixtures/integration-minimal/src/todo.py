"""Tiny in-memory todo list."""

from __future__ import annotations

import sys


class TodoList:
    def __init__(self) -> None:
        self._items: list[str] = []

    def add(self, item: str) -> None:
        self._items.append(item)

    def remove(self, index: int) -> str:
        return self._items.pop(index)

    def list(self) -> list[str]:
        return list(self._items)


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if not argv:
        print("usage: todo {add TEXT | remove INDEX | list}")
        return 1

    todos = TodoList()
    cmd, *rest = argv
    if cmd == "add":
        todos.add(" ".join(rest))
    elif cmd == "remove":
        todos.remove(int(rest[0]))
    elif cmd == "list":
        for i, item in enumerate(todos.list()):
            print(f"{i}: {item}")
    else:
        print(f"unknown command: {cmd}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
