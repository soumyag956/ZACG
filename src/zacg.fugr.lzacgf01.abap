*&---------------------------------------------------------------------*
*& Include          LZACGF01
*&---------------------------------------------------------------------*

FORM srole_collect USING taskname.

  DATA:
    lv_fullpath  TYPE string,
    lv_xml       TYPE string,
    lv_length    TYPE i,

    lw_srole_dtl TYPE zacg_srole_dtl,

    li_fcat      TYPE lvc_t_fcat,
    li_summary   TYPE zacg_t_risk_summary,
    li_detail    TYPE zacg_t_risk_detail.

  RECEIVE RESULTS FROM FUNCTION 'ZACG_ROLES'
    IMPORTING
      et_risk_summary       = li_summary
      et_risk_detail        = li_detail
    EXCEPTIONS
      system_failure        = 1
      communication_failure = 2
      OTHERS                = 3.
  IF sy-subrc IS INITIAL.
    APPEND LINES OF li_summary  TO i_summary.
    CLEAR li_summary.
    APPEND LINES OF li_detail   TO i_detail.
    CLEAR li_detail.
  ENDIF.

  v_receive = v_receive + 1.

  IF v_local IS NOT INITIAL.

    IF ( lines( i_detail ) GE v_xls_lines OR v_receive = v_call ).

      lv_fullpath = v_fullpath.

      IF v_filecount IS NOT INITIAL.
        v_filecount = v_filecount + 1.
      ELSE.
        IF lines( i_detail ) GE v_xls_lines.
          v_filecount = 1.
        ELSEIF v_receive = v_call.
          v_filecount = 1.
        ENDIF.
      ENDIF.

      IF v_filecount IS NOT INITIAL.
        DATA(lv_len) = strlen( lv_fullpath ).
        lv_len = lv_len - 5.
        lv_fullpath = lv_fullpath(lv_len).
        DATA(lv_count) = |({ v_filecount })|.
        CONDENSE lv_count NO-GAPS.
        lv_fullpath = |{ lv_fullpath }{ lv_count }.xlsx|.
        lw_srole_dtl-runid = v_runid.
        lw_srole_dtl-filepath = lv_fullpath.

        PERFORM convert_itab_to_xlsx USING 'S' CHANGING i_detail lw_srole_dtl-content.

        CLEAR: i_detail.

        lw_srole_dtl-cuser = sy-uname.
        lw_srole_dtl-cdate = sy-datum.
        lw_srole_dtl-ctime = sy-uzeit.
        MODIFY zacg_srole_dtl FROM lw_srole_dtl.
        CLEAR lw_srole_dtl.

      ENDIF.

    ENDIF.

  ELSE.

    cl_abap_memory_utilities=>get_total_used_size(
      IMPORTING
        size = DATA(ltp_size)                " Memory Size in Bytes
    ).

    IF ltp_size GE v_max_memory.
      v_file    = abap_true.
      v_receive = v_call.
      CLEAR: i_summary, i_detail.
    ENDIF.

  ENDIF.



ENDFORM.



FORM crole_collect USING taskname.

  DATA:
    lv_fullpath  TYPE string,
    lv_xml       TYPE string,
    lv_length    TYPE i,

    lw_srole_dtl TYPE zacg_srole_dtl,

    li_fcat      TYPE lvc_t_fcat,
    li_summary   TYPE zacg_t_risk_summary,
    li_detail    TYPE zacg_t_risk_detail.

  RECEIVE RESULTS FROM FUNCTION 'ZACG_COMPOSITE_ROLES'
    IMPORTING
      et_risk_summary       = li_summary
      et_risk_detail        = li_detail
    EXCEPTIONS
      system_failure        = 1
      communication_failure = 2
      OTHERS                = 3.
  IF sy-subrc IS INITIAL.
    APPEND LINES OF li_summary  TO i_summary.
    CLEAR li_summary.
    APPEND LINES OF li_detail   TO i_detail.
    CLEAR li_detail.
  ENDIF.

  v_receive = v_receive + 1.

  IF v_local IS NOT INITIAL.

    IF ( lines( i_detail ) GE v_xls_lines OR v_receive = v_call ).

      lv_fullpath = v_fullpath.

      IF v_filecount IS NOT INITIAL.
        v_filecount = v_filecount + 1.
      ELSE.
        IF lines( i_detail ) GE v_xls_lines.
          v_filecount = 1.
        ELSEIF v_receive = v_call.
          v_filecount = 1.
        ENDIF.
      ENDIF.

      IF v_filecount IS NOT INITIAL.
        DATA(lv_len) = strlen( lv_fullpath ).
        lv_len = lv_len - 5.
        lv_fullpath = lv_fullpath(lv_len).
        DATA(lv_count) = |({ v_filecount })|.
        CONDENSE lv_count NO-GAPS.
        lv_fullpath = |{ lv_fullpath }{ lv_count }.xlsx|.
        lw_srole_dtl-runid = v_runid.
        lw_srole_dtl-filepath = lv_fullpath.

        PERFORM convert_itab_to_xlsx USING 'C' CHANGING i_detail lw_srole_dtl-content.

        CLEAR: i_summary, i_detail.

        lw_srole_dtl-cuser = sy-uname.
        lw_srole_dtl-cdate = sy-datum.
        lw_srole_dtl-ctime = sy-uzeit.
        MODIFY zacg_srole_dtl FROM lw_srole_dtl.
        CLEAR lw_srole_dtl.
      ENDIF.

    ENDIF.

  ELSE.

    cl_abap_memory_utilities=>get_total_used_size(
      IMPORTING
        size = DATA(ltp_size)                " Memory Size in Bytes
    ).

    IF ltp_size GE v_max_memory.
      v_file    = abap_true.
      v_receive = v_call.
      CLEAR: i_summary, i_detail.
    ENDIF.

  ENDIF.

