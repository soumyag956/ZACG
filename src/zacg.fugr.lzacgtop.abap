FUNCTION-POOL zacg.                         "MESSAGE-ID ..

TYPES:
  BEGIN OF ty_users_roles,
    bname	    TYPE xubname,
    agr_name  TYPE agr_name_c,
    child_agr	TYPE child_agr,
  END OF ty_users_roles.

DATA:
  v_free_wp        TYPE i,
  v_can_use        TYPE i,
  v_from           TYPE sy-tabix,
  v_to             TYPE sy-tabix,
  v_task           TYPE char10,
  v_call           TYPE i,
  v_receive        TYPE i,
  v_maxpost        TYPE i,
  v_local          TYPE flag,
  v_runid          TYPE sysuuid_x,
  v_perc           TYPE p DECIMALS 1 VALUE '0.9',
  v_filecount      TYPE i,
  v_fullpath       TYPE string,
  v_mod_fullpath   TYPE string,
  v_max_memory     TYPE abap_msize VALUE 1896198888,
  v_max_usr_memory TYPE abap_msize VALUE 758479555,
*  v_max_memory   TYPE abap_msize VALUE 98888,
  v_file           TYPE flag,
  v_xls_lines      TYPE i VALUE 400000,
  v_xls_usr_lines  TYPE i VALUE 250000,
  v_xls_max_lines  TYPE i VALUE 500000,

  i_summary        TYPE zacg_t_risk_summary,
  i_detail         TYPE zacg_t_risk_detail,
  i_solix          TYPE STANDARD TABLE OF solix,
  i_xml            TYPE STANDARD TABLE OF string,
  i_users_roles    TYPE STANDARD TABLE OF ty_users_roles.
