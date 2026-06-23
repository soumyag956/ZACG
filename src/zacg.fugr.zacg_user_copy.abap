FUNCTION zacg_user_copy.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IT_USERS) TYPE  ZACG_T_COPY_USER
*"  EXPORTING
*"     REFERENCE(ET_USERS) TYPE  ZACG_T_COPY_USER
*"----------------------------------------------------------------------

  DATA:

    lw_logondata      TYPE bapilogond,
    lw_defaults       TYPE bapidefaul,
    lw_address        TYPE bapiaddr3,
    lw_company        TYPE bapiuscomp,
    lw_password       TYPE bapipwd,

    li_parameter      TYPE STANDARD TABLE OF bapiparam,
    li_profiles       TYPE STANDARD TABLE OF bapiprof,
    li_activitygroups TYPE STANDARD TABLE OF bapiagr,
    li_return         TYPE STANDARD TABLE OF bapiret2,
    li_parameter1     TYPE STANDARD TABLE OF bapiparam1,
    li_groups         TYPE STANDARD TABLE OF bapigroups.


  LOOP AT it_users INTO DATA(lw_users).

    APPEND INITIAL LINE TO et_users ASSIGNING FIELD-SYMBOL(<lfs_users>).
    <lfs_users> = lw_users.

    CLEAR: lw_logondata, lw_defaults, lw_address, lw_company, lw_password,
           li_parameter, li_profiles, li_activitygroups, li_return, li_parameter1, li_groups.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username       = lw_users-from_user
        cache_results  = ' '
      IMPORTING
        logondata      = lw_logondata
        defaults       = lw_defaults
        address        = lw_address
        company        = lw_company
      TABLES
        parameter      = li_parameter
        profiles       = li_profiles
        activitygroups = li_activitygroups
        return         = li_return
        parameter1     = li_parameter1
        groups         = li_groups.

    READ TABLE li_return INTO DATA(lw_return) WITH KEY
    type = 'E'.
    IF sy-subrc IS INITIAL.
      <lfs_users>-icon    = '@02@'.
      <lfs_users>-message = lw_return-message.
      CONTINUE.
    ENDIF.

    CLEAR: lw_address, lw_password, li_return.
    lw_address-lastname = lw_users-to_user.
    lw_address-fullname = lw_users-to_user.

    lw_logondata-ltime    = abap_false.
    lw_logondata-bcode    = abap_false.
    lw_logondata-codvn    = abap_true.
    lw_logondata-passcode = abap_false.

    CALL FUNCTION 'BAPI_USER_CREATE1'
      EXPORTING
        username   = lw_users-to_user
        logondata  = lw_logondata
        password   = lw_password
        defaults   = lw_defaults
        address    = lw_address
        company    = lw_company
      TABLES
        parameter  = li_parameter
        return     = li_return
        groups     = li_groups
        parameter1 = li_parameter1.

    CLEAR lw_return.
    READ TABLE li_return INTO lw_return WITH KEY
    type = 'E'.
    IF sy-subrc IS INITIAL.
      <lfs_users>-icon    = '@02@'.
      <lfs_users>-message = lw_return-message.
      CONTINUE.
    ELSE.
      READ TABLE li_return INTO lw_return WITH KEY
      type = 'S'.
      IF sy-subrc IS INITIAL.
        <lfs_users>-icon    = '@01@'.
        <lfs_users>-message = lw_return-message.
      ENDIF.
    ENDIF.

    CLEAR li_return.
    CALL FUNCTION 'BAPI_USER_PROFILES_ASSIGN'
      EXPORTING
        username = lw_users-to_user
      TABLES
        profiles = li_profiles
        return   = li_return.


    CLEAR li_return.
    CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
      EXPORTING
        username       = lw_users-to_user
      TABLES
        activitygroups = li_activitygroups
        return         = li_return.

    CLEAR lw_return.
    READ TABLE li_return INTO lw_return WITH KEY
    type = 'E'.
    IF sy-subrc IS INITIAL.
      <lfs_users>-icon    = '@1A@'.
      <lfs_users>-message = lw_return-message.
    ENDIF.


  ENDLOOP.




ENDFUNCTION.
