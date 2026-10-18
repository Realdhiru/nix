---
title: Why This Repository Uses Flakes
tags: [nix, flakes, repository-decision]
---

# Why This Repository Uses Flakes

This system uses `flake.nix` and the checked-in `flake.lock` as the source of its Nix inputs. This keeps the host's package and module inputs reviewable alongside its configuration.

The lockfile makes input revisions explicit; it does not make hardware, mutable home-directory data, or every build outcome identical across machines. Flakes also add a learning and maintenance cost, which is accepted here to keep the system configuration and its inputs together.

Do not use channel updates as the system's input update path. Review changes to `flake.lock` and run the repository rebuild workflow documented in [[Root Flake Topology]].

General flake mechanics are documented in the separate `nix-brain` vault's [[Flakes and Inputs]].
