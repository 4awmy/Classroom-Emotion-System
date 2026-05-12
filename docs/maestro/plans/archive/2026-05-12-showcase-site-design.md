---
design_depth: deep
task_complexity: medium
topic: showcase-site
date: 2026-05-12
---

# Design Document: Classroom Emotion System Showcase Portal

## 1. Problem Statement
The "Classroom Emotion System" is a sophisticated, multi-component AI project. Currently, its documentation and value proposition are scattered across multiple files and platforms. There is no central "front door" for examiners or users to understand the project's story, see it in action, and learn how to test it.

**Solution**: A branded, multi-page web portal acting as the official landing page and technical manual, aligning with AASTMT's visual identity.

## 2. Requirements

### Functional
- **AAST Visual Identity**: Navy Blue (`#002244`) and Gold (`#C49808`) theme with logos. (REQ-BRAND)
- **Integrated Demo Video**: High-visibility YouTube/CDN embed on the home page. (REQ-DEMO)
- **Dynamic Documentation**: Automatically render `ARCHITECTURE.md` and `documentation.md` via `react-markdown`. (REQ-DOCS)
- **Testing Hub**: Dedicated section for "How to Test," "Manual," and "Credentials." (REQ-MANUAL)
- **Responsive Hybrid Layout**: Story-driven home page + sidebar-driven technical docs. (REQ-UX)
- **External Linking**: Decoupled portal linking to external live project services.

### Non-Functional
- **Performance**: Fast initial load via Vite/Static hosting.
- **Scalability**: Zero impact on main project resources (Stateless/Static). (REQ-RESOURCES)
- **Maintainability**: Markdown-first content strategy.

## 3. Approach (Selected)
**Hybrid Showcase-Manual**:
- **React (Vite) + Tailwind CSS** for the build and design system.
- **React Router** for multi-page navigation.
- **Home Page**: Narrative storyteller style featuring the Case Study and Demo Video.
- **Docs Section**: Persistent sidebar navigation rendering existing project Markdown files.

## 4. Architecture

### Folder Structure
- `showcase-site/`
  - `src/components/`: Header, Footer, MarkdownRenderer, Sidebar, VideoPlayer.
  - `src/pages/`: Home.tsx, Docs.tsx, Manual.tsx.
  - `src/docs/`: Links/copies of project .md files.
  - `tailwind.config.js`: Custom AAST color palette.

### Data Flow
- User visits site -> React Router directs to Home/Docs.
- Docs page fetches/imports `.md` files -> `react-markdown` parses and styles via Tailwind Typography plugin.

## 5. Agent Team
- **ux_designer**: Layout, AAST theme variables, and component API design.
- **coder**: Project scaffolding, component implementation, and routing setup.
- **technical_writer**: Content consolidation for the Case Study and the new `MANUAL.md`.

## 6. Risk Assessment
- **Risk**: AAST Branding accuracy. (Mitigation: Use exact hex codes and institutional font pairings).
- **Risk**: Markdown layout breaks. (Mitigation: Mobile-first styling and `overflow-x-auto` for tables).
- **Risk**: Link Rot. (Mitigation: Clear disclaimers and link validation during build).

## 7. Success Criteria
- Website loads in < 2 seconds.
- Demo video is playable and responsive.
- All technical documentation is readable and correctly formatted.
- Site is successfully deployed to a static hosting provider (e.g., DO App Platform).
