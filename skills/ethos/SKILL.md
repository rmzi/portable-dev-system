---
description: Grounding in core development principles. Use when starting significant work, feeling stuck, or needing to reset decision-making clarity.
---
# /ethos — Core Development Principles

> Understand · Build · Validate

When invoked, remind of these principles. Use as grounding before significant work.

## The Eight Principles

### 1. Understand Before You Act
Read existing code before modifying. Map the territory before changing it.
> "Weeks of coding can save hours of planning."

### 2. Small, Reversible Steps
Atomic commits. Small PRs. Refactor before adding.
> "Make the change easy, then make the easy change." — Kent Beck

### 3. Tests as Specification
Tests document intent. Code documents implementation.

### 4. Explicit Over Implicit
Declare dependencies. Name things for what they do. Configuration over invisible convention.

### 5. Optimize for Change
Code is read 10x more than written. Coupling is the enemy. Delete freely.

### 6. Fail Fast, Recover Gracefully
Validate at boundaries. Crash on programmer errors. Handle user errors.

### 7. Automation as Documentation
Scripts encode knowledge. CI runs what developers run. Automate the repeated.

### 8. Portability of Operation
Detect the runtime's capabilities before relying on them. Degrade gracefully when a tool, agent type, or state path is missing — never hard-fail on an assumption the platform didn't promise. Where context lives, which tools exist, how the session was launched: none of it should decide whether the work gets done.

## When Stuck

1. What problem am I actually solving?
2. What's the simplest thing that could work?
3. What would I do if I had to delete this in a month?
4. Am I building for today or for imaginary tomorrow?

## MECE — Structure for Clarity

**Mutually Exclusive** (no overlap) + **Collectively Exhaustive** (no gaps). Apply everywhere:

| Domain | MECE means |
|--------|-----------|
| **Skills** | Each skill has one clear purpose, no overlap |
| **Functions** | Each function does one thing, responsibilities don't overlap |
| **Architecture** | Components have clear, non-overlapping responsibilities |
| **Documentation** | Each topic in one place |
