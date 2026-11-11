# PatientPal — On-Device AI Context Pipeline

A standalone Swift sample adapted from the multi-stage AI workflow in the collaborative PatientPal iOS project. It demonstrates structured context selection, profile extraction, answer generation, and a separate response-review stage.

**Start with [`ContextPipeline.swift`](Sources/PatientPalSample/ContextPipeline.swift), then [`AppleContextModel.swift`](Sources/PatientPalSample/AppleContextModel.swift).** These files show the orchestration and actual Foundation Models integration.

This expanded public adaptation was prepared with AI assistance. Packaging, validation, fixtures, and tests were added for this sample; they are not presented as historical application code or proof of any one collaborator's authorship. See [provenance and changes](PROVENANCE.md).

## Architecture

```text
Question + supplied visits ──► structured visit-ID selection
                                    │
                            validate IDs and recover original records
                                    │
Question + supplied profile ─► relevant profile summary
                                    │
                            selected context + question
                                    │
                              draft generation
                                    │
                            context-aware review
                                    │
                            accepted draft / fixed refusal
```

Each live stage uses a separate Apple `LanguageModelSession`. This is model-guided retrieval over a small structured input; it does not use embeddings or a vector database. The selection stage sees all supplied visit summaries. Only the answer stage receives the selected subset.

## Repository guide

| File | Responsibility |
| --- | --- |
| [`Models.swift`](Sources/PatientPalSample/Models.swift) | Minimal Codable records, typed results/errors, and model interface |
| [`ContextPipeline.swift`](Sources/PatientPalSample/ContextPipeline.swift) | Four-stage orchestration, selection validation, budgets, cancellation, and refusal handling |
| [`AppleContextModel.swift`](Sources/PatientPalSample/AppleContextModel.swift) | On-device sessions, guided generation, JSON prompt inputs, and availability checks |
| [`Demo.swift`](Sources/PatientPalDemo/Demo.swift) | Synthetic scheduling example with scripted and live modes |
| [`PipelineTests.swift`](Tests/PatientPalSampleTests/PipelineTests.swift) | Deterministic orchestration and failure-path tests |
| [`PROVENANCE.md`](PROVENANCE.md) | Relationship to original project and newly added sample behavior |

## Run

Requires macOS 26 or later and full Xcode 26 with Swift 6.2 and the macOS 26 SDK. The standalone Command Line Tools may lack the Foundation Models macro plugin; use the full Xcode toolchain (set `DEVELOPER_DIR` to your Xcode app’s `Contents/Developer` directory if needed). The package has no third-party dependencies and requires no API keys.

```sh
git clone https://github.com/Griffinjlee/patientpal-ai-code-sample.git
cd patientpal-ai-code-sample
swift test
swift run patientpal-demo
```

The default demo is **scripted**: it exercises the pipeline without invoking an AI model. Its predetermined answers are not evidence of retrieval quality. Tests also use a controlled stub and require no enabled model.

For real on-device generation on an eligible Mac with Apple Intelligence enabled and the model available:

```sh
swift run patientpal-demo --live
```

The live adapter checks model availability and propagates errors. It has no cloud fallback. Live answers are nondeterministic and may differ from the scripted example.

## Design decisions

### Preserve source records

The model selects IDs, and the pipeline retrieves the original records by those IDs. Invented, duplicated, or excessive selections are rejected before answer generation. This prevents generated record copies from silently becoming the source of truth, although it does not guarantee that the selection is relevant or complete.

### Separate model stages

A protocol exposes the four stages independently, allowing deterministic tests of orchestration without confusing model quality with program correctness. The profile summary remains model-generated and can contain omissions or errors.

### Minimize context and logging

The public schema intentionally excludes names, contacts, insurance details, and recordings. The pipeline does not print record contents. The executable prints only results from its embedded synthetic fixtures. No application database or real user data is loaded.

### Handle failure explicitly

Invalid input, invalid selections, empty drafts, and model errors fail through typed errors. Empty context produces a distinct no-context result. A blocked screen returns a fixed refusal; a failed screen throws rather than releasing the draft. Cancellation is checked between stages.

### Keep limitations visible

Character budgets are defensive sample limits, not precise model-token budgeting. Model context-window errors still propagate. Prompts label input as untrusted, but prompt instructions do not guarantee resistance to injection. Neither the model-based review nor the test suite validates medical accuracy or clinical safety. This is an educational prototype, not a clinical tool.

## Tests and validation

The tests cover preserving selected source records, stage ordering, invented/duplicate/excess IDs, empty context, profile-only context, blocked output, screening failure, blank questions, duplicate source IDs, oversized input, empty drafts, and cancellation.

Build and test results are recorded in [VALIDATION.md](VALIDATION.md). The live model's answer quality is not assessed by these deterministic tests.

## References

- [Apple Foundation Models documentation](https://developer.apple.com/documentation/foundationmodels)
- [Generating content with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)

The full PatientPal application remains private. This repository includes only the reviewed public adaptation and synthetic example data.
