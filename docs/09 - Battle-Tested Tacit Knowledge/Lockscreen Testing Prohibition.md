---
title: Lockscreen Testing Prohibition
tags: [trap, lockscreen, pam, security, authentication]
---

# Lockscreen Testing Prohibition: Preserving PAM Session State

An invariant engineering rule for automated scripts and developer test suites: **Never autonomously test or invoke the lockscreen (`Lock.qml`).**

---

## 1. Root Cause: PAM Session Desynchronization

`Lock.qml` interfaces directly with Linux **PAM (Pluggable Authentication Modules)** to handle session security and user password verification.

- When an automated script or background agent spawns the lockscreen in a non-interactive shell, PAM creates an unconfirmed session lock descriptor.
- Because no human is present to type credentials into the physical TTY device, PAM session descriptors become desynchronized from the display manager.
- When the human user returns and inputs their valid password, PAM fails to validate the corrupted session state. The graphical session remains locked, forcing a hard power cycle or TTY kill.

---

## 2. Operational Rule
Lockscreen modifications must only be evaluated via non-locking visual mockups or verified directly by the human user.

## Related Nodes
- [[Intel GPU Ring Buffer Trap]]
- [[Emergency Recovery Protocol]]
