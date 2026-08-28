# HIBEYA Akal Budi â€” Curriculum & Skill Architecture

## Objective

Akal Budi must support multiple curricula, subjects and education levels without creating subject-specific application architecture.

The runtime must remain generic.

Examples such as Jawi, Mathematics, Bahasa Melayu or preschool learning are content domains, not separate applications or separate progress engines.

## Core model

```text
Curriculum Authority
  -> Curriculum Version
    -> Education Level
      -> Subject
        -> Strand
          -> Standard

Skill
  -> prerequisite relationships

Activity
  -> ActivitySkillMapping[]
  -> ActivityCurriculumMapping[]
```

## Separation of concerns

### Curriculum standards

Represent what an external curriculum authority specifies.

They are:

- versioned;
- source-backed;
- reviewable;
- supersedable.

### Skills

Represent reusable learner capabilities.

Skills are curriculum-independent where possible.

For example:

```text
colour-recognition
visual-discrimination
jawi-letter-recognition
word-decoding
quantity-comparison
```

A skill may support several curricula.

### Activities

Activities teach or observe skills.

An activity may map to zero, one or several curriculum standards.

A new activity is not allowed to invent an official curriculum mapping.

## Curriculum claims

A production claim such as "aligned with KPM" requires:

1. a source-verified curriculum version;
2. source provenance;
3. a reviewed standard mapping;
4. review metadata;
5. a non-superseded curriculum version.

Empty curriculum mappings are valid.

Unverified curriculum claims are not.

## Skill graph

Skill prerequisites form a directed acyclic graph.

Example:

```text
letter-recognition
        |
        v
letter-discrimination
        |
        v
letter-joining
        |
        v
word-reading
```

The graph must remain free of cycles.

## Learner model â€” future

The architecture is designed to support:

```text
Learner Profile
  + Curriculum Path
  + Skill State
  + Activity History
  + Accessibility
        |
        v
Recommendation Engine
        |
        v
Activity
```

Adaptive recommendation is intentionally not implemented in Phase 005B.

## Data ownership

Curriculum source documents and standards are governed content.

Learner progress is runtime data.

They must not be stored or versioned in the same way.

## Commercial scalability

Do not create:

```text
jawi_progress
math_progress
english_progress
```

Use generic:

```text
learner_skill_state
activity_attempt
curriculum_enrolment
```

Subject-specific behaviour belongs in content and mechanic plugins.
