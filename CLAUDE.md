# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**ZACG (Access Control Guard)** is an in-house SAP ABAP security / access-governance suite — effectively a self-built alternative to SAP GRC Access Control. It is delivered as an **[abapGit](https://abapgit.org) export**: every object lives as a flat file under `src/` named `<object>.<type>.<ext>` (e.g. `zacg_mainf01.prog.abap`, `zcl_zacg_dpc_ext.clas.abap`). There is no local build, test, or lint tooling in the repo.

## Working in this repo (no local toolchain)

- **There is nothing to build/run/test locally.** ABAP cannot be compiled here. Changes are validated only after being pulled into an SAP NetWeaver AS ABAP system via abapGit and activated (SE80/ADT). State this caveat when reporting that a change "works".
- **Deploy:** install abapGit on the target system, clone this repo into package `ZACG`, pull, and activate all objects. Gateway (for `ZACG_SRV` + Fiori apps), SAP Business Workflow, and the standard `AGR_*` / `BAPI_USER_*` / `PRGN_*` / `SUSR_*` APIs must be present.
- **No `.abapgit.xml`** is committed, so set the package and `src/` starting folder in abapGit at clone time.
- **Editing:** match the existing style. The code mixes classic procedural ABAP with modern 7.40+ syntax (inline `DATA(...)`, `VALUE #( )`, string templates) — both are acceptable since the codebase already relies on 7.40+.
- When matching/replacing header stubs, note that the `*& Form <name>` comment line is often a **wrong copy-paste** of a different form's name; anchor edits on the real `FORM <name>` statement, not the comment.

## Entry points

| Object | Role |
|---|---|
| Transaction `ZACG` → report `ZACG_MAIN` (dynpro 1000) | The whole tool. A tree menu drives dozens of dynpros. |
| `ZACG_ROLE_ASSIGNMENT` | Assign roles (manual/file) + trigger the request workflow. Also SUBMITted as a background job by the workflow. |
| `ZACG_DASHBOARD` | Batch: builds SoD/critical-access analytics into `ZACG_DASHBOARD`. |
| `ZACG_FFID_LOGOUT` | Batch: reconciles/closes firefighter (FFID) sessions. |
| `ZACG_TCODE_USAGE_BATCH`, `ZACG_TLOG_BATCH` | Batch: usage / FFID transaction-log collectors. |
| `ZACG_UPD_CONFIG` | Maintain config (risk library, rule sets, role/mitigation owners, line managers). |
| OData `ZACG_SRV` (`ZCL_ZACG_DPC_EXT` / `ZCL_ZACG_MPC_EXT`) | Feeds the `zacgdashboard` / `zsecrtdashboard` SAPUI5 apps. |

## Architecture (the big picture)

`ZACG_MAIN` is the hub. Its logic is overwhelmingly procedural and concentrated in **one ~18.6k-line include, `zacg_mainf01.prog.abap`** (~175 `FORM` routines). The other `zacg_main*` includes follow the standard report split: `*TOP` (global data/types), `*S01` (selection screens 0001–0017+ as subscreens), `*DEF`/`*IMP` (local classes `lcl_acg`, `lcl_acg_tree`, `lcl_event_receiver`), `*O01` (PBO), `*I01` (PAI), `*H01` (helpers). Most real work happens in `FORM`s called from PAI, not in the local classes.

Functional flows (all inside `zacg_mainf01` unless noted):

