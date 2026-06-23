# ZACG – Access Control Guard

**ZACG (Access Control Guard)** is an in-house SAP ABAP suite for **security, authorization and access-governance administration**. It bundles user and role analysis, mass role/user maintenance, an access-request approval workflow with built-in **Segregation of Duties (SoD) risk analysis**, Firefighter (emergency access) handling, and SAP Fiori/UI5 dashboards into a single custom package.

Think of it as a lightweight, self-built alternative to SAP GRC Access Control, delivered as an [abapGit](https://abapgit.org) repository.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [Main Components](#main-components)
- [Data Model](#data-model)
- [Authorization Concept](#authorization-concept)
- [Fiori / UI5 Dashboards](#fiori--ui5-dashboards)
- [Installation](#installation)
- [Usage](#usage)
- [Background Jobs](#background-jobs)
- [Conventions](#conventions)
- [License](#license)

---

## Overview

The tool is centered on a single SAP transaction, **`ZACG`**, which launches the report `ZACG_MAIN` (screen `1000`). From there the administrator drives a tree-based menu that exposes dozens of security operations. Supporting reports, an OData service, workflow objects and two SAPUI5 applications round out the package.

| Property            | Value                                          |
|---------------------|------------------------------------------------|
| Package             | `ZACG` – *Access Control Guard*                |
| Main transaction    | `ZACG` → report `ZACG_MAIN`, dynpro `1000`     |
| Message class       | `ZACG` – *Guard Tool*                          |
| OData service       | `ZACG_SRV` (`/sap/opu/odata/sap/ZACG_SRV`)     |
| Fiori apps          | `zacgdashboard`, `zsecrtdashboard`             |
| Workflow object     | `ZACG_CL_WF_ROLE_ASSIGNMENT`                   |
| Serialization       | abapGit (`src/` flat folder)                   |

---

## Key Features

### Role & User Analysis
- **Role analysis** – inspect single, composite and derived roles by *role level* (L0–L4), in summary or detail layout, with optional file-based simulation.
- **User analysis** – analyze user-to-role assignments by module and level, summary or detail.
- ALV tree / grid output with downloadable Excel and template formats.

### User Administration
- **Create users** from an Excel template.
- **Set / reset passwords** – mass (via file) or manual, with automated e-mail notification.
- **Set productive passwords** in bulk.
- **Lock / unlock users**, including inactivity-based locking.
- **Update user master details** from a template.
- **Monitor standard users** (e.g. SAP\*, DDIC) for compliance.

### Role Maintenance (mass / template driven)
- Change **role descriptions**.
- **Create derived roles** and **delete inheritance**.
- **Add / remove single roles** to/from **composite roles**.
- **Create composite roles** and **delete roles**.
- **Push master roles** to derived roles.
- **Mass-maintain authorization values** (add/deactivate authorizations, org-field changes, permission-value updates).
- **Copy users** and copy roles.

### Access-Request Workflow with Risk Analysis
- Raise role-assignment **access requests** (`ZACG_ROLE_ASSIGNMENT`).
- Built-in **Segregation of Duties (SoD)** and **critical access** risk analysis against a configurable **risk library / rule set**.
- Multi-stage approval (line manager → role owner) via SAP Business Workflow (`ZACG_CL_WF_ROLE_ASSIGNMENT`, 21 workflow tasks).
- **Mitigation owners** and rejection-reason handling.
- E-mail notifications to employees, managers, role owners and mitigation owners.

### Firefighter / Emergency Access (FFID)
- Firefighter ID header, log and transaction-log tables (`ZACG_FFID_*`).
- **Automatic FFID logout** report (`ZACG_FFID_LOGOUT`) that closes orphaned firefighter sessions and stamps logout date/time.

### Reporting Dashboards
- **Security Dashboard** Fiori apps surfacing SoD and critical role/user metrics at role-level and process-level via the `ZACG_SRV` OData service.
- Background dashboard builder (`ZACG_DASHBOARD`) with automatic housekeeping of aged entries.

---

## Architecture

```
                         ┌──────────────────────────────┐
   SAP GUI (tcode ZACG)  │        ZACG_MAIN (report)     │
        ───────────────► │  tree menu + dynpros 1000..   │
                         │  lcl_acg / lcl_acg_tree (OO)  │
                         └───────────────┬──────────────┘
                                         │ PERFORM forms (mainf01)
                 ┌───────────────────────┼─────────────────────────┐
                 ▼                       ▼                         ▼
        User/Role admin          Mass maintenance          Access request +
        (BAPIs, file I/O)        (XSLT templates,           risk analysis
                                  BDC, AGR_* APIs)                │
                                                                  ▼
                                                      SAP Business Workflow
                                                  ZACG_CL_WF_ROLE_ASSIGNMENT
                                                       (21 PDTS tasks)

   Fiori / UI5  ──►  OData ZACG_SRV (ZCL_ZACG_DPC_EXT / ZCL_ZACG_MPC_EXT)
   zacgdashboard / zsecrtdashboard      reads SoD & critical-access data

   Batch:  ZACG_DASHBOARD · ZACG_TCODE_USAGE_BATCH · ZACG_TLOG_BATCH · ZACG_FFID_LOGOUT
```

- **Presentation:** classic dynpro UI in `ZACG_MAIN` (controls: docking/splitter containers, ALV tree, ALV grid) plus two SAPUI5 dashboards.
- **Application logic:** mostly procedural `FORM` routines in `ZACG_MAINF01` orchestrated by local classes (`lcl_acg`, `lcl_acg_tree`, `lcl_event_receiver`).
- **Mass operations** are driven by **XSLT transformations** that generate and parse Excel/XML templates (download a template, fill it, upload to execute).
- **Workflow & OData** layers provide the request-approval and reporting capabilities.

---

## Repository Layout

This repository is an **abapGit** export. All objects live as flat files under `src/`, named `<object>.<type>.<ext>`.

```
ZACG/
├── README.md
└── src/                 ← all ABAP & SAPUI5 objects (abapGit serialized)
    ├── *.prog.abap/.xml         Reports & includes
    ├── *.clas.abap/.xml         Global classes (OData, workflow, demo)
    ├── *.fugr.*                 Function groups
    ├── *.tabl.xml               Transparent tables & structures
    ├── *.dtel/.doma/.ttyp.xml   Data elements, domains, table types
    ├── *.shlp/.enqu.xml         Search helps, lock objects
    ├── *.suso/.sush/.susc.xml   Authorization objects/fields/classes
    ├── *.xslt.*                 XSLT transformations (Excel templates)
    ├── *.pdts.xml               Workflow tasks (21)
    ├── *.wapa.*                 SAPUI5 / BSP applications
    ├── *.iwsg/.iwsv/.iwmo/.iwom/.iwpr.xml   Gateway/OData service objects
    ├── *.sicf.xml               ICF service nodes
    ├── *.tran.xml               Transaction ZACG
    └── *.msag.xml               Message class ZACG
```

Object-type tallies (approx.): 24 reports, 6 classes, 6 function groups, 45 tables/structures, 38 authorization objects, 39 XSLT transformations, 21 workflow tasks, plus 2 UI5 apps.

---

## Main Components

### Reports

| Report                       | Purpose                                                            |
|------------------------------|--------------------------------------------------------------------|
| `ZACG_MAIN`                  | Central tool launched by transaction `ZACG`; tree menu + dynpros.  |
| `ZACG_ROLE_ASSIGNMENT`       | Assign roles (manual or file) and trigger the request workflow.    |
| `ZACG_DASHBOARD`             | Builds/refreshes dashboard data; housekeeping of aged rows.        |
| `ZACG_FFID_LOGOUT`           | Closes stale Firefighter sessions and writes logout timestamps.    |
| `ZACG_UPD_CONFIG`            | Maintain configuration (risk library, owners, rule sets, etc.).    |
| `ZACG_TCODE_USAGE_BATCH`     | Collects transaction-code usage statistics.                        |
| `ZACG_TLOG_BATCH`            | Transaction-log batch collector.                                   |
| `ZACG_ENCRIPT_PROG`          | Encryption helper.                                                 |

`ZACG_MAIN` is composed of the usual include set: `*TOP` (data), `*S01` (selection screens 0001–0017+), `*DEF`/`*IMP` (local classes), `*O01` (PBO), `*I01` (PAI), `*F01` (≈120 form routines), `*H01` (helpers).

### Classes

| Class                         | Role                                                        |
|-------------------------------|-------------------------------------------------------------|
| `ZACG_CL_WF_ROLE_ASSIGNMENT`  | Workflow business object for the access-request approval.   |
| `ZCL_ZACG_DPC` / `_DPC_EXT`   | OData **data provider** for `ZACG_SRV` (SoD/critical sets). |
| `ZCL_ZACG_MPC` / `_MPC_EXT`   | OData **model provider** for `ZACG_SRV`.                    |

### Function Groups

`ZACG` (main utilities incl. search-help exit), `ZACG_AGR_DEFINE`, `ZACG_TREE_CONTRL` (ALV tree control), `ZACG_USR02` (USR02 table maintenance), `ZACG_ALSMEX` / `YALSMEX` (Excel↔internal-table conversion).

---

## Data Model

Representative tables under the `ZACG_*` namespace:

- **Access requests / workflow:** `ZACG_REQUESTED_ROLES`, `ZACG_REQ_APROVER`, `ZACG_REQ_APV_BLK`, `ZACG_REQ_BLK_MAP`, `ZACG_REJECTION_REASON`, `ZACG_RECIPIENT`, `ZACG_MANAGER`.
- **Risk / SoD library:** `ZACG_RISK_MSTR`, `ZACG_RISK_LIB`, `ZACG_RISK_COMB`, `ZACG_FUE_RUL_SET`, `ZACG_FUNCT`, `ZACG_OBJ_FVAL`.
- **Mitigation & ownership:** `ZACG_MITIGATION_OWNER`, `ZACG_MITG_OWNERS`, `ZACG_MITG_LOG`, `ZACG_ROLE_OWNERS`, `ZACG_UNIQUE_ROLE_OWNER`, `ZACG_ROLE_OWNER_RECIPIENT`.
- **Firefighter:** `ZACG_FFID_HDR`, `ZACG_FFID_LOG`, `ZACG_FFID_TLOG`.
- **Usage / logging & dashboard:** `ZACG_TUSG_DLOG`, `ZACG_DASHBOARD`, `ZACG_USER_DETAIL`, `ZACG_USER_SUM_BG`, `ZACG_USR02`.
- **Locking & misc:** `ZACG_LOCK_REQ`, `ZACG_AGR_DEFINE`, `ZACG_TREE_CONTRL`.

Plus numerous DDIC structures (`ZACG_S_*`), table types (`ZACG_T_*`), data elements, domains, search helps and the lock object `EZACG_REQ_APRV`.

---

## Authorization Concept

ZACG ships **38 authorization objects** so each function can be locked down individually. The transaction itself is protected by `Z_ZACG_ADM` (activity `16`). Examples:

| Object        | Guards                                   |
|---------------|------------------------------------------|
| `Z_ZACG_ADM`  | Overall ZACG admin / transaction start   |
| `ZACG_CROL`   | Create role                              |
| `ZACG_DROL`   | Derive role                              |
| `ZACG_DELR`   | Delete role                              |
| `ZACG_CCRL`   | Create composite role                    |
| `ZACG_RPWD`   | Reset password                           |
| `ZACG_PPWD`   | Set productive password                  |
| `ZACG_LUSR`   | Lock user                                |
| `ZACG_FFID`   | Firefighter access                       |
| `ZACG_NREQ`   | New access request                       |
| `ZACG_DASH`   | Dashboard access                         |

(…and many more `ZACG_*` objects covering org-level, mass user/role operations, address/role-assignment, etc.)

---

## Fiori / UI5 Dashboards

Two SAPUI5 (Fiori-style) applications are delivered as BSP repositories (`*.wapa.*`):

- **`zacgdashboard`** – *Misc Report Dashboard* (view/controller `miscRepDashboard`).
- **`zsecrtdashboard`** – *Security Dashboard Report* (App + `miscRepDashboard` views).

Both consume the OData service **`ZACG_SRV`** and visualize SoD and critical-access analytics:

- SoD by **role level** and **process level** (`sodRoleLevel*`, `sodRoleProcess*`).
- SoD by **user level** (`sodUserLevel*`).
- **Critical role** and **critical user** analyses (`criticalRole*`, `criticalUser*`).

Each app includes a `manifest.json`, i18n bundle, component/model/controller JavaScript, QUnit/OPA test suites and a Fiori Launchpad sandbox for standalone testing. Runtime is exposed through ICF nodes (`*.sicf.xml`).

---

## Installation

This is an **abapGit** repository. To deploy it to an SAP NetWeaver AS ABAP system:

1. Install [abapGit](https://docs.abapgit.org/) (standalone report `ZABAPGIT` or the developer version).
2. In abapGit choose **+ Online**, enter this repository URL, and assign the target package (e.g. `ZACG`).
3. **Pull** the repository, then activate all objects (abapGit will list inactive objects).
4. Verify dependencies are present on the target system: SAP Gateway / NetWeaver Gateway (for the OData service and Fiori apps), SAP Business Workflow (for the access-request process), and the standard role/user APIs (`AGR_*`, `BAPI_USER_*`, `SUSR_*`).
5. Activate the ICF nodes for the OData service and UI5 apps (`SICF`), register/activate `ZACG_SRV` in the Gateway service catalog, and configure the workflow tasks (`PDTS`) and event linkages.
6. Maintain configuration data (risk library, rule sets, role/mitigation owners, approvers) via `ZACG_UPD_CONFIG` and the related upload templates.

> **Note:** No `.abapgit.xml` is committed at the repo root, so set the package and (optional) starting folder in abapGit at clone time. Objects are serialized in a **flat** `src/` folder.

---

## Usage

1. Run transaction **`ZACG`** (requires `Z_ZACG_ADM`, activity 16).
2. Navigate the left-hand tree to the desired function (role analysis, user admin, mass maintenance, access requests, etc.).
3. For **template-driven** operations:
   - Click **Download Format** to obtain the Excel/XML template (generated via the matching `ZACG_*_TEM` XSLT).
   - Fill in the template offline.
   - Upload the file and press **Execute**; results are shown in an ALV report with per-row status messages and can be downloaded.
4. For **access requests**, submit role assignments; ZACG runs SoD/critical-access analysis and routes the request through manager and role-owner approval before provisioning.

---

## Background Jobs

Schedule these reports as periodic jobs (e.g. in `SM36`):

| Report                    | Suggested schedule     | Purpose                                     |
|---------------------------|------------------------|---------------------------------------------|
| `ZACG_FFID_LOGOUT`        | Frequent (e.g. hourly) | Close orphaned Firefighter sessions.        |
| `ZACG_DASHBOARD`          | Daily                  | Rebuild dashboard data; purge aged rows.    |
| `ZACG_TCODE_USAGE_BATCH`  | Daily                  | Collect transaction-code usage statistics.  |
| `ZACG_TLOG_BATCH`         | Daily                  | Collect transaction-log data.               |

---

## Conventions

- **Namespace:** all custom objects are prefixed `ZACG_` (a few helpers use `Z*` / `Y*`, e.g. `YALSMEX`).
- **Language:** master language is **English (`E`)**.
- **UI:** classic dynpro + ALV for administration; SAPUI5 for analytical dashboards.
- **Mass operations:** standardized around *download-template → fill → upload → execute*, implemented with XSLT transformations and `ALSMEX`-style Excel conversion.

---

## License

No license file is currently included in this repository. Treat the code as proprietary / internal unless a license is added by the repository owner.
