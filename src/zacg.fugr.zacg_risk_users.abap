FUNCTION zacg_risk_users.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_USER_ROLE) TYPE  ZACG_T_USER_ROLE OPTIONAL
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_LOCAL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_FILENAME) TYPE  STRING OPTIONAL
*"     VALUE(IV_FULLPATH) TYPE  STRING OPTIONAL
*"     VALUE(IT_LEVEL) TYPE  ZACG_T_LEVEL OPTIONAL
*"     VALUE(IT_MODULE) TYPE  ZACG_T_MODULE OPTIONAL
*"     VALUE(IV_PATH) TYPE  STRING OPTIONAL
*"     VALUE(IV_JOBNAME) TYPE  BTCJOB OPTIONAL
*"     VALUE(IV_JOBCOUNT) TYPE  BTCJOBCNT OPTIONAL
*"  EXPORTING
*"     VALUE(ET_RISK_SUMMARY) TYPE  ZACG_T_RISK_SUMMARY
*"     VALUE(ET_RISK_DETAIL) TYPE  ZACG_T_RISK_DETAIL
*"     VALUE(EV_FILE) TYPE  FLAG
*"     VALUE(EV_MESSAGE) TYPE  BAPI_MSG
*"----------------------------------------------------------------------

  DATA:
    lv_maxpost         TYPE i,
    lv_index           TYPE sy-tabix,
    lv_setno           TYPE i,
    lv_length          TYPE i,
    lv_filename        TYPE string,
    lv_fullpath        TYPE string,
    lv_xml             TYPE string,


    lw_srole_dtl       TYPE zacg_srole_dtl,

    li_fcat            TYPE lvc_t_fcat,
    lr_role            TYPE RANGE OF agr_name,
    lr_user            TYPE RANGE OF xubname,
    li_users_roles     TYPE STANDARD TABLE OF ty_users_roles,
    li_users_roles_tmp TYPE STANDARD TABLE OF ty_users_roles,
    li_users_set       TYPE zacg_t_user_set,
    li_xml_stream      TYPE xml_rawdata.


  CLEAR: ev_file, v_local, v_filecount, v_fullpath, v_file, i_summary, i_detail.

  v_local     = iv_local.
  v_fullpath  = iv_fullpath.
  IF v_local IS NOT INITIAL.
    DATA(lo_guid_service) = NEW cl_nwdemo_service( ).
    v_runid =  lo_guid_service->create_uuid( ).
  ENDIF.

  CLEAR i_users_roles.
  CLEAR: et_risk_summary, et_risk_detail, ev_file.

  DATA(lit_user_role) = it_user_role.

  lr_role = VALUE #( FOR lwa_user_role IN it_user_role ( sign = 'I' option = 'EQ' low = lwa_user_role-agr_name ) ).
  SORT lr_role BY low.
  DELETE ADJACENT DUPLICATES FROM lr_role COMPARING low.
  DELETE lr_role WHERE low IS INITIAL.
  IF lr_role IS NOT INITIAL.
    SELECT DISTINCT agr_name, child_agr
      FROM agr_agrs
      WHERE agr_name IN @lr_role
    ORDER BY agr_name
    INTO TABLE @DATA(lit_agr_name).
  ENDIF.

  LOOP AT lit_user_role ASSIGNING FIELD-SYMBOL(<lfs_user_role>).
    READ TABLE lit_agr_name TRANSPORTING NO FIELDS WITH KEY agr_name = <lfs_user_role>-agr_name BINARY SEARCH. " Check role is composite
    IF sy-subrc IS INITIAL.
      lv_index = sy-tabix.
      LOOP AT lit_agr_name INTO DATA(lwa_agr_name) FROM lv_index.
        IF lwa_agr_name-agr_name NE <lfs_user_role>-agr_name.
          EXIT.
        ELSE.
          "Populate child roles for identified composite roles
          APPEND INITIAL LINE TO li_users_roles ASSIGNING FIELD-SYMBOL(<lfs_users_roles>).
          <lfs_users_roles>-bname = <lfs_user_role>-bname.
          <lfs_users_roles>-agr_name = lwa_agr_name-agr_name.
          <lfs_users_roles>-child_agr = lwa_agr_name-child_agr.
        ENDIF.
      ENDLOOP.

      CLEAR <lfs_user_role>-bname.
    ENDIF.

    IF li_users_roles IS NOT INITIAL. " it will be not initial when chiled roles are filled for any composite role
      APPEND LINES OF li_users_roles TO i_users_roles.
    ELSE.

      " If role is single
      READ TABLE lit_agr_name TRANSPORTING NO FIELDS WITH KEY child_agr = <lfs_user_role>-agr_name. " check single role is not part of composite
      IF sy-subrc IS NOT INITIAL.

        " Single role is not part of composite check further the same role is alrady appended earlier
        READ TABLE i_users_roles TRANSPORTING NO FIELDS WITH KEY bname = <lfs_user_role>-bname
                                                                 child_agr = <lfs_user_role>-agr_name.
        IF sy-subrc IS NOT INITIAL.
          APPEND INITIAL LINE TO i_users_roles ASSIGNING <lfs_users_roles>.
          <lfs_users_roles>-bname     = <lfs_user_role>-bname.
          <lfs_users_roles>-child_agr = <lfs_user_role>-agr_name.
        ENDIF.
      ENDIF.

    ENDIF.

    CLEAR li_users_roles.

  ENDLOOP.
  DELETE lit_user_role WHERE bname IS INITIAL.


  CHECK i_users_roles IS NOT INITIAL.

  lr_user = VALUE #( FOR ls_user_role IN i_users_roles ( sign = 'I' option = 'EQ' low = ls_user_role-bname  ) ).
