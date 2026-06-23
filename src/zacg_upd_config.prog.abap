*&---------------------------------------------------------------------*
*& Report ZACG_UPD_CONFIG
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zacg_upd_config.

CONSTANTS : co_trans_fmst TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_FUNC_MAST',
            co_trans_fval TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_PERM_VAL',
            co_trans_lman TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_LINE_MAN',
            co_trans_mown TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_MITG_OWN',
            co_trans_rcom TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_RISK_COMB',
            co_trans_tcom TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_TAB_COMB',
            co_trans_rlib TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_RISK_LIB',
            co_trans_rmst TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_RISK_MAST',
            co_trans_rown TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_ROLE_OWN',
            co_trans_rset TYPE cxsltdesc VALUE 'ZACG_UPD_CONF_FUE_RULE_SET',
            co_file_fmst  TYPE string VALUE '/Upload Function Master.xls',
            co_file_fval  TYPE string VALUE '/Upload Permissible Values.xls',
            co_file_lman  TYPE string VALUE '/Upload Line Manager.xls',
            co_file_mown  TYPE string VALUE '/Upload Mitigation Owner.xls',
            co_file_rcom  TYPE string VALUE '/Upload Risk Combination.xls',
            co_file_rlib  TYPE string VALUE '/Upload Risk Library.xls',
            co_file_rmst  TYPE string VALUE '/Upload Risk Master.xls',
            co_file_rown  TYPE string VALUE '/Upload Risk Owner.xls',
            co_file_rset  TYPE string VALUE '/Upload FUE Rule Set.xls'.

DATA: gv_rc          TYPE i,
      gv_ucomm       TYPE sy-ucomm,
      git_file_table TYPE filetable,
      git_excel      TYPE STANDARD TABLE OF zacg_alsmex_tabline.

SELECTION-SCREEN : BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.

  PARAMETERS: r_rmst RADIOBUTTON GROUP gr1,
              r_fmst RADIOBUTTON GROUP gr1,
              r_rlib RADIOBUTTON GROUP gr1,
              r_rcom RADIOBUTTON GROUP gr1,
              r_tcom RADIOBUTTON GROUP gr1,
              r_fval RADIOBUTTON GROUP gr1,
              r_rown RADIOBUTTON GROUP gr1,
              r_mown RADIOBUTTON GROUP gr1,
              r_lman RADIOBUTTON GROUP gr1,
              r_rset RADIOBUTTON GROUP gr1,
              p_file TYPE localfile.

SELECTION-SCREEN : END OF BLOCK b1.

SELECTION-SCREEN: BEGIN OF LINE,
PUSHBUTTON 5(20) TEXT-001 USER-COMMAND dwn_temp.
SELECTION-SCREEN: END OF LINE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title = 'Select a file'
    CHANGING
      file_table   = git_file_table
      rc           = gv_rc.
  IF sy-subrc = 0.
    READ TABLE git_file_table INTO DATA(lwa_file_table) INDEX 1.
    p_file = lwa_file_table-filename.
  ENDIF.

AT SELECTION-SCREEN.
  gv_ucomm = sy-ucomm.
  IF gv_ucomm EQ 'ONLI'.
    PERFORM validate_file.
  ELSEIF gv_ucomm EQ 'DWN_TEMP'.
    PERFORM download_template.
  ENDIF.

START-OF-SELECTION.
  PERFORM update.

