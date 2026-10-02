# Plan

## Scope

Implement domain model behavior for `StudyItem` and `StudyPlan` according to specification, preserving the published public API signature and keeping the supplied `StudyPlannerPublicTests.swift` tests unchanged.
The required behavior encompasses:
- Custom validation for `StudyItem` field invariants and custom `Decodable` conformance.
- Duplicate detection, title-then-ID sorting, and JSON decoding (supporting both array and keyed objects) for `StudyPlan`.
- Category filtering, incomplete estimated minute calculations, and idempotent item completion.
- The optional bonus `importMerging(_:)` method with in-place replacement, ascending ID appends, and atomic failure behavior.
- Additional student-authored unit tests following the Arrange-Act-Assert  pattern in a distinct test file.
---
## Acceptance criteria

### 1. Item Invariants & Error Precedence
- `StudyItem` rejects blank/whitespace-only titles with `StudyPlanError.blankTitle`.
- `StudyItem` rejects `estimatedMinutes <= 0` with `StudyPlanError.nonPositiveEstimatedMinutes`.
- Blank title validation takes precedence over non-positive minutes when both fields are invalid.

### 2. Decoding Boundaries
- Keyed `StudyPlan` JSON objects (`{"items": [...]}`) decode properly and trigger validation.
- Direct JSON array payloads (`[StudyItem]`) decode into valid `StudyPlan` instances.
- Invalid items in decoded JSON trigger the corresponding `StudyPlanError`.

### 3. Duplicates & Deterministic Ordering
- Duplicate item IDs in `StudyPlan` initialization throw `StudyPlanError.duplicateID(firstDuplicateID)` reporting the first duplicate encountered.
- Items are sorted deterministically by `title` ascending, breaking ties using `id` ascending.

### 4. Queries & Completion
- `items(in:)` filters and returns items matching the requested `StudyCategory`.
- `incompleteMinutes()` sums `estimatedMinutes` across all uncompleted items (`isCompleted == false`).
- `markCompleted(id:)` sets `isCompleted = true` for the target ID, acts idempotently if already completed, and throws `StudyPlanError.unknownID(id)` for missing IDs.

### 5. Optional Bonus: `importMerging(_:)`
- Throws `StudyPlanError.duplicateID` if incoming `importedItems` contain internal duplicate IDs, leaving the original plan state unmodified (atomic behavior).
- Replaces existing items in-place at their original index locations.
- Appends genuinely new items at the end, sorted in ascending ID order.

### 6. Student XCTest Suite & Evidence
- At least 6 student `test...` methods in `StudentStudyPlannerTests.swift` using  Arrange-Act-Assert formatting.
- `AGENT_WORKLOG.md` and `PLAN.md` document design choices, review logs, and `swift test` execution output.
---
## Implementation steps

1. **`StudyItem` Validation & Decodable** (`Sources/StudyPlanner/StudyPlanner.swift`)
   - Add initializer checks for blank titles and non-positive minutes with title-first precedence.
   - Implement custom `init(from decoder: Decoder)` delegating to throwing initializer.

2. **`StudyPlan` Initializer & Sort** (`Sources/StudyPlanner/StudyPlanner.swift`)
   - Implement duplicate ID detection via `Set<String>` iteration to identify first duplicate.
   - Implement deterministic sorting using `$0.title < $1.title` with `$0.id < $1.id` fallback.

3. **`StudyPlan` JSON Decoding** (`Sources/StudyPlanner/StudyPlanner.swift`)
   - Implement `StudyPlan.decode(from:)` to handle top-level JSON arrays and keyed objects.
   - Add custom `init(from decoder: Decoder)` for `StudyPlan` to route keyed decoding through `init(items:)`.

4. **Queries & Completion Mutations** (`Sources/StudyPlanner/StudyPlanner.swift`)
   - Implement `items(in:)` filtering.
   - Implement `incompleteMinutes()` aggregation over uncompleted items.
   - Implement `markCompleted(id:)` with guard checks for unknown IDs.

5. **Bonus Functionality: `importMerging(_:)`** (`Sources/StudyPlanner/StudyPlanner.swift`)
   - Validate incoming array for internal duplicates prior to state mutation.
   - Map existing indices, replace matching IDs in-place, and append remaining new items sorted by ID ascending.

6. **Student Unit Test Suite** (`Tests/StudyPlannerTests/StudentStudyPlannerTests.swift`)
   - Author unit tests following the AAA pattern covering edge cases, decoding, queries, mutations, and bonus import behavior.
---
## Risks

- **JSON Array vs Keyed Decoding Ambiguity:** Decoding fallback could swallow domain errors if not explicitly checked against root JSON structure. Resolved by checking JSON root type prior to target parsing.
- **`importMerging` Atomicity:** Modifying state prior to full validation risks partial updates on error. Resolved by validating all incoming IDs prior to altering `self.items`.
- **Duplicate ID Detection Order:** Standard dictionary/set iteration can obscure "first duplicate" ordering. Resolved by scanning array sequentially with a tracking set.
---
## `swift test` verification

| Command | Date | Result | Follow-up |
| :--- | :--- | :--- | :--- |
| swift test | `2026-09-30` | Starter test failure at `fatalError` | Expected behavior prior to domain logic implementation. |
| swift test | `2026-10-01` | 3 passed, 0 failures | Core validation, ordering, queries, and starter tests passing. |
| swift test | `2026-10-01` | 1 failure in `testDecodingTopLevelArrayAndKeyedJSON` | Synthesized Decodable bypassed initializer rules for JSON objects. Implemented explicit `init(from decoder:)`. |
| swift test | `2026-10-01` | 5 passed, 0 failures | Starter public tests and initial Codable boundary tests passing cleanly. |
| swift test | `2026-10-02` | 1 failure in `testImportMergingDuplicateIncomingIDsThrowsWithoutModifyingPlan` | Partial state mutation occurred before duplicate checks. Add upfront duplicate scanning for atomicity. |
| swift test | `2026-10-02` | 12 passed, 0 failures | All tests  passed cleanly. |
| swift test | `2026-10-02` | 12 passed, 0 failures | Artifact evidence captured and saved to `artifacts/swift-test-run.txt`. |
