---
design_depth: deep
task_complexity: complex
---

# Design Document: Digital Ocean Configuration

## 1. Problem Statement
The Classroom Emotion System requires a production-ready deployment architecture on Digital Ocean. Currently, the system runs locally with SQLite and local CSV exports, which are not suitable for ephemeral cloud environments. We need to deploy the three core server-side components (FastAPI backend, Vision AI service, and R Shiny dashboard) in a scalable, reliable manner while ensuring persistent data storage. The solution must provide automated builds and straightforward configuration without the overhead of manual server administration.

## 2. Requirements

**Functional Requirements:**
- **REQ-1:** Deploy FastAPI, Vision AI, and Shiny as independently scalable services.
- **REQ-2:** Persist relational data to a Managed PostgreSQL database.
- **REQ-3:** Store generated CSV exports in a Digital Ocean Spaces (S3-compatible) bucket.

**Non-Functional Requirements:**
- **REQ-4:** Enable automated deployments upon pushing code to the repository.
- **REQ-5:** Maintain a single, live production environment to minimize costs.

**Constraints:**
- **REQ-6:** Deliver infrastructure configuration as a native Digital Ocean `app.yaml` file.
- **REQ-7:** Vision AI processes must fit within App Platform's standard CPU/RAM tiers.

## 3. Approach

**Selected Approach: Microservices on App Platform**
We will deploy the system using a single `app.yaml` file defining three distinct components on Digital Ocean App Platform. 

- **Use App Platform (PaaS)** — *[To prioritize deployment simplicity and automated builds over granular OS control]* `Traces To: REQ-4, REQ-7` *(considered: Droplets/Kubernetes — rejected because they introduce unnecessary maintenance overhead)*.
- **Separate Microservices** — *[To prevent the Vision AI's resource-intensive processing from starving the main FastAPI web server]* `Traces To: REQ-1` *(considered: Monolithic Backend — rejected because of resource contention risks)*.
- **Managed DB & Spaces** — *[To guarantee data durability across ephemeral container restarts]* `Traces To: REQ-2, REQ-3` *(considered: App Platform Dev DB — rejected because it lacks production-grade backups)*.

## 4. Architecture

**Data Flow & Components**:
- **Digital Ocean App Platform**:
  - `backend` (FastAPI): Exposes HTTP/WS, writes to DB, uploads CSVs to Spaces.
  - `vision` (Python): Processes video/audio streams.
  - `frontend` (R Shiny): Displays analytics dashboards.
- **External to App Platform**:
  - `Managed PostgreSQL`: Relational storage (URL injected to backend/vision via env vars).
  - `DO Spaces`: Object storage for CSVs (keys injected to backend/frontend).

**Key Architectural Decisions**:
- **Direct DB Access for Vision** — *[Vision will connect directly to the Managed DB using the shared `DATABASE_URL` to write evidence, avoiding unnecessary HTTP overhead]* `Traces To: REQ-1` *(considered: Vision calling FastAPI to save data — rejected due to latency and complexity)*.
- **Direct S3 Access for Shiny** — *[Shiny will read CSVs directly from Spaces using an S3 client, keeping the FastAPI backend focused on core business logic]* `Traces To: REQ-3` *(considered: FastAPI serving CSVs to Shiny — rejected because S3 is optimized for file serving)*.

## 5. Agent Team
- **`architect`**: Draft the final `app.yaml` specification.
- **`coder`**: Update `python-api`, `vision`, and `shiny-app` to support PostgreSQL and S3.
- **`devops_engineer`**: Optimize the Dockerfiles for App Platform.

## 6. Risk Assessment
- **Risk 1: Vision AI Resource Constraints**: High impact. App Platform uses standard CPUs without GPUs. Computer vision tasks might hit memory/CPU limits and crash the container. *Mitigation*: Specify a higher-tier instance size (e.g., 1GB or 2GB RAM) for the `vision` worker in the `app.yaml`. Optimize the processing framerate.
- **Risk 2: Network Latency**: Medium impact. Services need to communicate with the Managed DB and Spaces bucket. *Mitigation*: Create the Managed DB, Spaces, and App Platform app in the **exact same datacenter region** (e.g., `FRA1` or `LON1`) to ensure near-zero latency.

## 7. Success Criteria
- The `app.yaml` is fully declarative and correctly maps the `backend`, `vision`, and `frontend` services with their respective environment variables and ports.
- The codebase is successfully updated to integrate `psycopg2` (PostgreSQL) and `boto3`/`paws` (S3/Spaces).
- The three Dockerfiles build successfully without errors in the Digital Ocean App Platform CI pipeline.
- The deployed backend successfully persists relational data to the Managed DB and exports CSVs to DO Spaces.
- The mobile app can securely connect to the live backend URL.