*&---------------------------------------------------------------------*
*& Form validate_file
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_file .

  DATA:
    lv_begin_col TYPE  i VALUE 1,
    lv_begin_row TYPE  i VALUE 1,
    lv_end_col   TYPE  i,
    lv_end_row   TYPE  i VALUE 99999.

  IF gv_ucomm = 'ONLI'.

    IF r_rmst = abap_true.
      lv_end_col = 4.
    ELSEIF r_fmst = abap_true.
      lv_end_col = 2.
    ELSEIF r_rlib = abap_true.
      lv_end_col = 7.
    ELSEIF r_rcom = abap_true.
      lv_end_col = 4.
    ELSEIF r_fval = abap_true.
      lv_end_col = 3.
    ELSEIF r_rown = abap_true.
      lv_end_col = 3.
    ELSEIF r_mown = abap_true.
      lv_end_col = 1.
    ELSEIF r_lman = abap_true.
      lv_end_col = 3.
    ELSEIF r_rset = abap_true.
      lv_end_col = 5.
    ENDIF.

    CALL FUNCTION 'ZACG_ALSM_EXCEL_TO_INT_TAB'
      EXPORTING
        filename                = p_file
        i_begin_col             = lv_begin_col
        i_begin_row             = lv_begin_row
        i_end_col               = lv_end_col
        i_end_row               = lv_end_row
      TABLES
        intern                  = git_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT git_excel INTO DATA(lwa_excel).

        IF lwa_excel-row = '0002'.
          EXIT.
        ENDIF.

        IF r_rmst = abap_true.

          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Risk ID'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Description'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value NE 'Level'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0004'.
              IF lwa_excel-value NE 'Module'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.

        ELSEIF r_fmst = abap_true.

          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Function ID'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Description'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.

        ELSEIF r_rlib = abap_true.
          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Function ID'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Transaction'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value NE 'Auth Object'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0004'.
              IF lwa_excel-value NE 'Field'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0005'.
              IF lwa_excel-value NE 'Field Value - Low'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0006'.
              IF lwa_excel-value NE 'Field Value - High'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0007'.
              IF lwa_excel-value NE 'Inactive'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.
        ELSEIF r_rcom = abap_true.
          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Risk ID'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Function1'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value NE 'Function2'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0004'.
              IF lwa_excel-value NE 'Function3'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.
        ELSEIF r_fval = abap_true.
          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Auth Object'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Field'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value NE 'Permissible value'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0004'.
              IF lwa_excel-value NE 'Text'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.

        ELSEIF r_rown = abap_true.
          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Role Name'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Role Owner'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value NE 'Bulk Role Owner'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.

        ELSEIF r_mown = abap_true.
          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Mitigation Owner'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.

        ELSEIF r_lman = abap_true.
          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'User'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Line Manager'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value NE 'Bulk Line Manager'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
          ENDCASE.
        ELSEIF r_rset = abap_true.
          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'Priority'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Rule Description'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value NE 'Auth. Object'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0004'.
              IF lwa_excel-value NE 'Auth. Field'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN '0005'.
              IF lwa_excel-value NE 'Auth. Value'.
                CLEAR: sy-ucomm, gv_ucomm.
                EXIT.
              ENDIF.
            WHEN OTHERS.
          ENDCASE.
        ENDIF.
      ENDLOOP.

      IF gv_ucomm IS INITIAL.
        MESSAGE 'Please provide valid File' TYPE 'E'.
      ENDIF.

    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form update
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM update.

  TYPES : BEGIN OF lty_rule_set,
            priority  TYPE zacg_rule_prio,
            rule_desc	TYPE zacg_rule_desc,
            object    TYPE agobject,
            field     TYPE agrfield,
            value	    TYPE agval,
          END OF lty_rule_set.
  DATA: lv_col           TYPE i,
        lv_assign        TYPE i,
        lwa_excel        TYPE zacg_alsmex_tabline,
        lit_risk_mst     TYPE STANDARD TABLE OF zacg_risk_mstr,
        lit_func_mst     TYPE STANDARD TABLE OF zacg_funct,
        lit_risk_lib     TYPE STANDARD TABLE OF zacg_risk_lib,
        lit_risk_com     TYPE STANDARD TABLE OF zacg_risk_comb,
        lit_obj_fval     TYPE STANDARD TABLE OF zacg_obj_fval,
        lit_role_own     TYPE STANDARD TABLE OF zacg_role_owners,
        lit_mit_own      TYPE STANDARD TABLE OF zacg_mitg_owners,
        lit_line_manager TYPE STANDARD TABLE OF zacg_manager,
        lit_rule_set_t   TYPE STANDARD TABLE OF lty_rule_set,
        lit_rule_set     TYPE STANDARD TABLE OF zacg_fue_rul_set.


  IF gv_ucomm = 'ONLI'.

    IF r_rmst = abap_true.

      LOOP AT git_excel INTO DATA(lwa_excel1).
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_risk_mst ASSIGNING FIELD-SYMBOL(<lfs_risk_mst>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col + 1 OF STRUCTURE <lfs_risk_mst> TO FIELD-SYMBOL(<lfs_value>).
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      DELETE lit_risk_mst INDEX 1.
      IF lit_risk_mst IS NOT INITIAL.
        DELETE FROM zacg_risk_mstr.
        MODIFY zacg_risk_mstr FROM TABLE lit_risk_mst.
        COMMIT WORK AND WAIT.
        MESSAGE 'Risk Master data successfully updated' TYPE 'S'.
      ENDIF.

    ELSEIF r_fmst = abap_true.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_func_mst ASSIGNING FIELD-SYMBOL(<lfs_func_mst>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col + 1 OF STRUCTURE <lfs_func_mst> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      DELETE lit_func_mst INDEX 1.
      IF lit_func_mst IS NOT INITIAL.
        DELETE FROM zacg_funct.
        MODIFY zacg_funct FROM TABLE lit_func_mst.
        COMMIT WORK AND WAIT.
        MESSAGE 'Function Master data successfully updated' TYPE 'S'.
      ENDIF.

    ELSEIF r_rlib = abap_true.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_risk_lib ASSIGNING FIELD-SYMBOL(<lfs_risk_lib>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col + 1 OF STRUCTURE <lfs_risk_lib> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      DELETE lit_risk_lib INDEX 1.
      IF lit_risk_lib IS NOT INITIAL.
        DELETE FROM zacg_risk_lib.
        MODIFY zacg_risk_lib FROM TABLE lit_risk_lib.
        COMMIT WORK AND WAIT.
        MESSAGE 'Risk Library successfully updated' TYPE 'S'.
      ENDIF.

    ELSEIF r_rcom = abap_true.

      READ TABLE git_excel TRANSPORTING NO FIELDS WITH KEY row = '0002'.
      DELETE git_excel FROM 1 TO sy-tabix - 1.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_risk_com ASSIGNING FIELD-SYMBOL(<lfs_risk_com>).
        ENDAT.

        lv_assign = lwa_excel-col + 1.
        IF lwa_excel-col > 2.
          READ TABLE lit_risk_com INTO DATA(lwa_risk_com) INDEX lines( lit_risk_com ).
          APPEND INITIAL LINE TO lit_risk_com ASSIGNING <lfs_risk_com>.
          <lfs_risk_com>-risk = lwa_risk_com-risk.
          lv_assign = 3.
        ENDIF.

        ASSIGN COMPONENT lv_assign OF STRUCTURE <lfs_risk_com> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        lv_col = lwa_excel-col.

        UNASSIGN <lfs_value>.
      ENDLOOP.
      LOOP AT lit_risk_com ASSIGNING <lfs_risk_com>.
        ON CHANGE OF <lfs_risk_com>-risk.
          CLEAR lwa_risk_com.
          READ TABLE lit_risk_com INTO lwa_risk_com INDEX sy-tabix + 1.
          IF lwa_risk_com-risk NE <lfs_risk_com>-risk.
            <lfs_risk_com>-crit = abap_true.
          ENDIF.
        ENDON.
      ENDLOOP.

      IF lit_risk_com IS NOT INITIAL.
        DELETE FROM zacg_risk_comb.
        MODIFY zacg_risk_comb FROM TABLE lit_risk_com.
        COMMIT WORK AND WAIT.
        MESSAGE 'Risk combination successfully updated' TYPE 'S'.
      ENDIF.

    ELSEIF r_tcom = abap_true..

    ELSEIF r_fval = abap_true.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_obj_fval ASSIGNING FIELD-SYMBOL(<lfs_obj_fval>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col + 1 OF STRUCTURE <lfs_obj_fval> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      IF lit_obj_fval IS NOT INITIAL.
        DELETE FROM zacg_obj_fval.
        MODIFY zacg_obj_fval FROM TABLE lit_obj_fval.
        COMMIT WORK AND WAIT.
        MESSAGE 'Permisible values successfully updated' TYPE 'S'.
      ENDIF.


    ELSEIF r_rown = abap_true.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_role_own ASSIGNING FIELD-SYMBOL(<lfs_role_own>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col + 1 OF STRUCTURE <lfs_role_own> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      DELETE lit_role_own INDEX 1.
      IF lit_role_own IS NOT INITIAL.
        DELETE FROM zacg_role_owners.
        MODIFY zacg_role_owners FROM TABLE lit_role_own.
        COMMIT WORK AND WAIT.
        MESSAGE 'Role Owners successfully updated' TYPE 'S'.
      ENDIF.

    ELSEIF r_mown = abap_true.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_mit_own ASSIGNING FIELD-SYMBOL(<lfs_mit_own>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col + 1 OF STRUCTURE <lfs_mit_own> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      DELETE lit_mit_own INDEX 1.
      IF lit_mit_own IS NOT INITIAL.
        DELETE FROM zacg_mitg_owners.
        MODIFY zacg_mitg_owners FROM TABLE lit_mit_own.
        COMMIT WORK AND WAIT.
        MESSAGE 'Mitigation Owners successfully updated' TYPE 'S'.
      ENDIF.

    ELSEIF r_lman = abap_true.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_line_manager ASSIGNING FIELD-SYMBOL(<lfs_line_manager>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col + 1 OF STRUCTURE <lfs_line_manager> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      DELETE lit_line_manager INDEX 1.
      IF lit_line_manager IS NOT INITIAL.
        DELETE FROM zacg_manager.
        MODIFY zacg_manager FROM TABLE lit_line_manager.
        COMMIT WORK AND WAIT.
        MESSAGE 'Line Managers successfully updated' TYPE 'S'.
      ENDIF.

    ELSEIF r_rset = abap_true.

      LOOP AT git_excel INTO lwa_excel1.
        lwa_excel = lwa_excel1.
        AT NEW row.
          APPEND INITIAL LINE TO lit_rule_set_t ASSIGNING FIELD-SYMBOL(<lfs_rule_set>).
        ENDAT.
        ASSIGN COMPONENT lwa_excel-col OF STRUCTURE <lfs_rule_set> TO <lfs_value>.
        IF <lfs_value> IS ASSIGNED.
          <lfs_value> = lwa_excel-value.
        ENDIF.

        UNASSIGN <lfs_value>.
      ENDLOOP.

      DELETE lit_rule_set_t INDEX 1.
      IF lit_rule_set_t IS NOT INITIAL.
        DELETE FROM zacg_fue_rul_set.
        lit_rule_set = VALUE #( FOR lwa_rule_set IN lit_rule_set_t ( priority = lwa_rule_set-priority
                                                                     rule_desc = lwa_rule_set-rule_desc
                                                                     object = lwa_rule_set-object
                                                                     field = lwa_rule_set-field
                                                                     value = lwa_rule_set-value ) ).
        MODIFY zacg_fue_rul_set FROM TABLE lit_rule_set.
        COMMIT WORK AND WAIT.
        MESSAGE 'Rule Set successfully updated' TYPE 'S'.
      ENDIF.


    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form download_template
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM download_template .

  DATA : lv_trans_name TYPE cxsltdesc,
         lv_filename   TYPE string.
  DATA : lv_length TYPE i,
         lv_xml    TYPE xstring,
         lt_solix  TYPE STANDARD TABLE OF solix,
         lv_path   TYPE string,
         lv_file   TYPE string.

*** Assign Template Name and File Name
  IF r_fmst IS NOT INITIAL.
    lv_trans_name = co_trans_fmst.
    lv_filename = co_file_fmst.
  ELSEIF r_fval IS NOT INITIAL.
    lv_trans_name = co_trans_fval.
    lv_filename = co_file_fval.
  ELSEIF r_lman IS NOT INITIAL.
    lv_trans_name = co_trans_lman.
    lv_filename = co_file_lman.
  ELSEIF r_mown IS NOT INITIAL.
    lv_trans_name = co_trans_mown.
    lv_filename = co_file_mown.
  ELSEIF r_rcom IS NOT INITIAL.
    lv_trans_name = co_trans_rcom.
    lv_filename = co_file_rcom.
  ELSEIF r_rlib IS NOT INITIAL.
    lv_trans_name = co_trans_rlib.
    lv_filename = co_file_rlib.
  ELSEIF r_rmst IS NOT INITIAL.
    lv_trans_name = co_trans_rmst.
    lv_filename = co_file_rmst.
  ELSEIF r_rown IS NOT INITIAL.
    lv_trans_name = co_trans_rown.
    lv_filename = co_file_rown.
  ELSEIF r_rset IS NOT INITIAL.
    lv_trans_name = co_trans_rset.
    lv_filename = co_file_rset.
  ENDIF.

*** Get Directory
  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_path
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.
  IF sy-subrc IS INITIAL AND lv_path IS NOT INITIAL.
    lv_file = lv_path && lv_filename.
*** Get Excel Template in XML

    TRY.
        CALL TRANSFORMATION (lv_trans_name)
        SOURCE lit_excel = space
        RESULT XML lv_xml.
      CATCH cx_root INTO DATA(ls_error).
        DATA(lv_error) = ls_error->get_text( ).
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.

    IF lv_xml IS NOT INITIAL.
*** Convert XML to Binary
      CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
        EXPORTING
          buffer        = lv_xml
        IMPORTING
          output_length = lv_length
        TABLES
          binary_tab    = lt_solix.
*** Download Excel File
      CALL METHOD cl_gui_frontend_services=>gui_download
        EXPORTING
          bin_filesize            = lv_length
          filetype                = 'BIN'
          filename                = lv_file
        CHANGING
          data_tab                = lt_solix
        EXCEPTIONS
          file_write_error        = 1
          no_batch                = 2
          gui_refuse_filetransfer = 3
          invalid_type            = 4
          no_authority            = 5
          unknown_error           = 6
          header_not_allowed      = 7
          separator_not_allowed   = 8
          filesize_not_allowed    = 9
          header_too_long         = 10
          dp_error_create         = 11
          dp_error_send           = 12
          dp_error_write          = 13
          unknown_dp_error        = 14
          access_denied           = 15
          dp_out_of_memory        = 16
          disk_full               = 17
          dp_timeout              = 18
          file_not_found          = 19
          dataprovider_exception  = 20
          control_flush_error     = 21
          OTHERS                  = 22.
      IF sy-subrc <> 0.
        MESSAGE 'Error Occured While Downloading the Template' TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDIF.


ENDFORM.
