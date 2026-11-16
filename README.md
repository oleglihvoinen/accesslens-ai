# AccessLens AI

An AI-assisted web accessibility assessment prototype that combines automated accessibility checks, evidence-based explanations, optional AI suggestions, and human review.

## Overview

AccessLens AI helps designers and developers identify accessibility problems and decide what to improve. The application provides:

- An interactive dashboard and a clearly labelled sample report.
- Browser-based accessibility checks for approved websites.
- Findings with technical evidence, affected elements, and applicable accessibility rules.
- Optional AI-generated explanations and suggested improvements.
- Human review statuses and assessment history.
- Before-and-after comparisons and JSON/CSV or print-friendly exports.

The sample report uses illustrative data; it is not a live assessment of a real website.

## Technology

- **Frontend:** semantic HTML, CSS and JavaScript.
- **Backend:** Node.js native HTTP server.
- **Database:** SQLite.
- **Accessibility scanning:** Playwright, Chromium and axe-core.
- **AI:** optional OpenAI API integration.
- **Testing:** Node.js test runner and HTTP smoke tests.

## Run locally

**Requirements:** Node.js 22.13+ and npm; Node.js 24+ is recommended.

1. Install dependencies: `npm install`.
2. Install Chromium: `npx playwright install chromium`.
3. Copy `.env.example` to `.env`.
4. Configure a random `SCAN_ACCESS_TOKEN`, approved `SCAN_ALLOWED_HOSTS`, and `DATA_DIR=./data`. If needed, set `OPENAI_API_KEY` only in the local environment.
5. Start the server: `npm start`.
6. Open the local address configured by `HOST`, `PORT` and `BASE_PATH`.
7. Run automated tests: `npm test`.

The sample demonstration is available without an AI API key. Real scans require a configured browser and permission to assess the target website.

## How it works

1. A permitted webpage is loaded through a controlled browser session.
2. axe-core identifies detectable accessibility rule violations.
3. The report presents affected elements, severity and supporting evidence.
4. If enabled, AI adds contextual explanations and suggested fixes.
5. A reviewer evaluates findings, updates their status and exports results.

**AI explanations are suggestions, not independently verified accessibility violations.** Automated checks cover only part of accessibility. Manual keyboard, screen-reader and user testing remain necessary. The priority score is a heuristic and not a WCAG compliance score.

## Security and limitations

- Keep API keys, access tokens and scan data outside source control.
- Never commit `.env`, `data/` or `node_modules/`.
- Limit scanning to explicitly approved public hosts.
- Prevent browser access to internal addresses and cloud metadata services through network-level controls; an application allowlist alone is insufficient.
- The current authorization model is single-operator and not suitable for multi-tenant production use without further engineering.
- Review AI recommendations before applying changes.

See [Security](SECURITY.md), [Architecture](docs/ARCHITECTURE.md), [AI evaluation](docs/AI-EVALUATION.md) and [Accessibility statement](ACCESSIBILITY.md) for additional technical details.

## Next steps

1. Validate real scans end to end and strengthen error handling.
2. Compare AI suggestions with expert-reviewed accessibility fixes.
3. Conduct keyboard, screen-reader and usability testing.
4. Improve mobile usability and reporting.
5. Evaluate secure multi-page scanning and collaboration features.

## License

MIT; see [LICENSE](LICENSE).