ENDFORM.

FORM user_collect USING taskname.


  DATA:
    lv_xml         TYPE string,
    lv_length      TYPE i,
    lv_maxuser     TYPE i,
    lv_setno       TYPE i,
    lv_jobname     TYPE btcjob,
    lv_jobcount    TYPE btcjobcnt,
    lv_date        TYPE erdat,

    lw_srole_dtl   TYPE zacg_srole_dtl,

    li_fcat        TYPE lvc_t_fcat,
    li_summary     TYPE zacg_t_risk_summary,
    li_detail      TYPE zacg_t_risk_detail,
    lit_detail     TYPE zacg_t_risk_detail,
    lit_detail_tmp TYPE zacg_t_risk_detail,
    lit_user_table TYPE STANDARD TABLE OF zacg_user_detail,
    li_user_sum_bg TYPE STANDARD TABLE OF zacg_user_sum_bg.

  RECEIVE RESULTS FROM FUNCTION 'ZACG_USERS_ROLES_SET'
    IMPORTING
      et_risk_summary       = li_summary
      et_risk_detail        = li_detail
      ev_file               = v_file
      ev_jobname            = lv_jobname
      ev_jobcount           = lv_jobcount
    EXCEPTIONS
      system_failure        = 1
      communication_failure = 2
      OTHERS                = 3.
  IF sy-subrc IS INITIAL.

    APPEND LINES OF li_summary  TO i_summary.
    CLEAR li_summary.
    APPEND LINES OF li_detail TO i_detail.
    CLEAR li_detail.

  ENDIF.

  IF sy-uname = 'KALLOL'.
