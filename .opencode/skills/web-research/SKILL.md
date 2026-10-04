---
name: web-research
description: Use before giving any advice, recommendation, audit, or plan. Searches the web for current information on the topic so advice is based on up-to-date facts, not stale knowledge.
---

# Web Research

Search the web for current information before giving any advice. Never advise from training knowledge alone.

## Process

1. Identify the topics the advice depends on: technologies, frameworks, libraries, versions, security practices, standards, tools, or APIs.
2. Run one web search per topic with targeted queries (e.g., `<library> latest version`, `<library> breaking changes`, `<practice> current best practice`).
3. Fetch and read the most relevant results: official docs, release notes, changelogs, security advisories, and reputable technical sources.
4. Extract the facts that affect the advice: current versions, deprecations, breaking changes, known issues, security advisories, and updated best practices.
5. Compare findings against prior knowledge; where they differ, the web result wins.

## Rules

- Run this skill before every advice, recommendation, audit, plan, or phase instruction.
- Search even for familiar topics; knowledge may be outdated.
- Every web-based claim must carry a source (URL or page title).
- Search only legitimate, reputable sources: official documentation, vendor blogs and release notes, changelogs, security advisories (e.g., NVD, GitHub Security Advisories, vendor CVE pages), and established technical references (e.g., MDN, OWASP, official standards bodies). Do not use content farms, SEO-spam sites, unmoderated user content, or unknown low-authority blogs as sources.
- Prefer official and primary sources; treat forums and informal posts as secondary and only when corroborated by a primary source.
- Note publication dates for time-sensitive facts and prefer recent sources.
- If web search fails or returns nothing relevant, say so explicitly in the advice and mark the affected claims as unverified instead of guessing.

## Output

Summarize research findings alongside the advice:

- `researched`: topics searched.
- `sources`: URLs or page titles consulted.
- `key findings`: current versions, deprecations, advisories, or changed best practices that affect the advice.
- `unverified`: any claim that could not be confirmed online.
