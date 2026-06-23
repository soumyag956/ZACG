FUNCTION zacg_risk_roles.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_ROLE) TYPE  ZT_ROLE
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

  DATA:

    lv_length     TYPE i,
    lv_filename   TYPE string,

    lr_role       TYPE RANGE OF agr_name,

    li_role       TYPE zt_role,
    li_xml_stream TYPE xml_rawdata.


  CLEAR: ev_file, v_file, v_local, v_filecount, v_fullpath, i_summary, i_detail.

  v_local     = iv_local.
  v_fullpath  = iv_fullpath.
  IF v_local IS NOT INITIAL.
    DATA(lo_guid_service) = NEW cl_nwdemo_service( ).
    v_runid =  lo_guid_service->create_uuid( ).
  ENDIF.

  CLEAR: et_risk_summary, et_risk_detail.

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

  CLEAR: v_from, v_to, v_task, v_call, v_receive.
  v_from = 1.
  v_to   = 10.

  DO.


    IF v_file IS NOT INITIAL.
      ev_file = abap_true.
      EXIT.
    ENDIF.

    v_task = sy-index.

    CLEAR li_role.
    APPEND LINES OF it_role FROM v_from TO v_to TO li_role.
    lr_role = VALUE #( FOR lw_role IN li_role ( sign = 'I' option = 'EQ' low = lw_role-agr_name ) ).

    IF lr_role IS NOT INITIAL.

      v_call = v_call + 1.
      v_task = |TASK_| & |{ v_call }|.

      DO.

        IF v_file IS NOT INITIAL.
          ev_file = abap_true.
          EXIT.
        ENDIF.

        IF v_can_use >= v_call - v_receive. " if call reach max limit of can use WP then wait for WP to free

          CALL FUNCTION 'ZACG_ROLES' STARTING NEW TASK v_task
            DESTINATION 'NONE'
            PERFORMING srole_collect ON END OF TASK
            EXPORTING
              it_role               = lr_role
              iv_summary            = iv_summary
              iv_detail             = iv_detail
              it_level              = it_level
              it_module             = it_module
            EXCEPTIONS
              system_failure        = 1
              communication_failure = 2
              resource_failure      = 3
              OTHERS                = 4.
          IF sy-subrc IS INITIAL.
            v_from = v_to + 1.
            v_to   = v_to + 10.
            EXIT.
          ELSE.
            WAIT UP TO 1 SECONDS. " Wait to call again since exception found while calling
          ENDIF.

        ELSE.

          WAIT UP TO 1 SECONDS. " Wait to call again as WP reach max permisible limit
          WAIT UNTIL v_receive >= v_call.
        ENDIF.

      ENDDO.

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

ENDFUNCTION.