*    DO.ENDDO.
  ENDIF.

  v_receive = v_receive + 1.

  IF v_local IS NOT INITIAL.

    CLEAR: i_summary, i_detail.

    SELECT *
      FROM zacg_user_detail
      INTO TABLE lit_user_table
      WHERE runid = v_runid.
    IF sy-subrc IS INITIAL.
      IF lines( lit_user_table ) GE v_xls_usr_lines OR v_receive = v_call.
        LOOP AT lit_user_table INTO DATA(lwa_user_table).
          APPEND INITIAL LINE TO i_detail ASSIGNING FIELD-SYMBOL(<lfs_detail>).
          <lfs_detail>-user       = lwa_user_table-bname.
          <lfs_detail>-composite  = lwa_user_table-composite.
          <lfs_detail>-agr_name   = lwa_user_table-agr_name.
          <lfs_detail>-risk       = lwa_user_table-risk.
          <lfs_detail>-riskd      = lwa_user_table-riskd.
          <lfs_detail>-func       = lwa_user_table-func.
          <lfs_detail>-funcd      = lwa_user_table-funcd.
          <lfs_detail>-tcode      = lwa_user_table-tcode.
          <lfs_detail>-object     = lwa_user_table-object.
          <lfs_detail>-field      = lwa_user_table-field.
          <lfs_detail>-low        = lwa_user_table-low.
        ENDLOOP.
        DELETE zacg_user_detail FROM TABLE lit_user_table.
        CLEAR lit_user_table.
      ELSE.
        CLEAR lit_user_table.
      ENDIF.
    ENDIF.

    IF i_detail IS NOT INITIAL.

      IF lines( i_detail ) GE v_xls_max_lines.

        SELECT user,
          COUNT( * ) AS max_count
          FROM @i_detail AS user
          GROUP BY user
          ORDER BY max_count DESCENDING
          INTO TABLE @DATA(lit_mxcount).
        IF sy-subrc IS INITIAL.
          lv_maxuser = lit_mxcount[ 1 ]-max_count.
          IF lv_maxuser LT v_xls_lines.
            lv_maxuser = v_xls_lines.
          ENDIF.
        ENDIF.
        SORT lit_mxcount BY max_count.


        LOOP AT lit_mxcount INTO DATA(lwa_mxcount).

          SELECT *
            FROM @i_detail AS per_user
            WHERE user = @lwa_mxcount-user
            INTO TABLE @lit_detail.

          IF lines( lit_detail ) EQ lv_maxuser.

            PERFORM convert_itab_to_xlsx USING 'U' CHANGING lit_detail lw_srole_dtl-content.


          ELSEIF lines( lit_detail ) + lines( lit_detail_tmp ) LT lv_maxuser.

            APPEND LINES OF lit_detail TO lit_detail_tmp.

          ELSEIF lines( lit_detail ) + lines( lit_detail_tmp ) EQ lv_maxuser.

            APPEND LINES OF lit_detail TO lit_detail_tmp.
            PERFORM convert_itab_to_xlsx USING 'U' CHANGING lit_detail_tmp lw_srole_dtl-content.
            CLEAR lit_detail_tmp.

          ELSEIF lines( lit_detail ) + lines( lit_detail_tmp ) GT lv_maxuser.

            IF lines( lit_detail ) > lines( lit_detail_tmp ).
              PERFORM convert_itab_to_xlsx USING 'U' CHANGING lit_detail lw_srole_dtl-content.
            ELSE.
              PERFORM convert_itab_to_xlsx USING 'U' CHANGING lit_detail_tmp lw_srole_dtl-content.
              lit_detail_tmp = lit_detail.
            ENDIF.

          ENDIF.

          IF lw_srole_dtl-content IS NOT INITIAL.

            DATA(lv_len) = strlen( v_fullpath ) - 5.
            DATA(lv_fullpath) = v_fullpath(lv_len).

            v_filecount = v_filecount + 1.
            DATA(lv_count) = |({ v_filecount })|.
            CONDENSE lv_count NO-GAPS.

            lv_fullpath = |{ lv_fullpath }{ lv_count }.xlsx|.

            lw_srole_dtl-runid    = v_runid.
            lw_srole_dtl-filepath = lv_fullpath.
            lw_srole_dtl-cuser    = sy-uname.
            lw_srole_dtl-cdate    = sy-datum.
            lw_srole_dtl-ctime    = sy-uzeit.
            MODIFY zacg_srole_dtl FROM lw_srole_dtl.
            CLEAR lw_srole_dtl.

          ENDIF.

        ENDLOOP.

        IF lit_detail_tmp IS NOT INITIAL.

          PERFORM convert_itab_to_xlsx USING 'U' CHANGING lit_detail_tmp lw_srole_dtl-content.

          lv_len = strlen( v_fullpath ) - 5.
          lv_fullpath = v_fullpath(lv_len).

          v_filecount = v_filecount + 1.
          lv_count = |({ v_filecount })|.
          CONDENSE lv_count NO-GAPS.

          lv_fullpath = |{ lv_fullpath }{ lv_count }.xlsx|.

          lw_srole_dtl-runid    = v_runid.
          lw_srole_dtl-filepath = lv_fullpath.
          lw_srole_dtl-cuser    = sy-uname.
          lw_srole_dtl-cdate    = sy-datum.
          lw_srole_dtl-ctime    = sy-uzeit.
          MODIFY zacg_srole_dtl FROM lw_srole_dtl.
          CLEAR lw_srole_dtl.

        ENDIF.


      ELSE.

        PERFORM convert_itab_to_xlsx USING 'U' CHANGING i_detail lw_srole_dtl-content.

        lv_len = strlen( v_fullpath ) - 5.
        lv_fullpath = v_fullpath(lv_len).

        v_filecount = v_filecount + 1.
        lv_count = |({ v_filecount })|.
        CONDENSE lv_count NO-GAPS.

        lv_fullpath = |{ lv_fullpath }{ lv_count }.xlsx|.

        lw_srole_dtl-runid    = v_runid.
        lw_srole_dtl-filepath = lv_fullpath.
        lw_srole_dtl-cuser    = sy-uname.
        lw_srole_dtl-cdate    = sy-datum.
        lw_srole_dtl-ctime    = sy-uzeit.
        MODIFY zacg_srole_dtl FROM lw_srole_dtl.
        CLEAR lw_srole_dtl.

      ENDIF.

    ENDIF.

  ELSE.

    cl_abap_memory_utilities=>get_total_used_size(
      IMPORTING
        size = DATA(ltp_size)                " Memory Size in Bytes
    ).

    IF lv_jobname IS INITIAL.

      IF v_file    = abap_true.
        v_receive = v_call.
        CLEAR: i_summary, i_detail.
      ENDIF.

      IF ltp_size GE v_max_usr_memory.
        v_file    = abap_true.
        v_receive = v_call.
        CLEAR: i_summary, i_detail.
      ENDIF.

    ELSE.

      " Store data in a staging table
      lv_date = sy-datum - 5.
      DELETE FROM zacg_user_sum_bg WHERE erdat LE lv_date.
      LOOP AT i_summary INTO DATA(lwa_summary).
        APPEND INITIAL LINE TO li_user_sum_bg ASSIGNING FIELD-SYMBOL(<lfs_user_sum_bg>).
        MOVE-CORRESPONDING lwa_summary TO <lfs_user_sum_bg>.
        <lfs_user_sum_bg>-jobname   = lv_jobname.
        <lfs_user_sum_bg>-jobcount  = lv_jobcount.
        <lfs_user_sum_bg>-bname     = lwa_summary-user.
        <lfs_user_sum_bg>-rlevel    = lwa_summary-level.
        <lfs_user_sum_bg>-rmodule   = lwa_summary-module.
        <lfs_user_sum_bg>-erdat     = sy-datum.
      ENDLOOP.
      MODIFY zacg_user_sum_bg FROM TABLE li_user_sum_bg.
      CLEAR: i_summary, li_user_sum_bg.

    ENDIF.

  ENDIF.

