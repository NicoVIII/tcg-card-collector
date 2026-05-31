# Development Overview

This repository follows a monorepo layout inspired by full-house.

## Areas

- server: Gleam backend
- client-web: SolidJS frontend
- skir-src: contract definitions
- deploy: deployment and operations helpers

## Delivery Rule

Implement one vertical slice at a time.
A slice is done only when checks are green and the feature works end-to-end.
