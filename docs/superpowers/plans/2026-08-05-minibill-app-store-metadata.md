# MiniBill App Store Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the root `readme.md` with a submission-ready bilingual App Store/ASO dossier for MiniBill.

**Architecture:** One Markdown document contains separate Simplified Chinese and English metadata blocks plus common App Review, privacy questionnaire, category, age-rating, and screenshot-copy guidance. Every field includes a measured length so it can be copied into App Store Connect safely.

**Tech Stack:** Markdown and a small one-off UTF-8 byte/character validation command.

## Global Constraints

- Product name remains `MiniBill`; do not use the old Chinese engineering name.
- App Store name and subtitle are each at most 30 characters.
- Promotional text is at most 170 characters; description is at most 4000 characters; keywords are at most 100 UTF-8 bytes.
- Do not repeat the app/company name in keywords and do not use competitor trademarks.
- Claims must match the implementation: local-only data, no account/cloud/ads/analytics/tracking, manual backup/restore, local reminders, local share images, project-name aggregation, no categories.
- Privacy URL: `https://app-privacy-support.pages.dev/MiniBill/privacy/`.
- Support URL: `https://app-privacy-support.pages.dev/MiniBill/support/`.

---

### Task 1: Write and validate bilingual store dossier

**Files:**
- Replace: `readme.md`

- [ ] **Step 1: Add a Chinese block** containing name, subtitle, keyword string, promotional text, full description, version 1.0 release notes, screenshot captions, and reviewer notes.
- [ ] **Step 2: Add an English block** with the same fields, localized naturally rather than literally.
- [ ] **Step 3: Add shared submission guidance** for primary/secondary category, age rating, copyright, bundle/version, privacy/support/marketing URLs, encryption answer, sign-in/demo account, notification review path, backup/restore review path, and App Privacy answers.
- [ ] **Step 4: Validate each field length** with literal strings and report characters/UTF-8 bytes beside each value. Shorten any over-limit field without weakening accuracy.
- [ ] **Step 5: Run a placeholder scan and `git diff --check`; do not commit unrelated MiniBill repository changes because the repository has no baseline commit.**