ENDFORM.

FORM convert_itab_to_xlsx USING v_type TYPE char1
                          CHANGING it_detail TYPE zacg_t_risk_detail
                                   wa_content TYPE xstring.

  DATA:
    lo_excel_structure      TYPE REF TO data,
    lo_source_table_descr   TYPE REF TO cl_abap_tabledescr,
    lo_table_row_descriptor TYPE REF TO cl_abap_structdescr.

  GET REFERENCE OF it_detail INTO lo_excel_structure.
  DATA(lo_itab_service) = cl_salv_itab_services=>create_for_table_ref( lo_excel_structure ).
  lo_source_table_descr ?= cl_abap_tabledescr=>describe_by_data_ref( lo_excel_structure ).
  lo_table_row_descriptor ?= lo_source_table_descr->get_table_line_type( ).

  DATA(lo_tool_xls) = cl_salv_export_tool_xls=>create_for_excel(
    EXPORTING
      r_data = lo_excel_structure ).

  DATA(lo_config) = lo_tool_xls->configuration( ).

  IF v_type = 'S'.

    lo_config->add_column(
      EXPORTING
        header_text  = 'Role name'
        field_name   = 'AGR_NAME'
        display_type = if_salv_bs_model_column=>uie_text_view ).

  ELSEIF v_type = 'C'.

    lo_config->add_column(
      EXPORTING
        header_text  = 'Composite Role'
        field_name   = 'COMPOSITE'
        display_type = if_salv_bs_model_column=>uie_text_view ).

    lo_config->add_column(
      EXPORTING
        header_text  = 'Single Role'
        field_name   = 'AGR_NAME'
        display_type = if_salv_bs_model_column=>uie_text_view ).

  ELSEIF v_type = 'U'.

    lo_config->add_column(
      EXPORTING
        header_text  = 'User ID'
        field_name   = 'USER'
        display_type = if_salv_bs_model_column=>uie_text_view ).

    lo_config->add_column(
      EXPORTING
        header_text  = 'Composite Role'
        field_name   = 'COMPOSITE'
        display_type = if_salv_bs_model_column=>uie_text_view ).

    lo_config->add_column(
      EXPORTING
        header_text  = 'Single Role'
        field_name   = 'AGR_NAME'
        display_type = if_salv_bs_model_column=>uie_text_view ).

  ENDIF.

  lo_config->add_column(
    EXPORTING
      header_text  = 'Risk Id'
      field_name   = 'RISK'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  lo_config->add_column(
    EXPORTING
      header_text  = 'Risk Description'
      field_name   = 'RISKD'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  lo_config->add_column(
    EXPORTING
      header_text  = 'Function Id'
      field_name   = 'FUNC'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  lo_config->add_column(
    EXPORTING
      header_text  = 'Function Description'
      field_name   = 'FUNCD'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  lo_config->add_column(
    EXPORTING
      header_text  = 'Transaction / Service'
      field_name   = 'TCODE'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  lo_config->add_column(
    EXPORTING
      header_text  = 'Object'
      field_name   = 'OBJECT'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  lo_config->add_column(
    EXPORTING
      header_text  = 'Field'
      field_name   = 'FIELD'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  lo_config->add_column(
    EXPORTING
      header_text  = 'Low'
      field_name   = 'LOW'
      display_type = if_salv_bs_model_column=>uie_text_view ).

  TRY.
      lo_tool_xls->read_result( IMPORTING content = wa_content ).
    CATCH cx_root.
  ENDTRY.

ENDFORM.