*  lr_user = VALUE #( FOR lwa_user_role IN  lit_user_role ( sign = 'I' option = 'EQ' low = lwa_user_role-bname  ) ).
  SORT lr_user BY low.
  DELETE ADJACENT DUPLICATES FROM lr_user COMPARING low.

  SELECT bname,
    COUNT( * ) AS max_count
    FROM @i_users_roles AS user
    GROUP BY bname
    ORDER BY max_count DESCENDING
    INTO TABLE @DATA(lit_mxcount).
  IF sy-subrc IS INITIAL.
    lv_maxpost = lit_mxcount[ 1 ]-max_count.
  ENDIF.

  LOOP AT lr_user INTO DATA(ls_user).

    SELECT *
      FROM @i_users_roles AS users_roles
      WHERE bname = @ls_user-low
      INTO TABLE @li_users_roles.

    IF lines( li_users_roles ) EQ lv_maxpost.
      lv_setno = lv_setno + 1.
      LOOP AT li_users_roles INTO DATA(lwa_users_roles).
        APPEND INITIAL LINE TO li_users_set ASSIGNING FIELD-SYMBOL(<lfs_users_set>).
        <lfs_users_set>-setno     = lv_setno.
        <lfs_users_set>-bname     = lwa_users_roles-bname.
        <lfs_users_set>-agr_name  = lwa_users_roles-agr_name.
        <lfs_users_set>-child_agr = lwa_users_roles-child_agr.
      ENDLOOP.
    ELSEIF ( lines( li_users_roles ) + lines( li_users_roles_tmp ) ) LT lv_maxpost.
      APPEND LINES OF li_users_roles TO li_users_roles_tmp.
    ELSEIF ( lines( li_users_roles ) + lines( li_users_roles_tmp ) ) EQ lv_maxpost.
      lv_setno = lv_setno + 1.
      APPEND LINES OF li_users_roles TO li_users_roles_tmp.
      LOOP AT li_users_roles_tmp INTO lwa_users_roles.
        APPEND INITIAL LINE TO li_users_set ASSIGNING <lfs_users_set>.
        <lfs_users_set>-setno     = lv_setno.
        <lfs_users_set>-bname     = lwa_users_roles-bname.
        <lfs_users_set>-agr_name  = lwa_users_roles-agr_name.
        <lfs_users_set>-child_agr = lwa_users_roles-child_agr.
      ENDLOOP.
      CLEAR li_users_roles_tmp.
    ELSEIF ( lines( li_users_roles ) + lines( li_users_roles_tmp ) ) GE lv_maxpost.
      lv_setno = lv_setno + 1.
      LOOP AT li_users_roles_tmp INTO lwa_users_roles.
        APPEND INITIAL LINE TO li_users_set ASSIGNING <lfs_users_set>.
        <lfs_users_set>-setno     = lv_setno.
        <lfs_users_set>-bname     = lwa_users_roles-bname.
        <lfs_users_set>-agr_name  = lwa_users_roles-agr_name.
        <lfs_users_set>-child_agr = lwa_users_roles-child_agr.
      ENDLOOP.
      CLEAR li_users_roles_tmp.
      li_users_roles_tmp = li_users_roles.
    ENDIF.

  ENDLOOP.

  IF li_users_roles_tmp IS NOT INITIAL.
    lv_setno = lv_setno + 1.
    LOOP AT li_users_roles_tmp INTO lwa_users_roles.
      APPEND INITIAL LINE TO li_users_set ASSIGNING <lfs_users_set>.
      <lfs_users_set>-setno     = lv_setno.
      <lfs_users_set>-bname     = lwa_users_roles-bname.
      <lfs_users_set>-agr_name  = lwa_users_roles-agr_name.
      <lfs_users_set>-child_agr = lwa_users_roles-child_agr.
    ENDLOOP.
    CLEAR li_users_roles_tmp.
  ENDIF.


  DO.
    CALL FUNCTION 'SPBT_INITIALIZE'
      IMPORTING
        free_pbt_wps                   = v_free_wp
      EXCEPTIONS
        invalid_group_name             = 1
        internal_error                 = 2
        pbt_env_already_initialized    = 3
        currently_no_resources_avail   = 4
        no_pbt_resources_found         = 5
        cant_init_different_pbt_groups = 6
        OTHERS                         = 7.
    IF sy-subrc EQ 0.
      v_can_use = v_free_wp * v_perc.
      EXIT.
    ELSEIF sy-subrc = 3.
      CALL FUNCTION 'SPBT_GET_CURR_RESOURCE_INFO' "try to get free work processes
        IMPORTING
          free_pbt_wps                = v_free_wp
        EXCEPTIONS
          internal_error              = 1
          pbt_env_not_initialized_yet = 2
          OTHERS                      = 3.
      IF sy-subrc IS INITIAL.
        v_can_use = v_free_wp * v_perc.
        EXIT.
      ELSE.
        EXIT.
      ENDIF.
    ENDIF.
  ENDDO.

  CLEAR: ev_file, v_file, v_task, v_call, v_receive, i_summary, i_detail.


  DO.

    IF v_file IS NOT INITIAL.
      ev_file = abap_true.
      EXIT.
    ENDIF.

    SELECT *
      FROM @li_users_set AS user_set
      WHERE setno = @sy-index
      INTO TABLE @DATA(li_users_set_tmp).

    IF sy-subrc IS NOT INITIAL.
      EXIT.
    ELSE.

      v_call = v_call + 1.
      v_task = |TASK_| & |{ v_call }|.

      DO.

        IF v_file IS NOT INITIAL.
          ev_file = abap_true.
          EXIT.
        ENDIF.

        IF v_can_use >= v_call - v_receive. " if call reach max limit of can use WP then wait for WP to free

          CALL FUNCTION 'ZACG_USERS_ROLES_SET' STARTING NEW TASK v_task
            DESTINATION 'NONE'
            PERFORMING user_collect ON END OF TASK
            EXPORTING
              it_users              = li_users_set_tmp
              it_level              = it_level
              it_module             = it_module
              iv_summary            = iv_summary
              iv_detail             = iv_detail
              iv_local              = iv_local
              iv_fullpath           = iv_fullpath
              iv_runid              = v_runid
              iv_filecount          = v_filecount
              iv_jobname            = iv_jobname
              iv_jobcount           = iv_jobcount
            EXCEPTIONS
              system_failure        = 1
              communication_failure = 2
              resource_failure      = 3
              OTHERS                = 4.
          IF sy-subrc IS INITIAL.
            EXIT.
          ELSE.
            WAIT UP TO 1 SECONDS. " Wait to call again since exception found while calling
          ENDIF.

        ELSE.
          WAIT UP TO 1 SECONDS. " Wait to call again as WP reach max permisible limit
          WAIT UNTIL v_receive >= v_call.
        ENDIF.

      ENDDO.

      CLEAR li_users_set_tmp.

    ENDIF.

  ENDDO.

  WAIT UNTIL v_receive >= v_call.


  IF v_runid IS NOT INITIAL.

    SELECT * FROM zacg_srole_dtl INTO TABLE @DATA(li_excel_data) WHERE runid = @v_runid.
    IF sy-subrc IS INITIAL.
      LOOP AT li_excel_data INTO DATA(lw_excel_data).

        CLEAR li_xml_stream.
        lv_filename = lw_excel_data-filepath.

        CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
          EXPORTING
            buffer        = lw_excel_data-content
          IMPORTING
            output_length = lv_length
          TABLES
            binary_tab    = li_xml_stream.

        CALL METHOD cl_gui_frontend_services=>gui_download
          EXPORTING
            bin_filesize = lv_length
            filetype     = 'BIN'
            filename     = lv_filename
          CHANGING
            data_tab     = li_xml_stream
          EXCEPTIONS
            OTHERS       = 1.
        IF sy-subrc IS INITIAL.
        ENDIF.

      ENDLOOP.

      DELETE FROM zacg_srole_dtl WHERE runid = v_runid.
      ev_message   = 'File successfully downloaded'.

    ENDIF.

  ENDIF.

  IF iv_jobname IS NOT INITIAL.
    CLEAR i_summary.
    SELECT bname
           composite
           agr_name
           risk
           riskd
           rlevel
           leveld
           type
           typed
           rmodule
           moduled
           sel
      FROM zacg_user_sum_bg
      INTO TABLE i_summary
      WHERE jobname = iv_jobname
        AND jobcount = iv_jobcount.
  ENDIF.

  et_risk_summary = i_summary.
  et_risk_detail  = i_detail.
  ev_file         = v_file.

ENDFUNCTION.
