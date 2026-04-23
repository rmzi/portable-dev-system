# Todo CLI

A tiny todo-list command-line tool. Built for PDS integration testing — small enough to grok in one pass, real enough to grill on.

## Usage

```bash
python -m src.todo add "Buy milk"
python -m src.todo list
python -m src.todo remove 0
```

## Running tests

```bash
pytest
```

## Notes

- No persistence layer yet — todos live in memory, lost on exit.
- No validation on add (empty strings accepted).
- `list` output format is ad-hoc.