- **User admin & passwords:** `create_user` (BAPI_USER_CREATE1 + commit), `set_reset_password_mass`/`_manual`, `set_prod_password_mass`, `lock_user`/`show_lock_user_report`, `update_user_details`. Password resets/locks e-mail the user via `CL_BCS`.
- **Role maintenance (template-driven):** `change_description_of_roles`, `derive_role_create`, `delete_inheritance`, `add_single_role_to_composite`, `remove_single_from_composite`, `delete_roles`, `push_master_role`, `create_composite_role` (BDC via `bdc_dynpro`/`bdc_field`), `create_role_copy`. These wrap `PRGN_*` / `SUPRN_*` function modules.
- **Mass authorization-value maintenance:** `maintain_auth_values` (dispatcher, uses the PFCG role API `IF_PFCG_ROLE`) → `maintain_add_*` / `maintain_del_*` / `maintain_dct_*` / `maintain_act_*`.
- **Access-request workflow with SoD risk analysis:** request creation (`raise_new_request`, `raise_bulk_request`, number ranges `ZACG_RREQ`/`ZACG_BREQ`/`ZACG_CREQ`) → approver rows in `ZACG_REQ_APROVER` → risk-analysis grid (screen 8007) → `approve_after_risk_analysis` / `reject_after_risk_anaysis` → mitigation (`ZACG_MITG_LOG`) → workflow object **`ZACG_CL_WF_ROLE_ASSIGNMENT`** (BI_OBJECT/IF_WORKFLOW; 21 PDTS tasks) which finally calls `ASSIGN_ROLE` to schedule `ZACG_ROLE_ASSIGNMENT`. Notifications go through `ZACG_NOTIFY_USERS_FOR_ROLE_REQ` (actions `RQ`/`RA`/`RR`).
- **Firefighter / emergency access (FFID):** `emergency_login` (RFC_PING + SYSTEM_REMOTE_LOGIN, logs to `ZACG_FFID_LOG`), `emergency_logout` (TH_DELETE_USER), tables `ZACG_FFID_HDR`/`_LOG`/`_TLOG`.
- **Dashboards:** `ZACG_DASHBOARD` writes results into table `ZACG_DASHBOARD` keyed by the background job; `ZCL_ZACG_DPC_EXT` reads the latest *finished* job (TBTCO status 'F') for each SoD/critical entity set.

### Recurring conventions worth knowing

- **Excel templates everywhere.** Most mass operations are *download template → fill → upload → execute*. Templates are generated by **XSLT transformations** (`ZACG_*_TEM`, `ZSEC_XSLT_*`); uploads are parsed with `ALSM_EXCEL_TO_INTERNAL_TABLE` (function groups `ZACG_ALSMEX` / `YALSMEX`). Each upload has a `p_<x>_validate` selection-screen FORM that checks the file extension and exact header-row labels and clears `sy-ucomm`/`g_ucomm` to block execution on failure.
- **Screen-numbered helpers.** Naming is `show_<nnnn>` (PBO display), `show_result_<nnnn>` (ALV of a result table), `get_data_<nnnn>` (read-only retrieval), `user_command_<nnnn>` (PAI), `validate_<nnnn>`. Result tables are global `gt_*` / `i_outtab_<nnnn>`; ALV containers are `o_conttainer_<nnnn>` / `o_grid_<nnnn>` (note the typo `conttainer`).
- **Authorization:** transaction is guarded by `Z_ZACG_ADM`; the tree builds object names dynamically as `'ZACG_' && <node-key>` and checks `ACTVT = '16'` (`authority_check`). There are ~38 `ZACG_*` auth objects, one per function.
- **Generated vs custom OData classes:** `ZCL_ZACG_DPC` / `ZCL_ZACG_MPC` are Gateway-generated (do not hand-edit); custom logic lives in the `_EXT` subclasses.
- **Namespace/language:** objects are `ZACG_*` (a few `Z*`/`Y*` helpers); master language is English. Many user-facing strings are hardcoded English literals despite message class `ZACG` existing.

## Known issues / landmines (do not reintroduce)

- **BAPI commits:** `BAPI_USER_*` functions do **not** commit. Routines that write users/roles must call `BAPI_TRANSACTION_COMMIT` (fixed in `create_user`, `assign_roles`, `man_role_ass`, `file_role_ass`). Use `READ TABLE … INDEX 1` + `sy-subrc`, never unguarded `lt_return[ 1 ]` (raises `CX_SY_ITAB_LINE_NOT_FOUND`).
- **`ZACG_ENCRIPT_PROG`** is a program-hiding tool (hardcoded password `'P@SSW0RD1'`, native `EXEC SQL UPDATE D010SINF`). It is a security red flag and a deletion candidate — do not extend it.
- **Hardcoded sender e-mail** `arnab.bhaduri@pwc.com` appears in the password/lock routines; passwords are e-mailed in clear text. The OData data provider (`ZCL_ZACG_DPC_EXT`) has **no `AUTHORITY-CHECK`**.
- `ZACG_FFID_LOGOUT` only sees the local app-server's sessions (`cl_server_info`), so it can wrongly close FFID sessions on other instances.
- `ASSIGN_ROLE` in the workflow class ends with a `WHILE … = sy-dbcnt` busy-wait with no timeout.
- `set_prod_password_manual` and `update_rejection_from_manager` are empty/commented-out no-ops; `ZDEMO_CLASS` is an empty placeholder.

## Git

Develop on branch `claude/compassionate-hawking-uwjvj3` (or as instructed). Commit/push only when asked; never open a PR unless explicitly requested.
