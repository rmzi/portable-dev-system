---
description: Core development principles for grounding before significant work
---
# /ethos — Core Development Principles

> ╔══════════════════════════════════╗
> ║  Understand · Build · Validate  ║
> ╚══════════════════════════════════╝

When invoked, remind of these principles. Use as grounding before significant work.

## The Seven Principles

### 1. Understand Before You Act
Read existing code before modifying. Map the territory before changing it.
> "Weeks of coding can save hours of planning."

### 2. Small, Reversible Steps
Atomic commits. Small PRs. Refactor before adding.
> "Make the change easy, then make the easy change." — Kent Beck

### 3. Tests as Specification
Tests document intent. Code documents implementation.
> "Legacy code is code without tests." — Michael Feathers

### 4. Explicit Over Implicit
Declare dependencies. Name things for what they do. Configuration over invisible convention.
> "Explicit is better than implicit." — Zen of Python

### 5. Optimize for Change
Code is read 10x more than written. Coupling is the enemy. Delete freely.
> "The only constant is change." — Heraclitus

### 6. Fail Fast, Recover Gracefully
Validate at boundaries. Crash on programmer errors. Handle user errors.
> "Errors should never pass silently." — Zen of Python

### 7. Automation as Documentation
Scripts encode knowledge. CI runs what developers run. Automate the repeated.
> "If it hurts, do it more frequently." — Martin Fowler

## When Stuck

1. What problem am I actually solving?
2. What's the simplest thing that could work?
3. What would I do if I had to delete this in a month?
4. Am I building for today or for imaginary tomorrow?

## The Unix Way

- Write programs that do one thing well
- Write programs to work together
- Write programs that handle text streams
- Small is beautiful
- Clarity over cleverness

## MECE — Structure for Clarity

**Mutually Exclusive** (no overlap) + **Collectively Exhaustive** (no gaps). Apply everywhere:

| Domain | MECE means |
|--------|-----------|
| **Skills** | Each skill has one clear purpose, no overlap |
| **Functions** | Each function does one thing, responsibilities don't overlap |
| **Architecture** | Components have clear, non-overlapping responsibilities |
| **Documentation** | Each topic in one place |

### Anti-patterns

- Two functions that partially do the same thing
- A service that handles "everything related to X and also some Y"
- Documentation split across multiple places with overlap
- Error handling scattered with duplicate catch blocks

> "A place for everything, and everything in its place."
