# Provenance and scope

PatientPal is a collaborative iOS project. This repository is a public, educational adaptation of its on-device context pipeline, not an export of the private application and not a claim of sole authorship by any collaborator.

## Relationship to the original project

The source reviewed for this adaptation was `PatientPal/LLMViews/Automating.swift`, especially `modelQuery(input:)`, and the DTO definitions in `PatientPal/LLMViews/Tools/DataStruct.swift`.

The original workflow:

1. Converted stored visit objects to Codable DTOs and JSON.
2. Used a Foundation Models session to generate relevant visit DTOs.
3. Used another session to summarize relevant profile information.
4. Generated a concise answer from selected visits and profile context.
5. Sent the draft through a separate model-based screening session.

The public package preserves that sequence and the use of on-device Foundation Models. It does not include the original SwiftUI interface, persistence layer, complete DTO schema, prompt examples containing personal names, or application configuration.

## Changes made for this public sample

The expanded package was prepared with AI assistance. Its standalone packaging, reduced data types, protocol boundary, synthetic fixtures, tests, and validation behavior were newly written for the sample. The refactored pipeline and revised adapter demonstrate the original architecture but should not be represented as unchanged historical application code.

Specific changes include:

- Select record IDs and resolve them against original input, rather than accepting model-generated copies of visit records.
- Reject invented IDs, duplicate IDs, and selections exceeding three records.
- Remove record/profile debug printing and forced encoding operations.
- Pass errors to the caller and check cancellation between stages.
- Add bounded inputs and explicit no-context handling.
- Replace free-form screening output with a typed decision and fixed refusal.
- Supply question and context to the screen, rather than only the draft.

These improvements are sample additions; they are not evidence that the private application already implemented them. The repository does not establish individual contribution percentages. Applicants should describe only the original work they personally performed and be prepared to explain the sample and its AI-assisted changes.

## Publication boundary

Only the files in this small package are published. All demonstration records are invented. No private application files, patient records, recordings, contact information, credentials, Xcode user state, or third-party/vendor source files are included. No license for the private application is granted by this sample.
