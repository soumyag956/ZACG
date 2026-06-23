FUNCTION zacg_risk_composite_simulation.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_SUMULATIONFILE) TYPE  LOCALFILE
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_LOCAL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_FILENAME) TYPE  STRING OPTIONAL
*"     VALUE(IV_FULLPATH) TYPE  STRING OPTIONAL
*"     VALUE(IT_LEVEL) TYPE  ZACG_T_LEVEL OPTIONAL
*"     VALUE(IT_MODULE) TYPE  ZACG_T_MODULE OPTIONAL
*"     VALUE(IV_PATH) TYPE  STRING OPTIONAL
*"  EXPORTING
*"     VALUE(ET_RISK_SUMMARY) TYPE  ZACG_T_RISK_SUMMARY
*"     VALUE(ET_RISK_DETAIL) TYPE  ZACG_T_RISK_DETAIL
*"     VALUE(EV_FILE) TYPE  FLAG
*"     VALUE(EV_MESSAGE) TYPE  BAPI_MSG
*"----------------------------------------------------------------------

  TYPES: BEGIN OF lty_comp,
           agr_name  TYPE agr_name_c,
           child_agr TYPE child_agr,
         END OF lty_comp.


  DATA:
    lv_maxpost    TYPE i,
    lv_setno      TYPE i,
    lv_length     TYPE i,
    lv_filename   TYPE string,

    lw_excel      TYPE alsmex_tabline,

    lr_comp       TYPE RANGE OF agr_name,

    li_comp_set   TYPE zacg_t_comp_set,
    li_comp_tmp   TYPE STANDARD TABLE OF lty_comp,
    li_xml_stream TYPE xml_rawdata,
    li_role_simu  TYPE STANDARD TABLE OF lty_comp,
    li_excel      TYPE STANDARD TABLE OF alsmex_tabline.


  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = iv_sumulationfile
      i_begin_col             = 1
      i_begin_row             = 2
      i_end_col               = 2
      i_end_row               = 9999
    TABLES
      intern                  = li_excel
    EXCEPTIONS
      inconsistent_parameters = 1
      upload_ole              = 2
      OTHERS                  = 3.
  IF sy-subrc IS INITIAL.

    LOOP AT li_excel INTO DATA(lw_excel1).
      lw_excel = lw_excel1.
      AT NEW row.
        APPEND INITIAL LINE TO li_role_simu ASSIGNING FIELD-SYMBOL(<lfs_role_simu>).
      ENDAT.
      ASSIGN COMPONENT lw_excel-col OF STRUCTURE <lfs_role_simu> TO FIELD-SYMBOL(<lfs_value>).
      IF <lfs_value> IS ASSIGNED.
        <lfs_value> = lw_excel-value.
      ENDIF.

      UNASSIGN <lfs_value>.
    ENDLOOP.

    SORT li_role_simu BY agr_name child_agr.
    DELETE ADJACENT DUPLICATES FROM li_role_simu COMPARING agr_name child_agr.

    lr_comp = VALUE #( FOR lw_role_simu IN  li_role_simu ( sign = 'I' option = 'EQ' low = lw_role_simu-agr_name  ) ).
    SORT lr_comp BY low.
    DELETE ADJACENT DUPLICATES FROM lr_comp COMPARING low.

    " Get Roles from Composite
    SELECT agr_name, child_agr
      FROM agr_agrs
      WHERE agr_name IN @lr_comp
        AND attributes = @space
    INTO TABLE @DATA(li_agr_agrs).
    IF sy-subrc IS INITIAL.
    ENDIF.

    APPEND LINES OF li_role_simu TO li_agr_agrs.

    SORT li_agr_agrs BY agr_name child_agr.
    DELETE ADJACENT DUPLICATES FROM li_agr_agrs COMPARING agr_name child_agr.

    lr_comp = VALUE #( FOR lw_role_simu IN  li_role_simu ( sign = 'I' option = 'EQ' low = lw_role_simu-agr_name  ) ).
    SORT lr_comp BY low.
    DELETE ADJACENT DUPLICATES FROM lr_comp COMPARING low.


  ENDIF.

  IF lr_comp IS NOT INITIAL.

    CLEAR: ev_file, v_file, v_local, v_filecount, v_fullpath, i_summary, i_detail.

    v_local     = iv_local.
    v_fullpath  = iv_fullpath.
    IF v_local IS NOT INITIAL.
      DATA(lo_guid_service) = NEW cl_nwdemo_service( ).
      v_runid =  lo_guid_service->create_uuid( ).
    ENDIF.

    CLEAR: et_risk_summary, et_risk_detail.

    LOOP AT lr_comp[] INTO DATA(lwa_comp).
      SELECT *
        FROM @li_agr_agrs AS composite
        WHERE agr_name = @lwa_comp-low
      INTO TABLE @DATA(li_comp).
      IF sy-subrc IS INITIAL.
        IF lv_maxpost < sy-dbcnt.
          lv_maxpost = sy-dbcnt.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT lr_comp[] INTO lwa_comp.

      SELECT *
        FROM @li_agr_agrs AS composite
        WHERE agr_name = @lwa_comp-low
      INTO TABLE @li_comp.

      IF lv_maxpost = sy-dbcnt.
        lv_setno = lv_setno + 1.
        LOOP AT li_comp INTO DATA(lwa_agr_agrs).
          APPEND INITIAL LINE TO li_comp_set ASSIGNING FIELD-SYMBOL(<lfs_comp_set>).
          <lfs_comp_set>-setno      = lv_setno.
          <lfs_comp_set>-agr_name   = lwa_agr_agrs-agr_name.
          <lfs_comp_set>-child_agr  = lwa_agr_agrs-child_agr.
        ENDLOOP.
      ELSEIF lv_maxpost > sy-dbcnt + lines( li_comp_tmp ).
        APPEND LINES OF li_comp TO li_comp_tmp.
        CONTINUE.
      ELSEIF lv_maxpost = sy-dbcnt + lines( li_comp_tmp ).
        lv_setno = lv_setno + 1.
        APPEND LINES OF li_comp TO li_comp_tmp.
        LOOP AT li_comp_tmp INTO DATA(lwa_comp1).
          APPEND INITIAL LINE TO li_comp_set ASSIGNING <lfs_comp_set>.
          <lfs_comp_set>-setno      = lv_setno.
          <lfs_comp_set>-agr_name   = lwa_comp1-agr_name.
          <lfs_comp_set>-child_agr  = lwa_comp1-child_agr.
        ENDLOOP.
        CLEAR: li_comp_tmp.
      ELSE.
        lv_setno = lv_setno + 1.
        LOOP AT li_comp_tmp INTO lwa_comp1.
          APPEND INITIAL LINE TO li_comp_set ASSIGNING <lfs_comp_set>.
          <lfs_comp_set>-setno      = lv_setno.
          <lfs_comp_set>-agr_name   = lwa_comp1-agr_name.
          <lfs_comp_set>-child_agr  = lwa_comp1-child_agr.
        ENDLOOP.
        CLEAR: li_comp_tmp.
        APPEND LINES OF li_comp TO li_comp_tmp.
      ENDIF.

    ENDLOOP.
    IF li_comp_tmp IS NOT INITIAL.
      lv_setno = lv_setno + 1.
      LOOP AT li_comp_tmp INTO lwa_comp1.
        APPEND INITIAL LINE TO li_comp_set ASSIGNING <lfs_comp_set>.
        <lfs_comp_set>-setno      = lv_setno.
        <lfs_comp_set>-agr_name   = lwa_comp1-agr_name.
        <lfs_comp_set>-child_agr  = lwa_comp1-child_agr.
      ENDLOOP.
      CLEAR: li_comp_tmp.
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

    CLEAR: v_task, v_call, v_receive.


    DO.

      IF v_file IS NOT INITIAL.
        ev_file = abap_true.
        EXIT.
      ENDIF.

      SELECT *
        FROM @li_comp_set AS comp_ins
        WHERE setno = @sy-index
      INTO TABLE @DATA(li_comp_roles).

      IF sy-subrc IS INITIAL.

        v_call = v_call + 1.
        v_task = |TASK_| & |{ v_call }|.

        DO.

          IF v_file IS NOT INITIAL.
            ev_file = abap_true.
            EXIT.
          ENDIF.

          IF v_can_use >= v_call - v_receive. " if call reach max limit of can use WP then wait for WP to free

            CALL FUNCTION 'ZACG_COMPOSITE_ROLES' STARTING NEW TASK v_task
              DESTINATION 'NONE'
              PERFORMING crole_collect ON END OF TASK
              EXPORTING
                it_comp_set           = li_comp_roles
                it_level              = it_level
                it_module             = it_module
                iv_summary            = iv_summary
                iv_detail             = iv_detail
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

        CLEAR li_comp_roles.

      ELSE.

        EXIT. " No More Role to Process

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

    et_risk_summary = i_summary.
    et_risk_detail  = i_detail.
    ev_file = v_file.

  ENDIF.

ENDFUNCTION.
