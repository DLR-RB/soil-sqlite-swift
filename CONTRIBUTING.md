# Contributing to SOIL Core (Swift)

Thank you for considering a contribution to SOIL Core in Swift. All contributions - large and small - are valuable.
This document explains how to contribute and the agreements that apply to contributions.

## Where contributions come from

This project is developed as part of DLR — GSOC (German Space Operations Center, [DLR](https://www.dlr.de/)).
In addition to external community contributions, parts of the codebase may be contributed from
other SOIL repositories. For external contributors the process below applies; for in-repo
DLR contributors, the same standards apply but no separate agreement is required.

## How to contribute

1. **Small changes** — feel free to open a pull request directly for documentation fixes,
   small bug fixes, or clarifications.
2. **Large or behavioural changes** — please open an *issue* first to describe the proposal, or
   start a discussion in an existing issue. This avoids duplicated work and ensures the change
   aligns with the SOIL design before you spend time implementing it.
3. **Questions** — use the issue tracker. It keeps the conversation searchable for others.

### Setting up locally

```sh
swift build   # compile the library
swift test    # run the test suite (recommended before opening a pull request)
```

### Opening a pull request

- Keep the change focused; make one logical change per pull request.
- Add or update tests to cover the change. The CI runs `swift test`, and tests that don't pass
  will block the merge.
- Follow the existing code style.
- Update the [`Readme.md`](Readme.md) if the change affects the public API or usage examples.
- Write a clear, descriptive pull request title and body explaining **what** changed and
  **why**.
- If the change introduces a public API addition, document it with DocC-style comments.

## Contributor license agreement

Because contributions may come from many individuals and be combined into a larger project, we
ask every contributor to sign the **SOIL Individual Contributor Agreement** before a pull
request can be merged:

- [SOIL Individual Contributor Agreement.pdf](SOIL%20Individual%20Contributor%20Agreement.pdf)

Please fill out, sign, and submit the agreement (e.g. send it to the repository maintainer).
A signed agreement ensures that your contribution can be legally distributed under the MIT
license while you retain ownership of your work. Once the agreement is on file, contributions
to this repository are covered and can be merged without per-pull approval on licensing.

This is a *contributor license agreement* (it transfers license rights, not copyright) — you
keep the copyright to your work; you grant the project permission to use and distribute it.

## License

By contributing to this repository, you agree that your contributions are licensed under the
[MIT License](LICENSE.txt).

## Acknowledgements

This work follows the contributing practices of the broader SOIL project. See the
[SOIL documentation repository](https://github.com/DLR-RB/soil-documentation) for the
underlying concepts.
