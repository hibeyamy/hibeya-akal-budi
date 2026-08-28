# HIBEYA Akal Budi â€” Curriculum Source & Review Governance

## Principle

Akal Budi may use official curriculum documents as factual references, but official source documents are not copied into the product repository.

The repository stores:

- source metadata;
- official source URLs;
- verification status;
- cryptographic document hashes;
- mapping review records.

Local source files remain outside Git.

## Verification levels

### unverified

A source has been proposed but its authority/domain has not been confirmed.

### metadata-verified

The source title and URL have been verified against an official authority domain.

This does not mean the complete document has been captured.

### document-verified

A local copy of the official document has been captured for internal review and its SHA-256 hash is recorded.

The local document remains ignored by Git.

### superseded

A newer curriculum version or official document has replaced the source.

## Curriculum mapping workflow

```text
Official source
    |
    v
metadata-verified
    |
    v
local capture + SHA-256
    |
    v
document-verified
    |
    v
curriculum extraction
    |
    v
human mapping review
    |
    v
approved mapping
    |
    v
production curriculum claim
```

## Copyright boundary

Do not copy substantial curriculum-document text into activity manifests.

Store structured identifiers, short factual labels and original HIBEYA instructional content.

The curriculum source registry provides traceability without making the repository a redistribution channel for source documents.

## Review principle

Automation can:

- validate source-domain provenance;
- calculate hashes;
- validate mapping structure;
- detect missing review metadata.

Automation cannot decide that an activity is pedagogically aligned with an official standard.

That requires explicit human/educator review.
