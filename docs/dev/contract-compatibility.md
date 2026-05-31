# Contract Compatibility Policy

The MVP Skir contract is intentionally unversioned.

## Rule

Breaking contract changes are only allowed when backend and frontend adaptations are delivered in the same PR.

## Required when changing `skir-src/*.skir`

- Update contract source files in `skir-src/`.
- Update or verify the contract snapshot file `skir-snapshot.txt`.
- Ensure corresponding server driver mapping changes are included.
- Ensure corresponding frontend request/query/mutation changes are included in the same PR.

## Review Checklist

- Is this a breaking change for existing request/response shapes?
- If yes, are backend and frontend adaptations included together?
- Did contract snapshot check pass?
