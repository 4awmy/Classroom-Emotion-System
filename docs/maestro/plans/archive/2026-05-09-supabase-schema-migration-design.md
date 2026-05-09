---
status: "approved"
design_depth: "deep"
task_complexity: "complex"
---

# Design Document: Supabase Schema Migration

## 1. Problem Statement
The Classroom Emotion System is migrating from SQLite (v1) to Supabase PostgreSQL (v2) to support relational queries, RLS, and built-in Auth. The new 15-table schema, RLS policies, and custom JWT hooks are fully defined in `data-schema/README.md`. 

The problem is to systematically apply this new schema to the remote Supabase project while maintaining version control, establishing a reproducible deployment pipeline, and updating downstream client types. We lack an existing local Supabase CLI setup, requiring an initial bootstrap before the migration files can be generated and pushed.

## 2. Requirements
**Functional Requirements:**
- **REQ-1**: Initialize the local Supabase environment and link it to the remote project (`asefcgykjadlekhwwzar`).
- **REQ-2**: Split the raw SQL from `data-schema/README.md` into three sequential migration files: Schema, RLS Policies, and Auth Hooks.
- **REQ-3**: Push the migrations to the remote Supabase database and verify table creation.
- **REQ-4**: Generate updated TypeScript types from the applied schema for downstream client use.

**Non-Functional Requirements:**
- **REQ-5**: Maintain reproducibility by tracking all schema changes in version control via the `supabase/migrations` folder.
- **REQ-6**: Ensure safety by applying changes systematically rather than via raw manual execution in the dashboard.

**Constraints:**
- **REQ-7**: Must strictly adhere to the locked confidence values and schema definitions provided in the v2 contract.

## 3. Approach
**Selected Approach: Version-Controlled Sequential Migrations**
We will initialize a local Supabase CLI, link to the remote project, and generate three specific migration files (Schema, RLS, Auth). We will push these to the remote DB and then auto-generate TypeScript types. 

**Key Decisions:**
- Use `supabase init` and `supabase link` to bootstrap local state. *(considered: manual folder creation — rejected because it lacks the CLI tooling required for `db push` and type generation)* — *[Ensures reproducible, command-driven execution]* Traces To: REQ-1, REQ-5
- Split SQL into 3 files: `01_schema.sql`, `02_rls.sql`, `03_auth_hooks.sql`. *(considered: single monolithic file — rejected because it makes debugging failures harder)* — *[Provides clean modularity and easier rollbacks]* Traces To: REQ-2, REQ-6
- Apply via `supabase db push` and verify via MCP. — *[Validates the schema instantly against the remote instance]* Traces To: REQ-3
- Generate TS types post-push. — *[Provides immediate type safety for downstream frontend/backend clients]* Traces To: REQ-4

## 4. Architecture
**Data Flow & Key Interfaces:**
1. **Local Dev Environment**: Supabase CLI acts as the bridge. Migration files (`supabase/migrations/*.sql`) define the state. — *[Keeps local file system as the source of truth before syncing]* Traces To: REQ-5
2. **Remote Supabase Instance**: Receives the schema via `db push`. The remote PostgreSQL database will hold the 15 tables, RLS policies, and the custom `custom_jwt_claims` Postgres function. — *[Provides relational capabilities and secure isolated data access]* Traces To: REQ-3, REQ-7
3. **Client Integration**: The `supabase/database.types.ts` (or similar) is generated from the remote instance. This file is then exported/copied to the `python-api/` and `react-native-app/` directories. *(considered: hand-rolling types — rejected due to drift risk and complexity)* — *[Ensures end-to-end type safety between the DB and the application layers]* Traces To: REQ-4

## 5. Agent Team
**Assigned Agents:**
- **`devops_engineer`**: Responsible for initializing the Supabase CLI, linking the project, and running the `db push` and type generation commands. — *[Specializes in infrastructure tooling and CLI workflows]* Traces To: REQ-1, REQ-3, REQ-4
- **`data_engineer`**: Responsible for splitting the provided SQL into the three discrete migration files (`01_schema`, `02_rls`, `03_auth_hooks`) and ensuring they are syntactically valid and conflict-free. — *[Specializes in database schema modeling and SQL migration authoring]* Traces To: REQ-2, REQ-5, REQ-7

## 6. Risk Assessment
**Identified Risks:**
- **Risk 1: CLI Authentication Failures**. The local Supabase CLI requires a valid access token to link to the remote project. *Mitigation*: We will use the `SUPABASE_ACCESS_TOKEN` environment variable or rely on existing local auth. If it fails, we will guide the user to provide a token. Traces To: REQ-1
- **Risk 2: Foreign Key Constraint Violations**. The schema contains interdependent tables (e.g., `classes` depends on `courses` and `lecturers`). If tables are created out of order, the migration will fail. *Mitigation*: The `data_engineer` will ensure the tables are ordered correctly (which they appear to be in the provided SQL, e.g., admins/lecturers/students first) within `01_schema.sql`. Traces To: REQ-2, REQ-6
- **Risk 3: RLS Policy Errors**. Malformed policies can lock users out of their own data or expose it to others. *Mitigation*: We are using the exact, pre-approved SQL from the `data-schema/README.md`. No modifications will be made to the policy logic. Traces To: REQ-7

## 7. Success Criteria
**Measurable Outcomes:**
- **SC-1**: The `supabase/migrations/` directory exists and contains exactly 3 `.sql` files (`schema`, `rls`, `auth`). Traces To: REQ-2, REQ-5
- **SC-2**: The `mcp_supabase_list_tables` tool confirms that 15 new tables exist in the remote `public` schema. Traces To: REQ-3
- **SC-3**: The `supabase gen types typescript` command completes successfully, and a `database.types.ts` file is generated locally. Traces To: REQ-4