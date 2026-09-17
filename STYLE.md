# Code standards

Swift and Apple platform conventions for this project. Follow the
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
first; everything below either reinforces or narrows them.

## Comments

Code carries its own explanation. Name things so that a comment is unnecessary, then
don't write the comment.

- No narrative or rationale comments
- No doc comments restating what a signature already says
- `// MARK: -` to divide a file into sections is the one accepted form
- If a line genuinely cannot be understood without prose, that is a signal to rename or
  restructure it, not to annotate it

## Naming

- Clarity beats brevity, but omit needless words
- Methods read as sentences at the call site: `manager.pause(for: 1800)`
- Booleans read as assertions: `isResting`, `allowSkip`
- No abbreviations except those Apple itself uses (`min`, `max`, `URL`)
- Types are nouns, mutating methods are verbs, non-mutating ones are past participle or
  `-ing` forms

## Types and access

- `private` by default; widen only when something outside needs it
- `final` on classes unless subclassing is deliberate
- Structs and enums over classes unless identity or reference semantics are required
- `private(set)` for state a type owns but others may read
- Prefer `let`

## Optionals and failure

- No force unwrapping (`!`) and no force try in shipped paths
- No implicitly unwrapped optionals
- `guard` for early exit; keep the happy path unindented

## Concurrency

- The project builds in Swift 6 language mode with `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`; assume main-actor isolation unless a type states otherwise
- Prefer structured concurrency (`Task`, `async`/`await`) over callbacks and timers
- No `MainActor.assumeIsolated` to silence a warning — fix the isolation instead
- A `deinit` cannot touch main-actor state; design so cleanup isn't needed there

## SwiftUI

- A `body` that doesn't fit on a screen is too long; break it into private computed
  properties or child views
- Layout constants belong next to the view that uses them
- Colours, fonts and animation curves come from `Theme` — never inline literals
- Respect `accessibilityReduceMotion` wherever motion is introduced
- Give overlay content explicit sizes rather than combining `.frame(maxWidth: .infinity)`
  with outer padding, which overflows its window

## Formatting

- Four spaces, no tabs
- Roughly 100 columns
- One type per file, named after the type
- Imports sorted, and only what the file uses

## Before committing

- Builds clean with no warnings
- No commented-out code
- No debugging leftovers (`print`, temporary flags)
