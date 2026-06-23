*&---------------------------------------------------------------------*
*& Include          ZACG_MAINF01
*&---------------------------------------------------------------------*

FORM fill_node CHANGING li_node_table TYPE ty_node_table_type.

  DATA: lv_index     TYPE sy-tabix,
        lv_auth_pass TYPE flag,
        lw_node      TYPE sapwltreen,
        li_root      TYPE ty_node_table_type.

  CLEAR li_node_table.

  SELECT *
    FROM zacg_tree_contrl
    INTO TABLE @DATA(li_tree_root).
  IF sy-subrc IS INITIAL.

    DATA(li_tree_items) = li_tree_root.
    DELETE li_tree_root   WHERE isfolder IS INITIAL.
    DELETE li_tree_items  WHERE isfolder IS NOT INITIAL.

    SORT li_tree_root   BY relatship.
    SORT li_tree_items  BY relatkey relatship.

    LOOP AT li_tree_root INTO DATA(lw_tree_root).

      CLEAR li_root.

      MOVE-CORRESPONDING lw_tree_root TO lw_node.
      lw_node-relatship = cl_gui_simple_tree=>relat_last_child.
      APPEND lw_node TO li_node_table.
      CLEAR lw_node.

      LOOP AT li_tree_items INTO DATA(lw_tree_items) WHERE relatkey = lw_tree_root-node_key.

        CLEAR: lv_auth_pass.

        MOVE-CORRESPONDING lw_tree_items TO lw_node.
        lw_node-relatship = cl_gui_simple_tree=>relat_last_child.

        PERFORM authority_check USING lw_tree_items-node_key CHANGING lv_auth_pass.

        IF lv_auth_pass = abap_true.
          APPEND lw_node TO li_node_table.
          APPEND lw_node TO li_root.
          CLEAR lw_node.
        ENDIF.

      ENDLOOP.

      IF li_root IS INITIAL.
        READ TABLE li_node_table ASSIGNING FIELD-SYMBOL(<lfs_node_table>) INDEX lines( li_node_table ).
        IF <lfs_node_table> IS ASSIGNED.
          <lfs_node_table>-node_key = space.
        ENDIF.
      ENDIF.

      UNASSIGN <lfs_node_table>.

    ENDLOOP.

    DELETE li_node_table WHERE node_key IS INITIAL.

  ENDIF.



ENDFORM.

*&---------------------------------------------------------------------*
*& Form authority_check
*&---------------------------------------------------------------------*
*& Checks whether the current user is authorized for the tree node
*& identified by KEY. The authorization object name is derived by
*& prefixing the node key with 'ZACG_' (e.g. key 'CROL' -> 'ZACG_CROL')
*& and the standard activity 16 (display/execute) is checked.
*&
*&   -->  KEY    Tree node key (max 5 chars so 'ZACG_' + KEY fits the
*&               10-char XUOBJECT name).
*&   <--  VALID  ABAP_TRUE when the user passes the check, otherwise
*&               left unchanged.
*&
*& NOTE: every guarded node's object must expose field ACTVT, otherwise
*& AUTHORITY-CHECK returns sy-subrc = 2 (object/field unknown) and the
*& node is treated as not authorized.
*&---------------------------------------------------------------------*
FORM authority_check USING key TYPE tv_nodekey CHANGING valid TYPE flag.

  DATA: lv_object TYPE xuobject.

  CONCATENATE 'ZACG_' key INTO lv_object.

  AUTHORITY-CHECK OBJECT lv_object
  ID 'ACTVT'  FIELD '16'.
  IF sy-subrc IS INITIAL.
    valid = abap_true.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_1000
*&---------------------------------------------------------------------*
*& PAI handler for the main screen 1000. Leaves the screen on the
*& BACK / EXIT / CANCEL function codes.
*&---------------------------------------------------------------------*
FORM user_command_1000 .

  CASE g_ucomm.
    WHEN 'BACK'.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'EXIT'.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'CANCEL'.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN OTHERS.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_user
*&---------------------------------------------------------------------*
*& Mass-creates SAP users from the uploaded Excel template.
*&
*& Flow:
*&   1. Reads the spreadsheet (ALSMEX) into an internal table.
*&   2. For each user id (AT END OF userid) builds the logon, address,
*&      default, SNC and licence data and calls:
*&        - BAPI_USER_CREATE1          (create the user + password)
*&        - BAPI_USER_ACTGROUPS_ASSIGN (assign roles, if supplied)
*&        - BAPI_USER_PROFILES_ASSIGN  (assign profiles, if supplied)
*&        - BAPI_TRANSACTION_COMMIT    (persist the changes)
*&   3. Collects per-user status messages in GT_USER_OUTPUT and shows
*&      them in an ALV grid.
*&
*& Side effects: creates users and commits to the database.
*&---------------------------------------------------------------------*
FORM create_user .

  TYPES: BEGIN OF lty_user_data,
           sl_no        TYPE string,
           userid       TYPE string,
           fname        TYPE string,
           lname        TYPE string,
           dept         TYPE string,
           func         TYPE string,
           email_type   TYPE string,
           email        TYPE string,
           utype        TYPE string,
           passw1       TYPE string,
           ugroup       TYPE string,
           valid_from   TYPE string,
           valid_to     TYPE string,
           accno        TYPE string,
           cost_center  TYPE string,
           snc          TYPE string,
           out_dev      TYPE string,
           param_id     TYPE string,
           param_value  TYPE string,
*           system       TYPE string,
*           role_rec_sys TYPE string,
           role         TYPE string,
           sdate        TYPE string,
           edate        TYPE string,
           profile      TYPE string,
           prof_rec_sys TYPE string,
           lic_rec_sys  TYPE string,
           cont_utype   TYPE string,
         END OF lty_user_data.

  TYPES: BEGIN OF lty_user_data1,
           userid       TYPE string,
           fname        TYPE string,
           lname        TYPE string,
           dept         TYPE string,
           func         TYPE string,
           email_type   TYPE string,
           email        TYPE string,
           utype        TYPE string,
           passw1       TYPE string,
           ugroup       TYPE string,
           valid_from   TYPE string,
           valid_to     TYPE string,
           accno        TYPE string,
           cost_center  TYPE string,
           snc          TYPE string,
           out_dev      TYPE string,
           param_id     TYPE string,
           param_value  TYPE string,
*           system       TYPE string,
*           role_rec_sys TYPE string,
           role         TYPE string,
           sdate        TYPE string,
           edate        TYPE string,
           profile      TYPE string,
           prof_rec_sys TYPE string,
           lic_rec_sys  TYPE string,
           cont_utype   TYPE string,
         END OF lty_user_data1.

  DATA: lt_udata       TYPE STANDARD TABLE OF lty_user_data1,
        ls_usr_data    TYPE lty_user_data1,
        lt_udata1      TYPE STANDARD TABLE OF lty_user_data,
        lt_excel       TYPE STANDARD TABLE OF alsmex_tabline,
        ls_excel       TYPE alsmex_tabline,
        lv_com         TYPE i,
        lv_userid      TYPE bapibname-bapibname,
        ls_logondata   TYPE bapilogond,
        ls_password    TYPE bapipwd,
        ls_default     TYPE bapidefaul,
        ls_address     TYPE bapiaddr3,
        ls_snc         TYPE bapisncu,
        ls_uclass      TYPE bapiuclass,
        ls_gen_pw      TYPE bapipwd,
        lt_param       TYPE STANDARD TABLE OF bapiparam,
        ls_param       TYPE bapiparam,
        lt_return_user TYPE STANDARD TABLE OF bapiret2,
        lt_return_role TYPE STANDARD TABLE OF bapiret2,
        lt_return_prof TYPE STANDARD TABLE OF bapiret2,
        lt_role        TYPE STANDARD TABLE OF bapiagr,
        lt_profile     TYPE STANDARD TABLE OF bapiprof,
        ls_profile     TYPE bapiprof,
        ls_role        TYPE bapiagr,
        ls_output      TYPE ty_usr_output.

  DATA: lt_catalog TYPE lvc_t_fcat,
        ls_catalog TYPE lvc_s_fcat,
        lv_flag    TYPE char1.

  FIELD-SYMBOLS:<lfs_data> TYPE lty_user_data,
                <lfs_val>  TYPE any.

  CLEAR gt_user_output[].


  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = p_file
      i_begin_col             = 1
      i_begin_row             = p_srow
      i_end_col               = 9999
      i_end_row               = p_erow
    TABLES
      intern                  = lt_excel
    EXCEPTIONS
      inconsistent_parameters = 1
      upload_ole              = 2
      OTHERS                  = 3.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

  SORT lt_excel BY row col.

  LOOP AT lt_excel INTO ls_excel.
    AT NEW row.
      APPEND INITIAL LINE TO lt_udata1 ASSIGNING <lfs_data>.
      lv_com = 1.
    ENDAT.
    ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
    WHILE lv_com NE ls_excel-col.
      lv_com = lv_com + 1.
      ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
    ENDWHILE.
    IF lv_com EQ ls_excel-col.
      <lfs_val> = ls_excel-value.
    ENDIF.
    lv_com = lv_com + 1.
  ENDLOOP.

  LOOP AT lt_udata1 INTO DATA(ls_udata1).
    MOVE-CORRESPONDING ls_udata1 TO ls_usr_data.
    APPEND ls_usr_data TO lt_udata.
    CLEAR ls_usr_data.
  ENDLOOP.

  LOOP AT lt_udata INTO DATA(ls_udata).

*Check Mandatory fields
    IF ls_udata-lname IS INITIAL.
      ls_output-userid = ls_udata-userid.
      ls_output-user_msg = TEXT-018.
      APPEND ls_output TO gt_user_output.CLEAR ls_output.
    ENDIF.

    IF ls_udata-passw1 IS INITIAL.
      ls_output-userid = ls_udata-userid.
      ls_output-user_msg = TEXT-019.
      APPEND ls_output TO gt_user_output.CLEAR ls_output.
    ENDIF.


    ls_password-bapipwd = ls_udata-passw1.

    IF ls_udata-param_id IS NOT INITIAL AND
       ls_udata-param_value IS NOT INITIAL.
      ls_param-parid = ls_udata-param_id.
      ls_param-parva = ls_udata-param_value.
      APPEND ls_param TO lt_param.
      CLEAR ls_param.
    ENDIF.

    IF ls_udata-role IS NOT INITIAL AND
       ls_udata-sdate IS NOT INITIAL AND
       ls_udata-edate IS NOT INITIAL.
      ls_role-agr_name = ls_udata-role.
      CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
        EXPORTING
          date_external            = ls_udata-sdate
        IMPORTING
          date_internal            = ls_udata-sdate
        EXCEPTIONS
          date_external_is_invalid = 1
          OTHERS                   = 2.
      IF sy-subrc EQ 0.
        ls_role-from_dat = ls_udata-sdate.
      ENDIF.
      CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
        EXPORTING
          date_external            = ls_udata-edate
        IMPORTING
          date_internal            = ls_udata-edate
        EXCEPTIONS
          date_external_is_invalid = 1
          OTHERS                   = 2.
      IF sy-subrc EQ 0.
        ls_role-to_dat = ls_udata-edate.
      ENDIF.
      APPEND ls_role TO lt_role.
      CLEAR ls_role.
    ENDIF.

    IF ls_udata-profile IS NOT INITIAL.
      ls_profile-bapiprof = ls_udata-profile.
      APPEND ls_profile TO lt_profile.
      CLEAR ls_profile.
    ENDIF.

    IF lv_flag IS INITIAL.
      lv_userid = ls_udata-userid.

      ls_logondata-ustyp = ls_udata-utype.
      ls_logondata-class = ls_udata-ugroup.
      CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
        EXPORTING
          date_external            = ls_udata-valid_from
        IMPORTING
          date_internal            = ls_udata-valid_from
        EXCEPTIONS
          date_external_is_invalid = 1
          OTHERS                   = 2.
      IF sy-subrc EQ 0.
        ls_logondata-gltgv = ls_udata-valid_from.
      ENDIF.
      CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
        EXPORTING
          date_external            = ls_udata-valid_to
        IMPORTING
          date_internal            = ls_udata-valid_to
        EXCEPTIONS
          date_external_is_invalid = 1
          OTHERS                   = 2.
      IF sy-subrc EQ 0.
        ls_logondata-gltgb = ls_udata-valid_to.
      ENDIF.
      ls_logondata-accnt = ls_udata-accno.

      ls_default-spld = ls_udata-out_dev.
      ls_default-kostl = ls_udata-cost_center.

      ls_address-firstname = ls_udata-fname.
      ls_address-lastname = ls_udata-lname.
      ls_address-department = ls_udata-dept.
      ls_address-function = ls_udata-func.
      ls_address-e_mail = ls_udata-email.

      ls_snc-pname = ls_udata-snc.

      ls_uclass-lic_type = ls_udata-cont_utype.
      ls_uclass-sysid = ls_udata-lic_rec_sys.

      lv_flag = abap_true.
    ENDIF.

    AT END OF userid.

      CALL FUNCTION 'BAPI_USER_CREATE1'
        EXPORTING
          username           = lv_userid
          logondata          = ls_logondata
          password           = ls_password
          defaults           = ls_default
          address            = ls_address
          snc                = ls_snc
          uclass             = ls_uclass
        IMPORTING
          generated_password = ls_gen_pw
        TABLES
          parameter          = lt_param
          return             = lt_return_user.

      ls_output-userid = lv_userid.
      ls_output-gen_pw = ls_gen_pw-bapipwd.
*     Read the first BAPI message defensively. Direct index access
*     ( lt_return_user[ 1 ] ) raises CX_SY_ITAB_LINE_NOT_FOUND when the
*     BAPI returns no messages, so READ TABLE with an sy-subrc check is used.
      READ TABLE lt_return_user INTO DATA(ls_ret_user) INDEX 1.
      IF sy-subrc = 0.
        ls_output-user_msg = ls_ret_user-message.
        IF ls_ret_user-type = 'E'.
          CLEAR ls_output-gen_pw.
        ENDIF.
      ENDIF.

      IF lt_role IS NOT INITIAL.
        CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
          EXPORTING
            username       = lv_userid
          TABLES
            activitygroups = lt_role
            return         = lt_return_role.

        READ TABLE lt_return_role INTO DATA(ls_ret_role) INDEX 1.
        IF sy-subrc = 0.
          ls_output-role_msg = ls_ret_role-message.
        ENDIF.
      ELSE.
        ls_output-role_msg = 'No Role has been provided for this user'.
      ENDIF.

      IF lt_profile IS NOT INITIAL.
        CALL FUNCTION 'BAPI_USER_PROFILES_ASSIGN'
          EXPORTING
            username = lv_userid
          TABLES
            profiles = lt_profile
            return   = lt_return_prof.

        READ TABLE lt_return_prof INTO DATA(ls_ret_prof) INDEX 1.
        IF sy-subrc = 0.
          ls_output-prof_msg = ls_ret_prof-message.
        ENDIF.
      ELSE.
        ls_output-prof_msg = 'No Profile has been provided for this user'.
      ENDIF.

*     BAPI_USER_* functions register their work on the update task but do
*     not commit. Without an explicit commit the user / role / profile
*     assignment is never persisted even though the BAPI returns success.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.

      APPEND ls_output TO gt_user_output.
      CLEAR: lv_userid, ls_logondata, ls_password, ls_default,
             ls_address, ls_snc, ls_uclass, ls_gen_pw, lt_param,
             lt_return_user, lt_role, lt_return_role, lt_profile,
             lt_return_prof, lv_flag.
    ENDAT.
  ENDLOOP.

  CHECK gt_user_output IS NOT INITIAL.

  IF o_conttainer_9006 IS BOUND.
    CALL METHOD o_conttainer_9006->free.
    CLEAR o_conttainer_9006.
  ENDIF.

  IF o_gui_alv_grid_9006 IS BOUND.
    CLEAR o_gui_alv_grid_9006.
  ENDIF.

  IF o_conttainer_9006 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9006
      EXPORTING
        container_name = 'CC_9006'.
  ENDIF.

  IF o_conttainer_9006 IS BOUND AND o_gui_alv_grid_9006 IS NOT BOUND.
    CREATE OBJECT o_gui_alv_grid_9006
      EXPORTING
        i_parent = o_conttainer_9006.
  ENDIF.

  wa_layout-col_opt = abap_true.
  wa_layout-cwidth_opt = abap_true.

  ls_catalog-col_pos = 1.
  ls_catalog-fieldname = 'USERID'.
  ls_catalog-reptext = 'User ID'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 2.
  ls_catalog-fieldname = 'GEN_PW'.
  ls_catalog-reptext = 'Generated Password'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 3.
  ls_catalog-fieldname = 'USER_MSG'.
  ls_catalog-reptext = 'User Creation Message'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 4.
  ls_catalog-fieldname = 'ROLE_MSG'.
  ls_catalog-reptext = 'Role Assignment Message'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 5.
  ls_catalog-fieldname = 'PROF_MSG'.
  ls_catalog-reptext = 'Profile Assignment Message'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_gui_alv_grid_9006 IS BOUND.
    CALL METHOD o_gui_alv_grid_9006->set_table_for_first_display
      EXPORTING
        is_layout       = wa_layout
      CHANGING
        it_fieldcatalog = lt_catalog
        it_outtab       = gt_user_output.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_dld_user_template
*&---------------------------------------------------------------------*
*& Lets the user pick a folder and downloads the "Create User" Excel
*& template there. The empty template is produced by XSLT transformation
*& ZSEC_XSLT_USER_TEMPLATE and written with GUI_DOWNLOAD.
*& Front-end only (uses CL_GUI_FRONTEND_SERVICES / GUI_DOWNLOAD).
*&---------------------------------------------------------------------*
FORM f_dld_user_template .

  DATA : lv_path TYPE string,
         lv_file TYPE string,
         lt_tab  TYPE TABLE OF string,
         lv_xml  TYPE string,
         lt_xml  TYPE STANDARD TABLE OF string.

  CONSTANTS: lco_file TYPE string VALUE '\User_Template.xls'.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_path
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc EQ 0 AND lv_path IS NOT INITIAL.
    lv_file = lv_path && lco_file.
    TRY.
        CALL TRANSFORMATION zsec_xslt_user_template
        SOURCE it_tab = lt_tab
        RESULT XML lv_xml.
      CATCH cx_root INTO DATA(ls_error).
        DATA(lv_error) = ls_error->get_text( ).
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    IF lv_xml IS NOT INITIAL.
      APPEND lv_xml TO lt_xml.
      CALL FUNCTION 'GUI_DOWNLOAD'
        EXPORTING
          filename                = lv_file
          filetype                = 'ASC'
        TABLES
          data_tab                = lt_xml
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
  .
ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_file2_validate
*&---------------------------------------------------------------------*
*& Validates the password-reset upload file (P_FILE2) at AT SELECTION
*& SCREEN time. Confirms the file is supplied, has an .XLS extension and
*& that the first two header cells read 'User ID' and 'Password'. On any
*& failure it clears sy-ucomm / g_ucomm and raises an error message so
*& the action is not executed.
*&---------------------------------------------------------------------*
FORM p_pwfile_validate .
  TYPES: BEGIN OF lty_std_role,
           uname TYPE string,
           passw TYPE string,
         END OF lty_std_role.

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  IF sy-ucomm = 'EXE'.
    sy-ucomm = 'EXE2'.
  ENDIF.

  CHECK g_ucomm = 'EX2'.

  IF p_file2 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file2 ) - 4.
    TRANSLATE p_file2+lv_len(4) TO UPPER CASE.
    IF p_file2+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file2
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'User ID'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Password'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_init_password
*&---------------------------------------------------------------------*
*& Mass password set/reset from the uploaded Excel file (P_FILE2).
*&
*& For each "User ID / Password" row:
*&   - blank password  -> BAPI_USER_CHANGE with GENERATE_PWD (system
*&     generates a password),
*&   - filled password -> BAPI_USER_CHANGE sets that password.
*& On success the new password is e-mailed to the user's SMTP address
*& (looked up via USR21 / ADR6) using CL_BCS. Per-user status is shown
*& in ALV grid on screen 9007 (GT_PWD_OUTPUT).
*&
*& KNOWN ISSUES (see code review): the BCS sender address is hard-coded,
*& the password is sent in clear text, and lt_return[ 1 ] is read without
*& a guard.
*&---------------------------------------------------------------------*
FORM set_reset_password_mass .
  TYPES: BEGIN OF lty_std_role,
           sno   TYPE i,
           uname TYPE xubname,
           passw TYPE xuncode,
         END OF lty_std_role.

  DATA : lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lt_init_excel TYPE TABLE OF lty_std_role,
         lv_com        TYPE i,
         ls_pwd_output TYPE ty_pwd_output,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         ls_password   TYPE bapipwd,
         ls_passwordx  TYPE bapipwdx,
         ls_gen_pwd    TYPE bapipwd,
         lt_return     TYPE STANDARD TABLE OF bapiret2,
         send_request  TYPE REF TO cl_bcs,
         mailsubject   TYPE so_obj_des,
         mailtext      TYPE bcsy_text,
         document      TYPE REF TO cl_document_bcs,
         sender        TYPE REF TO cl_cam_address_bcs,
         recipient_to  TYPE REF TO cl_cam_address_bcs.

  CLEAR gt_pwd_output.
  IF p_file2 IS NOT INITIAL.

    IF o_conttainer_9007 IS BOUND.
      CALL METHOD o_conttainer_9007->free.
      CLEAR o_conttainer_9007.
    ENDIF.

    IF o_gui_alv_grid_9007 IS BOUND.
      CLEAR o_gui_alv_grid_9007.
    ENDIF.

    CLEAR gt_pwd_output[].

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file2
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 3
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        SELECT bname,
               persnumber,
               addrnumber
        FROM usr21
        INTO TABLE @DATA(lit_usr21)
        FOR ALL ENTRIES IN @lt_init_excel
        WHERE bname = @lt_init_excel-uname.
        IF sy-subrc IS INITIAL.
          SORT lit_usr21 BY bname.
          SELECT addrnumber,
                 persnumber,
                 smtp_addr
          FROM adr6
          INTO TABLE @DATA(lit_adr6)
          FOR ALL ENTRIES IN @lit_usr21
          WHERE addrnumber = @lit_usr21-addrnumber
          AND persnumber = @lit_usr21-persnumber.
          IF sy-subrc IS INITIAL.
            SORT lit_adr6 BY addrnumber.
          ENDIF.
        ENDIF.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
          ls_pwd_output-userid = lwa_init_excel-uname.
          ls_pwd_output-pwd    = lwa_init_excel-passw.

          READ TABLE lit_usr21 INTO DATA(lwa_usr21) WITH KEY bname = lwa_init_excel-uname BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            IF lwa_init_excel-passw IS INITIAL.
              CALL FUNCTION 'BAPI_USER_CHANGE'
                EXPORTING
                  username           = lwa_usr21-bname
                  generate_pwd       = abap_true
                IMPORTING
                  generated_password = ls_gen_pwd
                TABLES
                  return             = lt_return.
              ls_pwd_output-userid = lwa_usr21-bname.
              IF lt_return[ 1 ]-type = 'E'.
                CLEAR ls_gen_pwd-bapipwd.
              ENDIF.
              ls_pwd_output-pwd = ls_gen_pwd-bapipwd.
              ls_pwd_output-msg_ty = lt_return[ 1 ]-type.
              ls_pwd_output-pwd_msg = lt_return[ 1 ]-message.

            ELSE.
              ls_password-bapipwd = lwa_init_excel-passw.
              ls_passwordx-bapipwd = abap_true.
              CALL FUNCTION 'BAPI_USER_CHANGE'
                EXPORTING
                  username  = lwa_usr21-bname
                  password  = ls_password
                  passwordx = ls_passwordx
                TABLES
                  return    = lt_return.
              IF lt_return IS NOT INITIAL.
                ls_pwd_output-userid = lwa_usr21-bname.
                ls_pwd_output-msg_ty = lt_return[ 1 ]-type.
                ls_pwd_output-pwd_msg = lt_return[ 1 ]-message.
              ENDIF.
            ENDIF.

            IF ls_pwd_output-msg_ty = 'E'.
              ls_pwd_output-mail_msg = 'Eror in Password Reset'.
            ELSE.
              READ TABLE lit_adr6 INTO DATA(lwa_adr6) WITH KEY addrnumber = lwa_usr21-addrnumber
                              persnumber = lwa_usr21-persnumber BINARY SEARCH.
              IF sy-subrc IS INITIAL.
                TRY.
                    send_request = cl_bcs=>create_persistent( ).
                    DATA(lv_sys) = sy-sysid && '/' && sy-mandt.
                    CONCATENATE 'Password Reset in' lv_sys INTO DATA(lv_subject) SEPARATED BY space.
                    mailsubject = lv_subject .
                    APPEND 'Hello User,' TO mailtext.
                    APPEND INITIAL LINE TO mailtext.
                    CONCATENATE 'Your password has been reset to' lwa_init_excel-passw 'in' lv_sys
                    INTO DATA(lv_body) SEPARATED BY space.
                    APPEND lv_body TO mailtext.
                    APPEND INITIAL LINE TO mailtext.
                    APPEND 'From,' TO mailtext.
                    APPEND 'Security Team' TO mailtext.

                    document = cl_document_bcs=>create_document(
                      i_type    = 'RAW'
                      i_text    = mailtext
                      i_subject = mailsubject ).
                    send_request->set_document( document ).

                    sender = cl_cam_address_bcs=>create_internet_address( 'arnab.bhaduri@pwc.com' ).
                    send_request->set_sender( sender ).

                    recipient_to = cl_cam_address_bcs=>create_internet_address( lwa_adr6-smtp_addr ).
                    send_request->add_recipient( i_recipient = recipient_to ).
                    DATA(lv_sent) = send_request->send( ).
                    IF lv_sent = abap_true.
                      ls_pwd_output-mail_msg = 'Mail has been sent to the User'.
                      COMMIT WORK.
                    ELSE.
                      ls_pwd_output-mail_msg = 'Mail could not be sent to the User'.
                    ENDIF.
                  CATCH cx_bcs INTO DATA(bcs_exception).
                    DATA(lv_excp) =  bcs_exception->get_text( ).
                ENDTRY.
              ELSE.
                ls_pwd_output-msg_ty = 'E'.
                ls_pwd_output-mail_msg = 'No Email ID has been maintained in User Data.'.
              ENDIF.
            ENDIF.
          ELSE.
            ls_pwd_output-msg_ty = 'E'.
            ls_pwd_output-pwd_msg = 'Invalid User Name'.
            ls_pwd_output-mail_msg = 'User does not exist'.
          ENDIF.
          APPEND ls_pwd_output TO gt_pwd_output.
          CLEAR : ls_pwd_output.
        ENDLOOP.
      ENDIF.
    ENDIF.

    IF o_conttainer_9007 IS NOT BOUND.
      CREATE OBJECT o_conttainer_9007
        EXPORTING
          container_name = 'CC_9007'.
    ENDIF.

    IF o_conttainer_9007 IS BOUND AND o_gui_alv_grid_9007 IS NOT BOUND.
      CREATE OBJECT o_gui_alv_grid_9007
        EXPORTING
          i_parent = o_conttainer_9007.
    ENDIF.

    wa_layout-col_opt = abap_true.
    wa_layout-cwidth_opt = abap_true.

    ls_catalog-col_pos = 1.
    ls_catalog-fieldname = 'USERID'.
    ls_catalog-reptext = 'User ID'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 2.
    ls_catalog-fieldname = 'PWD'.
    ls_catalog-reptext = 'Password'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 3.
    ls_catalog-fieldname = 'PWD_MSG'.
    ls_catalog-reptext = 'Password Reset Message'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 4.
    ls_catalog-fieldname = 'MAIL_MSG'.
    ls_catalog-reptext = 'Mail Status'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    IF o_gui_alv_grid_9007 IS BOUND.
      CALL METHOD o_gui_alv_grid_9007->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_pwd_output.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_reset_password_manual
*&---------------------------------------------------------------------*
*& Manual password set/reset for the users entered in select-option
*& SO_UPW. Behaves like SET_RESET_PASSWORD_MASS but takes the users and
*& the single password P_PWD from the selection screen instead of a
*& file: blank P_PWD generates a password, otherwise P_PWD is set. The
*& new password is e-mailed to each user and results are shown in the
*& screen 9007 ALV grid. Same known issues as the mass variant.
*&---------------------------------------------------------------------*
FORM set_reset_password_manual .
  TYPES: BEGIN OF lty_std_role,
           uname TYPE xubname,
           passw TYPE xuncode,
         END OF lty_std_role.

  DATA : lt_excel       TYPE STANDARD TABLE OF alsmex_tabline,
         lt_init_excel  TYPE TABLE OF lty_std_role,
         lwa_init_excel TYPE lty_std_role,
         lv_com         TYPE i,
         ls_pwd_output  TYPE ty_pwd_output,
         lt_catalog     TYPE lvc_t_fcat,
         ls_catalog     TYPE lvc_s_fcat,
         ls_password    TYPE bapipwd,
         ls_passwordx   TYPE bapipwdx,
         ls_gen_pwd     TYPE bapipwd,
         lt_return      TYPE STANDARD TABLE OF bapiret2,
         send_request   TYPE REF TO cl_bcs,
         mailsubject    TYPE so_obj_des,
         mailtext       TYPE bcsy_text,
         document       TYPE REF TO cl_document_bcs,
         sender         TYPE REF TO cl_cam_address_bcs,
         recipient_to   TYPE REF TO cl_cam_address_bcs.


  CLEAR :gt_pwd_output.

  IF o_conttainer_9007 IS BOUND.
    CALL METHOD o_conttainer_9007->free.
    CLEAR o_conttainer_9007.
  ENDIF.

  IF o_gui_alv_grid_9007 IS BOUND.
    CLEAR o_gui_alv_grid_9007.
  ENDIF.

  IF so_upw[] IS NOT INITIAL.
    SELECT bname,
           persnumber,
           addrnumber
    FROM usr21
    INTO TABLE @DATA(lit_usr21)
*        FOR ALL ENTRIES IN @lt_init_excel
    WHERE bname IN  @so_upw[].
    IF sy-subrc IS INITIAL.
      SORT lit_usr21 BY bname.
      SELECT addrnumber,
             persnumber,
             smtp_addr
      FROM adr6
      INTO TABLE @DATA(lit_adr6)
      FOR ALL ENTRIES IN @lit_usr21
      WHERE addrnumber = @lit_usr21-addrnumber
      AND persnumber = @lit_usr21-persnumber.
      IF sy-subrc IS INITIAL.
        SORT lit_adr6 BY addrnumber.
      ENDIF.
    ENDIF.
    LOOP AT so_upw.
      ls_pwd_output-userid = so_upw-low.
      ls_pwd_output-pwd    = p_pwd.

      READ TABLE lit_usr21 INTO DATA(lwa_usr21) WITH KEY bname = so_upw-low BINARY SEARCH.
      IF sy-subrc IS INITIAL.
        IF p_pwd IS INITIAL.
          CALL FUNCTION 'BAPI_USER_CHANGE'
            EXPORTING
              username           = so_upw-low
              generate_pwd       = abap_true
            IMPORTING
              generated_password = ls_gen_pwd
            TABLES
              return             = lt_return.
          ls_pwd_output-userid = so_upw-low.
          IF lt_return[ 1 ]-type = 'E'.
            CLEAR ls_gen_pwd-bapipwd.
          ENDIF.
          ls_pwd_output-pwd = ls_gen_pwd-bapipwd.
          ls_pwd_output-msg_ty = lt_return[ 1 ]-type.
          ls_pwd_output-pwd_msg = lt_return[ 1 ]-message.
        ELSE.
          ls_password-bapipwd = p_pwd.
          ls_passwordx-bapipwd = abap_true.
          CALL FUNCTION 'BAPI_USER_CHANGE'
            EXPORTING
              username  = lwa_usr21-bname
              password  = ls_password
              passwordx = ls_passwordx
            TABLES
              return    = lt_return.
          IF lt_return IS NOT INITIAL.
            ls_pwd_output-msg_ty = lt_return[ 1 ]-type.
            ls_pwd_output-pwd_msg = lt_return[ 1 ]-message.
          ENDIF.
        ENDIF.
        IF ls_pwd_output-msg_ty = 'E'.
          ls_pwd_output-mail_msg = 'Eror in Password Reset'.
        ELSE.
          READ TABLE lit_adr6 INTO DATA(lwa_adr6) WITH KEY addrnumber = lwa_usr21-addrnumber
                          persnumber = lwa_usr21-persnumber BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            TRY.
                send_request = cl_bcs=>create_persistent( ).
                DATA(lv_sys) = sy-sysid && '/' && sy-mandt.
                CONCATENATE 'Password Reset in' lv_sys INTO DATA(lv_subject) SEPARATED BY space.
                mailsubject = lv_subject .
                APPEND 'Hello User,' TO mailtext.
                APPEND INITIAL LINE TO mailtext.
                CONCATENATE 'Your password has been reset to' lwa_init_excel-passw 'in' lv_sys
                INTO DATA(lv_body) SEPARATED BY space.
                APPEND lv_body TO mailtext.
                APPEND INITIAL LINE TO mailtext.
                APPEND 'From,' TO mailtext.
                APPEND 'Security Team' TO mailtext.

                document = cl_document_bcs=>create_document(
                  i_type    = 'RAW'
                  i_text    = mailtext
                  i_subject = mailsubject ).
                send_request->set_document( document ).

                sender = cl_cam_address_bcs=>create_internet_address( 'arnab.bhaduri@pwc.com' ).
                send_request->set_sender( sender ).

                recipient_to = cl_cam_address_bcs=>create_internet_address( lwa_adr6-smtp_addr ).
                send_request->add_recipient( i_recipient = recipient_to ).
                DATA(lv_sent) = send_request->send( ).
                IF lv_sent = 'X'.
                  ls_pwd_output-mail_msg = 'Mail has been sent to the User'.
                  COMMIT WORK.
                ELSE.
                  ls_pwd_output-mail_msg = 'Mail could not be sent to the User'.
                ENDIF.
              CATCH cx_bcs INTO DATA(bcs_exception).
                DATA(lv_excp) =  bcs_exception->get_text( ).
            ENDTRY.
          ELSE.
            ls_pwd_output-msg_ty = 'E'.
            ls_pwd_output-mail_msg = 'No Email ID has been maintained in User Data.'.
          ENDIF.
        ENDIF.
      ELSE.
        ls_pwd_output-msg_ty = 'E'.
        ls_pwd_output-pwd_msg = 'Invalid User Name'.
      ENDIF.
      APPEND ls_pwd_output TO gt_pwd_output.
    ENDLOOP.
  ENDIF.


  IF o_conttainer_9007 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9007
      EXPORTING
        container_name = 'CC_9007'.
  ENDIF.

  IF o_conttainer_9007 IS BOUND AND o_gui_alv_grid_9007 IS NOT BOUND.
    CREATE OBJECT o_gui_alv_grid_9007
      EXPORTING
        i_parent = o_conttainer_9007.
  ENDIF.

  wa_layout-col_opt = abap_true.
  wa_layout-cwidth_opt = abap_true.

  ls_catalog-col_pos = 1.
  ls_catalog-fieldname = 'USERID'.
  ls_catalog-reptext = 'User ID'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 2.
  ls_catalog-fieldname = 'PWD'.
  ls_catalog-reptext = 'Password'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 3.
  ls_catalog-fieldname = 'PWD_MSG'.
  ls_catalog-reptext = 'Password Reset Message'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 4.
  ls_catalog-fieldname = 'MAIL_MSG'.
  ls_catalog-reptext = 'Mail Status'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_gui_alv_grid_9007 IS BOUND.
    CALL METHOD o_gui_alv_grid_9007->set_table_for_first_display
      EXPORTING
        is_layout       = wa_layout
      CHANGING
        it_fieldcatalog = lt_catalog
        it_outtab       = gt_pwd_output.
  ENDIF.
*  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form f_pwfile_template
*&---------------------------------------------------------------------*
*& Lets the user pick a folder and downloads the "Password Reset" Excel
*& template (XSLT ZSEC_XSLT_PWD_TEMPLATE) via GUI_DOWNLOAD.
*& Front-end only.
*&---------------------------------------------------------------------*
FORM f_pwfile_template .
  DATA : lv_path TYPE string,
         lv_file TYPE string,
         lt_tab  TYPE TABLE OF string,
         lv_xml  TYPE string,
         lt_xml  TYPE STANDARD TABLE OF string.

  CONSTANTS: lco_file TYPE string VALUE '\PW_Reset_Template.xls'.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_path
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc EQ 0 AND lv_path IS NOT INITIAL.
    lv_file = lv_path && lco_file.
    TRY.
        CALL TRANSFORMATION zsec_xslt_pwd_template
        SOURCE it_tab = lt_tab
        RESULT XML lv_xml.
      CATCH cx_root INTO DATA(ls_error).
        DATA(lv_error) = ls_error->get_text( ).
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    IF lv_xml IS NOT INITIAL.
      APPEND lv_xml TO lt_xml.
      CALL FUNCTION 'GUI_DOWNLOAD'
        EXPORTING
          filename                = lv_file
          filetype                = 'ASC'
        TABLES
          data_tab                = lt_xml
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
*&---------------------------------------------------------------------*
*& Form show_lock_user_report
*&---------------------------------------------------------------------*
*& Builds the "lock inactive users" worklist on screen 9008.
*&
*& When results already exist (GT_LOCK_OUTPUT) it just redisplays them.
*& Otherwise it runs standard report RSUSR200 (captured via
*& CL_SALV_BS_RUNTIME_INFO), keeps only dialog users ('A') and flags
*& those inactive long enough (never logged on > 30 days, or last logon
*& > 60 days ago) into GT_LOCK_DATA for the administrator to select and
*& lock. Shows "No Data Found" when nothing qualifies.
*&---------------------------------------------------------------------*
FORM show_lock_user_report .

  DATA:
    lit_catalog TYPE lvc_t_fcat,
    lt_catalog  TYPE lvc_t_fcat,
    ls_catalog  TYPE lvc_s_fcat,
    lo_data     TYPE REF TO data,
    lt_data     TYPE STANDARD TABLE OF sim_rsusr200_alv.

  CLEAR: gt_lock_data[], lt_data[],gt_lock_output[].

  IF o_conttainer_9008 IS BOUND.
    CALL METHOD o_conttainer_9008->free.
    CLEAR o_conttainer_9008.
  ENDIF.

  IF o_gui_alv_grid_9008 IS BOUND.
    CLEAR o_gui_alv_grid_9008.
  ENDIF.

  IF gt_lock_output IS NOT INITIAL.

    IF o_conttainer_9008 IS NOT BOUND.
      CREATE OBJECT o_conttainer_9008
        EXPORTING
          container_name = 'CC_9008'.
    ENDIF.

    IF o_conttainer_9008 IS BOUND AND o_gui_alv_grid_9008 IS NOT BOUND.
      CREATE OBJECT o_gui_alv_grid_9008
        EXPORTING
          i_parent = o_conttainer_9008.
    ENDIF.

    CLEAR wa_layout-sel_mode.
    wa_layout-col_opt = abap_true.
    wa_layout-cwidth_opt = abap_true.

    ls_catalog-col_pos = 1.
    ls_catalog-fieldname = 'USERID'.
    ls_catalog-reptext = 'User ID'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 2.
    ls_catalog-fieldname = 'LOCKED'.
    ls_catalog-reptext = 'User Locked'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 3.
    ls_catalog-fieldname = 'LOCK_MSG'.
    ls_catalog-reptext = 'Lock Message'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 4.
    ls_catalog-fieldname = 'MAIL_SENT'.
    ls_catalog-reptext = 'Mail Sent Status'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 5.
    ls_catalog-fieldname = 'MAIL_MSG'.
    ls_catalog-reptext = 'Mail Sent Message'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    IF o_gui_alv_grid_9008 IS BOUND.
      CALL METHOD o_gui_alv_grid_9008->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_lock_output.
    ENDIF.

    CLEAR gt_lock_output.

  ELSE.

    cl_salv_bs_runtime_info=>set(
      EXPORTING
        display  = abap_false
        metadata = abap_false
        data     = abap_true
    ).

    SUBMIT rsusr200 WITH dtrdat   EQ p_dats
                    WITH notvalid EQ space
                    WITH commuser EQ space
                    WITH sysuser  EQ space
                    WITH refuser  EQ space
                    WITH u_locks  EQ 2     AND RETURN .

    cl_salv_bs_runtime_info=>get_data_ref(
      IMPORTING
        r_data_descr = DATA(lo_data_desc) ).
    IF lo_data_desc IS NOT INITIAL.
      CREATE DATA lo_data TYPE HANDLE lo_data_desc.
      ASSIGN lo_data->* TO <fs_data>.
    ENDIF.

    IF <fs_data> IS ASSIGNED.
      cl_salv_bs_runtime_info=>get_data(
        IMPORTING
          t_data = <fs_data> ).
    ENDIF.

    IF <fs_data> IS ASSIGNED AND <fs_data> IS NOT INITIAL.
      APPEND LINES OF <fs_data> TO lt_data.
      DELETE lt_data WHERE ustyp NE 'A'.
      LOOP AT lt_data INTO DATA(ls_data).
        IF ls_data-trdat1 CS 'Not'.
          DATA(lv_days) = sy-datum - ls_data-erdat.
          IF lv_days GE 30.
            APPEND ls_data TO gt_lock_data.
          ENDIF.
        ELSE.
          lv_days = sy-datum - ls_data-trdat.
          IF lv_days GE 60.
            APPEND ls_data TO gt_lock_data.
          ENDIF.
        ENDIF.
        CLEAR lv_days.
      ENDLOOP.
    ENDIF.

    cl_salv_bs_runtime_info=>clear_all( ).

    IF gt_lock_data IS NOT INITIAL.
      SORT gt_lock_data BY bname.

      IF o_conttainer_9008 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9008
          EXPORTING
            container_name = 'CC_9008'.
      ENDIF.

      IF o_conttainer_9008 IS BOUND AND o_gui_alv_grid_9008 IS NOT BOUND.
        CREATE OBJECT o_gui_alv_grid_9008
          EXPORTING
            i_parent = o_conttainer_9008.
      ENDIF.

      CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
        EXPORTING
          i_structure_name       = 'SIM_RSUSR200_ALV'
        CHANGING
          ct_fieldcat            = lit_catalog
        EXCEPTIONS
          inconsistent_interface = 1
          program_error          = 2
          OTHERS                 = 3.
      IF sy-subrc IS INITIAL.
      ENDIF.

      wa_layout-sel_mode = 'A'.
      wa_layout-cwidth_opt = abap_true.

      IF o_gui_alv_grid_9008 IS BOUND.
        CALL METHOD o_gui_alv_grid_9008->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lit_catalog
            it_outtab       = gt_lock_data.

      ENDIF.
    ELSE.
      MESSAGE 'No Data Found' TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_user
*&---------------------------------------------------------------------*
*& Locks the users selected in the screen-9008 grid.
*&
*& For each selected row it calls BAPI_USER_LOCK and, on success, looks
*& up the user's e-mail (BAPI_USER_GET_DETAIL) and notifies them via
*& CL_BCS. Status icons / messages are collected in GT_LOCK_OUTPUT and
*& shown in a pop-up ALV.
*&
*& KNOWN ISSUES: hard-coded BCS sender address; lt_return[ 1 ] read in
*& the success branch without a guard; only COMMIT WORK is issued for
*& the lock (BAPI_USER_LOCK).
*&---------------------------------------------------------------------*
FORM lock_user .

  DATA: lv_uname   TYPE bapibname-bapibname,
        ls_output  TYPE ty_lock_output,
        lt_return  TYPE STANDARD TABLE OF bapiret2,
        lt_ret_det TYPE STANDARD TABLE OF bapiret2,
        ls_address TYPE bapiaddr3.

  DATA: send_request  TYPE REF TO cl_bcs,
        mailsubject   TYPE so_obj_des,
        mailtext      TYPE bcsy_text,
        document      TYPE REF TO cl_document_bcs,
        sender        TYPE REF TO cl_cam_address_bcs,
        recipient_to  TYPE REF TO cl_cam_address_bcs,
        bcs_exception TYPE REF TO cx_bcs,
        lt_catalog    TYPE lvc_t_fcat,
        ls_catalog    TYPE lvc_s_fcat.

  CLEAR: gt_lock_output, mailtext, mailsubject.

  CALL METHOD o_gui_alv_grid_9008->get_selected_rows
    IMPORTING
      et_index_rows = DATA(lt_rowindex).

  CHECK lt_rowindex IS NOT INITIAL.

  SORT lt_rowindex BY index.

  LOOP AT lt_rowindex INTO DATA(ls_low_index).
    CLEAR: mailtext, mailsubject.
    READ TABLE gt_lock_data INTO DATA(ls_lock_data) INDEX ls_low_index-index.
    IF sy-subrc IS INITIAL.
      lv_uname = ls_lock_data-bname.
      CALL FUNCTION 'BAPI_USER_LOCK'
        EXPORTING
          username = lv_uname
        TABLES
          return   = lt_return.
      ls_output-userid = lv_uname.
      IF lt_return IS NOT INITIAL AND lt_return[ 1 ]-type NE 'E'.
        ls_output-locked = '@0V@'.
        ls_output-lock_msg = lt_return[ 1 ]-message.
        CALL FUNCTION 'BAPI_USER_GET_DETAIL'
          EXPORTING
            username = lv_uname
          IMPORTING
            address  = ls_address
          TABLES
            return   = lt_ret_det.
        IF ls_address-e_mail IS INITIAL.
          ls_output-mail_sent = '@0W@'.
          ls_output-mail_msg = 'No Email ID has been maintained in User Data'.
        ELSE.
          TRY.
              send_request = cl_bcs=>create_persistent( ).
              DATA(lv_sys) = sy-sysid && '/' && sy-mandt.
              CONCATENATE 'User ID' lv_uname 'Locked in' lv_sys INTO DATA(lv_subject) SEPARATED BY space.
              mailsubject = lv_subject .
              APPEND 'Hello User,' TO mailtext.
              APPEND INITIAL LINE TO mailtext.
              CONCATENATE 'Your user id' lv_uname 'has been locked in' lv_sys 'system due to inactivity.'
              INTO DATA(lv_body) SEPARATED BY space.
              APPEND lv_body TO mailtext.
              APPEND INITIAL LINE TO mailtext.
              APPEND 'From,' TO mailtext.
              APPEND 'Security Team' TO mailtext.
              CLEAR: lv_sys, lv_body.

              document = cl_document_bcs=>create_document(
                i_type    = 'RAW'
                i_text    = mailtext
                i_subject = mailsubject ).
              send_request->set_document( document ).

              sender = cl_cam_address_bcs=>create_internet_address( 'arnab.bhaduri@pwc.com' ).
              send_request->set_sender( sender ).

              recipient_to = cl_cam_address_bcs=>create_internet_address( ls_address-e_mail ).
              send_request->add_recipient( i_recipient = recipient_to ).
              DATA(lv_sent) = send_request->send( ).
              IF lv_sent = 'X'.
                ls_output-mail_sent = '@0V@'.
                ls_output-mail_msg = 'Mail has been sent to the User'.
                COMMIT WORK.
              ELSE.
                ls_output-mail_sent = '@0W@'.
                ls_output-mail_msg = 'Mail could not be sent to the User'.
              ENDIF.
            CATCH cx_bcs INTO bcs_exception.
              DATA(lv_excp) =  bcs_exception->get_text( ).
          ENDTRY.
        ENDIF.
      ELSE.
        ls_output-locked = '@0W@'.
        IF lt_return IS NOT INITIAL.
          ls_output-lock_msg = lt_return[ 1 ]-message.
        ENDIF.
        ls_output-mail_sent = '@0W@'.
        ls_output-mail_msg = 'Error occured while locking the user'.
      ENDIF.
      APPEND ls_output TO gt_lock_output.
      CLEAR: ls_output, lv_uname, lt_return, lt_ret_det, ls_address.
    ENDIF.
  ENDLOOP.

  CHECK gt_lock_output IS NOT INITIAL.

  DATA go_alv TYPE REF TO cl_salv_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table      = gt_lock_output[] ).

    CATCH cx_salv_msg.
  ENDTRY.

  DATA: lr_functions TYPE REF TO cl_salv_functions_list.

  lr_functions = go_alv->get_functions( ).
  lr_functions->set_all( 'X' ).

  IF go_alv IS BOUND.
    go_alv->set_screen_popup(
      start_column = 25
      end_column   = 100
      start_line   = 25
      end_line     = 30 ).

    go_alv->display( ).

  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form select_file
*&---------------------------------------------------------------------*
*& Opens the front-end file-open dialog (Excel filter) and returns the
*& chosen path.
*&   <--  P_P_FILE  Selected file name (unchanged if nothing picked).
*&---------------------------------------------------------------------*
FORM select_file  CHANGING p_p_file TYPE localfile.

  DATA: lv_rc         TYPE i,
        li_file_table TYPE filetable,
        lw_file_table TYPE file_table.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title = 'Select a file'
      file_filter  = 'Excel Workbook (*.xls)|*.xls'
    CHANGING
      file_table   = li_file_table
      rc           = lv_rc.
  IF sy-subrc = 0.
    READ TABLE li_file_table INTO lw_file_table INDEX 1.
    p_p_file = lw_file_table-filename.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form screen_modification
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN OUTPUT helper that keeps the role-level (screen
*& 0001) and user-level (screen 0002) "level" checkboxes in sync: ticking
*& "all" (L0) selects L1-L4 and vice-versa. Also shows/hides the role
*& assignment/removal block (group M04) on subscreen 9020 depending on
*& the RB_ADR radio button.
*&---------------------------------------------------------------------*
FORM screen_modification .

  IF sy-dynnr = 0001.
    IF sy-ucomm = 'RV10'.
      IF p_rlvl0 EQ abap_true.
        p_rlvl1 = abap_true.
        p_rlvl2 = abap_true.
        p_rlvl3 = abap_true.
        p_rlvl4 = abap_true.
      ELSE.
        p_rlvl1 = abap_false.
        p_rlvl2 = abap_false.
        p_rlvl3 = abap_false.
        p_rlvl4 = abap_false.
      ENDIF.
    ENDIF.
    IF sy-ucomm = 'RV11' OR
       sy-ucomm = 'RV12' OR
       sy-ucomm = 'RV13' OR
       sy-ucomm = 'RV14'.
      IF p_rlvl1 = abap_true AND
         p_rlvl2 = abap_true AND
         p_rlvl3 = abap_true AND
         p_rlvl4 = abap_true.
        p_rlvl0 = abap_true.
      ELSE.
        p_rlvl0 = abap_false.
      ENDIF.
    ENDIF.
  ELSEIF sy-dynnr = 0002.
    IF sy-ucomm = 'UV10'.
      IF p_ulvl0 EQ abap_true.
        p_ulvl1 = abap_true.
        p_ulvl2 = abap_true.
        p_ulvl3 = abap_true.
        p_ulvl4 = abap_true.
      ELSE.
        p_ulvl1 = abap_false.
        p_ulvl2 = abap_false.
        p_ulvl3 = abap_false.
        p_ulvl4 = abap_false.
      ENDIF.
    ENDIF.
    IF sy-ucomm = 'UV11' OR
       sy-ucomm = 'UV12' OR
       sy-ucomm = 'UV13' OR
       sy-ucomm = 'UV14'.
      IF p_ulvl1 = abap_true AND
         p_ulvl2 = abap_true AND
         p_ulvl3 = abap_true AND
         p_ulvl4 = abap_true.
        p_ulvl0 = abap_true.
      ELSE.
        p_ulvl0 = abap_false.
      ENDIF.
    ENDIF.
  ENDIF.

*** Role Assignment / Removal
  IF g_subscr_nr EQ 9020.
    LOOP AT SCREEN.
      IF rb_adr EQ 'X' AND screen-group1 EQ 'M04'.
        screen-active = 1.
        MODIFY SCREEN.
        CONTINUE.
      ELSEIF rb_adr EQ space AND screen-group1 EQ 'M04'.
        screen-active = 0.
        MODIFY SCREEN.
        CONTINUE.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9001
*&---------------------------------------------------------------------*
*& Main driver for the Role Risk Analysis screen (9001).
*&
*& Reads the selection-screen settings (role type S/C, risk levels
*& L0-L4, modules, summary vs detail, simulation flag/file) and calls
*& the risk-analysis function module ZACG_RISK_ROLES. Depending on the
*& result it shows the summary (screen 8001), detail (8002) or offers an
*& Excel download when the selection is too large to render online.
*& Handles the simulation upload path as well.
*&---------------------------------------------------------------------*
FORM user_command_9001.

  DATA: lv_answer(1) TYPE c,
        lv_detail    TYPE flag,
        lv_local     TYPE flag,
        lv_filename  TYPE string,
        lv_path      TYPE string,
        lv_fullpath  TYPE string,
        lv_action    TYPE i,
        lv_call      TYPE flag,
        lv_xml       TYPE string,
        lv_file      TYPE flag,
        lv_message   TYPE bapi_msg,

        lw_layout    TYPE lvc_s_layo,
        lw_excel     TYPE zacg_alsmex_tabline,

        o_grid_8001  TYPE REF TO cl_gui_alv_grid,

        li_roles     TYPE zt_role,
        li_level     TYPE zacg_t_level,
        li_fcat      TYPE lvc_t_fcat,
        li_tab       TYPE TABLE OF string,
        li_xml       TYPE STANDARD TABLE OF string,
        li_excel     TYPE STANDARD TABLE OF alsmex_tabline.


  CLEAR g_file.

  CLEAR: i_summary_9001, i_detail_9001.

  IF sy-ucomm = 'EXE'.
    sy-ucomm = g_ucomm = '&REX'.
  ENDIF.

  CASE g_ucomm.

    WHEN '&REX'.

      CLEAR: i_summary_9001, i_detail_9001.

      IF p_rsimu IS NOT INITIAL.
        p_role = 'C'.
      ENDIF.

      IF p_rlvl0 IS NOT INITIAL.
        CLEAR li_level.
      ELSE.
        IF p_rlvl1 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING FIELD-SYMBOL(<lfs_level>).
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '4'.
        ENDIF.
        IF p_rlvl2 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING <lfs_level>.
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '3'.
        ENDIF.
        IF p_rlvl3 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING <lfs_level>.
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '2'.
        ENDIF.
        IF p_rlvl4 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING <lfs_level>.
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '1'.
        ENDIF.
      ENDIF.

      IF p_role = 'S'.

        IF s_srole[] IS NOT INITIAL.
          IF p_rlvl0 IS INITIAL AND
             p_rlvl1 IS INITIAL AND
             p_rlvl2 IS INITIAL AND
             p_rlvl3 IS INITIAL AND
             p_rlvl4 IS INITIAL.
            CLEAR g_ucomm.
            MESSAGE 'Please provide Risk Level' TYPE 'S' DISPLAY LIKE 'E'.
          ELSE.
            " Get Unique Roles
            SELECT DISTINCT agr_name
              FROM agr_define
              WHERE agr_name IN @s_srole[]
              INTO TABLE @li_roles.
            IF sy-subrc IS INITIAL.

              IF r_dtl IS NOT INITIAL.
                lv_detail = abap_true.
                lv_call   = abap_true.
              ELSE.
                lv_call   = abap_true.
              ENDIF.

              IF lv_call   = abap_true.

                DATA(lv_text) = 'Processing'.
                CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
                  EXPORTING
                    percentage = 50
                    text       = lv_text.

                CLEAR: i_summary_9001, i_detail_9001.
                CALL FUNCTION 'ZACG_RISK_ROLES' DESTINATION 'NONE'
                  EXPORTING
                    it_role         = li_roles
                    iv_summary      = abap_true
                    iv_detail       = lv_detail
                    iv_local        = lv_local
                    iv_filename     = lv_filename
                    iv_fullpath     = lv_fullpath
                    it_level        = li_level
                    it_module       = s_rmod[]
                    iv_path         = lv_path
                  IMPORTING
                    et_risk_summary = i_summary_9001
                    et_risk_detail  = i_detail_9001
                    ev_file         = lv_file.

                IF lv_file IS INITIAL.

                  IF i_summary_9001 IS NOT INITIAL AND i_detail_9001 IS INITIAL.
                    CALL SCREEN 8001.
                  ELSEIF i_detail_9001 IS NOT INITIAL.
                    CALL SCREEN 8002.
                  ELSE.
                    MESSAGE 'No Risk Found' TYPE 'S'.
                  ENDIF.

                ELSE.

                  CLEAR: i_summary_9001, i_detail_9001.

                  CALL FUNCTION 'POPUP_TO_DECIDE_WITH_MESSAGE'
                    EXPORTING
                      diagnosetext1     = 'Due to wide selection range, results can not be displayed online.'
                      textline1         = 'Either selection range should be modified to minimise the result'
                      textline2         = 'or Excel download is recommended.'
                      textline3         = 'Do you want to continue with Excel download option?'
                      text_option1      = 'Continue'
                      text_option2      = 'Cancel'
                      icon_text_option1 = 'ICON_OKAY'
                      icon_text_option2 = 'ICON_CANCEL'
                      titel             = 'Warning'
                      cancel_display    = ' '
                    IMPORTING
                      answer            = lv_answer.
                  IF lv_answer = '1'. " User choose to continue to download the deatils in excel

                    CALL METHOD cl_gui_frontend_services=>file_save_dialog
                      EXPORTING
                        window_title      = 'Provide a location'
                        default_extension = 'xlsx'
                        file_filter       = 'Excel Workbook (*.xlsx)|*.xlsx'
                      CHANGING
                        filename          = lv_filename
                        path              = lv_path
                        fullpath          = lv_fullpath
                        user_action       = lv_action.
                    IF lv_action = 0.
                      lv_call   = abap_true.
                      lv_detail = abap_true.
                      lv_local  = abap_true.
                    ENDIF.

                    IF lv_call   = abap_true.

                      CALL FUNCTION 'ZACG_RISK_ROLES' DESTINATION 'NONE'
                        EXPORTING
                          it_role     = li_roles
                          iv_summary  = abap_true
                          iv_detail   = lv_detail
                          iv_local    = lv_local
                          iv_filename = lv_filename
                          iv_fullpath = lv_fullpath
                          it_level    = li_level
                          it_module   = s_rmod[]
                          iv_path     = lv_path
                        IMPORTING
                          ev_message  = lv_message.

                      MESSAGE lv_message TYPE 'S'.

                    ENDIF.

                  ENDIF.

                ENDIF.

              ENDIF.
            ELSE.
              CLEAR g_ucomm.
              MESSAGE 'Please provide valid Role(s)' TYPE 'S' DISPLAY LIKE 'E'.
            ENDIF.
          ENDIF.
        ELSE.
          CLEAR g_ucomm.
          MESSAGE 'Please provide valid Role(s)' TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.

      ELSEIF p_role = 'C'.

        IF p_rlvl0 IS INITIAL AND
           p_rlvl1 IS INITIAL AND
           p_rlvl2 IS INITIAL AND
           p_rlvl3 IS INITIAL AND
           p_rlvl4 IS INITIAL.

          CLEAR g_ucomm.
          MESSAGE 'Please provide Risk Level' TYPE 'S' DISPLAY LIKE 'E'.

        ELSE.

          IF r_dtl IS NOT INITIAL.
            lv_detail = abap_true.
          ENDIF.

          IF p_rsimu IS INITIAL.

            IF s_crole[] IS NOT INITIAL.

              " Get Roles from Composite
              SELECT DISTINCT agr_name
                FROM agr_agrs
                WHERE agr_name IN @s_crole[]
                  AND attributes = @space
              ORDER BY agr_name
              INTO TABLE @DATA(li_agr_agrs).
              IF sy-subrc IS INITIAL.
                lv_call = abap_true.
              ELSE.
                CLEAR g_ucomm.
                MESSAGE 'Please provide valid Composite Role(s)' TYPE 'S' DISPLAY LIKE 'E'.
              ENDIF.
            ELSE.
              CLEAR g_ucomm.
              MESSAGE 'Please provide valid Composite Role(s)' TYPE 'S' DISPLAY LIKE 'E'.
            ENDIF.
          ELSE.

            IF p_rfile IS NOT INITIAL.

              CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
                EXPORTING
                  filename                = p_rfile
                  i_begin_col             = 1
                  i_begin_row             = 1
                  i_end_col               = 2
                  i_end_row               = 1
                TABLES
                  intern                  = li_excel
                EXCEPTIONS
                  inconsistent_parameters = 1
                  upload_ole              = 2
                  OTHERS                  = 3.
              IF sy-subrc IS INITIAL.

                LOOP AT li_excel INTO lw_excel.
                  CASE lw_excel-col.
                    WHEN 1.
                      IF lw_excel-value <> 'Composite Role'.
                        CLEAR g_ucomm.
                        EXIT.
                      ENDIF.
                    WHEN 2.
                      IF lw_excel-value <> 'Single Role'.
                        CLEAR g_ucomm.
                        EXIT.
                      ENDIF.
                  ENDCASE.
                ENDLOOP.

                IF g_ucomm IS INITIAL.
                  MESSAGE 'Invalid file format. Click on Download button for correct format' TYPE 'S' DISPLAY LIKE 'E'.
                ELSE.
                  lv_call   = abap_true.
                ENDIF.

              ELSE.
                CLEAR g_ucomm.
                MESSAGE 'Please provide simulation file in xls format only' TYPE 'S' DISPLAY LIKE 'E'.
              ENDIF.
            ELSE.
              CLEAR g_ucomm.
              MESSAGE 'Please provide simulation file in xls format only' TYPE 'S' DISPLAY LIKE 'E'.
            ENDIF.
          ENDIF.
        ENDIF.

        IF lv_call = abap_true.

          lv_text = 'Processing'.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING
              percentage = 50
              text       = lv_text.

          CLEAR: i_summary_9001, i_detail_9001.

          IF p_rsimu IS INITIAL.
            CALL FUNCTION 'ZACG_RISK_COMPOSITE_ROLES' DESTINATION 'NONE'
              EXPORTING
                it_role         = li_agr_agrs
                iv_summary      = abap_true
                iv_detail       = lv_detail
                iv_local        = lv_local
                iv_filename     = lv_filename
                iv_fullpath     = lv_fullpath
                it_level        = li_level
                it_module       = s_rmod[]
                iv_path         = lv_path
              IMPORTING
                et_risk_summary = i_summary_9001
                et_risk_detail  = i_detail_9001
                ev_file         = lv_file.
          ELSE.
            CALL FUNCTION 'ZACG_RISK_COMPOSITE_SIMULATION' DESTINATION 'NONE'
              EXPORTING
                iv_sumulationfile = p_rfile
                iv_summary        = abap_true
                iv_detail         = lv_detail
                iv_local          = lv_local
                iv_filename       = lv_filename
                iv_fullpath       = lv_fullpath
                it_level          = li_level
                it_module         = s_rmod[]
                iv_path           = lv_path
              IMPORTING
                et_risk_summary   = i_summary_9001
                et_risk_detail    = i_detail_9001
                ev_file           = lv_file.

          ENDIF.

          IF lv_file IS INITIAL. " No Memory issue hence continue with ALV
            IF i_summary_9001 IS NOT INITIAL AND i_detail_9001 IS INITIAL.
              CALL SCREEN 8003.
            ELSEIF i_detail_9001 IS NOT INITIAL.
              CALL SCREEN 8004.
            ELSE.
              MESSAGE 'No Risk Found' TYPE 'S'.
            ENDIF.
          ELSE.

            CALL FUNCTION 'POPUP_TO_DECIDE_WITH_MESSAGE'
              EXPORTING
                diagnosetext1     = 'Due to wide selection range, results can not be displayed online.'
                textline1         = 'Either selection range should be modified to minimise the result'
                textline2         = 'or Excel download is recommended.'
                textline3         = 'Do you want to continue with Excel download option?'
                text_option1      = 'Continue'
                text_option2      = 'Cancel'
                icon_text_option1 = 'ICON_OKAY'
                icon_text_option2 = 'ICON_CANCEL'
                titel             = 'Warning'
                cancel_display    = ' '
              IMPORTING
                answer            = lv_answer.
            IF lv_answer = '1'. " User choose to continue to download the deatils in excel

              CLEAR: i_summary_9001, i_detail_9001.

              CALL METHOD cl_gui_frontend_services=>file_save_dialog
                EXPORTING
                  window_title      = 'Provide a location'
                  default_extension = 'xlsx'
                  file_filter       = 'Excel Workbook (*.xlsx)|*.xlsx'
                CHANGING
                  filename          = lv_filename
                  path              = lv_path
                  fullpath          = lv_fullpath
                  user_action       = lv_action.
              IF lv_action = 0.
                lv_call   = abap_true.
                lv_detail = abap_true.
                lv_local  = abap_true.
              ENDIF.

              IF lv_call   = abap_true.

                IF p_rsimu IS INITIAL.
                  CALL FUNCTION 'ZACG_RISK_COMPOSITE_ROLES' DESTINATION 'NONE'
                    EXPORTING
                      it_role     = li_agr_agrs
                      iv_summary  = abap_true
                      iv_detail   = lv_detail
                      iv_local    = lv_local
                      iv_filename = lv_filename
                      iv_fullpath = lv_fullpath
                      it_level    = li_level
                      it_module   = s_rmod[]
                      iv_path     = lv_path
                    IMPORTING
                      ev_message  = lv_message.
                ELSE.
                  CALL FUNCTION 'ZACG_RISK_COMPOSITE_SIMULATION' DESTINATION 'NONE'
                    EXPORTING
                      iv_sumulationfile = p_rfile
                      iv_summary        = abap_true
                      iv_detail         = lv_detail
                      iv_local          = lv_local
                      iv_filename       = lv_filename
                      iv_fullpath       = lv_fullpath
                      it_level          = li_level
                      it_module         = s_rmod[]
                      iv_path           = lv_path
                    IMPORTING
                      ev_message        = lv_message.
                ENDIF.

                MESSAGE lv_message TYPE 'S'.

              ENDIF.

            ENDIF.
          ENDIF.

        ENDIF.

      ELSE.

        IF p_rsimu IS INITIAL.
          CLEAR g_ucomm.
          MESSAGE 'Please select Role Type' TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.

      ENDIF.

    WHEN 'DFMT'.

      TRY.
          CALL TRANSFORMATION zacg_composite_simulation
          SOURCE it_tab = li_tab
          RESULT XML lv_xml.
        CATCH cx_root INTO DATA(ls_error).
          DATA(lv_error) = ls_error->get_text( ).
          MESSAGE lv_error TYPE 'E'.
      ENDTRY.

      IF lv_xml IS NOT INITIAL.

        APPEND lv_xml TO li_xml.

        CALL METHOD cl_gui_frontend_services=>file_save_dialog
          EXPORTING
            window_title      = 'Provide a location'
            default_extension = 'xls'
            file_filter       = 'xls file (*.xls)|*.xls'
          CHANGING
            filename          = lv_filename
            path              = lv_path
            fullpath          = lv_fullpath
            user_action       = lv_action.
        IF lv_action = 0.

          CALL METHOD cl_gui_frontend_services=>gui_download
            EXPORTING
              filetype = 'ASC'
              filename = lv_fullpath
            CHANGING
              data_tab = li_xml
            EXCEPTIONS
              OTHERS   = 1.
          IF sy-subrc IS INITIAL.
            MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          ENDIF.

        ENDIF.

      ENDIF.
    WHEN OTHERS.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_role_sumary_columns
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM set_role_summary_columns USING comp CHANGING li_fact TYPE lvc_t_fcat.


  IF comp = 'C'.
    APPEND INITIAL LINE TO li_fact ASSIGNING FIELD-SYMBOL(<lfs_fact>).
    <lfs_fact>-fieldname = 'COMPOSITE'.
    <lfs_fact>-tabname   = 'AGR_1251'.
    <lfs_fact>-rollname  = 'AGR_NAME'.
    <lfs_fact>-ref_table = 'AGR_1251'.
    <lfs_fact>-ref_field = 'AGR_NAME'.
    <lfs_fact>-scrtext_l = 'Composite Role'.
    <lfs_fact>-scrtext_m = 'Composite Role'.
    <lfs_fact>-scrtext_s = 'Composite Role'.
    <lfs_fact>-col_opt   = abap_true.

    APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
    <lfs_fact>-fieldname = 'AGR_NAME'.
    <lfs_fact>-tabname   = 'AGR_1251'.
    <lfs_fact>-rollname  = 'AGR_NAME'.
    <lfs_fact>-ref_table = 'AGR_1251'.
    <lfs_fact>-ref_field = 'AGR_NAME'.
    <lfs_fact>-scrtext_l = 'Single Role'.
    <lfs_fact>-scrtext_m = 'Single Role'.
    <lfs_fact>-scrtext_s = 'Single Role'.
    <lfs_fact>-col_opt   = abap_true.

  ELSEIF comp = 'U'.
    APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
    <lfs_fact>-fieldname = 'USER'.
    <lfs_fact>-tabname   = 'AGR_USERS'.
    <lfs_fact>-rollname  = 'XUBNAME'.
    <lfs_fact>-ref_table = 'AGR_USERS'.
    <lfs_fact>-ref_field = 'UNAME'.
    <lfs_fact>-scrtext_l = 'User ID'.
    <lfs_fact>-scrtext_m = 'User ID'.
    <lfs_fact>-scrtext_s = 'User ID'.
    <lfs_fact>-col_opt   = abap_true.

    DATA(li_summary) = i_summary_9001.
    DELETE li_summary WHERE composite IS INITIAL.
    IF li_summary IS NOT INITIAL.

      APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
      <lfs_fact>-fieldname = 'COMPOSITE'.
      <lfs_fact>-tabname   = 'AGR_1251'.
      <lfs_fact>-rollname  = 'AGR_NAME'.
      <lfs_fact>-ref_table = 'AGR_1251'.
      <lfs_fact>-ref_field = 'AGR_NAME'.
      <lfs_fact>-scrtext_l = 'Composite Role'.
      <lfs_fact>-scrtext_m = 'Composite Role'.
      <lfs_fact>-scrtext_s = 'Composite Role'.
      <lfs_fact>-col_opt   = abap_true.

      APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
      <lfs_fact>-fieldname = 'AGR_NAME'.
      <lfs_fact>-tabname   = 'AGR_1251'.
      <lfs_fact>-rollname  = 'AGR_NAME'.
      <lfs_fact>-ref_table = 'AGR_1251'.
      <lfs_fact>-ref_field = 'AGR_NAME'.
      <lfs_fact>-scrtext_l = 'Single Role'.
      <lfs_fact>-scrtext_m = 'Single Role'.
      <lfs_fact>-scrtext_s = 'Single Role'.
      <lfs_fact>-col_opt   = abap_true.

    ELSE.

      APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
      <lfs_fact>-fieldname = 'AGR_NAME'.
      <lfs_fact>-tabname   = 'AGR_1251'.
      <lfs_fact>-rollname  = 'AGR_NAME'.
      <lfs_fact>-ref_table = 'AGR_1251'.
      <lfs_fact>-ref_field = 'AGR_NAME'.
      <lfs_fact>-scrtext_l = 'Role name'.
      <lfs_fact>-scrtext_m = 'Role name'.
      <lfs_fact>-scrtext_s = 'Role'.
      <lfs_fact>-col_opt   = abap_true.

    ENDIF.

  ELSE.

    APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
    <lfs_fact>-fieldname = 'AGR_NAME'.
    <lfs_fact>-tabname   = 'AGR_1251'.
    <lfs_fact>-rollname  = 'AGR_NAME'.
    <lfs_fact>-ref_table = 'AGR_1251'.
    <lfs_fact>-ref_field = 'AGR_NAME'.
    <lfs_fact>-scrtext_l = 'Role name'.
    <lfs_fact>-scrtext_m = 'Role name'.
    <lfs_fact>-scrtext_s = 'Role'.
    <lfs_fact>-col_opt   = abap_true.

  ENDIF.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'RISK'.
  <lfs_fact>-scrtext_l = 'Risk Id'.
  <lfs_fact>-scrtext_m = 'Risk Id'.
  <lfs_fact>-scrtext_s = 'Risk Id'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'RISKD'.
  <lfs_fact>-scrtext_l = 'Risk Description'.
  <lfs_fact>-scrtext_m = 'Risk Description'.
  <lfs_fact>-scrtext_s = 'Risk Description'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'LEVELD'.
  <lfs_fact>-scrtext_l = 'Level'.
  <lfs_fact>-scrtext_m = 'Level'.
  <lfs_fact>-scrtext_s = 'Level'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'TYPED'.
  <lfs_fact>-scrtext_l = 'Risk Type'.
  <lfs_fact>-scrtext_m = 'Risk Type'.
  <lfs_fact>-scrtext_s = 'Type'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'MODULED'.
  <lfs_fact>-scrtext_l = 'Module'.
  <lfs_fact>-scrtext_m = 'Module'.
  <lfs_fact>-scrtext_s = 'Module'.
  <lfs_fact>-col_opt   = abap_true.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_role_detail_columns
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LI_FACT
*&---------------------------------------------------------------------*
FORM set_role_detail_columns  USING comp CHANGING li_fact TYPE lvc_t_fcat.

  IF comp = 'C'.
    APPEND INITIAL LINE TO li_fact ASSIGNING FIELD-SYMBOL(<lfs_fact>).
    <lfs_fact>-fieldname = 'COMPOSITE'.
    <lfs_fact>-tabname   = 'AGR_1251'.
    <lfs_fact>-rollname  = 'AGR_NAME'.
    <lfs_fact>-ref_table = 'AGR_1251'.
    <lfs_fact>-ref_field = 'AGR_NAME'.
    <lfs_fact>-scrtext_l = 'Composite Role'.
    <lfs_fact>-scrtext_m = 'Composite Role'.
    <lfs_fact>-scrtext_s = 'Composite Role'.
    <lfs_fact>-col_opt   = abap_true.

    APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
    <lfs_fact>-fieldname = 'AGR_NAME'.
    <lfs_fact>-tabname   = 'AGR_1251'.
    <lfs_fact>-rollname  = 'AGR_NAME'.
    <lfs_fact>-ref_table = 'AGR_1251'.
    <lfs_fact>-ref_field = 'AGR_NAME'.
    <lfs_fact>-scrtext_l = 'Single Role'.
    <lfs_fact>-scrtext_m = 'Single Role'.
    <lfs_fact>-scrtext_s = 'Single Role'.
    <lfs_fact>-col_opt   = abap_true.

  ELSEIF comp = 'U'.
    APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
    <lfs_fact>-fieldname = 'USER'.
    <lfs_fact>-tabname   = 'AGR_USERS'.
    <lfs_fact>-rollname  = 'XUBNAME'.
    <lfs_fact>-ref_table = 'AGR_USERS'.
    <lfs_fact>-ref_field = 'UNAME'.
    <lfs_fact>-scrtext_l = 'User ID'.
    <lfs_fact>-scrtext_m = 'User ID'.
    <lfs_fact>-scrtext_s = 'User ID'.
    <lfs_fact>-col_opt   = abap_true.

    DATA(li_detail) = i_detail_9001.
    DELETE li_detail WHERE composite IS INITIAL.
    IF li_detail IS NOT INITIAL.
      APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
      <lfs_fact>-fieldname = 'COMPOSITE'.
      <lfs_fact>-tabname   = 'AGR_1251'.
      <lfs_fact>-rollname  = 'AGR_NAME'.
      <lfs_fact>-ref_table = 'AGR_1251'.
      <lfs_fact>-ref_field = 'AGR_NAME'.
      <lfs_fact>-scrtext_l = 'Composite Role'.
      <lfs_fact>-scrtext_m = 'Composite Role'.
      <lfs_fact>-scrtext_s = 'Composite Role'.
      <lfs_fact>-col_opt   = abap_true.

      APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
      <lfs_fact>-fieldname = 'AGR_NAME'.
      <lfs_fact>-tabname   = 'AGR_1251'.
      <lfs_fact>-rollname  = 'AGR_NAME'.
      <lfs_fact>-ref_table = 'AGR_1251'.
      <lfs_fact>-ref_field = 'AGR_NAME'.
      <lfs_fact>-scrtext_l = 'Single Role'.
      <lfs_fact>-scrtext_m = 'Single Role'.
      <lfs_fact>-scrtext_s = 'Single Role'.
      <lfs_fact>-col_opt   = abap_true.

    ELSE.
      APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
      <lfs_fact>-fieldname = 'AGR_NAME'.
      <lfs_fact>-tabname   = 'AGR_1251'.
      <lfs_fact>-rollname  = 'AGR_NAME'.
      <lfs_fact>-ref_table = 'AGR_1251'.
      <lfs_fact>-ref_field = 'AGR_NAME'.
      <lfs_fact>-scrtext_l = 'Role name'.
      <lfs_fact>-scrtext_m = 'Role name'.
      <lfs_fact>-scrtext_s = 'Role'.
      <lfs_fact>-col_opt   = abap_true.
    ENDIF.

  ELSE.
    APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
    <lfs_fact>-fieldname = 'AGR_NAME'.
    <lfs_fact>-tabname   = 'AGR_1251'.
    <lfs_fact>-rollname  = 'AGR_NAME'.
    <lfs_fact>-ref_table = 'AGR_1251'.
    <lfs_fact>-ref_field = 'AGR_NAME'.
    <lfs_fact>-scrtext_l = 'Role name'.
    <lfs_fact>-scrtext_m = 'Role name'.
    <lfs_fact>-scrtext_s = 'Role'.
    <lfs_fact>-col_opt   = abap_true.
  ENDIF.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'RISK'.
  <lfs_fact>-scrtext_l = 'Risk Id'.
  <lfs_fact>-scrtext_m = 'Risk Id'.
  <lfs_fact>-scrtext_s = 'Risk Id'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'RISKD'.
  <lfs_fact>-scrtext_l = 'Risk Description'.
  <lfs_fact>-scrtext_m = 'Risk Description'.
  <lfs_fact>-scrtext_s = 'Risk Description'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'FUNC'.
  <lfs_fact>-scrtext_l = 'Function Id'.
  <lfs_fact>-scrtext_m = 'Function Id'.
  <lfs_fact>-scrtext_s = 'Function Id'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'FUNCD'.
  <lfs_fact>-scrtext_l = 'Function Description'.
  <lfs_fact>-scrtext_m = 'Function Description'.
  <lfs_fact>-scrtext_s = 'Function Description'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'TCODE'.
  <lfs_fact>-scrtext_l = 'TCode / Service'.
  <lfs_fact>-scrtext_m = 'Transaction / Service'.
  <lfs_fact>-scrtext_s = 'Transaction / Service'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'OBJECT'.
  <lfs_fact>-scrtext_l = 'Object'.
  <lfs_fact>-scrtext_m = 'Object'.
  <lfs_fact>-scrtext_s = 'Object'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'FIELD'.
  <lfs_fact>-scrtext_l = 'Field'.
  <lfs_fact>-scrtext_m = 'Field'.
  <lfs_fact>-scrtext_s = 'Field'.
  <lfs_fact>-col_opt   = abap_true.

  APPEND INITIAL LINE TO li_fact ASSIGNING <lfs_fact>.
  <lfs_fact>-fieldname = 'LOW'.
  <lfs_fact>-scrtext_l = 'Low'.
  <lfs_fact>-scrtext_m = 'Low'.
  <lfs_fact>-scrtext_s = 'Low'.
  <lfs_fact>-col_opt   = abap_true.

  LOOP AT li_fact ASSIGNING <lfs_fact>.
    <lfs_fact>-col_pos = sy-tabix.
  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form docking_9101
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form user_command_8001
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_8001 .

  g_ucomm = sy-ucomm.
  CASE g_ucomm.
    WHEN 'BACK' OR 'CANCEL' OR 'EXIT'.
      CLEAR g_ucomm.
      LEAVE TO SCREEN 0.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_8001
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_8001.

  DATA:
    lw_layout TYPE lvc_s_layo,
    li_fcat   TYPE lvc_t_fcat.


  CREATE OBJECT o_conttainer_8001
    EXPORTING
      container_name = 'CC_8001'.

  CREATE OBJECT o_docu_8001
    EXPORTING
      style = 'ALV_GRID'.

  CREATE OBJECT o_splitter_8001
    EXPORTING
      parent  = o_conttainer_8001
      rows    = 2
      columns = 1.

  o_top_cont_8001 = o_splitter_8001->get_container( row = 1 column = 1 ).

  o_bot_cont_8001 = o_splitter_8001->get_container( row = 2 column = 1 ).

  CALL METHOD o_splitter_8001->set_row_height
    EXPORTING
      id     = 1
      height = 35.

  CREATE OBJECT o_grid_8001
    EXPORTING
      i_parent = o_bot_cont_8001.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_top_of_page_8001 FOR o_grid_8001.
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8001.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8001.

  lw_layout-zebra      = abap_true.
  lw_layout-cwidth_opt = abap_true.
  lw_layout-box_fname  = 'SEL'.
  lw_layout-sel_mode   = 'A'.

  PERFORM set_role_summary_columns USING '' CHANGING li_fcat.

  CALL METHOD o_grid_8001->set_table_for_first_display
    EXPORTING
      is_layout       = lw_layout
    CHANGING
      it_outtab       = i_summary_9001
      it_fieldcatalog = li_fcat.

  CALL METHOD o_grid_8001->set_toolbar_interactive.

  CALL METHOD o_docu_8001->initialize_document
    EXPORTING
      background_color = cl_dd_area=>col_textarea.

  CALL METHOD o_grid_8001->list_processing_events
    EXPORTING
      i_event_name = 'TOP_OF_PAGE'
      i_dyndoc_id  = o_docu_8001.

ENDFORM.

FORM show_8002.

  DATA:
    lw_layout TYPE lvc_s_layo,
    li_fcat   TYPE lvc_t_fcat.

  CREATE OBJECT o_conttainer_8002
    EXPORTING
      container_name = 'CC_8002'.

  CREATE OBJECT o_docu_8002
    EXPORTING
      style = 'ALV_GRID'.

  CREATE OBJECT o_splitter_8002
    EXPORTING
      parent  = o_conttainer_8002
      rows    = 2
      columns = 1.

  o_top_cont_8002 = o_splitter_8002->get_container( row = 1 column = 1 ).

  o_bot_cont_8002 = o_splitter_8002->get_container( row = 2 column = 1 ).

  CALL METHOD o_splitter_8002->set_row_height
    EXPORTING
      id     = 1
      height = 35.

  CREATE OBJECT o_grid_8002
    EXPORTING
      i_parent = o_bot_cont_8002.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_top_of_page_8002 FOR o_grid_8002.
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8002.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8002.

  lw_layout-zebra      = abap_true.
  lw_layout-cwidth_opt = abap_true.
  lw_layout-box_fname  = 'SEL'.
  lw_layout-sel_mode   = 'A'.

  PERFORM set_role_detail_columns USING '' CHANGING li_fcat.

  CALL METHOD o_grid_8002->set_table_for_first_display
    EXPORTING
      is_layout       = lw_layout
    CHANGING
      it_outtab       = i_detail_9001
      it_fieldcatalog = li_fcat.

  CALL METHOD o_docu_8002->initialize_document
    EXPORTING
      background_color = cl_dd_area=>col_textarea.

  CALL METHOD o_grid_8002->list_processing_events
    EXPORTING
      i_event_name = 'TOP_OF_PAGE'
      i_dyndoc_id  = o_docu_8002.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form show_8003
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_8003.

  DATA:
    lw_layout TYPE lvc_s_layo,
    li_fcat   TYPE lvc_t_fcat.

  CREATE OBJECT o_conttainer_8003
    EXPORTING
      container_name = 'CC_8003'.

  CREATE OBJECT o_docu_8003
    EXPORTING
      style = 'ALV_GRID'.

  CREATE OBJECT o_splitter_8003
    EXPORTING
      parent  = o_conttainer_8003
      rows    = 2
      columns = 1.

  o_top_cont_8003 = o_splitter_8003->get_container( row = 1 column = 1 ).

  o_bot_cont_8003 = o_splitter_8003->get_container( row = 2 column = 1 ).

  CALL METHOD o_splitter_8003->set_row_height
    EXPORTING
      id     = 1
      height = 35.

  CREATE OBJECT o_grid_8003
    EXPORTING
      i_parent = o_bot_cont_8003.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_top_of_page_8003 FOR o_grid_8003.
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8003.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8003.

  lw_layout-zebra      = abap_true.
  lw_layout-cwidth_opt = abap_true.
  lw_layout-box_fname  = 'SEL'.
  lw_layout-sel_mode   = 'A'.

  PERFORM set_role_summary_columns USING 'C' CHANGING li_fcat.

  CALL METHOD o_grid_8003->set_table_for_first_display
    EXPORTING
      is_layout       = lw_layout
    CHANGING
      it_outtab       = i_summary_9001
      it_fieldcatalog = li_fcat.

  CALL METHOD o_docu_8003->initialize_document
    EXPORTING
      background_color = cl_dd_area=>col_textarea.

  CALL METHOD o_grid_8003->list_processing_events
    EXPORTING
      i_event_name = 'TOP_OF_PAGE'
      i_dyndoc_id  = o_docu_8003.

ENDFORM.

FORM show_8004.

  DATA:
    lw_layout TYPE lvc_s_layo,
    li_fcat   TYPE lvc_t_fcat.

  CREATE OBJECT o_conttainer_8004
    EXPORTING
      container_name = 'CC_8004'.

  CREATE OBJECT o_docu_8004
    EXPORTING
      style = 'ALV_GRID'.

  CREATE OBJECT o_splitter_8004
    EXPORTING
      parent  = o_conttainer_8004
      rows    = 2
      columns = 1.

  o_top_cont_8004 = o_splitter_8004->get_container( row = 1 column = 1 ).

  o_bot_cont_8004 = o_splitter_8004->get_container( row = 2 column = 1 ).

  CALL METHOD o_splitter_8004->set_row_height
    EXPORTING
      id     = 1
      height = 35.

  CREATE OBJECT o_grid_8004
    EXPORTING
      i_parent = o_bot_cont_8004.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_top_of_page_8004 FOR o_grid_8004.
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8004.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8004.

  lw_layout-zebra      = abap_true.
  lw_layout-cwidth_opt = abap_true.
  lw_layout-box_fname  = 'SEL'.
  lw_layout-sel_mode   = 'A'.

  PERFORM set_role_detail_columns USING 'C' CHANGING li_fcat.

  CALL METHOD o_grid_8004->set_table_for_first_display
    EXPORTING
      is_layout       = lw_layout
    CHANGING
      it_outtab       = i_detail_9001
      it_fieldcatalog = li_fcat.

  CALL METHOD o_docu_8004->initialize_document
    EXPORTING
      background_color = cl_dd_area=>col_textarea.

  CALL METHOD o_grid_8004->list_processing_events
    EXPORTING
      i_event_name = 'TOP_OF_PAGE'
      i_dyndoc_id  = o_docu_8004.

ENDFORM.

FORM show_8005.

  DATA:
    lw_layout TYPE lvc_s_layo,
    li_fcat   TYPE lvc_t_fcat.


  CREATE OBJECT o_conttainer_8005
    EXPORTING
      container_name = 'CC_8005'.

  CREATE OBJECT o_docu_8005
    EXPORTING
      style = 'ALV_GRID'.

  CREATE OBJECT o_splitter_8005
    EXPORTING
      parent  = o_conttainer_8005
      rows    = 2
      columns = 1.

  o_top_cont_8005 = o_splitter_8005->get_container( row = 1 column = 1 ).

  o_bot_cont_8005 = o_splitter_8005->get_container( row = 2 column = 1 ).

  CALL METHOD o_splitter_8005->set_row_height
    EXPORTING
      id     = 1
      height = 35.

  CREATE OBJECT o_grid_8005
    EXPORTING
      i_parent = o_bot_cont_8005.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_top_of_page_8005 FOR o_grid_8005.
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8005.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8005.

  lw_layout-zebra      = abap_true.
  lw_layout-cwidth_opt = abap_true.
  lw_layout-box_fname  = 'SEL'.
  lw_layout-sel_mode   = 'A'.

  PERFORM set_role_summary_columns USING 'U' CHANGING li_fcat.

  CALL METHOD o_grid_8005->set_table_for_first_display
    EXPORTING
      is_layout       = lw_layout
    CHANGING
      it_outtab       = i_summary_9001
      it_fieldcatalog = li_fcat.

  CALL METHOD o_grid_8005->set_toolbar_interactive.

  CALL METHOD o_docu_8005->initialize_document
    EXPORTING
      background_color = cl_dd_area=>col_textarea.

  CALL METHOD o_grid_8005->list_processing_events
    EXPORTING
      i_event_name = 'TOP_OF_PAGE'
      i_dyndoc_id  = o_docu_8005.

ENDFORM.


FORM show_8006.

  DATA:
    lw_layout TYPE lvc_s_layo,
    li_fcat   TYPE lvc_t_fcat.

  CREATE OBJECT o_conttainer_8006
    EXPORTING
      container_name = 'CC_8006'.

  CREATE OBJECT o_docu_8006
    EXPORTING
      style = 'ALV_GRID'.

  CREATE OBJECT o_splitter_8006
    EXPORTING
      parent  = o_conttainer_8006
      rows    = 2
      columns = 1.

  o_top_cont_8006 = o_splitter_8006->get_container( row = 1 column = 1 ).

  o_bot_cont_8006 = o_splitter_8006->get_container( row = 2 column = 1 ).

  CALL METHOD o_splitter_8006->set_row_height
    EXPORTING
      id     = 1
      height = 35.

  CREATE OBJECT o_grid_8006
    EXPORTING
      i_parent = o_bot_cont_8006.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_top_of_page_8006 FOR o_grid_8006.
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8006.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8006.

  lw_layout-zebra      = abap_true.
  lw_layout-cwidth_opt = abap_true.
  lw_layout-box_fname  = 'SEL'.
  lw_layout-sel_mode   = 'A'.

  PERFORM set_role_detail_columns USING 'U' CHANGING li_fcat.

  CALL METHOD o_grid_8006->set_table_for_first_display
    EXPORTING
      is_layout       = lw_layout
    CHANGING
      it_outtab       = i_detail_9001
      it_fieldcatalog = li_fcat.

  CALL METHOD o_docu_8006->initialize_document
    EXPORTING
      background_color = cl_dd_area=>col_textarea.

  CALL METHOD o_grid_8006->list_processing_events
    EXPORTING
      i_event_name = 'TOP_OF_PAGE'
      i_dyndoc_id  = o_docu_8006.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form doc_display
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM doc_display_8001.

  IF o_html_8001 IS INITIAL.
    CREATE OBJECT o_html_8001
      EXPORTING
        parent = o_top_cont_8001.
  ENDIF.

  CALL METHOD o_docu_8001->merge_document.

  o_docu_8001->html_control = o_html_8001.

  CALL METHOD o_docu_8001->display_document
    EXPORTING
      reuse_control      = 'X'
      parent             = o_top_cont_8001
    EXCEPTIONS
      html_display_error = 1
      OTHERS             = 2.

ENDFORM.

FORM doc_display_8002.

  IF o_html_8002 IS INITIAL.
    CREATE OBJECT o_html_8002
      EXPORTING
        parent = o_top_cont_8002.
  ENDIF.

  CALL METHOD o_docu_8002->merge_document.

  o_docu_8002->html_control = o_html_8002.

  CALL METHOD o_docu_8002->display_document
    EXPORTING
      reuse_control      = abap_true
      parent             = o_top_cont_8002
    EXCEPTIONS
      html_display_error = 1
      OTHERS             = 2.

ENDFORM.

FORM doc_display_8003.

  IF o_html_8003 IS INITIAL.
    CREATE OBJECT o_html_8003
      EXPORTING
        parent = o_top_cont_8003.
  ENDIF.

  CALL METHOD o_docu_8003->merge_document.

  o_docu_8003->html_control = o_html_8003.

  CALL METHOD o_docu_8003->display_document
    EXPORTING
      reuse_control      = 'X'
      parent             = o_top_cont_8003
    EXCEPTIONS
      html_display_error = 1
      OTHERS             = 2.

ENDFORM.

FORM doc_display_8004.

  IF o_html_8004 IS INITIAL.
    CREATE OBJECT o_html_8004
      EXPORTING
        parent = o_top_cont_8004.
  ENDIF.

  CALL METHOD o_docu_8004->merge_document.

  o_docu_8004->html_control = o_html_8004.

  CALL METHOD o_docu_8004->display_document
    EXPORTING
      reuse_control      = 'X'
      parent             = o_top_cont_8004
    EXCEPTIONS
      html_display_error = 1
      OTHERS             = 2.

ENDFORM.

FORM doc_display_8005.

  IF o_html_8005 IS INITIAL.
    CREATE OBJECT o_html_8005
      EXPORTING
        parent = o_top_cont_8005.
  ENDIF.

  CALL METHOD o_docu_8005->merge_document.

  o_docu_8005->html_control = o_html_8005.

  CALL METHOD o_docu_8005->display_document
    EXPORTING
      reuse_control      = 'X'
      parent             = o_top_cont_8005
    EXCEPTIONS
      html_display_error = 1
      OTHERS             = 2.

ENDFORM.

FORM doc_display_8006.

  IF o_html_8006 IS INITIAL.
    CREATE OBJECT o_html_8006
      EXPORTING
        parent = o_top_cont_8006.
  ENDIF.

  CALL METHOD o_docu_8006->merge_document.

  o_docu_8006->html_control = o_html_8006.

  CALL METHOD o_docu_8006->display_document
    EXPORTING
      reuse_control      = 'X'
      parent             = o_top_cont_8006
    EXCEPTIONS
      html_display_error = 1
      OTHERS             = 2.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form handle_top_of_page_8001
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM handle_top_of_page_8001 .

  DATA:
    lv_count         TYPE i,
    lv_count_c       TYPE string,
    lv_width         TYPE i,
    lv_text          TYPE sdydo_text_element,
    li_list_comments TYPE slis_t_listheader,
    li_summary_9001  TYPE zacg_t_risk_summary,
    li_comments      TYPE slis_t_listheader.


  CLEAR lv_text.
  lv_text = 'Selection Criteria'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8001->new_line.

  CLEAR lv_text.
  lv_text = 'Role Type'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8001->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  lv_text = ': Single'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8001->new_line.

  CLEAR lv_text.
  lv_text = 'Process'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8001->add_gap
    EXPORTING
      width = lv_width.

  CLEAR lv_text.
  IF s_rmod IS INITIAL.
    lv_text = ': All'.
  ELSE.
    SELECT *
    FROM dd07t
    INTO TABLE @DATA(li_dd07t)
    WHERE domname EQ 'ZRISK_PROC'
      AND domvalue_l IN @s_rmod
    ORDER BY domname, domvalue_l.
    LOOP AT li_dd07t INTO DATA(lw_dd07t).
      CONCATENATE lv_text lw_dd07t-ddtext INTO lv_text SEPARATED BY space.
    ENDLOOP.
    SHIFT lv_text LEFT DELETING LEADING space.
    CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  ENDIF.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8001->new_line.

  CLEAR lv_text.
  lv_text = 'Risk Level'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8001->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  IF p_rlvl0 IS NOT INITIAL.
    lv_text = 'All'.
  ELSE.
    IF p_rlvl1 IS NOT INITIAL.
      lv_text = 'Critical'.
    ENDIF.
    IF p_rlvl2 IS NOT INITIAL.
      CONCATENATE lv_text 'High' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl3 IS NOT INITIAL.
      CONCATENATE lv_text 'Medium' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl4 IS NOT INITIAL.
      CONCATENATE lv_text 'Low' INTO lv_text SEPARATED BY space.
    ENDIF.
  ENDIF.
  SHIFT lv_text LEFT DELETING LEADING space.
  CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.
  CALL METHOD o_docu_8001->new_line.

  CLEAR lv_text.
  lv_text = 'Result Summary'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8001->new_line.

  CLEAR lv_text.
  lv_text = 'No. of unique Roles found'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8001->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_summary_9001 = i_summary_9001.
  SORT li_summary_9001 BY agr_name.
  DELETE ADJACENT DUPLICATES FROM li_summary_9001 COMPARING agr_name.
  lv_count = lines( li_summary_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8001->new_line.

  CLEAR lv_text.
  lv_text = 'No. of line items found'.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8001->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_summary_9001 = i_summary_9001.
  lv_count = lines( li_summary_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8001->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8001->new_line.


  PERFORM doc_display_8001.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form handle_top_of_page_8002
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM handle_top_of_page_8002 .

  DATA:
    lv_count         TYPE i,
    lv_count_c       TYPE string,
    lv_width         TYPE i,
    lv_text          TYPE sdydo_text_element,
    li_list_comments TYPE slis_t_listheader,
    li_detail_9001   TYPE zacg_t_risk_detail,
    li_comments      TYPE slis_t_listheader.


  CLEAR lv_text.
  lv_text = 'Selection Criteria'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8002->new_line.

  CLEAR lv_text.
  lv_text = 'Role Type'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8002->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  lv_text = ': Single'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8002->new_line.

  CLEAR lv_text.
  lv_text = 'Process'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8002->add_gap
    EXPORTING
      width = lv_width.

  CLEAR lv_text.
  IF s_rmod IS INITIAL.
    lv_text = ': All'.
  ELSE.
    SELECT *
    FROM dd07t
    INTO TABLE @DATA(li_dd07t)
    WHERE domname EQ 'ZRISK_PROC'
      AND domvalue_l IN @s_rmod
    ORDER BY domname, domvalue_l.
    LOOP AT li_dd07t INTO DATA(lw_dd07t).
      CONCATENATE lv_text lw_dd07t-ddtext INTO lv_text SEPARATED BY space.
    ENDLOOP.
    SHIFT lv_text LEFT DELETING LEADING space.
    CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  ENDIF.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8002->new_line.

  CLEAR lv_text.
  lv_text = 'Risk Level'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8002->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  IF p_rlvl0 IS NOT INITIAL.
    lv_text = 'All'.
  ELSE.
    IF p_rlvl1 IS NOT INITIAL.
      lv_text = 'Critical'.
    ENDIF.
    IF p_rlvl2 IS NOT INITIAL.
      CONCATENATE lv_text 'High' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl3 IS NOT INITIAL.
      CONCATENATE lv_text 'Medium' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl4 IS NOT INITIAL.
      CONCATENATE lv_text 'Low' INTO lv_text SEPARATED BY space.
    ENDIF.
  ENDIF.
  SHIFT lv_text LEFT DELETING LEADING space.
  CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.
  CALL METHOD o_docu_8002->new_line.

  CLEAR lv_text.
  lv_text = 'Result Detail'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8002->new_line.

  CLEAR lv_text.
  lv_text = 'No. of unique Roles found'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8002->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_detail_9001 = i_detail_9001.
  SORT li_detail_9001 BY agr_name.
  DELETE ADJACENT DUPLICATES FROM li_detail_9001 COMPARING agr_name.
  lv_count = lines( li_detail_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8002->new_line.

  CLEAR lv_text.
  lv_text = 'No. of line items found'.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8002->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_detail_9001 = i_detail_9001.
  lv_count = lines( li_detail_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8002->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8002->new_line.


  PERFORM doc_display_8002.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form handle_top_of_page_8003
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM handle_top_of_page_8003 .

  DATA:
    lv_count         TYPE i,
    lv_count_c       TYPE string,
    lv_width         TYPE i,
    lv_text          TYPE sdydo_text_element,
    li_list_comments TYPE slis_t_listheader,
    li_summary_9001  TYPE zacg_t_risk_summary,
    li_comments      TYPE slis_t_listheader.


  CLEAR lv_text.
  lv_text = 'Selection Criteria'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8003->new_line.

  CLEAR lv_text.
  lv_text = 'Role Type'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8003->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  lv_text = ': Composite'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8003->new_line.

  CLEAR lv_text.
  lv_text = 'Process'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8003->add_gap
    EXPORTING
      width = lv_width.

  CLEAR lv_text.
  IF s_rmod IS INITIAL.
    lv_text = ': All'.
  ELSE.
    SELECT *
    FROM dd07t
    INTO TABLE @DATA(li_dd07t)
    WHERE domname EQ 'ZRISK_PROC'
      AND domvalue_l IN @s_rmod
    ORDER BY domname, domvalue_l.
    LOOP AT li_dd07t INTO DATA(lw_dd07t).
      CONCATENATE lv_text lw_dd07t-ddtext INTO lv_text SEPARATED BY space.
    ENDLOOP.
    SHIFT lv_text LEFT DELETING LEADING space.
    CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  ENDIF.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8003->new_line.

  CLEAR lv_text.
  lv_text = 'Risk Level'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8003->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  IF p_rlvl0 IS NOT INITIAL.
    lv_text = 'All'.
  ELSE.
    IF p_rlvl1 IS NOT INITIAL.
      lv_text = 'Critical'.
    ENDIF.
    IF p_rlvl2 IS NOT INITIAL.
      CONCATENATE lv_text 'High' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl3 IS NOT INITIAL.
      CONCATENATE lv_text 'Medium' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl4 IS NOT INITIAL.
      CONCATENATE lv_text 'Low' INTO lv_text SEPARATED BY space.
    ENDIF.
  ENDIF.
  SHIFT lv_text LEFT DELETING LEADING space.
  CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.
  CALL METHOD o_docu_8003->new_line.


  CLEAR lv_text.
  lv_text = 'Result Summary'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8003->new_line.

  CLEAR lv_text.
  lv_text = 'No. of unique Composite Roles found'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8003->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_summary_9001 = i_summary_9001.
  SORT li_summary_9001 BY composite.
  DELETE ADJACENT DUPLICATES FROM li_summary_9001 COMPARING composite.
  lv_count = lines( li_summary_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8003->new_line.

  CLEAR lv_text.
  lv_text = 'No. of line items found'.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8003->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_summary_9001 = i_summary_9001.
  lv_count = lines( li_summary_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8003->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8003->new_line.

  IF p_rsimu IS NOT INITIAL.
    CLEAR lv_text.
    lv_text = 'With Simulation'.
    CALL METHOD o_docu_8003->add_text
      EXPORTING
        text = lv_text.
  ENDIF.

  PERFORM doc_display_8003.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form handle_top_of_page_8004
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM handle_top_of_page_8004 .

  DATA:
    lv_count         TYPE i,
    lv_count_c       TYPE string,
    lv_width         TYPE i,
    lv_text          TYPE sdydo_text_element,
    li_list_comments TYPE slis_t_listheader,
    li_detail_9001   TYPE zacg_t_risk_detail,
    li_comments      TYPE slis_t_listheader.


  CLEAR lv_text.
  lv_text = 'Selection Criteria'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8004->new_line.

  CLEAR lv_text.
  lv_text = 'Role Type'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8004->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  lv_text = ': Composite'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8004->new_line.

  CLEAR lv_text.
  lv_text = 'Process'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8004->add_gap
    EXPORTING
      width = lv_width.

  CLEAR lv_text.
  IF s_rmod IS INITIAL.
    lv_text = ': All'.
  ELSE.
    SELECT *
    FROM dd07t
    INTO TABLE @DATA(li_dd07t)
    WHERE domname EQ 'ZRISK_PROC'
      AND domvalue_l IN @s_rmod
    ORDER BY domname, domvalue_l.
    LOOP AT li_dd07t INTO DATA(lw_dd07t).
      CONCATENATE lv_text lw_dd07t-ddtext INTO lv_text SEPARATED BY space.
    ENDLOOP.
    SHIFT lv_text LEFT DELETING LEADING space.
    CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  ENDIF.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8004->new_line.

  CLEAR lv_text.
  lv_text = 'Risk Level'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8004->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  IF p_rlvl0 IS NOT INITIAL.
    lv_text = 'All'.
  ELSE.
    IF p_rlvl1 IS NOT INITIAL.
      lv_text = 'Critical'.
    ENDIF.
    IF p_rlvl2 IS NOT INITIAL.
      CONCATENATE lv_text 'High' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl3 IS NOT INITIAL.
      CONCATENATE lv_text 'Medium' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_rlvl4 IS NOT INITIAL.
      CONCATENATE lv_text 'Low' INTO lv_text SEPARATED BY space.
    ENDIF.
  ENDIF.
  SHIFT lv_text LEFT DELETING LEADING space.
  CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.
  CALL METHOD o_docu_8004->new_line.


  CLEAR lv_text.
  lv_text = 'Result Detail'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8004->new_line.

  CLEAR lv_text.
  lv_text = 'No. of unique Composite Roles found'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8004->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_detail_9001 = i_detail_9001.
  SORT li_detail_9001 BY composite.
  DELETE ADJACENT DUPLICATES FROM li_detail_9001 COMPARING composite.
  lv_count = lines( li_detail_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8004->new_line.

  CLEAR lv_text.
  lv_text = 'No. of line items found'.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8004->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_detail_9001 = i_detail_9001.
  lv_count = lines( li_detail_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8004->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8004->new_line.

  IF p_rsimu IS NOT INITIAL.
    CLEAR lv_text.
    lv_text = 'With Simulation'.
    CALL METHOD o_docu_8004->add_text
      EXPORTING
        text = lv_text.
  ENDIF.

  PERFORM doc_display_8004.

ENDFORM.

FORM handle_top_of_page_8005 .

  DATA:
    lv_count         TYPE i,
    lv_count_c       TYPE string,
    lv_width         TYPE i,
    lv_text          TYPE sdydo_text_element,
    li_list_comments TYPE slis_t_listheader,
    li_summary_9001  TYPE zacg_t_risk_summary,
    li_comments      TYPE slis_t_listheader.


  CLEAR lv_text.
  lv_text = 'Selection Criteria'.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8005->new_line.

  CLEAR lv_text.
  lv_text = 'Process'.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8005->add_gap
    EXPORTING
      width = lv_width.

  CLEAR lv_text.
  IF s_umod IS INITIAL.
    lv_text = ': All'.
  ELSE.
    SELECT *
    FROM dd07t
    INTO TABLE @DATA(li_dd07t)
    WHERE domname EQ 'ZRISK_PROC'
      AND domvalue_l IN @s_umod
    ORDER BY domname, domvalue_l.
    LOOP AT li_dd07t INTO DATA(lw_dd07t).
      CONCATENATE lv_text lw_dd07t-ddtext INTO lv_text SEPARATED BY space.
    ENDLOOP.
    SHIFT lv_text LEFT DELETING LEADING space.
    CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  ENDIF.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8005->new_line.

  CLEAR lv_text.
  lv_text = 'Risk Level'.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8005->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  IF p_ulvl0 IS NOT INITIAL.
    lv_text = 'All'.
  ELSE.
    IF p_ulvl1 IS NOT INITIAL.
      lv_text = 'Critical'.
    ENDIF.
    IF p_ulvl2 IS NOT INITIAL.
      CONCATENATE lv_text 'High' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_ulvl3 IS NOT INITIAL.
      CONCATENATE lv_text 'Medium' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_ulvl4 IS NOT INITIAL.
      CONCATENATE lv_text 'Low' INTO lv_text SEPARATED BY space.
    ENDIF.
  ENDIF.
  SHIFT lv_text LEFT DELETING LEADING space.
  CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.
  CALL METHOD o_docu_8005->new_line.


  CLEAR lv_text.
  lv_text = 'Result Summary'.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8005->new_line.

  CLEAR lv_text.
  lv_text = 'No. of unique User(s)'.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8005->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_summary_9001 = i_summary_9001.
  SORT li_summary_9001 BY user.
  DELETE ADJACENT DUPLICATES FROM li_summary_9001 COMPARING user.
  lv_count = lines( li_summary_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8005->new_line.

  CLEAR lv_text.
  lv_text = 'No. of line items found'.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8005->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_summary_9001 = i_summary_9001.
  lv_count = lines( li_summary_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8005->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8005->new_line.

  IF p_usimu IS NOT INITIAL.
    CLEAR lv_text.
    lv_text = 'With Simulation'.
    CALL METHOD o_docu_8005->add_text
      EXPORTING
        text = lv_text.
  ENDIF.

  PERFORM doc_display_8005.

ENDFORM.

FORM handle_top_of_page_8006 .

  DATA:
    lv_count         TYPE i,
    lv_count_c       TYPE string,
    lv_width         TYPE i,
    lv_text          TYPE sdydo_text_element,
    li_list_comments TYPE slis_t_listheader,
    li_detail_9001   TYPE zacg_t_risk_detail,
    li_comments      TYPE slis_t_listheader.


  CLEAR lv_text.
  lv_text = 'Selection Criteria'.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8006->new_line.

  CLEAR lv_text.
  lv_text = 'Process'.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8006->add_gap
    EXPORTING
      width = lv_width.

  CLEAR lv_text.
  IF s_umod IS INITIAL.
    lv_text = ': All'.
  ELSE.
    SELECT *
    FROM dd07t
    INTO TABLE @DATA(li_dd07t)
    WHERE domname EQ 'ZRISK_PROC'
      AND domvalue_l IN @s_rmod
    ORDER BY domname, domvalue_l.
    LOOP AT li_dd07t INTO DATA(lw_dd07t).
      CONCATENATE lv_text lw_dd07t-ddtext INTO lv_text SEPARATED BY space.
    ENDLOOP.
    SHIFT lv_text LEFT DELETING LEADING space.
    CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  ENDIF.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8006->new_line.

  CLEAR lv_text.
  lv_text = 'Risk Level'.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8006->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  IF p_ulvl0 IS NOT INITIAL.
    lv_text = 'All'.
  ELSE.
    IF p_ulvl1 IS NOT INITIAL.
      lv_text = 'Critical'.
    ENDIF.
    IF p_ulvl2 IS NOT INITIAL.
      CONCATENATE lv_text 'High' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_ulvl3 IS NOT INITIAL.
      CONCATENATE lv_text 'Medium' INTO lv_text SEPARATED BY space.
    ENDIF.
    IF p_ulvl4 IS NOT INITIAL.
      CONCATENATE lv_text 'Low' INTO lv_text SEPARATED BY space.
    ENDIF.
  ENDIF.
  SHIFT lv_text LEFT DELETING LEADING space.
  CONCATENATE ':' lv_text INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.
  CALL METHOD o_docu_8006->new_line.


  CLEAR lv_text.
  lv_text = 'Result Detail'.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text      = lv_text
      sap_style = cl_dd_area=>heading.

  CALL METHOD o_docu_8006->new_line.

  CLEAR lv_text.
  lv_text = 'No. of unique User(s)'.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8006->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_detail_9001 = i_detail_9001.
  SORT li_detail_9001 BY composite.
  DELETE ADJACENT DUPLICATES FROM li_detail_9001 COMPARING composite.
  lv_count = lines( li_detail_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8006->new_line.

  CLEAR lv_text.
  lv_text = 'No. of line items found'.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.
  lv_width = 50 - strlen( lv_text ).
  CALL METHOD o_docu_8006->add_gap
    EXPORTING
      width = lv_width.
  CLEAR lv_text.
  li_detail_9001 = i_detail_9001.
  lv_count = lines( li_detail_9001 ).
  lv_count_c = lv_count.
  SHIFT lv_count_c LEFT DELETING LEADING space.
  CONCATENATE ':' lv_count_c INTO lv_text SEPARATED BY space.
  CALL METHOD o_docu_8006->add_text
    EXPORTING
      text = lv_text.

  CALL METHOD o_docu_8006->new_line.

  IF p_usimu IS NOT INITIAL.
    CLEAR lv_text.
    lv_text = 'With Simulation'.
    CALL METHOD o_docu_8006->add_text
      EXPORTING
        text = lv_text.
  ENDIF.

  PERFORM doc_display_8006.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form handle_toolbar
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> E_OBJECT
*&      --> E_INTERACTIVE
*&---------------------------------------------------------------------*
FORM handle_toolbar  USING    e_object TYPE REF TO cl_alv_event_toolbar_set
                              e_interactive.

  DATA: lw_toolbar TYPE stb_button.

  CASE g_subscr_nr.
    WHEN 8001 OR 8002 OR 8003 OR 8004 OR 8005 OR 8006 OR 9035.

      MOVE 3 TO lw_toolbar-butn_type.
      APPEND lw_toolbar TO e_object->mt_toolbar.
      CLEAR lw_toolbar.

      MOVE 'LDWD' TO lw_toolbar-function.
      MOVE icon_xls TO lw_toolbar-icon.
      MOVE 'Download to Excel' TO lw_toolbar-quickinfo.
      MOVE ' ' TO lw_toolbar-text.
      MOVE ' ' TO lw_toolbar-disabled.
      APPEND lw_toolbar TO e_object->mt_toolbar.
      CLEAR lw_toolbar.

    WHEN 9042.

      MOVE 3 TO lw_toolbar-butn_type.
      APPEND lw_toolbar TO e_object->mt_toolbar.
      CLEAR lw_toolbar.

      MOVE 'ALLR' TO lw_toolbar-function.
      MOVE icon_role TO lw_toolbar-icon.
      MOVE 'All Roles' TO lw_toolbar-quickinfo.
      MOVE 'All Roles' TO lw_toolbar-text.
      APPEND lw_toolbar TO e_object->mt_toolbar.
      CLEAR lw_toolbar.

    WHEN 9041.

      MOVE 3 TO lw_toolbar-butn_type.
      APPEND lw_toolbar TO e_object->mt_toolbar.
      CLEAR lw_toolbar.

      MOVE 'ALLR' TO lw_toolbar-function.
      MOVE icon_role TO lw_toolbar-icon.
      MOVE 'All Roles' TO lw_toolbar-quickinfo.
      MOVE 'All Roles' TO lw_toolbar-text.
      APPEND lw_toolbar TO e_object->mt_toolbar.
      CLEAR lw_toolbar.

    WHEN OTHERS.

  ENDCASE.



ENDFORM.
*&---------------------------------------------------------------------*
*& Form download_9001
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM download_8001.

  DATA : lv_filename   TYPE string,
         lv_path       TYPE string,
         lv_fullpath   TYPE string,
         lv_action     TYPE i,
         lv_count      TYPE sy-index,
         lv_exc_path   TYPE string,
         lv_fileno     TYPE i,
         lv_data_count TYPE i,
         lra_role      TYPE RANGE OF agr_name,
         lw_role       LIKE LINE OF lra_role.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      window_title      = 'Provide a location'
      default_extension = 'xls'
      file_filter       = 'xls file (*.xls)|*.xls'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
      user_action       = lv_action.
  IF lv_action = 0.
    SPLIT lv_filename AT '.' INTO DATA(lv_name) DATA(lv_ext).
    SELECT agr_name,
           COUNT( * ) AS count
    FROM @i_summary_9001 AS detail_data
    GROUP BY agr_name
    INTO TABLE @DATA(li_summary_data).
    DATA(li_summary_data_tmp) = li_summary_data.

    " Get max number of count for a single role
    SORT li_summary_data_tmp BY count DESCENDING.
    READ TABLE li_summary_data_tmp INTO DATA(lw_summary_data_tmp) INDEX 1.
    lv_data_count = lw_summary_data_tmp-count.
    IF lv_data_count < 100000.
      lv_data_count = 100000.
    ENDIF.

    IF li_summary_data IS NOT INITIAL.
      LOOP AT li_summary_data INTO DATA(lw_summary_data).

        lv_count = lv_count + lw_summary_data-count.
**** Excel will be splitted based on the max number of entries
        IF lv_count GE lv_data_count.

          lv_fileno = lv_fileno + 1.
          lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
          PERFORM download_sum_excel USING lv_exc_path i_summary_9001 lra_role.
          CLEAR : lra_role,lv_count.

          lv_count       = lw_summary_data-count.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_summary_data-agr_name.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.

        ELSE.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_summary_data-agr_name.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.
        ENDIF.
      ENDLOOP.

      IF lra_role IS NOT INITIAL.
        lv_fileno = lv_fileno + 1.
        lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
        PERFORM download_sum_excel USING lv_exc_path i_summary_9001 lra_role.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.

FORM download_8002.

  DATA : lv_filename   TYPE string,
         lv_path       TYPE string,
         lv_fullpath   TYPE string,
         lv_action     TYPE i,
         lv_count      TYPE sy-index,
         lv_exc_path   TYPE string,
         lv_fileno     TYPE i,
         lv_data_count TYPE i,
         lra_role      TYPE RANGE OF agr_name,
         lw_role       LIKE LINE OF lra_role.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      window_title      = 'Provide a location'
      default_extension = 'xls'
      file_filter       = 'xls file (*.xls)|*.xls'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
      user_action       = lv_action.
  IF lv_action = 0.
    SPLIT lv_filename AT '.' INTO DATA(lv_name) DATA(lv_ext).
    SELECT agr_name,
           COUNT( * ) AS count
    FROM @i_detail_9001 AS detail_data
    GROUP BY agr_name
    INTO TABLE @DATA(li_detail_data).
    DATA(li_detail_data_tmp) = li_detail_data.

    " Get max number of count for a single role
    SORT li_detail_data_tmp BY count DESCENDING.
    READ TABLE li_detail_data_tmp INTO DATA(lw_detail_data_tmp) INDEX 1.
    lv_data_count = lw_detail_data_tmp-count.
    IF lv_data_count < 100000.
      lv_data_count = 100000.
    ENDIF.

    IF li_detail_data IS NOT INITIAL.
      LOOP AT li_detail_data INTO DATA(lw_detail_data).

        lv_count = lv_count + lw_detail_data-count.
**** Excel will be splitted based on the max number of entries
        IF lv_count GE lv_data_count.

          lv_fileno = lv_fileno + 1.
          lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
          PERFORM download_role_detail_excel USING lv_exc_path i_detail_9001 lra_role.
          CLEAR : lra_role,lv_count.

          lv_count       = lw_detail_data-count.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_detail_data-agr_name.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.

        ELSE.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_detail_data-agr_name.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.
        ENDIF.
      ENDLOOP.

      IF lra_role IS NOT INITIAL.
        lv_fileno = lv_fileno + 1.
        lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
        PERFORM download_role_detail_excel USING lv_exc_path i_detail_9001 lra_role.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.

FORM download_8003.

  DATA : lv_filename   TYPE string,
         lv_path       TYPE string,
         lv_fullpath   TYPE string,
         lv_action     TYPE i,
         lv_count      TYPE sy-index,
         lv_exc_path   TYPE string,
         lv_fileno     TYPE i,
         lv_data_count TYPE i,
         lra_role      TYPE RANGE OF agr_name,
         lw_role       LIKE LINE OF lra_role.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      window_title      = 'Provide a location'
      default_extension = 'xls'
      file_filter       = 'xls file (*.xls)|*.xls'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
      user_action       = lv_action.
  IF lv_action = 0.
    SPLIT lv_filename AT '.' INTO DATA(lv_name) DATA(lv_ext).
    SELECT composite,
           COUNT( * ) AS count
    FROM @i_summary_9001 AS detail_data
    GROUP BY composite
    INTO TABLE @DATA(li_summary_data).
    DATA(li_summary_data_tmp) = li_summary_data.

    " Get max number of count for a single role
    SORT li_summary_data_tmp BY count DESCENDING.
    READ TABLE li_summary_data_tmp INTO DATA(lw_summary_data_tmp) INDEX 1.
    lv_data_count = lw_summary_data_tmp-count.
    IF lv_data_count < 100000.
      lv_data_count = 100000.
    ENDIF.

    IF li_summary_data IS NOT INITIAL.
      LOOP AT li_summary_data INTO DATA(lw_summary_data).

        lv_count = lv_count + lw_summary_data-count.
**** Excel will be splitted based on the max number of entries
        IF lv_count GE lv_data_count.

          lv_fileno = lv_fileno + 1.
          lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
          PERFORM download_comp_sum_excel USING lv_exc_path i_summary_9001 lra_role.
          CLEAR : lra_role,lv_count.

          lv_count       = lw_summary_data-count.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_summary_data-composite.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.

        ELSE.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_summary_data-composite.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.
        ENDIF.
      ENDLOOP.

      IF lra_role IS NOT INITIAL.
        lv_fileno = lv_fileno + 1.
        lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
        PERFORM download_comp_sum_excel USING lv_exc_path i_summary_9001 lra_role.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.

FORM download_8004.

  DATA : lv_filename   TYPE string,
         lv_path       TYPE string,
         lv_fullpath   TYPE string,
         lv_action     TYPE i,
         lv_count      TYPE sy-index,
         lv_exc_path   TYPE string,
         lv_fileno     TYPE i,
         lv_data_count TYPE i,
         lra_role      TYPE RANGE OF agr_name,
         lw_role       LIKE LINE OF lra_role.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      window_title      = 'Provide a location'
      default_extension = 'xls'
      file_filter       = 'xls file (*.xls)|*.xls'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
      user_action       = lv_action.
  IF lv_action = 0.
    SPLIT lv_filename AT '.' INTO DATA(lv_name) DATA(lv_ext).
    SELECT composite,
           COUNT( * ) AS count
    FROM @i_detail_9001 AS detail_data
    GROUP BY composite
    INTO TABLE @DATA(li_detail_data).
    DATA(li_detail_data_tmp) = li_detail_data.

    " Get max number of count for a single role
    SORT li_detail_data_tmp BY count DESCENDING.
    READ TABLE li_detail_data_tmp INTO DATA(lw_detail_data_tmp) INDEX 1.
    lv_data_count = lw_detail_data_tmp-count.
    IF lv_data_count < 100000.
      lv_data_count = 100000.
    ENDIF.

    IF li_detail_data IS NOT INITIAL.
      LOOP AT li_detail_data INTO DATA(lw_detail_data).

        lv_count = lv_count + lw_detail_data-count.
**** Excel will be splitted based on the max number of entries
        IF lv_count GE lv_data_count.

          lv_fileno = lv_fileno + 1.
          lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
          PERFORM download_comp_detail_excel USING lv_exc_path i_detail_9001 lra_role.
          CLEAR : lra_role,lv_count.

          lv_count       = lw_detail_data-count.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_detail_data-composite.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.

        ELSE.
*** Populate Role Range Table
          lw_role-sign    = 'I'.
          lw_role-option  = 'EQ'.
          lw_role-low     = lw_detail_data-composite.
          APPEND lw_role TO lra_role.
          CLEAR lw_role.
        ENDIF.
      ENDLOOP.

      IF lra_role IS NOT INITIAL.
        lv_fileno = lv_fileno + 1.
        lv_exc_path = |{ lv_path }{ lv_name } ({ lv_fileno }).{ lv_ext }|.
*** Download Excel
        PERFORM download_comp_detail_excel USING lv_exc_path i_detail_9001 lra_role.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form download_sum_excel
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_FILENAME
*&      --> LV_PATH
*&      --> LIT_DATA
*&      --> LRA_ROLE
*&---------------------------------------------------------------------*
FORM download_sum_excel  USING    VALUE(i_path)
                                  VALUE(i_data) TYPE zacg_t_risk_summary
                                  VALUE(i_role) TYPE zacg_range_tt.

  DATA : lv_length TYPE i,
         lv_xml    TYPE xstring,
         lt_solix  TYPE STANDARD TABLE OF solix.

  DELETE i_data WHERE agr_name NOT IN i_role.

  TRY.
      CALL TRANSFORMATION zacg_summary
      SOURCE lit_excel = i_data
      RESULT XML lv_xml.
    CATCH cx_root INTO DATA(ls_error).
      DATA(lv_error) = ls_error->get_text( ).
      MESSAGE lv_error TYPE 'E'.
  ENDTRY.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = lv_xml
    IMPORTING
      output_length = lv_length
    TABLES
      binary_tab    = lt_solix.

  CALL METHOD cl_gui_frontend_services=>gui_download
    EXPORTING
      bin_filesize            = lv_length
      filetype                = 'BIN'
      filename                = i_path
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

ENDFORM.
*&---------------------------------------------------------------------*
*& Form download_role_detail_excel
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_EXC_PATH
*&      --> I_DETAIL_9001
*&      --> LRA_ROLE
*&---------------------------------------------------------------------*
FORM download_role_detail_excel  USING    VALUE(i_path)
                                          VALUE(i_data) TYPE zacg_t_risk_detail
                                          VALUE(i_role) TYPE zacg_range_tt.

  DATA : lv_length TYPE i,
         lv_xml    TYPE xstring,
         lt_solix  TYPE STANDARD TABLE OF solix.

  DELETE i_data WHERE agr_name NOT IN i_role.

  TRY.
      CALL TRANSFORMATION zacg_role_detail
      SOURCE lit_excel = i_data
      RESULT XML lv_xml.
    CATCH cx_root INTO DATA(ls_error).
      DATA(lv_error) = ls_error->get_text( ).
      MESSAGE lv_error TYPE 'E'.
  ENDTRY.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = lv_xml
    IMPORTING
      output_length = lv_length
    TABLES
      binary_tab    = lt_solix.

  CALL METHOD cl_gui_frontend_services=>gui_download
    EXPORTING
      bin_filesize            = lv_length
      filetype                = 'BIN'
      filename                = i_path
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

ENDFORM.

FORM download_comp_sum_excel  USING VALUE(i_path)
                                    VALUE(i_data) TYPE zacg_t_risk_summary
                                    VALUE(i_role) TYPE zacg_range_tt.

  DATA : lv_length TYPE i,
         lv_xml    TYPE xstring,
         lt_solix  TYPE STANDARD TABLE OF solix.

  DELETE i_data WHERE composite NOT IN i_role.

  TRY.
      CALL TRANSFORMATION zacg_comp_summary
      SOURCE lit_excel = i_data
      RESULT XML lv_xml.
    CATCH cx_root INTO DATA(ls_error).
      DATA(lv_error) = ls_error->get_text( ).
      MESSAGE lv_error TYPE 'E'.
  ENDTRY.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = lv_xml
    IMPORTING
      output_length = lv_length
    TABLES
      binary_tab    = lt_solix.

  CALL METHOD cl_gui_frontend_services=>gui_download
    EXPORTING
      bin_filesize            = lv_length
      filetype                = 'BIN'
      filename                = i_path
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

ENDFORM.

FORM download_comp_detail_excel  USING    VALUE(i_path)
                                          VALUE(i_data) TYPE zacg_t_risk_detail
                                          VALUE(i_role) TYPE zacg_range_tt.

  DATA : lv_length TYPE i,
         lv_xml    TYPE xstring,
         lt_solix  TYPE STANDARD TABLE OF solix.

  DELETE i_data WHERE composite NOT IN i_role.

  TRY.
      CALL TRANSFORMATION zacg_comp_detail
      SOURCE lit_excel = i_data
      RESULT XML lv_xml.
    CATCH cx_root INTO DATA(ls_error).
      DATA(lv_error) = ls_error->get_text( ).
      MESSAGE lv_error TYPE 'E'.
  ENDTRY.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = lv_xml
    IMPORTING
      output_length = lv_length
    TABLES
      binary_tab    = lt_solix.

  CALL METHOD cl_gui_frontend_services=>gui_download
    EXPORTING
      bin_filesize            = lv_length
      filetype                = 'BIN'
      filename                = i_path
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

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_init_password
*&---------------------------------------------------------------------*
*& Set a productive password for the users in SO_UPW1 (manual variant).
*&
*& NOTE: the body is currently fully commented out, so this form is a
*& no-op. The intended logic (kept as comments) generated a temporary
*& password with BAPI_USER_CHANGE and then set the target productive
*& password P_PWD1 via SUSR_USER_CHANGE_PASSWORD_RFC, committing on
*& success and rolling back on error.
*&---------------------------------------------------------------------*
FORM set_prod_password_manual.



*  DATA:
*    lv_user      TYPE xubname,
*
*    lwa_bapipwd  TYPE bapipwd,
*    lwa_bapipwdx TYPE bapipwdx,
*    lwa_return   TYPE bapiret2,
*
*    lit_return   TYPE bapiret2_t.
*
*
*  CLEAR: i_outtab_9009.
*
*  LOOP AT so_upw1.
*
*    CLEAR: lv_user, lwa_bapipwd, lwa_return, lit_return.
*
*    lv_user               = so_upw1-low.
*    lwa_bapipwdx-bapipwd  = abap_true.
*
*    CALL FUNCTION 'BAPI_USER_CHANGE'
*      EXPORTING
*        username           = lv_user
*        passwordx          = lwa_bapipwdx
*        generate_pwd       = abap_true
*      IMPORTING
*        generated_password = lwa_bapipwd
*      TABLES
*        return             = lit_return.
*
*    LOOP AT lit_return INTO lwa_return.
*      IF lwa_return-type = 'E' OR lwa_return-type = 'A'.
*        ROLLBACK WORK.
*        EXIT.
*      ENDIF.
*    ENDLOOP.
*
*    IF lwa_return-type = 'E' OR lwa_return-type = 'A'.
*
*      APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING FIELD-SYMBOL(<lfs_outtab>).
*      <lfs_outtab>-type = '@02@'.
*      <lfs_outtab>-user = lv_user.
*      MESSAGE ID lwa_return-id TYPE lwa_return-type NUMBER lwa_return-number
*        INTO <lfs_outtab>-msg
*        WITH lwa_return-message_v1 lwa_return-message_v2
*             lwa_return-message_v3 lwa_return-message_v4.
*
*    ELSE.
*      CALL FUNCTION 'SUSR_USER_CHANGE_PASSWORD_RFC'
*        EXPORTING
*          bname                     = lv_user
*          password                  = lwa_bapipwd-bapipwd
*          new_password              = p_pwd1
*        IMPORTING
*          return                    = lwa_return
*        EXCEPTIONS
*          change_not_allowed        = 1
*          password_not_allowed      = 2
*          internal_error            = 3
*          canceled_by_user          = 4
*          password_attempts_limited = 5
*          OTHERS                    = 6.
*      IF sy-subrc = 0.
*        COMMIT WORK.
*        APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING <lfs_outtab>.
*        <lfs_outtab>-type = '@01@'.
*        <lfs_outtab>-user = lv_user.
*        <lfs_outtab>-msg = 'Passwrod successfully changed'.
*      ELSE.
*
*        ROLLBACK WORK.
*        APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING <lfs_outtab>.
*        <lfs_outtab>-type = '@02@'.
*        <lfs_outtab>-user = lv_user.
*        lwa_return-number = sy-msgno.
*        lwa_return-id     = sy-msgid.
*        lwa_return-type   = sy-msgty.
*        lwa_return-message_v1 = sy-msgv1.
*        lwa_return-message_v2 = sy-msgv2.
*        lwa_return-message_v3 = sy-msgv3.
*        lwa_return-message_v4 = sy-msgv4.
*
*        MESSAGE ID lwa_return-id TYPE lwa_return-type NUMBER lwa_return-number
*          INTO <lfs_outtab>-msg
*          WITH lwa_return-message_v1 lwa_return-message_v2
*               lwa_return-message_v3 lwa_return-message_v4.
*
*      ENDIF.
*
*    ENDIF.
*
*  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_initpw_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Set-Productive-Password
*& upload: requires an .XLS file whose header row reads
*& 'User ID' / 'Password'. Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_initpw_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_initpw IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_initpw ) - 4.
    TRANSLATE p_initpw+lv_len(4) TO UPPER CASE.
    IF p_initpw+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_initpw
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'User ID'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Password'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_filepath
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- P_FILE3
*&---------------------------------------------------------------------*
FORM get_filepath  CHANGING c_file.

  DATA: lt_file_table TYPE filetable,
        lv_rc         TYPE i.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title      = 'Select a file'
      default_extension = 'xls'
      file_filter       = cl_gui_frontend_services=>filetype_excel " 'xls file (*.xls)|*.xls'
    CHANGING
      file_table        = lt_file_table
      rc                = lv_rc.
  IF sy-subrc IS INITIAL.
    READ TABLE lt_file_table INTO DATA(lwa_file_table) INDEX 1.
    IF sy-subrc IS INITIAL.
      c_file = lwa_file_table-filename.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_filepath
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- P_FILE42
*&---------------------------------------------------------------------*
FORM get_filepath_xlsx_txt_41  CHANGING c_file.

  DATA: lt_file_table TYPE filetable,
        lv_rc         TYPE i.
  IF rb_xls41 IS NOT INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_open_dialog
      EXPORTING
        window_title      = 'Select a file'
        default_extension = 'xlsx'
        file_filter       = 'Excel Files (*.xls;*.xlsx)|*.xls;*.xlsx|All files (*.*)|*.*'
      CHANGING
        file_table        = lt_file_table
        rc                = lv_rc.
    IF sy-subrc IS INITIAL.
      READ TABLE lt_file_table INTO DATA(lwa_file_table) INDEX 1.
      IF sy-subrc IS INITIAL.
        c_file = lwa_file_table-filename.
      ENDIF.
    ENDIF.
  ELSEIF rb_txt41 IS NOT INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_open_dialog
      EXPORTING
        window_title      = 'Select a file'
        default_extension = 'txt'
        file_filter       = 'Excel Files (*.txt)'
      CHANGING
        file_table        = lt_file_table
        rc                = lv_rc.
    IF sy-subrc IS INITIAL.
      READ TABLE lt_file_table INTO lwa_file_table INDEX 1.
      IF sy-subrc IS INITIAL.
        c_file = lwa_file_table-filename.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_filepath
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- P_FILE42
*&---------------------------------------------------------------------*
FORM get_filepath_xlsx_txt_42  CHANGING c_file.

  DATA: lt_file_table TYPE filetable,
        lv_rc         TYPE i.
  IF rb_xls42 IS NOT INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_open_dialog
      EXPORTING
        window_title      = 'Select a file'
        default_extension = 'xlsx'
        file_filter       = 'Excel Files (*.xls;*.xlsx)|*.xls;*.xlsx|All files (*.*)|*.*'
      CHANGING
        file_table        = lt_file_table
        rc                = lv_rc.
    IF sy-subrc IS INITIAL.
      READ TABLE lt_file_table INTO DATA(lwa_file_table) INDEX 1.
      IF sy-subrc IS INITIAL.
        c_file = lwa_file_table-filename.
      ENDIF.
    ENDIF.
  ELSEIF rb_txt42 IS NOT INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_open_dialog
      EXPORTING
        window_title      = 'Select a file'
        default_extension = 'txt'
        file_filter       = 'Excel Files (*.txt)'
      CHANGING
        file_table        = lt_file_table
        rc                = lv_rc.
    IF sy-subrc IS INITIAL.
      READ TABLE lt_file_table INTO lwa_file_table INDEX 1.
      IF sy-subrc IS INITIAL.
        c_file = lwa_file_table-filename.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_cdrole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Change-Role-Description upload
*& (P_FILE4): requires an .XLS file whose header row reads
*& 'Role Name' / 'Role Description'. Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_cdrole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file4 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file4 ) - 4.
    TRANSLATE p_file4+lv_len(4) TO UPPER CASE.
    IF p_file4+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file4
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Role Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Role Description'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form change_description_of_roles
*&---------------------------------------------------------------------*
*& Mass-changes role (PFCG) descriptions from the uploaded Excel file
*& (P_FILE4, columns Role / Description).
*&
*& Each row is applied with PRGN_RFC_CHANGE_TEXTS for the logon language;
*& per-role status (type / message) is collected in GT_ROLE_DES and shown
*& in the screen-9011 ALV grid.
*& Side effect: updates role texts in the database.
*&---------------------------------------------------------------------*
FORM change_description_of_roles .

  TYPES : BEGIN OF lty_role_des,
            role TYPE agr_name,
            desc TYPE agr_title,
          END OF lty_role_des.

  DATA : lt_init_excel TYPE TABLE OF lty_role_des,
         ls_role_des   TYPE ty_role_des,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_texts     TYPE TABLE OF agr_texts,
         lit_return    TYPE TABLE OF bapiret2,
         lv_arg_name   TYPE agr_name.

  IF p_file4 IS NOT INITIAL.

    IF o_conttainer_9011 IS BOUND.
      CALL METHOD o_conttainer_9011->free.
      CLEAR o_conttainer_9011.
    ENDIF.

    IF o_grid_9011 IS BOUND.
      CLEAR o_grid_9011.
    ENDIF.

    CLEAR gt_role_des.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file4
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_role_des-role = lwa_init_excel-role.
          ls_role_des-desc = lwa_init_excel-desc.

          lit_texts = VALUE #( ( agr_name = lwa_init_excel-role
                                 spras = sy-langu
                                 text = lwa_init_excel-desc ) ).

          CALL FUNCTION 'PRGN_RFC_CHANGE_TEXTS'
            EXPORTING
              activity_group                = lwa_init_excel-role
            TABLES
              texts                         = lit_texts
              return                        = lit_return
            EXCEPTIONS
              activity_group_enqueued       = 1
              activity_group_does_not_exist = 2
              namespace_problem             = 3
              not_authorized                = 4
              wrong_language                = 5
              OTHERS                        = 6.
          IF lit_return IS NOT INITIAL.
            ls_role_des-type    = lit_return[ 1 ]-type.
            ls_role_des-message = lit_return[ 1 ]-message.
          ELSE.
            ls_role_des-type    = 'S'.
            ls_role_des-message = 'Role Description Changed.'.
          ENDIF.

          APPEND ls_role_des TO gt_role_des.
          CLEAR : ls_role_des.
        ENDLOOP.
      ENDIF.

      IF o_conttainer_9011 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9011
          EXPORTING
            container_name = 'CC_9011'.
      ENDIF.

      IF o_conttainer_9011 IS BOUND AND o_grid_9011 IS NOT BOUND.
        CREATE OBJECT o_grid_9011
          EXPORTING
            i_parent = o_conttainer_9011.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'ROLE'.
      ls_catalog-reptext = 'Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'DESC'.
      ls_catalog-reptext = 'DESC'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 4.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9011 IS BOUND.
        CALL METHOD o_grid_9011->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_role_des.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form download_template
*&---------------------------------------------------------------------*
*& Generic Excel-template downloader used by the role-maintenance
*& functions. Runs the given XSLT transformation to produce the empty
*& template, converts it to binary and saves it to a folder chosen by
*& the user.
*&   -->  I_FILENAME    File name to save (e.g. '\Role_Desc.xls').
*&   -->  I_TRANS_NAME  Name of the XSLT transformation to call.
*&---------------------------------------------------------------------*
FORM download_template USING i_filename    TYPE string
                             i_trans_name  TYPE cxsltdesc.

  DATA : lv_length TYPE i,
         lv_xml    TYPE xstring,
         lt_solix  TYPE STANDARD TABLE OF solix,
         lv_path   TYPE string,
         lv_file   TYPE string.

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
    lv_file = lv_path && i_filename.
*** Get Excel Template in XML

    TRY.
        CALL TRANSFORMATION (i_trans_name)
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
*&---------------------------------------------------------------------*
*& Form p_usupd_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Update-User-Details upload
*& (P_FILE3): requires an .XLS file whose header row reads 'User ID',
*& 'First Name', 'Last Name', 'Function', 'Department', 'Email ID'.
*& Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_usupd_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file3 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file3 ) - 4.
    TRANSLATE p_file3+lv_len(4) TO UPPER CASE.
    IF p_file3+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file3
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 6
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'User ID'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'First Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 3.
              IF lw_excel-value NE 'Last Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 4.
              IF lw_excel-value NE 'Function'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 5.
              IF lw_excel-value NE 'Department'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 6.
              IF lw_excel-value NE 'Email ID'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_drrole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Derive-Role upload (P_FILE5):
*& requires an .XLS file whose header row reads
*& 'Parent Role' / 'Child Role'. Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_drrole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file5 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file5 ) - 4.
    TRANSLATE p_file5+lv_len(4) TO UPPER CASE.
    IF p_file5+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file5
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Parent Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Child Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form derive_role_create
*&---------------------------------------------------------------------*
*& Mass-creates derived (child) roles from the uploaded Excel file
*& (P_FILE5, columns Parent Role / Child Role).
*&
*& Each row calls PRGN_RFC_CREATE_ACTIVITY_GROUP to derive the child
*& role from its parent. Per-row status is collected in GT_DR_ROLE and
*& shown in the screen-9012 ALV grid.
*& Side effect: creates roles in the database.
*&---------------------------------------------------------------------*
FORM derive_role_create .

  TYPES : BEGIN OF lty_dr_role,
            prole TYPE par_agr,
            crole TYPE agr_name,
          END OF lty_dr_role.

  DATA : lt_init_excel TYPE TABLE OF lty_dr_role,
         ls_dr_role    TYPE ty_dr_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_return    TYPE TABLE OF bapiret2.

  IF p_file5 IS NOT INITIAL.

    IF o_conttainer_9012 IS BOUND.
      CALL METHOD o_conttainer_9012->free.
      CLEAR o_conttainer_9012.
    ENDIF.

    IF o_grid_9012 IS BOUND.
      CLEAR o_grid_9012.
    ENDIF.

    CLEAR : gt_dr_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file5
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_dr_role-prole = lwa_init_excel-prole.
          ls_dr_role-crole = lwa_init_excel-crole.

          CALL FUNCTION 'PRGN_RFC_CREATE_ACTIVITY_GROUP'
            EXPORTING
              activity_group                = lwa_init_excel-crole
              parent_role                   = lwa_init_excel-prole
*             ACTIVITY_GROUP_TEXT           =
            TABLES
              return                        = lit_return
            EXCEPTIONS
              activity_group_already_exists = 1
              activity_group_enqueued       = 2
              namespace_problem             = 3
              illegal_characters            = 4
              error_when_creating_actgroup  = 5
              profile_name_exists           = 6
              profile_not_in_namespace      = 7
              no_auth_data_selected         = 8
              illegal_tcodes                = 9
              not_authorized                = 10
              profgen_tables_not_updated    = 11
              error_when_generating_profile = 12
              OTHERS                        = 13.
          IF lit_return IS NOT INITIAL.
            ls_dr_role-type    = lit_return[ 1 ]-type.
            ls_dr_role-message = lit_return[ 1 ]-message.
          ELSE.
            ls_dr_role-type    = 'S'.
            ls_dr_role-message = 'Child Role Derived from Parent'.
          ENDIF.

          APPEND ls_dr_role TO gt_dr_role.
          CLEAR : ls_dr_role.
        ENDLOOP.
      ENDIF.

      IF o_conttainer_9012 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9012
          EXPORTING
            container_name = 'CC_9012'.
      ENDIF.

      IF o_conttainer_9012 IS BOUND AND o_grid_9012 IS NOT BOUND.
        CREATE OBJECT o_grid_9012
          EXPORTING
            i_parent = o_conttainer_9012.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'PROLE'.
      ls_catalog-reptext = 'Parent Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'CROLE'.
      ls_catalog-reptext = 'Child Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 4.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9012 IS BOUND.
        CALL METHOD o_grid_9012->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_dr_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_dirole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Delete-Inheritance upload
*& (P_FILE6): requires an .XLS file whose header row reads
*& 'Parent Role' / 'Child Role'. Clears sy-ucomm / g_ucomm and raises an
*& error otherwise so the action is not executed.
*&---------------------------------------------------------------------*
FORM p_dirole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file6 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file6 ) - 4.
    TRANSLATE p_file6+lv_len(4) TO UPPER CASE.
    IF p_file6+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file6
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Parent Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Child Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form delete_inheritance
*&---------------------------------------------------------------------*
*& Removes the parent/child inheritance from derived roles listed in the
*& uploaded Excel file (P_FILE6, columns Parent Role / Child Role).
*&
*& Each child role is detached with PRGN_RFC_DELETE_DERIVATION. Per-row
*& status is collected in GT_DR_ROLE and shown in the screen-9013 ALV.
*& Side effect: changes role derivation in the database.
*&---------------------------------------------------------------------*
FORM delete_inheritance .

  TYPES : BEGIN OF lty_dr_role,
            prole TYPE par_agr,
            crole TYPE agr_name,
          END OF lty_dr_role.

  DATA : lt_init_excel TYPE TABLE OF lty_dr_role,
         ls_dr_role    TYPE ty_dr_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_return    TYPE TABLE OF bapiret2.


  IF p_file6 IS NOT INITIAL.

    IF o_conttainer_9013 IS BOUND.
      CALL METHOD o_conttainer_9013->free.
      CLEAR o_conttainer_9013.
    ENDIF.

    IF o_grid_9013 IS BOUND.
      CLEAR o_grid_9013.
    ENDIF.

    CLEAR : gt_dr_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file6
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_dr_role-prole = lwa_init_excel-prole.
          ls_dr_role-crole = lwa_init_excel-crole.

          CALL FUNCTION 'PRGN_RFC_DELETE_DERIVATION'
            EXPORTING
              role   = lwa_init_excel-crole
            TABLES
              return = lit_return.
          IF lit_return IS NOT INITIAL.
            ls_dr_role-type    = lit_return[ 1 ]-type.
            ls_dr_role-message = lit_return[ 1 ]-message.
          ELSE.
            ls_dr_role-type    = 'S'.
            ls_dr_role-message = 'Child Role Inheritance Deleted'.
          ENDIF.

          APPEND ls_dr_role TO gt_dr_role.
          CLEAR : ls_dr_role.
        ENDLOOP.
      ENDIF.
      IF o_conttainer_9013 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9013
          EXPORTING
            container_name = 'CC_9013'.
      ENDIF.

      IF o_conttainer_9013 IS BOUND AND o_grid_9013 IS NOT BOUND.
        CREATE OBJECT o_grid_9013
          EXPORTING
            i_parent = o_conttainer_9013.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'PROLE'.
      ls_catalog-reptext = 'Parent Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'CROLE'.
      ls_catalog-reptext = 'Child Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 4.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9013 IS BOUND.
        CALL METHOD o_grid_9013->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_dr_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_asrole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Add-Single-to-Composite upload
*& (P_FILE7): requires an .XLS file whose header row reads
*& 'Composite Role' / 'Single Role'. Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_asrole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file7 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file7 ) - 4.
    TRANSLATE p_file7+lv_len(4) TO UPPER CASE.
    IF p_file7+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file7
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Composite Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Single Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form add_single_role_to_composite
*&---------------------------------------------------------------------*
*& Adds single roles to composite roles from the uploaded Excel file
*& (P_FILE7, columns Composite Role / Single Role).
*&
*& Each row calls PRGN_RFC_ADD_AGRS_TO_COLL_AGR. Per-row status is
*& collected in GT_COMP_ROLE and shown in the screen-9014 ALV grid.
*& Side effect: changes composite-role membership in the database.
*&---------------------------------------------------------------------*
FORM add_single_role_to_composite .

  TYPES : BEGIN OF lty_comp_role,
            comp_role TYPE agr_name,
            srole     TYPE agr_name,
          END OF lty_comp_role.

  DATA : lt_init_excel TYPE TABLE OF lty_comp_role,
         ls_comp_role  TYPE ty_comp_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_return    TYPE TABLE OF bapiret2,
         lit_activity  TYPE TABLE OF agr_txt,
         lwa_activity  TYPE agr_txt.

  IF p_file7 IS NOT INITIAL.

    IF o_conttainer_9014 IS BOUND.
      CALL METHOD o_conttainer_9014->free.
      CLEAR o_conttainer_9014.
    ENDIF.

    IF o_grid_9014 IS BOUND.
      CLEAR o_grid_9014.
    ENDIF.

    CLEAR : gt_comp_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file7
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        SORT lt_init_excel BY comp_role.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_comp_role-srole     = lwa_init_excel-srole.
          ls_comp_role-comp_role = lwa_init_excel-comp_role.

          DATA(ltp_index) = sy-tabix + 1.
          READ TABLE lt_init_excel INTO DATA(lwa_init_excel1) INDEX ltp_index.
          IF sy-subrc IS NOT INITIAL.
            CLEAR : lwa_init_excel1.
          ENDIF.

          lwa_activity-agr_name = lwa_init_excel-srole.

          APPEND lwa_activity TO lit_activity.
          CLEAR : lwa_activity.

          IF lwa_init_excel-comp_role <> lwa_init_excel1-comp_role.

            CALL FUNCTION 'PRGN_RFC_ADD_AGRS_TO_COLL_AGR'
              EXPORTING
                activity_group                = lwa_init_excel-comp_role
              TABLES
                activity_groups               = lit_activity
                return                        = lit_return
              EXCEPTIONS
                activity_group_does_not_exist = 1
                no_collective_activity_group  = 2
                activity_group_enqueued       = 3
                namespace_problem             = 4
                not_authorized                = 5
                authority_incomplete          = 6
                OTHERS                        = 7.
            IF lit_return IS NOT INITIAL.
              ls_comp_role-type    = lit_return[ 1 ]-type.
              ls_comp_role-message = lit_return[ 1 ]-message.
            ELSE.
              ls_comp_role-type    = 'S'.
              ls_comp_role-message = 'Single role added to Composite Role'.
            ENDIF.

            CLEAR : lit_activity.
          ENDIF.
          APPEND ls_comp_role TO gt_comp_role.
          CLEAR : ls_comp_role.
        ENDLOOP.
      ENDIF.

      DATA(lit_comp_role) = gt_comp_role.
      DELETE lit_comp_role WHERE type IS INITIAL.
      SORT lit_comp_role BY comp_role.
      LOOP AT gt_comp_role ASSIGNING FIELD-SYMBOL(<lfs_comp_role>).
        READ TABLE lit_comp_role INTO DATA(lwa_comp_role) WITH KEY
        comp_role = <lfs_comp_role>-comp_role BINARY SEARCH.
        IF sy-subrc IS INITIAL.
          <lfs_comp_role>-type = lwa_comp_role-type.
          <lfs_comp_role>-message = lwa_comp_role-message.
        ENDIF.
      ENDLOOP.

      IF o_conttainer_9014 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9014
          EXPORTING
            container_name = 'CC_9014'.
      ENDIF.

      IF o_conttainer_9014 IS BOUND AND o_grid_9014 IS NOT BOUND.
        CREATE OBJECT o_grid_9014
          EXPORTING
            i_parent = o_conttainer_9014.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'COMP_ROLE'.
      ls_catalog-reptext = 'Composite Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'SROLE'.
      ls_catalog-reptext = 'Single Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 4.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9014 IS BOUND.
        CALL METHOD o_grid_9014->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_comp_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_rsrole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Remove-Single-from-Composite
*& upload (P_FILE8): requires an .XLS file whose header row reads
*& 'Composite Role' / 'Single Role'. Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_rsrole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file8 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file8 ) - 4.
    TRANSLATE p_file8+lv_len(4) TO UPPER CASE.
    IF p_file8+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file8
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Composite Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Single Role'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form remove_single_from_composite
*&---------------------------------------------------------------------*
*& Removes single roles from composite roles using the uploaded Excel
*& file (P_FILE8, columns Composite Role / Single Role).
*&
*& Each row calls PRGN_RFC_DEL_AGRS_IN_COLL_AGR. Per-row status is
*& collected in GT_COMP_ROLE and shown in the screen-9015 ALV grid.
*& Side effect: changes composite-role membership in the database.
*&---------------------------------------------------------------------*
FORM remove_single_from_composite .

  TYPES : BEGIN OF lty_comp_role,
            comp_role TYPE agr_name,
            srole     TYPE agr_name,
          END OF lty_comp_role.

  DATA : lt_init_excel TYPE TABLE OF lty_comp_role,
         ls_comp_role  TYPE ty_comp_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_return    TYPE TABLE OF bapiret2,
         lit_activity  TYPE TABLE OF agr_txt,
         lwa_activity  TYPE agr_txt.

  IF p_file8 IS NOT INITIAL.

    IF o_conttainer_9015 IS BOUND.
      CALL METHOD o_conttainer_9015->free.
      CLEAR o_conttainer_9015.
    ENDIF.

    IF o_grid_9015 IS BOUND.
      CLEAR o_grid_9015.
    ENDIF.

    CLEAR : gt_comp_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file8
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        SORT lt_init_excel BY comp_role.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_comp_role-srole     = lwa_init_excel-srole.
          ls_comp_role-comp_role = lwa_init_excel-comp_role.

          DATA(ltp_index) = sy-tabix + 1.
          READ TABLE lt_init_excel INTO DATA(lwa_init_excel1) INDEX ltp_index.
          IF sy-subrc IS NOT INITIAL.
            CLEAR : lwa_init_excel1.
          ENDIF.

          lwa_activity-agr_name = lwa_init_excel-srole.

          APPEND lwa_activity TO lit_activity.
          CLEAR : lwa_activity.

          IF lwa_init_excel-comp_role <> lwa_init_excel1-comp_role.

            CALL FUNCTION 'PRGN_RFC_DEL_AGRS_IN_COLL_AGR'
              EXPORTING
                activity_group                = lwa_init_excel-comp_role
              TABLES
                activity_groups               = lit_activity
                return                        = lit_return
              EXCEPTIONS
                activity_group_does_not_exist = 1
                no_collective_activity_group  = 2
                activity_group_enqueued       = 3
                namespace_problem             = 4
                not_authorized                = 5
                authority_incomplete          = 6
                OTHERS                        = 7.
            IF lit_return IS NOT INITIAL.
              ls_comp_role-type    = lit_return[ 1 ]-type.
              ls_comp_role-message = lit_return[ 1 ]-message.
            ELSE.
              ls_comp_role-type    = 'S'.
              ls_comp_role-message = 'Single role removed from Composite Role'.
            ENDIF.
*
            CLEAR : lit_activity.
          ENDIF.
          APPEND ls_comp_role TO gt_comp_role.
          CLEAR : ls_comp_role.
        ENDLOOP.
      ENDIF.

      DATA(lit_comp_role) = gt_comp_role.
      DELETE lit_comp_role WHERE type IS INITIAL.
      SORT lit_comp_role BY comp_role.
      LOOP AT gt_comp_role ASSIGNING FIELD-SYMBOL(<lfs_comp_role>).
        READ TABLE lit_comp_role INTO DATA(lwa_comp_role) WITH KEY
        comp_role = <lfs_comp_role>-comp_role BINARY SEARCH.
        IF sy-subrc IS INITIAL.
          <lfs_comp_role>-type = lwa_comp_role-type.
          <lfs_comp_role>-message = lwa_comp_role-message.
        ENDIF.
      ENDLOOP.

      IF o_conttainer_9015 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9015
          EXPORTING
            container_name = 'CC_9015'.
      ENDIF.

      IF o_conttainer_9015 IS BOUND AND o_grid_9015 IS NOT BOUND.
        CREATE OBJECT o_grid_9015
          EXPORTING
            i_parent = o_conttainer_9015.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'COMP_ROLE'.
      ls_catalog-reptext = 'Composite Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'SROLE'.
      ls_catalog-reptext = 'Single Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 4.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9015 IS BOUND.
        CALL METHOD o_grid_9015->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_comp_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_rmrole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Delete-Roles upload (P_FILE9):
*& requires an .XLS file whose header row reads 'Role Name'.
*& Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_rmrole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file9 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file9 ) - 4.
    TRANSLATE p_file9+lv_len(4) TO UPPER CASE.
    IF p_file9+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file9
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 1
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Role Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form delete_roles
*&---------------------------------------------------------------------*
*& Mass-deletes roles listed in the uploaded Excel file (P_FILE9,
*& column Role Name).
*&
*& Each row calls PRGN_ACTIVITY_GROUP_DELETE. Per-row status is collected
*& in GT_DEL_ROLE and shown in the screen-9016 ALV grid.
*& Side effect: deletes roles from the database.
*&---------------------------------------------------------------------*
FORM delete_roles .

  TYPES : BEGIN OF lty_del_role,
            role TYPE agr_name,
          END OF lty_del_role.

  DATA : lt_init_excel TYPE TABLE OF lty_del_role,
         ls_del_role   TYPE ty_del_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_return    TYPE sprot_u_tab.

  IF p_file9 IS NOT INITIAL.
    IF o_conttainer_9016 IS BOUND.
      CALL METHOD o_conttainer_9016->free.
      CLEAR o_conttainer_9016.
    ENDIF.

    IF o_grid_9016 IS BOUND.
      CLEAR o_grid_9016.
    ENDIF.

    CLEAR : gt_del_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file9
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 1
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_del_role-role = lwa_init_excel-role.

          CALL FUNCTION 'PRGN_ACTIVITY_GROUP_DELETE'
            EXPORTING
              activity_group                = lwa_init_excel-role
              show_dialog                   = space
            TABLES
              messages                      = lit_return
            EXCEPTIONS
              not_authorized                = 1
              transport_check_problem       = 2
              transport_canceled_or_problem = 3
              one_or_more_users_enqueued    = 4
              foreign_lock                  = 5
              user_cancels_action           = 6
              child_agr_exists              = 7
              deletion_in_target_cancelled  = 8
              tech_error                    = 9
              hr_error                      = 10
              OTHERS                        = 11.
          IF lit_return IS NOT INITIAL.
            LOOP AT lit_return INTO DATA(lwa_return).
              ls_del_role-type = lwa_return-severity.
              MESSAGE ID lwa_return-ag TYPE lwa_return-severity
                      NUMBER lwa_return-msgnr WITH lwa_return-var1
                      lwa_return-var2 lwa_return-var3 lwa_return-var4 INTO ls_del_role-message.
              APPEND ls_del_role TO gt_del_role.
            ENDLOOP.
          ELSE.
            ls_del_role-type    = 'S'.
            ls_del_role-message = |Role { lwa_init_excel-role } is deleted.|.
            APPEND ls_del_role TO gt_del_role.
            CLEAR : ls_del_role.
          ENDIF.
          CLEAR : ls_del_role.
        ENDLOOP.
      ENDIF.

      IF o_conttainer_9016 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9016
          EXPORTING
            container_name = 'CC_9016'.
      ENDIF.

      IF o_conttainer_9016 IS BOUND AND o_grid_9016 IS NOT BOUND.
        CREATE OBJECT o_grid_9016
          EXPORTING
            i_parent = o_conttainer_9016.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'ROLE'.
      ls_catalog-reptext = 'Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9016 IS BOUND.
        CALL METHOD o_grid_9016->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_del_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_pmrole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Push-Master-Role upload
*& (P_FILE10): requires an .XLS file whose header row reads 'Role Name'.
*& Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_pmrole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file10 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file10 ) - 4.
    TRANSLATE p_file10+lv_len(4) TO UPPER CASE.
    IF p_file10+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file10
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 1
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Role Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form push_master_role
*&---------------------------------------------------------------------*
*& Pushes (transfers) authorization data from master roles to their
*& derived roles for the roles listed in the uploaded Excel file
*& (P_FILE10, column Role Name).
*&
*& Each row calls SUPRN_TRANSFER_AUTH_DATA. Per-row status is shown in
*& the result ALV grid. Side effect: regenerates derived-role auth data.
*&---------------------------------------------------------------------*
FORM push_master_role .

  TYPES : BEGIN OF lty_pmas_role,
            role TYPE agr_name,
          END OF lty_pmas_role.

  DATA : lt_init_excel TYPE TABLE OF lty_pmas_role,
         ls_pmas_role  TYPE ty_del_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_return    TYPE bapirettab.

  IF p_file10 IS NOT INITIAL.
    IF o_conttainer_9017 IS BOUND.
      CALL METHOD o_conttainer_9017->free.
      CLEAR o_conttainer_9017.
    ENDIF.

    IF o_grid_9017 IS BOUND.
      CLEAR o_grid_9017.
    ENDIF.

    CLEAR : gt_pmast_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file10
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 1
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
          ls_pmas_role-role = lwa_init_excel-role.
          CALL FUNCTION 'SUPRN_TRANSFER_AUTH_DATA'
            EXPORTING
              top_activity_group = lwa_init_excel-role
            IMPORTING
              return             = lit_return.
          IF lit_return IS NOT INITIAL.
            ls_pmas_role-type    = lit_return[ 1 ]-type.
            ls_pmas_role-message = lit_return[ 1 ]-message.
          ELSE.
            ls_pmas_role-type    = 'S'.
            ls_pmas_role-message = 'Master Role Pushed to child'.
          ENDIF.

          APPEND ls_pmas_role TO gt_pmast_role.
          CLEAR : ls_pmas_role.
        ENDLOOP.
      ENDIF.

      IF o_conttainer_9017 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9017
          EXPORTING
            container_name = 'CC_9017'.
      ENDIF.

      IF o_conttainer_9017 IS BOUND AND o_grid_9017 IS NOT BOUND.
        CREATE OBJECT o_grid_9017
          EXPORTING
            i_parent = o_conttainer_9017.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'ROLE'.
      ls_catalog-reptext = 'Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9017 IS BOUND.
        CALL METHOD o_grid_9017->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_pmast_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_ccrole_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Create-Composite-Role upload
*& (P_FILE11): requires an .XLS file whose header row reads
*& 'Role Name' / 'Role Text'. Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_ccrole_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file11 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file11 ) - 4.
    TRANSLATE p_file11+lv_len(4) TO UPPER CASE.
    IF p_file11+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file11
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Role Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Role Text'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_composite_role
*&---------------------------------------------------------------------*
*& Creates composite roles from the uploaded Excel file (P_FILE11,
*& columns Role Name / Role Text).
*&
*& Implemented via a batch-input (BDC) session against transaction PFCG
*& (built with bdc_dynpro / bdc_field and run with CALL TRANSACTION).
*& Per-row status is collected in GT_CCOMP_ROLE and shown in the result
*& ALV grid. Side effect: creates composite roles in the database.
*&---------------------------------------------------------------------*
FORM create_composite_role .

  TYPES : BEGIN OF lty_comp_role,
            role TYPE agr_name,
            desc TYPE agr_title,
          END OF lty_comp_role.

  DATA : lt_init_excel TYPE TABLE OF lty_comp_role,
         ls_pmas_role  TYPE ty_ccomp_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lwa_comp_role TYPE ty_ccomp_role.

  IF p_file11 IS NOT INITIAL.
    IF o_conttainer_9018 IS BOUND.
      CALL METHOD o_conttainer_9018->free.
      CLEAR o_conttainer_9018.
    ENDIF.

    IF o_grid_9018 IS BOUND.
      CLEAR o_grid_9018.
    ENDIF.

    CLEAR : gt_ccomp_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file11
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

        PERFORM bdc_dynpro USING 'SAPLPRGN_TREE'    '0121'.
        PERFORM bdc_field  USING 'BDC_CURSOR'       'AGR_NAME_NEU'.
        PERFORM bdc_field  USING 'BDC_OKCODE'       '=SANLE'.
        PERFORM bdc_field  USING 'AGR_NAME_NEU'     lwa_init_excel-role.
        PERFORM bdc_dynpro USING 'SAPLPRGN_TREE'    '0300'.
        PERFORM bdc_field  USING 'BDC_CURSOR'       'S_AGR_TEXTS-TEXT'.
        PERFORM bdc_field  USING 'BDC_OKCODE'       '=SAVE'.
        PERFORM bdc_field  USING 'S_AGR_TEXTS-TEXT' lwa_init_excel-desc.
        CALL TRANSACTION 'PFCG' USING gt_bdctab MODE 'E' UPDATE 'S'
                                MESSAGES INTO gt_message.
        LOOP AT gt_message INTO DATA(lwa_message).

          lwa_comp_role-role = lwa_init_excel-role.
          lwa_comp_role-desc = lwa_init_excel-desc.
          lwa_comp_role-type = lwa_message-msgtyp.

          IF lwa_message-msgtyp = 'S'.
            lwa_comp_role-message = |Composite Role { lwa_init_excel-role } is created|.
          ELSE.
            MESSAGE ID lwa_message-msgid TYPE lwa_message-msgtyp
                      NUMBER lwa_message-msgnr WITH lwa_message-msgv1
                      lwa_message-msgv2 lwa_message-msgv3 lwa_message-msgv4
                      INTO lwa_comp_role-message.
          ENDIF.

          APPEND lwa_comp_role TO gt_ccomp_role.
          CLEAR : lwa_comp_role.
        ENDLOOP.
        CLEAR : gt_bdctab, gt_message.

      ENDLOOP.



      IF o_conttainer_9018 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9018
          EXPORTING
            container_name = 'CC_9018'.
      ENDIF.

      IF o_conttainer_9018 IS BOUND AND o_grid_9018 IS NOT BOUND.
        CREATE OBJECT o_grid_9018
          EXPORTING
            i_parent = o_conttainer_9018.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'ROLE'.
      ls_catalog-reptext = 'Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'DESC'.
      ls_catalog-reptext = 'Role Description'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 4.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9018 IS BOUND.
        CALL METHOD o_grid_9018->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_ccomp_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form bdc_dynpro
*&---------------------------------------------------------------------*
*& BDC helper: appends a screen (dynpro start) entry to the batch-input
*& table GT_BDCTAB.
*&   -->  IV_PROGRAM  Program name of the screen.
*&   -->  IV_DYNPRO   Screen (dynpro) number.
*&---------------------------------------------------------------------*
FORM bdc_dynpro USING iv_program
                      iv_dynpro.

  DATA : lwa_bdctab TYPE bdcdata.

  lwa_bdctab-program  = iv_program.
  lwa_bdctab-dynpro   = iv_dynpro.
  lwa_bdctab-dynbegin = abap_true.
  APPEND lwa_bdctab TO gt_bdctab.
  CLEAR : lwa_bdctab.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form bdc_field
*&---------------------------------------------------------------------*
*& BDC helper: appends a field value entry to the batch-input table
*& GT_BDCTAB.
*&   -->  IV_FNAM  Screen field name.
*&   -->  IV_FVAL  Field value.
*&---------------------------------------------------------------------*
FORM bdc_field  USING iv_fnam
                      iv_fval.

  DATA : lwa_bdctab TYPE bdcdata.

  lwa_bdctab-fnam = iv_fnam.
  lwa_bdctab-fval = iv_fval.

  APPEND lwa_bdctab TO gt_bdctab.
  CLEAR : lwa_bdctab.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form update_user_details
*&---------------------------------------------------------------------*
*& Mass-updates user master address data (first/last name, function,
*& department, e-mail) from the uploaded Excel file (P_FILE3).
*&
*& Each row calls BAPI_USER_CHANGE with the address structure and its
*& change-flags. Per-row status is collected in GT_USER_DETAILS and
*& shown in the screen-9010 ALV grid.
*& Side effect: changes user master data in the database.
*&---------------------------------------------------------------------*
FORM update_user_details .

  TYPES : BEGIN OF lty_user_det,
            userid     TYPE xubname,
            firstname  TYPE ad_namefir,
            lastname   TYPE ad_namelas,
            function   TYPE ad_fnctn,
            department TYPE ad_dprtmnt,
            e_mail     TYPE ad_smtpadr,
          END OF lty_user_det.

  DATA : ls_user_details TYPE ty_user_details,
         lt_catalog      TYPE lvc_t_fcat,
         ls_catalog      TYPE lvc_s_fcat,
         lt_excel        TYPE STANDARD TABLE OF alsmex_tabline,
         lt_init_excel   TYPE TABLE OF lty_user_det,
         lv_com          TYPE i,
         lwa_address     TYPE bapiaddr3,
         lwa_addressx    TYPE bapiaddr3x,
         lit_return      TYPE TABLE OF bapiret2.

  IF p_file3 IS NOT INITIAL.

    IF o_conttainer_9010 IS BOUND.
      CALL METHOD o_conttainer_9010->free.
      CLEAR o_conttainer_9010.
    ENDIF.

    IF o_grid_9010 IS BOUND.
      CLEAR o_grid_9010.
    ENDIF.

    CLEAR gt_user_details.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file3
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 6
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.

      IF lt_init_excel IS NOT INITIAL.

        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_user_details-userid     = lwa_init_excel-userid.
          ls_user_details-firstname  = lwa_init_excel-firstname.
          ls_user_details-lastname   = lwa_init_excel-lastname.
          ls_user_details-department = lwa_init_excel-department.
          ls_user_details-function   = lwa_init_excel-function.
          ls_user_details-e_mail     = lwa_init_excel-e_mail.

          lwa_address-firstname  = lwa_init_excel-firstname.
          lwa_address-lastname   = lwa_init_excel-lastname.
          lwa_address-department = lwa_init_excel-department.
          lwa_address-function   = lwa_init_excel-function.
          lwa_address-e_mail     = lwa_init_excel-e_mail.

          IF lwa_init_excel-firstname IS NOT INITIAL.
            lwa_addressx-firstname  = abap_true.
          ENDIF.

          IF lwa_init_excel-lastname IS NOT INITIAL.
            lwa_addressx-lastname   = abap_true.
          ENDIF.

          IF lwa_init_excel-department IS NOT INITIAL.
            lwa_addressx-department = abap_true.
          ENDIF.

          IF lwa_init_excel-function IS NOT INITIAL.
            lwa_addressx-function   = abap_true.
          ENDIF.

          IF lwa_init_excel-e_mail IS NOT INITIAL.
            lwa_addressx-e_mail     = abap_true.
          ENDIF.

          CALL FUNCTION 'BAPI_USER_CHANGE'
            EXPORTING
              username = lwa_init_excel-userid
              address  = lwa_address
              addressx = lwa_addressx
            TABLES
              return   = lit_return.
          IF lit_return IS NOT INITIAL.
            ls_user_details-type    = lit_return[ 1 ]-type.
            ls_user_details-message = lit_return[ 1 ]-message.
          ENDIF.
          APPEND ls_user_details TO gt_user_details.
          CLEAR : ls_user_details.
        ENDLOOP.
      ENDIF.

    ENDIF.

    IF o_conttainer_9010 IS NOT BOUND.
      CREATE OBJECT o_conttainer_9010
        EXPORTING
          container_name = 'CC_9010'.
    ENDIF.

    IF o_conttainer_9010 IS BOUND AND o_grid_9010 IS NOT BOUND.
      CREATE OBJECT o_grid_9010
        EXPORTING
          i_parent = o_conttainer_9010.
    ENDIF.

    wa_layout-col_opt    = abap_true.
    wa_layout-cwidth_opt = abap_true.

    ls_catalog-col_pos = 1.
    ls_catalog-fieldname = 'USERID'.
    ls_catalog-reptext = 'User ID'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 2.
    ls_catalog-fieldname = 'FIRSTNAME'.
    ls_catalog-reptext = 'First Name'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 3.
    ls_catalog-fieldname = 'LASTNAME'.
    ls_catalog-reptext = 'Last Name'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 4.
    ls_catalog-fieldname = 'DEPARTMENT'.
    ls_catalog-reptext = 'Department'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 5.
    ls_catalog-fieldname = 'FUNCTION'.
    ls_catalog-reptext = 'Function'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 6.
    ls_catalog-fieldname = 'E_MAIL'.
    ls_catalog-reptext = 'E Mail'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 7.
    ls_catalog-fieldname = 'TYPE'.
    ls_catalog-reptext = 'Message Type'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 8.
    ls_catalog-fieldname = 'MESSAGE'.
    ls_catalog-reptext = 'Message'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    IF o_grid_9010 IS BOUND.
      CALL METHOD o_grid_9010->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_user_details.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form man_role_ad
*&---------------------------------------------------------------------*
*& Manual role assignment / removal (screen 9020).
*&
*& Builds the role list from select-option SO_AROLE with validity dates
*& P_FVALID..P_TVALID (defaulted to today..9999-12-31). For each user in
*& SO_CROLE it reads the current assignments (BAPI_USER_GET_DETAIL),
*& then either appends the roles (RB_ADR = add) or removes them
*& (RB_DER = remove) and writes them back with
*& BAPI_USER_ACTGROUPS_ASSIGN, committing the change. Per-user status is
*& shown in the screen-9020 ALV grid.
*& Side effect: changes user role assignments in the database.
*&---------------------------------------------------------------------*
FORM man_role_ass .

  DATA: lt_act         TYPE STANDARD TABLE OF bapiagr,
        lt_act_ad      TYPE STANDARD TABLE OF bapiagr,
        ls_act_ad      TYPE bapiagr,
        lt_ret1        TYPE STANDARD TABLE OF bapiret2,
        lt_ret2        TYPE STANDARD TABLE OF bapiret2,
        ls_role_output TYPE ty_role_output,
        lt_catalog     TYPE lvc_t_fcat,
        ls_catalog     TYPE lvc_s_fcat.

  LOOP AT so_arole.
    ls_act_ad-agr_name = so_arole-low.
    ls_act_ad-from_dat = p_fvalid.
    ls_act_ad-to_dat = p_tvalid.
    APPEND ls_act_ad TO lt_act_ad.
    CLEAR ls_act_ad.
  ENDLOOP.

  IF p_fvalid IS INITIAL.
    p_fvalid = sy-datum.
  ENDIF.

  IF p_tvalid IS INITIAL.
    p_tvalid = '99991231'.
  ENDIF.

  LOOP AT so_crole.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username       = so_crole-low
      TABLES
        activitygroups = lt_act
        return         = lt_ret1.
    IF lt_ret1 IS NOT INITIAL AND lt_ret1[ 1 ]-type = 'E'.
      ls_role_output-userid = so_crole-low.
      ls_role_output-role_msg = lt_ret1[ 1 ]-message.
    ELSE.
      IF rb_adr EQ 'X'.
        APPEND LINES OF lt_act_ad TO lt_act.
      ELSEIF rb_der EQ 'X'.
        LOOP AT lt_act_ad INTO ls_act_ad.
          DELETE lt_act WHERE agr_name = ls_act_ad-agr_name.
        ENDLOOP.
      ENDIF.
      CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
        EXPORTING
          username       = so_crole-low
        TABLES
          activitygroups = lt_act
          return         = lt_ret2.

*     BAPI_USER_ACTGROUPS_ASSIGN does not commit on its own; without this
*     the assignment / removal is not persisted.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.

      ls_role_output-userid = so_crole-low.
      READ TABLE lt_ret2 INTO DATA(ls_ret2) INDEX 1.
      IF sy-subrc = 0.
        ls_role_output-role_msg = ls_ret2-message.
      ENDIF.
    ENDIF.
    APPEND ls_role_output TO gt_role_output.
    CLEAR: ls_role_output, lt_act, lt_ret1, lt_ret2.
  ENDLOOP.

  CHECK gt_role_output IS NOT INITIAL.

  IF o_conttainer_9020 IS BOUND.
    CALL METHOD o_conttainer_9020->free.
    CLEAR o_conttainer_9020.
  ENDIF.

  IF o_grid_9020 IS BOUND.
    CLEAR o_grid_9020.
  ENDIF.

  IF o_conttainer_9020 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9020
      EXPORTING
        container_name = 'CC_9020'.
  ENDIF.

  IF o_conttainer_9020 IS BOUND AND o_grid_9020 IS NOT BOUND.
    CREATE OBJECT o_grid_9020
      EXPORTING
        i_parent = o_conttainer_9020.
  ENDIF.

  wa_layout-col_opt = abap_true.
  wa_layout-cwidth_opt = abap_true.

  ls_catalog-col_pos = 1.
  ls_catalog-fieldname = 'USERID'.
  ls_catalog-reptext = 'User ID'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 2.
  ls_catalog-fieldname = 'ROLE_MSG'.
  ls_catalog-reptext = 'Role Assignment/Deletion Message'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9020 IS BOUND.
    CALL METHOD o_grid_9020->set_table_for_first_display
      EXPORTING
        is_layout       = wa_layout
      CHANGING
        it_fieldcatalog = lt_catalog
        it_outtab       = gt_role_output.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form file_role_ass
*&---------------------------------------------------------------------*
*& File-based role assignment / removal (screen 9020).
*&
*& Reads the uploaded Excel file (P_FILE13, columns User Name / Role
*& Name / From Date / To Date / Add-Remove Indicator). For each user it
*& reads the current assignments (BAPI_USER_GET_DETAIL), applies the
*& add ('A') or delete ('D') rows (dates converted with
*& CONVERT_DATE_TO_INTERNAL), writes them back with
*& BAPI_USER_ACTGROUPS_ASSIGN and commits. Per-user status is shown in
*& the screen-9020 ALV grid.
*& Side effect: changes user role assignments in the database.
*&---------------------------------------------------------------------*
FORM file_role_ass .

  TYPES: BEGIN OF lty_std_role,
           uname TYPE string,
           role  TYPE string,
           fdate TYPE string,
           tdate TYPE string,
           rop   TYPE string,
         END OF lty_std_role.

  DATA: lt_std_role    TYPE STANDARD TABLE OF lty_std_role,
        lt_excel       TYPE STANDARD TABLE OF alsmex_tabline,
        ls_excel       TYPE alsmex_tabline,
        lv_com         TYPE i,
        ls_role_output TYPE ty_role_output,
        lt_catalog     TYPE lvc_t_fcat,
        ls_catalog     TYPE lvc_s_fcat.

  DATA: lt_act    TYPE STANDARD TABLE OF bapiagr,
        lt_act_ad TYPE STANDARD TABLE OF bapiagr,
        ls_act_ad TYPE bapiagr,
        lt_ret1   TYPE STANDARD TABLE OF bapiret2,
        lt_ret2   TYPE STANDARD TABLE OF bapiret2,
        lv_uname  TYPE bapibname-bapibname.

  FIELD-SYMBOLS:<lfs_data> TYPE lty_std_role,
                <lfs_val>  TYPE any.

  IF p_file13 IS NOT INITIAL.

    IF o_conttainer_9020 IS BOUND.
      CALL METHOD o_conttainer_9020->free.
      CLEAR o_conttainer_9020.
    ENDIF.

    IF o_grid_9020 IS BOUND.
      CLEAR o_grid_9020.
    ENDIF.

    CLEAR gt_role_output[].

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file13
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 5
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc <> 0.
* Implement suitable error handling here
    ENDIF.

    SORT lt_excel BY row col.

    LOOP AT lt_excel INTO ls_excel.
      AT NEW row.
        APPEND INITIAL LINE TO lt_std_role ASSIGNING <lfs_data>.
        lv_com = 1.
      ENDAT.
      ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
      WHILE lv_com NE ls_excel-col.
        lv_com = lv_com + 1.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
      ENDWHILE.
      IF lv_com EQ ls_excel-col.
        <lfs_val> = ls_excel-value.
      ENDIF.
      lv_com = lv_com + 1.
    ENDLOOP.

    LOOP AT lt_std_role INTO DATA(ls_std_role).
      TRANSLATE ls_std_role-rop TO UPPER CASE.
      AT NEW uname.
        lv_uname = ls_std_role-uname.
        CALL FUNCTION 'BAPI_USER_GET_DETAIL'
          EXPORTING
            username       = lv_uname
          TABLES
            activitygroups = lt_act
            return         = lt_ret1.
        IF lt_ret1 IS NOT INITIAL AND lt_ret1[ 1 ]-type = 'E'.
          ls_role_output-userid = lv_uname.
          ls_role_output-role_msg = lt_ret1[ 1 ]-message.
          APPEND ls_role_output TO gt_role_output.
          CLEAR ls_role_output.
          CONTINUE.
        ENDIF.
      ENDAT.
      IF lt_ret1 IS INITIAL OR lt_ret1[ 1 ]-type NE 'E'.
        IF ls_std_role-rop EQ 'A'.
          ls_act_ad-agr_name = ls_std_role-role.
          CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
            EXPORTING
              date_external            = ls_std_role-fdate
            IMPORTING
              date_internal            = ls_std_role-fdate
            EXCEPTIONS
              date_external_is_invalid = 1
              OTHERS                   = 2.
          IF sy-subrc EQ 0.
            ls_act_ad-from_dat = ls_std_role-fdate.
          ENDIF.
          CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
            EXPORTING
              date_external            = ls_std_role-tdate
            IMPORTING
              date_internal            = ls_std_role-tdate
            EXCEPTIONS
              date_external_is_invalid = 1
              OTHERS                   = 2.
          IF sy-subrc EQ 0.
            ls_act_ad-to_dat = ls_std_role-tdate.
          ENDIF.
          APPEND ls_act_ad TO lt_act.
          CLEAR ls_act_ad.
        ELSEIF ls_std_role-rop EQ 'D'.
          DELETE lt_act WHERE agr_name = ls_std_role-role.
        ENDIF.
        AT END OF uname.
          CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
            EXPORTING
              username       = lv_uname
            TABLES
              activitygroups = lt_act
              return         = lt_ret2.

*         Persist the assignment - the BAPI does not commit on its own.
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              wait = abap_true.

          ls_role_output-userid = lv_uname.
          READ TABLE lt_ret2 INTO DATA(ls_ret2) INDEX 1.
          IF sy-subrc = 0.
            ls_role_output-role_msg = ls_ret2-message.
          ENDIF.
          APPEND ls_role_output TO gt_role_output.
          CLEAR: ls_role_output, lt_act, lt_ret1, lt_ret2, lv_uname.
        ENDAT.
      ENDIF.
    ENDLOOP.

    CHECK gt_role_output IS NOT INITIAL.

    IF o_conttainer_9020 IS NOT BOUND.
      CREATE OBJECT o_conttainer_9020
        EXPORTING
          container_name = 'CC_9020'.
    ENDIF.

    IF o_conttainer_9020 IS BOUND AND o_grid_9020 IS NOT BOUND.
      CREATE OBJECT o_grid_9020
        EXPORTING
          i_parent = o_conttainer_9020.
    ENDIF.

    wa_layout-col_opt = abap_true.
    wa_layout-cwidth_opt = abap_true.

    ls_catalog-col_pos = 1.
    ls_catalog-fieldname = 'USERID'.
    ls_catalog-reptext = 'User ID'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 2.
    ls_catalog-fieldname = 'ROLE_MSG'.
    ls_catalog-reptext = 'Role Assignment/Deletion Message'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    IF o_grid_9020 IS BOUND.
      CALL METHOD o_grid_9020->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_role_output.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9002
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9002.

  DATA:
    lv_file      TYPE flag,
    lv_detail    TYPE flag,
    lv_error     TYPE flag,
    lv_answer(1) TYPE c,
    lv_local     TYPE flag,
    lv_filename  TYPE string,
    lv_path      TYPE string,
    lv_fullpath  TYPE string,
    lv_action    TYPE i,
    lv_message   TYPE bapi_msg,
    lv_xml       TYPE string,

    lr_users     TYPE RANGE OF xubname,

    li_level     TYPE zacg_t_level,
    li_user_role TYPE zacg_t_user_role,
    li_excel     TYPE STANDARD TABLE OF alsmex_tabline,
    li_tab       TYPE TABLE OF string,
    li_xml       TYPE STANDARD TABLE OF string.

  CLEAR g_file.

  CLEAR: i_summary_9001, i_detail_9001.

  IF sy-ucomm = 'EXE'.
    sy-ucomm = g_ucomm = '&UEX'.
  ENDIF.

  CASE g_ucomm.

    WHEN '&UEX'.

      CLEAR: i_summary_9001, i_detail_9001.

      IF p_ulvl0 IS NOT INITIAL.
        CLEAR li_level.
      ELSE.
        IF p_ulvl1 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING FIELD-SYMBOL(<lfs_level>).
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '4'.
        ENDIF.
        IF p_ulvl2 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING <lfs_level>.
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '3'.
        ENDIF.
        IF p_ulvl3 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING <lfs_level>.
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '2'.
        ENDIF.
        IF p_ulvl4 IS NOT INITIAL.
          APPEND INITIAL LINE TO li_level ASSIGNING <lfs_level>.
          <lfs_level>-sign = 'I'.
          <lfs_level>-option = 'EQ'.
          <lfs_level>-low = '1'.
        ENDIF.
      ENDIF.

      IF r_udtl IS NOT INITIAL.
        lv_detail = abap_true.
      ENDIF.

      CHECK lv_error IS INITIAL.

      IF s_user[] IS NOT INITIAL AND p_usimu IS INITIAL.

        SELECT bname
          FROM usr02
          WHERE bname IN @s_user[]
          AND gltgv <= @sy-datum
          AND ( gltgb >= @sy-datum OR gltgb IS INITIAL )
          AND ustyp IN ('A','S')
          AND uflag IN (0,128)
          INTO TABLE @DATA(li_valid_users).
        IF sy-subrc IS NOT INITIAL.
          CLEAR g_ucomm.
          lv_error = abap_true.
          MESSAGE 'Please provide valid User ID' TYPE 'S' DISPLAY LIKE 'E'.
        ELSE.
          SELECT a~bname, b~agr_name
          FROM usr02 AS a
          INNER JOIN agr_users AS b
          ON a~bname EQ b~uname
          WHERE a~bname IN @s_user[]
            AND a~gltgv <= @sy-datum
            AND ( a~gltgb >= @sy-datum OR a~gltgb IS INITIAL )
            AND a~ustyp IN ('A','S')
            AND a~uflag IN (0,128)
            AND b~from_dat <= @sy-datum
            AND b~to_dat >= @sy-datum
          INTO TABLE @li_user_role.
          IF li_user_role IS INITIAL.
            CLEAR g_ucomm.
            lv_error = abap_true.
            MESSAGE 'No Risk found for the users(s)' TYPE 'S' DISPLAY LIKE 'E'.
          ENDIF.
        ENDIF.

      ELSEIF s_user[] IS INITIAL AND p_usimu IS INITIAL.
        CLEAR g_ucomm.
        lv_error = abap_true.
        MESSAGE 'Please provide User(s)' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.

      IF p_ulvl0 IS INITIAL AND
         p_ulvl1 IS INITIAL AND
         p_ulvl2 IS INITIAL AND
         p_ulvl3 IS INITIAL AND
         p_ulvl4 IS INITIAL.
        CLEAR g_ucomm.
        lv_error = abap_true.
        MESSAGE 'Please provide Risk Level' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.

      CHECK lv_error IS INITIAL.

      IF p_usimu IS NOT INITIAL.

        IF p_ufile IS NOT INITIAL.

          CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
            EXPORTING
              filename                = p_ufile
              i_begin_col             = 1
              i_begin_row             = 1
              i_end_col               = 2
              i_end_row               = 99999
            TABLES
              intern                  = li_excel
            EXCEPTIONS
              inconsistent_parameters = 1
              upload_ole              = 2
              OTHERS                  = 3.
          IF sy-subrc IS INITIAL.

            LOOP AT li_excel INTO DATA(lw_excel).

              IF lw_excel-row GT '0001'.
                EXIT.
              ENDIF.

              CASE lw_excel-col.
                WHEN 1.
                  IF lw_excel-value <> 'User ID'.
                    lv_error = abap_true.
                    EXIT.
                  ENDIF.
                WHEN 2.
                  IF lw_excel-value <> 'Role'.
                    lv_error = abap_true.
                    EXIT.
                  ENDIF.
              ENDCASE.

            ENDLOOP.

            IF lv_error IS NOT INITIAL.
              CLEAR g_ucomm.
              lv_error = abap_true.
              MESSAGE 'Invalid file format. Click on Download button for correct format' TYPE 'S' DISPLAY LIKE 'E'.
            ENDIF.
          ELSE.
            CLEAR g_ucomm.
            lv_error = abap_true.
            MESSAGE 'Please provide simulation file in xls format only' TYPE 'S' DISPLAY LIKE 'E'.
          ENDIF.
        ELSE.
          CLEAR g_ucomm.
          lv_error = abap_true.
          MESSAGE 'Please provide simulation file in xls format only' TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.

      ENDIF.


      IF lv_error IS INITIAL.

        IF p_usimu IS NOT INITIAL.

          DELETE li_excel WHERE row EQ '0001'.

          LOOP AT li_excel INTO DATA(lw_excel1).
            lw_excel = lw_excel1.
            AT NEW row.
              APPEND INITIAL LINE TO li_user_role ASSIGNING FIELD-SYMBOL(<lfs_user_role>).
            ENDAT.
            ASSIGN COMPONENT lw_excel-col OF STRUCTURE <lfs_user_role> TO FIELD-SYMBOL(<lfs_value>).
            IF <lfs_value> IS ASSIGNED.
              <lfs_value> = lw_excel-value.
            ENDIF.
            UNASSIGN <lfs_value>.
          ENDLOOP.

          lr_users = VALUE #( FOR lw_user_role IN li_user_role ( sign = 'I' option = 'EQ' low = lw_user_role-bname  ) ).
          SORT lr_users BY low.
          DELETE ADJACENT DUPLICATES FROM lr_users COMPARING low.
          IF lr_users IS NOT INITIAL.

            SELECT a~bname, b~agr_name
                    FROM usr02 AS a
                    INNER JOIN agr_users AS b
                    ON a~bname EQ b~uname
                    WHERE a~bname IN @lr_users[]
                      AND a~gltgv <= @sy-datum
                      AND ( a~gltgb >= @sy-datum OR a~gltgb IS INITIAL )
                      AND a~ustyp IN ('A','S')
                      AND a~uflag IN (0,128)
                      AND b~to_dat >= @sy-datum
                    INTO TABLE @DATA(li_user_role_exist).
            IF sy-subrc IS INITIAL.
              APPEND LINES OF li_user_role_exist TO li_user_role.
            ENDIF.

            SORT li_user_role BY bname agr_name.
            DELETE ADJACENT DUPLICATES FROM li_user_role COMPARING bname agr_name.
          ENDIF.

        ENDIF.

        IF li_user_role IS NOT INITIAL.

          CALL FUNCTION 'ZACG_RISK_USERS' DESTINATION 'NONE'
            EXPORTING
              it_user_role    = li_user_role
              iv_summary      = abap_true
              iv_detail       = lv_detail
              it_level        = li_level
              it_module       = s_umod[]
            IMPORTING
              et_risk_summary = i_summary_9001
              et_risk_detail  = i_detail_9001
              ev_file         = lv_file.

          IF lv_file IS NOT INITIAL.

            CALL FUNCTION 'POPUP_TO_DECIDE_WITH_MESSAGE'
              EXPORTING
                diagnosetext1     = 'Due to wide selection range, results can not be displayed online.'
                textline1         = 'Either selection range should be modified to minimise the result'
                textline2         = 'or Excel download is recommended.'
                textline3         = 'Do you want to continue with Excel download option?'
                text_option1      = 'Continue'
                text_option2      = 'Cancel'
                icon_text_option1 = 'ICON_OKAY'
                icon_text_option2 = 'ICON_CANCEL'
                titel             = 'Warning'
                cancel_display    = ' '
              IMPORTING
                answer            = lv_answer.
            IF lv_answer = '1'. " User choose to continue to download the deatils in excel

              CLEAR: i_summary_9001, i_detail_9001.

              CALL METHOD cl_gui_frontend_services=>file_save_dialog
                EXPORTING
                  window_title      = 'Provide a location'
                  default_extension = 'xlsx'
                  file_filter       = 'Excel Workbook (*.xlsx)|*.xlsx'
                CHANGING
                  filename          = lv_filename
                  path              = lv_path
                  fullpath          = lv_fullpath
                  user_action       = lv_action.
              IF lv_action = 0.

                lv_local  = abap_true.

                CALL FUNCTION 'ZACG_RISK_USERS'
                  EXPORTING
                    it_user_role = li_user_role
                    iv_summary   = abap_true
                    iv_detail    = lv_detail
                    it_level     = li_level
                    it_module    = s_umod[]
                    iv_local     = lv_local
                    iv_filename  = lv_filename
                    iv_fullpath  = lv_fullpath
                  IMPORTING
                    ev_message   = lv_message.

              ENDIF.

              MESSAGE lv_message TYPE 'S'.

            ENDIF.


          ELSE.

            IF i_summary_9001 IS INITIAL AND i_detail_9001 IS INITIAL.
              MESSAGE 'No Risk Found' TYPE 'S'.
            ELSE.
              IF lv_detail IS INITIAL.
                CALL SCREEN 8005.
              ELSE.
                CALL SCREEN 8006.
              ENDIF.
            ENDIF.
          ENDIF.

        ELSE.
          MESSAGE 'No valid users found as per given input' TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.

      ENDIF.


    WHEN 'UFMT'.

      TRY.
          CALL TRANSFORMATION zacg_users_simulation
          SOURCE it_tab = li_tab
          RESULT XML lv_xml.
        CATCH cx_root INTO DATA(ls_error).
          DATA(lv_error_msg) = ls_error->get_text( ).
          MESSAGE lv_error_msg TYPE 'E'.
      ENDTRY.

      IF lv_xml IS NOT INITIAL.

        APPEND lv_xml TO li_xml.

        CALL METHOD cl_gui_frontend_services=>file_save_dialog
          EXPORTING
            window_title      = 'Provide a location'
            default_extension = 'xls'
            file_filter       = 'xls file (*.xls)|*.xls'
          CHANGING
            filename          = lv_filename
            path              = lv_path
            fullpath          = lv_fullpath
            user_action       = lv_action.
        IF lv_action = 0.

          CALL METHOD cl_gui_frontend_services=>gui_download
            EXPORTING
              filetype = 'ASC'
              filename = lv_fullpath
            CHANGING
              data_tab = li_xml
            EXCEPTIONS
              OTHERS   = 1.
          IF sy-subrc IS INITIAL.
            MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          ENDIF.

        ENDIF.

      ENDIF.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_role_assign_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the File-Role-Assignment upload
*& (P_FILE13): requires an .XLS file whose header row reads 'User Name',
*& 'Role Name', 'From Date', 'To Date', 'Add/Remove Indicator'.
*& Blocks the action on any failure.
*&---------------------------------------------------------------------*
FORM p_role_assign_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file13 IS INITIAL.
*** Manual Validation
    IF so_crole[] IS INITIAL.
      MESSAGE 'Please Provide User ID' TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
    ELSEIF so_arole[] IS INITIAL.
      MESSAGE 'Please Provide Roles' TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
    ENDIF.
    IF rb_adr EQ 'X'.
      IF p_fvalid > p_tvalid.
        MESSAGE 'Valid From Date cannot be greater than the Valid To Date'
        TYPE 'S' DISPLAY LIKE 'E'.
        LEAVE LIST-PROCESSING.
      ENDIF.
    ENDIF.
  ELSE.

    DATA(lv_len) = strlen( p_file13 ) - 4.
    TRANSLATE p_file13+lv_len(4) TO UPPER CASE.
    IF p_file13+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file13
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 5
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'User Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'Role Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 3.
              IF lw_excel-value NE 'From Date'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 4.
              IF lw_excel-value NE 'To Date'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 5.
              IF lw_excel-value NE 'Add/Remove Indicator'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_role_copy
*&---------------------------------------------------------------------*
*& Copies roles from the uploaded Excel file (P_FILE12, columns Original
*& Role Name / New Role Name).
*&
*& Each row calls PRGN_COPY_AGR to copy the source role to the target.
*& Per-row status is collected in GT_COPY_ROLE and shown in the
*& screen-9012 ALV grid. Side effect: creates roles in the database.
*&---------------------------------------------------------------------*
FORM create_role_copy .

  TYPES : BEGIN OF lty_copy_role,
            org_role TYPE agr_name,
            new_role TYPE agr_name,
          END OF lty_copy_role.

  DATA : lt_init_excel TYPE TABLE OF lty_copy_role,
         ls_copy_role  TYPE ty_copy_role,
         lt_catalog    TYPE lvc_t_fcat,
         ls_catalog    TYPE lvc_s_fcat,
         lt_excel      TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com        TYPE i,
         lit_return    TYPE sprot_u_tab.

  IF p_file12 IS NOT INITIAL.

    IF o_conttainer_9012 IS BOUND.
      CALL METHOD o_conttainer_9012->free.
      CLEAR o_conttainer_9012.
    ENDIF.

    IF o_grid_9012 IS BOUND.
      CLEAR o_grid_9012.
    ENDIF.

    CLEAR : gt_copy_role.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_file12
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.
      LOOP AT lt_excel INTO DATA(ls_excel).
        AT NEW row.
          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lv_com = 1.
        ENDAT.
        ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_val>).
        WHILE lv_com NE ls_excel-col.
          lv_com = lv_com + 1.
          ASSIGN COMPONENT lv_com OF STRUCTURE <lfs_data> TO <lfs_val>.
        ENDWHILE.
        IF lv_com EQ ls_excel-col.
          <lfs_val> = ls_excel-value.
        ENDIF.
        lv_com = lv_com + 1.
      ENDLOOP.
      IF lt_init_excel IS NOT INITIAL.
        LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

          ls_copy_role-org_role = lwa_init_excel-org_role.
          ls_copy_role-new_role = lwa_init_excel-new_role.

          CALL FUNCTION 'PRGN_COPY_AGR'
            EXPORTING
              source_agr                     = lwa_init_excel-org_role
              target_agr                     = lwa_init_excel-new_role
              display_messages               = space
            IMPORTING
              messages                       = lit_return
            EXCEPTIONS
              no_recording                   = 1
              target_agrname_not_free        = 2
              source_agr_not_exists          = 3
              no_authority_for_creation      = 4
              no_authority_for_user_insert   = 5
              no_authority_for_tcodes_insert = 6
              no_authority_for_object_insert = 7
              no_authority_for_srole_insert  = 8
              no_authority_for_srole_show    = 9
              flag_not_existing              = 10
              action_cancelled               = 11
              no_auth_for_objects_and_users  = 12
              no_auth_for_sroles_and_users   = 13
              enqueue_failure                = 14
              hr_incomplete                  = 15
              dist_incomplete                = 16
              OTHERS                         = 17.
          IF lit_return IS NOT INITIAL.
            LOOP AT lit_return INTO DATA(lwa_return).
              ls_copy_role-type = lwa_return-severity.
              MESSAGE ID lwa_return-ag TYPE lwa_return-severity
                      NUMBER lwa_return-msgnr WITH lwa_return-var1
                      lwa_return-var2 lwa_return-var3 lwa_return-var4 INTO ls_copy_role-message.
              APPEND ls_copy_role TO gt_copy_role.
              CLEAR : ls_copy_role.
            ENDLOOP.
          ELSE.
            ls_copy_role-type    = 'S'.
            ls_copy_role-message = |Role { lwa_init_excel-new_role } is created.|.
            APPEND ls_copy_role TO gt_copy_role.
            CLEAR : ls_copy_role.
          ENDIF.
          CLEAR : ls_copy_role.
        ENDLOOP.
      ENDIF.

      IF o_conttainer_9019 IS NOT BOUND.
        CREATE OBJECT o_conttainer_9019
          EXPORTING
            container_name = 'CC_9019'.
      ENDIF.

      IF o_conttainer_9019 IS BOUND AND o_grid_9019 IS NOT BOUND.
        CREATE OBJECT o_grid_9019
          EXPORTING
            i_parent = o_conttainer_9019.
      ENDIF.

      wa_layout-col_opt    = abap_true.
      wa_layout-cwidth_opt = abap_true.

      ls_catalog-col_pos = 1.
      ls_catalog-fieldname = 'ORG_ROLE'.
      ls_catalog-reptext = 'Original Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 2.
      ls_catalog-fieldname = 'NEW_ROLE'.
      ls_catalog-reptext = 'New Role'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 3.
      ls_catalog-fieldname = 'TYPE'.
      ls_catalog-reptext = 'Type'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      ls_catalog-col_pos = 4.
      ls_catalog-fieldname = 'MESSAGE'.
      ls_catalog-reptext = 'Message'.
      APPEND ls_catalog TO lt_catalog.
      CLEAR ls_catalog.

      IF o_grid_9019 IS BOUND.
        CALL METHOD o_grid_9019->set_table_for_first_display
          EXPORTING
            is_layout       = wa_layout
          CHANGING
            it_fieldcatalog = lt_catalog
            it_outtab       = gt_copy_role.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form p_copy_role_validate
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN validation for the Copy-Role upload (P_FILE12):
*& requires an .XLS file whose header row reads
*& 'Original Role Name' / 'New Role Name'. Blocks the action on failure.
*&---------------------------------------------------------------------*
FORM p_copy_role_validate .

  DATA lt_excel TYPE STANDARD TABLE OF alsmex_tabline.

  CHECK g_ucomm = 'EXE'.

  IF p_file12 IS INITIAL.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide valid file' TYPE 'E'.
  ELSE.
    DATA(lv_len) = strlen( p_file12 ) - 4.
    TRANSLATE p_file12+lv_len(4) TO UPPER CASE.
    IF p_file12+lv_len(4) = '.XLS'.
      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file12
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 2
          i_end_row               = 1
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.
        LOOP AT lt_excel INTO DATA(lw_excel).
          CASE sy-tabix.
            WHEN 1.
              IF lw_excel-value NE 'Original Role Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
            WHEN 2.
              IF lw_excel-value NE 'New Role Name'.
                CLEAR lw_excel.
                EXIT.
              ENDIF.
          ENDCASE.
        ENDLOOP.
        IF lw_excel IS INITIAL.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form monitor_standard_users
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM monitor_standard_users .

  DATA:
    lit_catalog TYPE lvc_t_fcat,
    lo_data     TYPE REF TO data.

  IF o_conttainer_9021 IS BOUND.
    CALL METHOD o_conttainer_9021->free.
    CLEAR o_conttainer_9021.
  ENDIF.

  IF o_grid_9021 IS BOUND.
    CLEAR o_grid_9021.
  ENDIF.

  cl_salv_bs_runtime_info=>set(
    EXPORTING
      display  = abap_false
      metadata = abap_false
      data     = abap_true
  ).

  SUBMIT rsusr003 AND RETURN .

  cl_salv_bs_runtime_info=>get_data_ref(
    IMPORTING
      r_data_descr = DATA(lo_data_desc) ).
  IF lo_data_desc IS NOT INITIAL.
    CREATE DATA lo_data TYPE HANDLE lo_data_desc.
    ASSIGN lo_data->* TO <fs_data>.
  ENDIF.

  IF <fs_data> IS ASSIGNED.
    cl_salv_bs_runtime_info=>get_data(
      IMPORTING
        t_data = <fs_data> ).
  ENDIF.


  cl_salv_bs_runtime_info=>clear_all( ).

  IF o_conttainer_9021 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9021
      EXPORTING
        container_name = 'CC_9021'.
  ENDIF.

  IF o_conttainer_9021 IS BOUND AND o_grid_9021 IS NOT BOUND.
    CREATE OBJECT o_grid_9021
      EXPORTING
        i_parent = o_conttainer_9021.
  ENDIF.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'SIM_RSUSR003_ALV'
    CHANGING
      ct_fieldcat            = lit_catalog
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.
  IF sy-subrc IS INITIAL.
    READ TABLE lit_catalog ASSIGNING FIELD-SYMBOL(<lfs_catalog>) INDEX 1.
    IF sy-subrc IS INITIAL.
      CLEAR <lfs_catalog>-tech.
    ENDIF.
  ENDIF.

  wa_layout-zebra = abap_true.
  wa_layout-col_opt = abap_true.
  wa_layout-cwidth_opt = abap_true.

  IF o_grid_9021 IS BOUND.
    CALL METHOD o_grid_9021->set_table_for_first_display
      EXPORTING
        is_layout       = wa_layout
      CHANGING
        it_fieldcatalog = lit_catalog
        it_outtab       = <fs_data>.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form mbs
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM mbs .

  DATA: lit_catalog TYPE lvc_t_fcat,
        lo_data     TYPE REF TO data,
        lt_data     TYPE STANDARD TABLE OF usrcd,
        lt_data_dup TYPE STANDARD TABLE OF usrcd,
        ls_data     TYPE usrcd.


  UNASSIGN <fs_data>.

  IF o_conttainer_9022 IS BOUND.
    CALL METHOD o_conttainer_9022->free.
    CLEAR o_conttainer_9022.
  ENDIF.

  IF o_grid_9022 IS BOUND.
    CLEAR o_grid_9022.
  ENDIF.

  cl_salv_bs_runtime_info=>set(
    EXPORTING
      display  = abap_false
      metadata = abap_false
      data     = abap_true
  ).

  SUBMIT rsusr100n WITH fdate EQ p_fdate WITH
  ftime EQ p_ftime WITH tdate EQ p_tdate WITH
  ttime EQ p_ttime WITH pass EQ 'X' WITH
  tval EQ 'X' WITH role EQ 'X' WITH
  prof EQ 'X'
  AND RETURN .

  cl_salv_bs_runtime_info=>get_data_ref(
    IMPORTING
      r_data_descr = DATA(lo_data_desc) ).
  IF lo_data_desc IS NOT INITIAL.
    CREATE DATA lo_data TYPE HANDLE lo_data_desc.
    ASSIGN lo_data->* TO <fs_data>.
  ENDIF.

  IF <fs_data> IS ASSIGNED.
    cl_salv_bs_runtime_info=>get_data(
      IMPORTING
        t_data = <fs_data> ).
  ENDIF.

  IF <fs_data> IS ASSIGNED AND <fs_data> IS NOT INITIAL.
    APPEND LINES OF <fs_data> TO lt_data.
    LOOP AT lt_data INTO ls_data.
      IF ls_data-bname NE ls_data-modbe.
        DELETE TABLE <fs_data> FROM ls_data.
      ENDIF.
    ENDLOOP.
  ENDIF.

  cl_salv_bs_runtime_info=>clear_all( ).

  IF <fs_data> IS ASSIGNED AND <fs_data> IS NOT INITIAL.

    IF o_conttainer_9022 IS NOT BOUND.
      CREATE OBJECT o_conttainer_9022
        EXPORTING
          container_name = 'CC_9022'.
    ENDIF.

    IF o_conttainer_9022 IS BOUND AND o_grid_9022 IS NOT BOUND.
      CREATE OBJECT o_grid_9022
        EXPORTING
          i_parent = o_conttainer_9022.
    ENDIF.

    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name       = 'USRCD'
      CHANGING
        ct_fieldcat            = lit_catalog
      EXCEPTIONS
        inconsistent_interface = 1
        program_error          = 2
        OTHERS                 = 3.
    IF sy-subrc IS INITIAL.
    ENDIF.

    wa_layout-col_opt = abap_true.
    wa_layout-cwidth_opt = abap_true.

    IF o_grid_9022 IS BOUND AND <fs_data> IS ASSIGNED.
      CALL METHOD o_grid_9022->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lit_catalog
          it_outtab       = <fs_data>.
    ENDIF.
  ELSE.
    MESSAGE 'No Data Found!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_user_list
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM display_user_list .

  DATA: lt_catalog TYPE lvc_t_fcat,
        ls_catalog TYPE lvc_s_fcat.

  CLEAR : gt_users.

  IF o_conttainer_9023 IS BOUND.
    CALL METHOD o_conttainer_9023->free.
    CLEAR o_conttainer_9023.
  ENDIF.

  IF o_grid_9023 IS BOUND.
    CLEAR o_grid_9023.
  ENDIF.

  SELECT bname,
         profile
   FROM ust04
   INTO TABLE @DATA(lt_users)
   WHERE profile LIKE 'S%'.
  IF sy-subrc IS INITIAL.
    SORT lt_users BY bname profile.
    DELETE ADJACENT DUPLICATES FROM lt_users COMPARING bname profile.

    gt_users = lt_users.

    IF o_conttainer_9023 IS NOT BOUND.
      CREATE OBJECT o_conttainer_9023
        EXPORTING
          container_name = 'CC_9023'.
    ENDIF.

    IF o_conttainer_9023 IS BOUND AND o_grid_9023 IS NOT BOUND.
      CREATE OBJECT o_grid_9023
        EXPORTING
          i_parent = o_conttainer_9023.
    ENDIF.

    wa_layout-col_opt    = abap_true.
    wa_layout-cwidth_opt = abap_true.

    ls_catalog-col_pos = 1.
    ls_catalog-fieldname = 'BANME'.
    ls_catalog-reptext = 'User Name'.
    ls_catalog-indx_field = 1.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    ls_catalog-col_pos = 2.
    ls_catalog-indx_field = 2.
    ls_catalog-fieldname = 'PROFILE'.
    ls_catalog-reptext = 'Profile Name'.
    APPEND ls_catalog TO lt_catalog.
    CLEAR ls_catalog.

    IF o_grid_9023 IS BOUND.
      CALL METHOD o_grid_9023->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_users.
    ENDIF.

*    TRY.
*        cl_salv_table=>factory(
*          EXPORTING
*            r_container    = o_conttainer_9023
*            container_name = 'CC_9023'
*          IMPORTING
*            r_salv_table   = gr_table
*          CHANGING
*            t_table        = lt_users ).
*
*        PERFORM enable_layout_setting.
*        PERFORM set_user_columns.
*
*        lr_functions = gr_table->get_functions( ).
*        lr_functions->set_all( ).
*        gr_table->display( ).
*      CATCH cx_salv_msg INTO DATA(lo_error).
*        MESSAGE lo_error->get_text( ) TYPE 'E'.
*    ENDTRY.


  ELSE.
    MESSAGE 'No User Found for SAP ALL Role' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form enable_layout_setting
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM enable_layout_setting .

  DATA layout_settings TYPE REF TO cl_salv_layout.
  DATA layout_key      TYPE salv_s_layout_key.

  layout_settings = gr_table->get_layout( ).

  layout_key-report = sy-repid.
  layout_settings->set_key( layout_key ).

  layout_settings->set_save_restriction(
    if_salv_c_layout=>restrict_none ).

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_user_columns
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM set_user_columns .

  DATA: lr_columns TYPE REF TO cl_salv_columns_table,
        lr_column  TYPE REF TO cl_salv_column.

  lr_columns = gr_table->get_columns( ).
  lr_columns->set_optimize( abap_true ).

  TRY.
      lr_column = lr_columns->get_column( 'BNAME' ).
      lr_column->set_short_text( 'User' ).
      lr_column->set_medium_text( 'User Name' ).
      lr_column->set_long_text( 'User Name' ).

      lr_column = lr_columns->get_column( 'PROFILE' ).
      lr_column->set_short_text( 'Profile' ).
      lr_column->set_medium_text( 'Profile Name' ).
      lr_column->set_long_text( 'Profile Name' ).

    CATCH cx_salv_not_found INTO DATA(lo_error).
      MESSAGE lo_error->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_prod_password_mass
*&---------------------------------------------------------------------*
*& Mass-sets productive passwords from the uploaded Excel file (P_INITPW,
*& columns User ID / Password).
*&
*& Validates the header row, then for each user first sets a temporary
*& password (BAPI_USER_CHANGE with GENERATE_PWD) and then changes it to
*& the productive password from the file via
*& SUSR_USER_CHANGE_PASSWORD_RFC, committing on success and rolling back
*& on error. Status icons / messages are collected in I_OUTTAB_9009 and
*& shown on screen 9009.
*& Side effect: changes user passwords in the database.
*&---------------------------------------------------------------------*
FORM set_prod_password_mass .

  TYPES:
    BEGIN OF lty_usr_pwd,
      user TYPE xubname,
      pwd  TYPE xuncode,
    END OF lty_usr_pwd.

  DATA:
    lv_user      TYPE xubname,

    lwa_bapipwd  TYPE bapipwd,
    lwa_bapipwdx TYPE bapipwdx,
    lwa_return   TYPE bapiret2,

    lit_excel    TYPE STANDARD TABLE OF alsmex_tabline,
    lit_usr_pwd  TYPE STANDARD TABLE OF lty_usr_pwd,
    lit_return   TYPE bapiret2_t.


  CLEAR: i_outtab_9009.

  DATA(lv_length) = strlen( p_initpw ).
  lv_length = lv_length - 4.
  DATA(lv_extn)   = p_initpw+lv_length(4).
  TRANSLATE lv_extn TO UPPER CASE.

  IF lv_extn EQ '.XLS'.
    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_initpw
        i_begin_col             = 1
        i_begin_row             = 1
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = lit_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.

    LOOP AT lit_excel INTO DATA(lwa_excel).

      IF lwa_excel-row = '0002'.
        EXIT.
      ENDIF.

      CASE lwa_excel-col.
        WHEN '0001'.
          IF lwa_excel-value NE 'User ID'.
            APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING FIELD-SYMBOL(<lfs_outtab>).
            <lfs_outtab>-type = '@02@'.
            <lfs_outtab>-msg = 'Please provide valid file'.
            EXIT.
          ENDIF.
        WHEN '0002'.
          IF lwa_excel-value NE 'Password'.
            APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING <lfs_outtab>.
            <lfs_outtab>-type = '@02@'.
            <lfs_outtab>-msg = 'Please provide valid file'.
            EXIT.
          ENDIF.
      ENDCASE.
    ENDLOOP.

  ELSE.

    APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING <lfs_outtab>.
    <lfs_outtab>-type = '@02@'.
    <lfs_outtab>-msg = 'Please provide valid file'.

  ENDIF.

  DELETE lit_excel WHERE row = '0001'.

  LOOP AT lit_excel INTO DATA(lwa_excel1).
    lwa_excel = lwa_excel1.
    AT NEW row.
      APPEND INITIAL LINE TO lit_usr_pwd ASSIGNING FIELD-SYMBOL(<lfs_usr_pwd>).
    ENDAT.
    ASSIGN COMPONENT lwa_excel-col OF STRUCTURE <lfs_usr_pwd> TO FIELD-SYMBOL(<lfs_value>).
    IF <lfs_value> IS ASSIGNED.
      <lfs_value> = lwa_excel-value.
    ENDIF.

    UNASSIGN <lfs_value>.
  ENDLOOP.

  CHECK i_outtab_9009 IS INITIAL.

  LOOP AT lit_usr_pwd INTO DATA(lwa_usr_pwd).

    CLEAR: lv_user, lwa_bapipwd, lwa_return, lit_return.

    lv_user               = lwa_usr_pwd-user.
    lwa_bapipwdx-bapipwd  = abap_true.

    CALL FUNCTION 'BAPI_USER_CHANGE'
      EXPORTING
        username           = lv_user
        passwordx          = lwa_bapipwdx
        generate_pwd       = abap_true
      IMPORTING
        generated_password = lwa_bapipwd
      TABLES
        return             = lit_return.

    LOOP AT lit_return INTO lwa_return.
      IF lwa_return-type = 'E' OR lwa_return-type = 'A'.
        ROLLBACK WORK.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lwa_return-type = 'E' OR lwa_return-type = 'A'.

      APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING <lfs_outtab>.
      <lfs_outtab>-type = '@02@'.
      <lfs_outtab>-user = lv_user.
      MESSAGE ID lwa_return-id TYPE lwa_return-type NUMBER lwa_return-number
        INTO <lfs_outtab>-msg
        WITH lwa_return-message_v1 lwa_return-message_v2
             lwa_return-message_v3 lwa_return-message_v4.

    ELSE.

      CALL FUNCTION 'SUSR_USER_CHANGE_PASSWORD_RFC'
        EXPORTING
          bname                     = lv_user
          password                  = lwa_bapipwd-bapipwd
          new_password              = lwa_usr_pwd-pwd
        IMPORTING
          return                    = lwa_return
        EXCEPTIONS
          change_not_allowed        = 1
          password_not_allowed      = 2
          internal_error            = 3
          canceled_by_user          = 4
          password_attempts_limited = 5
          OTHERS                    = 6.
      IF sy-subrc = 0.
        COMMIT WORK.
        APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING <lfs_outtab>.
        <lfs_outtab>-type = '@01@'.
        <lfs_outtab>-user = lv_user.
        <lfs_outtab>-msg = 'Password successfully changed'.
      ELSE.

        ROLLBACK WORK.
        APPEND INITIAL LINE TO i_outtab_9009 ASSIGNING <lfs_outtab>.
        <lfs_outtab>-type = '@02@'.
        <lfs_outtab>-user = lv_user.
        MESSAGE ID lwa_return-id TYPE lwa_return-type NUMBER lwa_return-number
          INTO <lfs_outtab>-msg
          WITH lwa_return-message_v1 lwa_return-message_v2
               lwa_return-message_v3 lwa_return-message_v4.

      ENDIF.

    ENDIF.

  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form mass_maintain_validate
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM mass_maintain_validate .

  TYPES:
    BEGIN OF lty_extn,
      extn_name(4) TYPE c,
    END OF lty_extn.

  DATA: lv_file        TYPE rlgrap-filename,

        lt_extn        TYPE STANDARD TABLE OF lty_extn,
        lt_excel       TYPE STANDARD TABLE OF alsmex_tabline,
        lt_type        TYPE truxs_t_text_data,
        lt_upload_file TYPE STANDARD TABLE OF ty_upload_file.

  CHECK g_ucomm = 'EXE'.

  CLEAR i_upload_file.

  IF p_file14 IS NOT INITIAL.

    SPLIT p_file14 AT '.' INTO TABLE lt_extn.

    LOOP AT lt_extn INTO DATA(lwa_extn).
    ENDLOOP.

    TRANSLATE lwa_extn-extn_name TO UPPER CASE.
    IF lwa_extn-extn_name = 'XLS' OR
       lwa_extn-extn_name = 'XLSX'.

      lv_file = p_file14.
      CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
        EXPORTING
*         i_line_header        = 'X'
          i_tab_raw_data       = lt_type
          i_filename           = lv_file
        TABLES
          i_tab_converted_data = lt_upload_file
        EXCEPTIONS
          conversion_failed    = 1
          OTHERS               = 2.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.

      IF lt_upload_file IS NOT INITIAL.

        READ TABLE lt_upload_file INTO DATA(lwa_header) INDEX 1.

        IF sy-subrc IS INITIAL.

          IF pa_adi IS NOT INITIAL OR pa_dli IS NOT INITIAL.

            IF lwa_header-field1 = 'Role' AND
               lwa_header-field2 = 'Object' AND
               lwa_header-field3 = 'Field' AND
               lwa_header-field4 = 'Instance' AND
               lwa_header-field5 = 'Value'.
              i_upload_file = lt_upload_file.
            ELSE.
              CLEAR: sy-ucomm, g_ucomm.
              MESSAGE 'Please provide valid file' TYPE 'E'.
            ENDIF.

          ELSEIF pa_din IS NOT INITIAL OR pa_ain IS NOT INITIAL.

            IF lwa_header-field1 = 'Role' AND
               lwa_header-field2 = 'Object' AND
               lwa_header-field3 = 'Instance'.
              i_upload_file = lt_upload_file.
            ELSE.
              CLEAR: sy-ucomm, g_ucomm.
              MESSAGE 'Please provide valid file' TYPE 'E'.
            ENDIF.

          ELSEIF pa_ani IS NOT INITIAL.

            IF lwa_header-field1 = 'Role' AND
               lwa_header-field2 = 'Object' AND
               lwa_header-field3 = 'Field' AND
               lwa_header-field4 = 'Group' AND
               lwa_header-field5 = 'Value'.
              i_upload_file = lt_upload_file.
            ELSE.
              CLEAR: sy-ucomm, g_ucomm.
              MESSAGE 'Please provide valid file' TYPE 'E'.
            ENDIF.

          ELSE.

            IF lwa_header-field1 = 'Role' AND
               lwa_header-field2 = 'Object' AND
               lwa_header-field3 = 'Field' AND
               lwa_header-field4 = 'Value'.
              i_upload_file = lt_upload_file.
            ELSE.
              CLEAR: sy-ucomm, g_ucomm.
              MESSAGE 'Please provide valid file' TYPE 'E'.
            ENDIF.

          ENDIF.

        ELSE.

          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE 'Please provide valid file' TYPE 'E'.

        ENDIF.

      ENDIF.

    ELSE.

      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'The file extension is not Excel' TYPE 'E'.

    ENDIF.

  ELSE.

    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide a filename' TYPE 'E'.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_auth_values
*&---------------------------------------------------------------------*
*& Driver for the mass authorization-value maintenance function.
*&
*& Reads the uploaded Excel file (P_FILE14, columns Role / Object /
*& Field name / Authorization value) and, depending on the selected
*& operation radio buttons (add / delete / deactivate / activate), and
*& whether the change applies to all instances or a specific instance,
*& dispatches to the maintain_add_* / maintain_del_* / maintain_dct_* /
*& maintain_act_* sub-forms. Those apply the change to each role through
*& the PFCG role API (IF_PFCG_ROLE) and commit.
*&   -->  FP_INSTANCE  Flag: process a specific authorization instance
*&                     rather than all instances of the object.
*& Side effect: changes role authorization data in the database.
*&---------------------------------------------------------------------*
FORM maintain_auth_values USING fp_instance TYPE flag.

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            value  TYPE agval,
          END OF lty_auth_val,
          BEGIN OF lty_auth_val1,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            auth   TYPE agauth,
            value  TYPE agval,
          END OF lty_auth_val1,
          BEGIN OF lty_auth_val2,
            role   TYPE agr_name,
            object TYPE xuobject,
            auth   TYPE agauth,
          END OF lty_auth_val2,
          BEGIN OF lty_auth_val3,
            role     TYPE agr_name,
            object   TYPE xuobject,
            field    TYPE agrfield,
            group(3) TYPE n,
            value    TYPE agval,
          END OF lty_auth_val3,
          tt_tpr01 TYPE SORTED TABLE OF tpr01 WITH UNIQUE KEY low high,
          BEGIN OF ty_mod_values,
            object TYPE xuobject,
            field  TYPE xufield,
            varbl  TYPE usorg-varbl,
            action TYPE char01,
            valrep TYPE tt_tpr01,
            val    TYPE tt_tpr01,
          END   OF ty_mod_values.

  DATA : lt_init_excel        TYPE TABLE OF lty_auth_val,
         lt_init_excel1       TYPE TABLE OF lty_auth_val1,
         lt_init_excel2       TYPE TABLE OF lty_auth_val2,
         lt_init_excel3       TYPE TABLE OF lty_auth_val3,
         lt_unique_group      TYPE TABLE OF lty_auth_val3,
         lt_excel             TYPE STANDARD TABLE OF alsmex_tabline,
         lv_com               TYPE i,
         lv_subrc             TYPE sy-subrc,
         lwa_message          TYPE if_spcg_msg_buffer=>ty_messages,
         lt_messages          TYPE if_spcg_msg_buffer=>tt_messages,
         lt_messages1         TYPE if_spcg_msg_buffer=>tt_messages,
         lt_nodes_prefetch    TYPE if_pfcg_role=>tt_node,
         lt_pfcg_role         TYPE if_pfcg_role=>tt_pfcg_role,
         lt_node_root         TYPE if_pfcg_role=>node_tt_root,
         it_mod_values        TYPE TABLE OF ty_mod_values,
         lwa_mod_values       TYPE ty_mod_values,
         lt_change_values     TYPE if_pfcg_role=>node_tt_auth_values,
         lwa_val              TYPE tpr01,
         lt_val               TYPE TABLE OF tpr01,
         lr_mod_values        TYPE REF TO ty_mod_values,
         lr_val               TYPE REF TO tpr01,
         ls_auth_values       TYPE if_pfcg_role=>node_st_auth_values,
         lr_auth_values       TYPE REF TO if_pfcg_role=>node_st_auth_values,
         lt_std_values        TYPE if_pfcg_role=>node_tt_auth_values,
         lv_new_status        TYPE tpr_st_del,
         lv_atleast_on_succes TYPE flag.


  IF p_file14 IS NOT INITIAL.

    IF pa_adi IS NOT INITIAL OR pa_dli IS NOT INITIAL.

      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file14
          i_begin_col             = 1
          i_begin_row             = 2
          i_end_col               = 6
          i_end_row               = 99999
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc IS INITIAL.
      ENDIF.
      lv_subrc = sy-subrc.

    ELSEIF pa_din IS NOT INITIAL OR pa_ain IS NOT INITIAL.

      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file14
          i_begin_col             = 1
          i_begin_row             = 2
          i_end_col               = 3
          i_end_row               = 99999
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc IS INITIAL.
      ENDIF.
      lv_subrc = sy-subrc.

    ELSEIF pa_ani IS NOT INITIAL.

      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file14
          i_begin_col             = 1
          i_begin_row             = 2
          i_end_col               = 5
          i_end_row               = 99999
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc IS INITIAL.
      ENDIF.
      lv_subrc = sy-subrc.

    ELSE.

      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file14
          i_begin_col             = 1
          i_begin_row             = 2
          i_end_col               = 5
          i_end_row               = 99999
        TABLES
          intern                  = lt_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc IS INITIAL.
      ENDIF.
      lv_subrc = sy-subrc.

    ENDIF.


    IF lv_subrc IS INITIAL OR i_upload_file IS NOT INITIAL.

      DELETE i_upload_file INDEX 1.

      LOOP AT i_upload_file INTO DATA(lwa_upload_file).

        IF pa_adi IS NOT INITIAL OR pa_dli IS NOT INITIAL.

          APPEND INITIAL LINE TO lt_init_excel1 ASSIGNING FIELD-SYMBOL(<lfs_data1>).
          <lfs_data1>-role   = lwa_upload_file-field1.
          <lfs_data1>-object = lwa_upload_file-field2.
          <lfs_data1>-field  = lwa_upload_file-field3.
          <lfs_data1>-auth   = lwa_upload_file-field4.
          <lfs_data1>-value  = lwa_upload_file-field5.

        ELSEIF pa_din IS NOT INITIAL OR pa_ain IS NOT INITIAL.

          APPEND INITIAL LINE TO lt_init_excel2 ASSIGNING FIELD-SYMBOL(<lfs_data2>).
          <lfs_data2>-role      = lwa_upload_file-field1.
          <lfs_data2>-object    = lwa_upload_file-field2.
          <lfs_data2>-auth      = lwa_upload_file-field3.

        ELSEIF pa_ani IS NOT INITIAL.

          APPEND INITIAL LINE TO lt_init_excel3 ASSIGNING FIELD-SYMBOL(<lfs_data3>).
          <lfs_data3>-role     = lwa_upload_file-field1.
          <lfs_data3>-object   = lwa_upload_file-field2.
          <lfs_data3>-field    = lwa_upload_file-field3.
          <lfs_data3>-group    = lwa_upload_file-field4.
          <lfs_data3>-value    = lwa_upload_file-field5.

        ELSE.

          APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
          <lfs_data>-role   = lwa_upload_file-field1.
          <lfs_data>-object = lwa_upload_file-field2.
          <lfs_data>-field  = lwa_upload_file-field3.
          <lfs_data>-value  = lwa_upload_file-field4.

        ENDIF.

      ENDLOOP.

      SORT lt_init_excel  BY role object field value.
      SORT lt_init_excel1 BY role object field auth value.
      SORT lt_init_excel2 BY role object auth.
      SORT lt_init_excel3 BY role object group field value.

      lt_unique_group = lt_init_excel3.
      DELETE ADJACENT DUPLICATES FROM lt_unique_group COMPARING role object group.


*** Get Unique Role
      IF pa_adi IS NOT INITIAL OR pa_dli IS NOT INITIAL .
        lt_pfcg_role = VALUE #( FOR lwa_role1 IN lt_init_excel1 ( role = lwa_role1-role ) ).
      ELSEIF pa_din IS NOT INITIAL OR pa_ain IS NOT INITIAL.
        lt_pfcg_role = VALUE #( FOR lwa_role2 IN lt_init_excel2 ( role = lwa_role2-role ) ).
      ELSEIF pa_ani IS NOT INITIAL.
        lt_pfcg_role = VALUE #( FOR lwa_role3 IN lt_init_excel3 ( role = lwa_role3-role ) ).
      ELSE.
        lt_pfcg_role = VALUE #( FOR lwa_role IN lt_init_excel ( role = lwa_role-role ) ).
      ENDIF.

      SORT lt_pfcg_role BY role.
      DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

      APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
      APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
      CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
        EXPORTING
          it_pfcg_role      = lt_pfcg_role
          it_nodes_prefetch = lt_nodes_prefetch
        IMPORTING
          et_node_root      = lt_node_root
          eo_msg_buffer     = DATA(lo_msg_buffer).

*** Populate Message
      PERFORM update_message USING lo_msg_buffer '' ''.

      IF lt_node_root IS NOT INITIAL.
        SORT lt_node_root BY role.

        IF pa_din IS NOT INITIAL OR pa_ain IS NOT INITIAL.

*** Deactivate Object Instance
          LOOP AT lt_init_excel2 INTO DATA(lwa_init_excel2).
            DATA(lv_index2) = sy-tabix - 1.
            READ TABLE lt_init_excel2 INTO DATA(lwa_init_excel2t) INDEX lv_index2.
            IF sy-subrc IS NOT INITIAL.
              CLEAR : lwa_init_excel2t.
            ENDIF.

            TRY.
                IF lwa_init_excel2-role <> lwa_init_excel2t-role.
                  READ TABLE lt_node_root REFERENCE INTO DATA(lwa_node_root)
                    WITH KEY role = lwa_init_excel2-role BINARY SEARCH.
                  IF sy-subrc IS INITIAL.
*** Read Role
                    CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
                      IMPORTING
                        et_auth_auths = DATA(lt_auth_auths)
                        eo_msg_buffer = lo_msg_buffer.

**** Delete Inactive Authorization
                    IF pa_din IS NOT INITIAL.
                      DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.
                    ELSEIF pa_ain IS NOT INITIAL.
                      DELETE lt_auth_auths WHERE st_inactiv IS INITIAL.
                    ENDIF.

*** Populate Message
                    PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.

                  ENDIF.
                ENDIF.

                READ TABLE lt_auth_auths ASSIGNING FIELD-SYMBOL(<lfs_auth_auths>)
                         WITH KEY object = lwa_init_excel2-object
                                  auth   = lwa_init_excel2-auth.
                IF sy-subrc IS INITIAL.
                  IF pa_din IS NOT INITIAL.
                    <lfs_auth_auths>-st_inactiv = abap_true.
                    lv_new_status = abap_true.
                  ELSE.
                    <lfs_auth_auths>-st_inactiv = abap_false.
                    lv_new_status = abap_false.
                  ENDIF.

                  CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_active_auth_status
                    EXPORTING
                      is_auth       = <lfs_auth_auths>
                      iv_new_status = lv_new_status
                    IMPORTING
                      es_auth       = DATA(lt_ex_auth)
                      eo_msg_buffer = lo_msg_buffer.

                  PERFORM update_message_dins USING lo_msg_buffer
                                                    lwa_node_root->role
                                                    lwa_init_excel2-object
                                                    lwa_init_excel2-auth.

                ENDIF.

              CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

                DATA(lv_text) = lo_pfcg_role->get_text( ).
                lwa_message-msgty  = 'E'.
                lwa_message-msgid  = '01'.
                lwa_message-msgno  = '319'.
                lwa_message-msgv1  = lv_text.
                APPEND lwa_message TO lt_messages.

              CATCH cx_pfcg_role_scc4.

            ENDTRY.
          ENDLOOP.

        ELSEIF pa_ani IS NOT INITIAL.

*** Start of Change by Rounak
          LOOP AT lt_init_excel3 INTO DATA(lwa_init_excel3).
*** Clear
            CLEAR: lv_text.
            DATA(lv_index_nxt) = sy-tabix + 1.
            DATA(lv_index_prv) = sy-tabix - 1.
*** Get Next Line Record
            READ TABLE lt_init_excel3 INTO DATA(lwa_init_excel3_nxt) INDEX lv_index_nxt.
            IF sy-subrc IS NOT INITIAL.
              CLEAR : lwa_init_excel3_nxt.
            ENDIF.
*** Get Previous Line Record
            READ TABLE lt_init_excel3 INTO DATA(lwa_init_excel3_prv) INDEX lv_index_prv.
            IF sy-subrc IS NOT INITIAL.
              CLEAR : lwa_init_excel3_prv.
            ENDIF.

*** "AT NEW" role object group
            IF lwa_init_excel3-role   <> lwa_init_excel3_prv-role OR
               lwa_init_excel3-object <> lwa_init_excel3_prv-object OR
               lwa_init_excel3-group  <> lwa_init_excel3_prv-group.

              DATA(lv_object_add_error) = abap_false.

*** Add New Instance
              READ TABLE lt_node_root REFERENCE INTO lwa_node_root
                         WITH KEY role = lwa_init_excel3-role BINARY SEARCH.
              IF sy-subrc IS INITIAL.
                TRY.
                    CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~add_manual_auth
                      EXPORTING
                        iv_object     = lwa_init_excel3-object
                      IMPORTING
                        es_auth_auths = DATA(lwa_auth_auth)
                        eo_msg_buffer = lo_msg_buffer.

                    PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.

                  CATCH cx_pfcg_role INTO lo_pfcg_role.

                    lv_object_add_error = abap_true.

                    lv_text = lo_pfcg_role->get_text( ).
                    lwa_message-msgty  = 'E'.
                    lwa_message-msgid  = '01'.
                    lwa_message-msgno  = '319'.
                    lwa_message-msgv1  = lv_text.
                    APPEND lwa_message TO lt_messages.

                  CATCH cx_pfcg_role_scc4.
                    lv_object_add_error = abap_true.

                ENDTRY.
              ELSE.
                lv_object_add_error = abap_true.
              ENDIF.
            ENDIF.

            IF lv_object_add_error = abap_false.
*** Add Authorization Value
              ls_auth_values-field       = lwa_init_excel3-field.
              ls_auth_values-low         = lwa_init_excel3-value.
              ls_auth_values-change_mode = 'I'.
              APPEND ls_auth_values TO lt_change_values.

*** "AT END OF " Role Object Group
              IF lwa_init_excel3-role   <> lwa_init_excel3_nxt-role OR
                 lwa_init_excel3-object <> lwa_init_excel3_nxt-object OR
                 lwa_init_excel3-group  <> lwa_init_excel3_nxt-group.

                IF lt_change_values IS NOT INITIAL.

                  TRY.
                      CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                        EXPORTING
                          is_auth        = lwa_auth_auth
                          it_auth_values = lt_change_values
                        IMPORTING
                          eo_msg_buffer  = lo_msg_buffer.

                      PERFORM update_message USING lo_msg_buffer lwa_node_root->role lwa_auth_auth-object.

                      CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                        EXPORTING
                          is_auth        = lwa_auth_auth
                        IMPORTING
                          et_auth_values = DATA(lt_auth_values_new_ani)
                          eo_msg_buffer  = lo_msg_buffer.

                      PERFORM update_message1 USING lwa_init_excel3-role lwa_auth_auth-object lt_change_values.

                      lv_atleast_on_succes = abap_true.

                    CATCH cx_pfcg_role INTO lo_pfcg_role.

                      lv_text = lo_pfcg_role->get_text( ).
                      lwa_message-msgty  = 'E'.
                      lwa_message-msgid  = '01'.
                      lwa_message-msgno  = '319'.
                      lwa_message-msgv1  = lv_text.
                      APPEND lwa_message TO lt_messages.

                    CATCH cx_pfcg_role_scc4.

                  ENDTRY.
                ENDIF.
                CLEAR : lt_change_values.
              ENDIF.
            ENDIF.

          ENDLOOP.
*** End of Change by Rounak

*** Start of Change by Rounak
        ELSEIF pa_adi IS NOT INITIAL.

          SORT lt_init_excel1 BY role object auth field value.
          DELETE ADJACENT DUPLICATES FROM lt_init_excel1 COMPARING
          role object auth field.

          LOOP AT lt_pfcg_role INTO DATA(lwa_pfcg_role).

            READ TABLE lt_node_root REFERENCE INTO lwa_node_root
            WITH KEY role = lwa_pfcg_role-role.
            IF sy-subrc IS INITIAL.

              CLEAR: lt_auth_auths, lo_msg_buffer.

              CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
                IMPORTING
                  et_auth_auths = lt_auth_auths
                  eo_msg_buffer = lo_msg_buffer.

              DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.

              READ TABLE lt_init_excel1 TRANSPORTING NO FIELDS
              WITH KEY role = lwa_pfcg_role-role.
              IF sy-subrc IS INITIAL.

                DATA(lv_role_index) = sy-tabix.

                LOOP AT lt_init_excel1 INTO DATA(lwa_single_role_data) FROM lv_role_index.

                  IF lwa_single_role_data-role EQ lwa_pfcg_role-role.

                    READ TABLE lt_auth_auths INTO DATA(lt_each_object_line)
                    WITH KEY object = lwa_single_role_data-object
                             auth = lwa_single_role_data-auth.

                    IF sy-subrc IS INITIAL.

                      ls_auth_values-field       = lwa_single_role_data-field.
                      ls_auth_values-low         = lwa_single_role_data-value.
                      ls_auth_values-change_mode = 'I'.
                      APPEND ls_auth_values TO lt_change_values.

                      TRY.
                          CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                            EXPORTING
                              is_auth        = lt_each_object_line
                              it_auth_values = lt_change_values
                            IMPORTING
                              eo_msg_buffer  = lo_msg_buffer.

                          CLEAR lt_change_values.

                          PERFORM update_message USING lo_msg_buffer lwa_node_root->role lwa_auth_auth-object.

                        CATCH cx_pfcg_role INTO lo_pfcg_role.

                          lv_text = lo_pfcg_role->get_text( ).
                          lwa_message-msgty  = 'E'.
                          lwa_message-msgid  = '01'.
                          lwa_message-msgno  = '319'.
                          lwa_message-msgv1  = lv_text.
                          APPEND lwa_message TO lt_messages.

                        CATCH cx_pfcg_role_scc4.

                      ENDTRY.

                    ENDIF.

                  ELSE.

                    "Go to the next Role
                    EXIT.

                  ENDIF.

                ENDLOOP.

              ENDIF.

            ENDIF.

          ENDLOOP.

        ELSE.

          IF fp_instance IS NOT INITIAL.
            LOOP AT lt_init_excel1 INTO DATA(lwa_init_excel_t).
              APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_init_excel2>).
              <lfs_init_excel2>-role    = lwa_init_excel_t-role.
              <lfs_init_excel2>-object  = lwa_init_excel_t-object.
              <lfs_init_excel2>-field   = lwa_init_excel_t-field.
              <lfs_init_excel2>-value   = lwa_init_excel_t-value.
            ENDLOOP.
          ENDIF.

          LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
            DATA(lv_index) = sy-tabix + 1.
            READ TABLE lt_init_excel INTO DATA(lwa_init_excel1) INDEX lv_index.
            IF sy-subrc IS NOT INITIAL.
              CLEAR : lwa_init_excel1.
            ENDIF.

            TRY .
                lwa_val-low = lwa_init_excel-value.
                APPEND lwa_val TO lt_val.
                CLEAR : lwa_val.

                IF lwa_init_excel-role <> lwa_init_excel1-role OR lwa_init_excel-object
                  <> lwa_init_excel1-object OR lwa_init_excel-field <> lwa_init_excel1-field.

                  lwa_mod_values-object = lwa_init_excel-object.
                  lwa_mod_values-field  = lwa_init_excel-field.
                  lwa_mod_values-valrep = VALUE #( ( low = '*' ) ).
                  lwa_mod_values-val    = lt_val.

                  APPEND lwa_mod_values TO it_mod_values.
                  CLEAR : lwa_mod_values,lt_val.

                  IF lwa_init_excel-role <> lwa_init_excel1-role .
                    READ TABLE lt_node_root REFERENCE INTO lwa_node_root
                    WITH KEY role = lwa_init_excel-role BINARY SEARCH.
                    IF sy-subrc IS INITIAL.
                      IF pa_add EQ abap_true OR pa_del EQ abap_true OR pa_adi EQ abap_true OR pa_dli EQ abap_true OR pa_din EQ abap_true.

*** Read authorizations of current role
                        CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
                          IMPORTING
                            et_auth_auths = lt_auth_auths
                            eo_msg_buffer = lo_msg_buffer.
**** Delete Inactive Authorization
                        DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.
*** Populate Message
                        PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.
*** Add New Instance if the instance is not available
                        IF pa_add EQ abap_true OR pa_adi EQ abap_true.
                          LOOP AT it_mod_values INTO lwa_mod_values .
                            READ TABLE lt_auth_auths TRANSPORTING NO FIELDS WITH KEY object = lwa_mod_values-object.
                            IF sy-subrc IS NOT INITIAL.
                              CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~add_manual_auth
                                EXPORTING
                                  iv_object     = lwa_mod_values-object
                                IMPORTING
                                  es_auth_auths = DATA(lwa_auth_auth1)
                                  eo_msg_buffer = lo_msg_buffer.

                              PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.

                              APPEND lwa_auth_auth1 TO lt_auth_auths.
                              CLEAR : lwa_auth_auth1.

                            ENDIF.
                          ENDLOOP.
                        ENDIF.

                      ELSEIF pa_ins EQ abap_true.

                        DATA(it_mod_values1) = it_mod_values.
                        SORT it_mod_values1 BY object.
                        DELETE ADJACENT DUPLICATES FROM it_mod_values1 COMPARING object.
*** Add New Instance
                        LOOP AT it_mod_values1 INTO lwa_mod_values.
                          CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~add_manual_auth
                            EXPORTING
                              iv_object     = lwa_mod_values-object
                            IMPORTING
                              es_auth_auths = lwa_auth_auth1
                              eo_msg_buffer = lo_msg_buffer.

                          PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.
*
                          APPEND lwa_auth_auth1 TO lt_auth_auths.
                          CLEAR : lwa_auth_auth1.
                        ENDLOOP.

                      ENDIF.

**********************************************************************
*Additional code can be written to filter out the instance
**********************************************************************

                      LOOP AT lt_auth_auths REFERENCE INTO DATA(lwa_auth_auths).

                        IF fp_instance IS NOT INITIAL.
                          READ TABLE lt_init_excel1 TRANSPORTING NO FIELDS WITH KEY
                          role = lwa_node_root->role
                          object = lwa_auth_auths->object
                          auth = lwa_auth_auths->auth.
                          IF sy-subrc IS NOT INITIAL.
                            CONTINUE.
                          ENDIF.

                        ENDIF.

                        READ TABLE it_mod_values WITH KEY object = lwa_auth_auths->object TRANSPORTING NO FIELDS.
                        IF sy-subrc NE 0.
                          CONTINUE.
                        ENDIF.
                        " Read current values for auth
                        CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                          EXPORTING
                            is_auth        = lwa_auth_auths->*
                          IMPORTING
                            et_auth_values = DATA(lt_auth_values_old)
                            eo_msg_buffer  = lo_msg_buffer.

                        CLEAR: lt_change_values.

                        LOOP AT it_mod_values REFERENCE INTO lr_mod_values WHERE object = lwa_auth_auths->object.

                          IF pa_add EQ abap_true OR pa_ins EQ abap_true OR pa_adi EQ abap_true.
                            LOOP AT lr_mod_values->val REFERENCE INTO lr_val.
                              " Check for '*' first
                              READ TABLE lt_auth_values_old
                                WITH KEY field = lr_mod_values->field
                                         low   = '*'
                                TRANSPORTING NO FIELDS BINARY SEARCH.
                              IF sy-subrc EQ 0.
                                CONTINUE.
                              ENDIF.
                              " Check value
                              READ TABLE lt_auth_values_old
                                WITH KEY field = lr_mod_values->field
                                         low   = lr_val->low
                                         high  = lr_val->high
                                TRANSPORTING NO FIELDS BINARY SEARCH.
                              IF sy-subrc NE 0.
                                ls_auth_values-field       = lr_mod_values->field.
                                ls_auth_values-low         = lr_val->low.
                                ls_auth_values-high        = lr_val->high.
                                ls_auth_values-change_mode = 'I'.
                                APPEND ls_auth_values TO lt_change_values.
                              ENDIF.
                            ENDLOOP.
                          ELSEIF pa_del EQ abap_true OR pa_dli EQ abap_true.
                            LOOP AT lr_mod_values->val REFERENCE INTO lr_val.
                              READ TABLE lt_auth_values_old
                                WITH KEY field = lr_mod_values->field
                                         low   = lr_val->low
                                         high  = lr_val->high
                                TRANSPORTING NO FIELDS BINARY SEARCH.
                              IF sy-subrc EQ 0.
                                ls_auth_values-field       = lr_mod_values->field.
                                ls_auth_values-low         = lr_val->low.
                                ls_auth_values-high        = lr_val->high.
                                ls_auth_values-change_mode = 'D'.
                                APPEND ls_auth_values TO lt_change_values.
                              ENDIF.
                            ENDLOOP.
                          ENDIF.
                        ENDLOOP.
                        IF lt_change_values IS NOT INITIAL.
                          CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                            EXPORTING
                              is_auth        = lwa_auth_auths->*
                              it_auth_values = lt_change_values
                            IMPORTING
                              eo_msg_buffer  = lo_msg_buffer.

                          PERFORM update_message USING lo_msg_buffer lwa_node_root->role lwa_auth_auths->object.

                          CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                            EXPORTING
                              is_auth        = lwa_auth_auths->*
                            IMPORTING
                              et_auth_values = DATA(lt_auth_values_new)
                              eo_msg_buffer  = lo_msg_buffer.

                          PERFORM update_message1 USING lwa_init_excel-role lwa_auth_auths->object lt_change_values.

                        ELSE.
                          lt_auth_values_new = lt_auth_values_old.
                        ENDIF.
                      ENDLOOP.

                      CLEAR : it_mod_values.
                    ENDIF.
                  ENDIF.
                ENDIF.

              CATCH cx_pfcg_role INTO lo_pfcg_role.

                lv_text = lo_pfcg_role->get_text( ).
                lwa_message-msgty  = 'E'.
                lwa_message-msgid  = '01'.
                lwa_message-msgno  = '319'.
                lwa_message-msgv1  = lv_text.
                APPEND lwa_message TO lt_messages.

              CATCH cx_pfcg_role_scc4.

            ENDTRY.

          ENDLOOP.
        ENDIF.

        IF pa_ani IS INITIAL OR lv_atleast_on_succes IS NOT INITIAL..
          CALL METHOD cl_pfcg_role_factory=>do_check
            IMPORTING
              ev_rejected   = DATA(lv_rejected)
              eo_msg_buffer = lo_msg_buffer.
          CLEAR lt_messages.

          lt_messages1 = lo_msg_buffer->get_messages( ).
          APPEND LINES OF lt_messages1 TO lt_messages.
          IF lv_rejected EQ abap_false.

            CALL METHOD cl_pfcg_role_factory=>do_save
              EXPORTING
                iv_update_task = abap_false
              IMPORTING
                ev_rejected    = lv_rejected
                eo_msg_buffer  = lo_msg_buffer.

            CLEAR: lt_messages.
            lt_messages = lo_msg_buffer->get_messages( ).
            APPEND LINES OF lt_messages TO lt_messages1.

            COMMIT WORK.
          ELSE.
            ROLLBACK WORK.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form update_message
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LO_MSG_BUFFER
*&      <-- GT_AUTH_VAL
*&---------------------------------------------------------------------*
FORM update_message  USING  io_msg_buffer TYPE REF TO if_spcg_msg_buffer
                            iv_role       TYPE agr_name
                            iv_object     TYPE xuobject.

  DATA : lt_message   TYPE if_spcg_msg_buffer=>tt_messages,
         lwa_auth_val TYPE ty_auth_val,
         lt_auth_val  TYPE TABLE OF ty_auth_val.

  IF iv_role IS INITIAL.
    lt_message = io_msg_buffer->get_messages( ).
  ELSE.
    lt_message = io_msg_buffer->get_messages( iv_role = iv_role ).
  ENDIF.

  LOOP AT lt_message INTO DATA(lwa_message).

    lwa_auth_val-role = lwa_message-role.
    IF lwa_message-msgty = 'S'.
      lwa_auth_val-type = 'Success'.
    ELSEIF lwa_message-msgty = 'E'.
      lwa_auth_val-type = 'Error'.
    ELSE.
      lwa_auth_val-type = lwa_message-msgty.
    ENDIF.
    lwa_auth_val-message = lwa_message-message.
    lwa_auth_val-object  = iv_object.

    APPEND lwa_auth_val TO lt_auth_val.
    CLEAR : lwa_auth_val.

  ENDLOOP.

  IF lt_auth_val IS NOT INITIAL.
    APPEND LINES OF lt_auth_val TO gt_auth_val.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form update_message1
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LWA_INIT_EXCEL_ROLE
*&      --> LWA_AUTH_AUTHS_>OBJECT
*&      --> LT_CHANGE_VALUES
*&---------------------------------------------------------------------*
FORM update_message1  USING   iv_role          TYPE agr_name
                              iv_object        TYPE xuobject
                              it_change_values TYPE if_pfcg_role=>node_tt_auth_values.

  DATA : lwa_auth_val TYPE ty_auth_val,
         lt_auth_val  TYPE TABLE OF ty_auth_val.

  LOOP AT it_change_values INTO DATA(lwa_change_values).

    lwa_auth_val-role = iv_role.
    lwa_auth_val-object = iv_object.
    lwa_auth_val-field  = lwa_change_values-field.
    lwa_auth_val-value  = lwa_change_values-low.
    lwa_auth_val-type   = 'Success'.
*    lwa_auth_val-action = lwa_change_values-change_mode.
    IF lwa_change_values-change_mode = 'I'.
      lwa_auth_val-message = |Value { lwa_change_values-low } added to object { iv_object } in Role { iv_role }|.
    ELSEIF lwa_change_values-change_mode = 'D'.
      lwa_auth_val-message = |Value { lwa_change_values-low } removed from object { iv_object } in Role { iv_role }|.
    ENDIF.

    APPEND lwa_auth_val TO lt_auth_val.
    CLEAR : lwa_auth_val.

  ENDLOOP.

  IF lt_auth_val IS NOT INITIAL.
    APPEND LINES OF lt_auth_val TO gt_auth_val.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9009
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9009 .

  DATA: lwa_layout TYPE lvc_s_layo,
        lwa_fcat   TYPE lvc_s_fcat,
        lit_fcat   TYPE lvc_t_fcat.

  IF o_conttainer_9009 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9009
      EXPORTING
        container_name = 'CC_9009'.
  ENDIF.

  IF o_conttainer_9009 IS BOUND AND o_grid_9009 IS NOT BOUND.
    CREATE OBJECT o_grid_9009
      EXPORTING
        i_parent = o_conttainer_9009.
  ENDIF.

  lwa_layout-col_opt    = abap_true.
  lwa_layout-cwidth_opt = abap_true.

  lwa_fcat-col_pos = 1.
  lwa_fcat-fieldname = 'TYPE'.
  lwa_fcat-reptext = 'Type'.
  APPEND lwa_fcat TO lit_fcat.
  CLEAR lwa_fcat.

  lwa_fcat-col_pos = 2.
  lwa_fcat-fieldname = 'USER'.
  lwa_fcat-reptext = 'User ID'.
  APPEND lwa_fcat TO lit_fcat.
  CLEAR lwa_fcat.

  lwa_fcat-col_pos = 3.
  lwa_fcat-fieldname = 'MSG'.
  lwa_fcat-reptext = 'Message'.
  APPEND lwa_fcat TO lit_fcat.
  CLEAR lwa_fcat.

  IF o_grid_9009 IS BOUND.
    IF g_9009_first IS INITIAL.
      g_9009_first = abap_true.
      CALL METHOD o_grid_9009->set_table_for_first_display
        EXPORTING
          is_layout       = lwa_layout
        CHANGING
          it_fieldcatalog = lit_fcat
          it_outtab       = i_outtab_9009.
    ELSE.
      o_grid_9009->refresh_table_display( ).
    ENDIF.
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9024
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9024 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  IF o_conttainer_9024 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9024
      EXPORTING
        container_name = 'CC_9024'.
  ENDIF.

  IF o_conttainer_9024 IS BOUND AND o_grid_9024 IS NOT BOUND.
    CREATE OBJECT o_grid_9024
      EXPORTING
        i_parent = o_conttainer_9024.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-cwidth_opt = abap_true.

  ls_catalog-col_pos = 1.
  ls_catalog-fieldname = 'ROLE'.
  ls_catalog-reptext = 'Role Name'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 2.
  ls_catalog-fieldname = 'OBJECT'.
  ls_catalog-reptext = 'Object'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 3.
  ls_catalog-fieldname = 'FIELD'.
  ls_catalog-reptext = 'Field'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 4.
  ls_catalog-fieldname = 'VALUE'.
  ls_catalog-reptext = 'Value'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 5.
  ls_catalog-fieldname = 'TYPE'.
  ls_catalog-reptext = 'Message Type'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 6.
  ls_catalog-fieldname = 'MESSAGE'.
  ls_catalog-reptext = 'Message'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9024 IS BOUND.
    IF g_9024_first IS INITIAL.
      g_9024_first = abap_true.
      CALL METHOD o_grid_9024->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_auth_val.
    ELSE.
      o_grid_9024->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9025
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9025 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  IF o_conttainer_9025 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9025
      EXPORTING
        container_name = 'CC_9025'.
  ENDIF.

  IF o_conttainer_9025 IS BOUND AND o_grid_9025 IS NOT BOUND.
    CREATE OBJECT o_grid_9025
      EXPORTING
        i_parent = o_conttainer_9025.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-cwidth_opt = abap_true.

  ls_catalog-col_pos = 1.
  ls_catalog-fieldname = 'ROLE'.
  ls_catalog-reptext = 'Role Name'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 2.
  ls_catalog-fieldname = 'PARENT'.
  ls_catalog-reptext = 'Parent Role Name'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 3.
  ls_catalog-fieldname = 'OBJECT'.
  ls_catalog-reptext = 'Object'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 4.
  ls_catalog-fieldname = 'AUTH'.
  ls_catalog-reptext = 'Authorization'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 5.
  ls_catalog-fieldname = 'FIELD'.
  ls_catalog-reptext = 'Field'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 6.
  ls_catalog-fieldname = 'LOW'.
  ls_catalog-reptext = 'Auth value Low'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 7.
  ls_catalog-fieldname = 'HIGH'.
  ls_catalog-reptext = 'Auth value High'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 8.
  ls_catalog-fieldname = 'STATUS'.
  ls_catalog-reptext = 'Status'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9025 IS BOUND.
    IF g_9025_first IS INITIAL.
      g_9025_first = abap_true.
      CALL METHOD o_grid_9025->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_derive_role.
    ELSE.
      o_grid_9025->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form direct_change
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM direct_change.

  DATA : lt_child_role   TYPE RANGE OF agr_name,
         lt_parent_role  TYPE RANGE OF agr_name,
         lwa_derive_role TYPE ty_derive_role.

  SELECT agr_name,
         parent_agr
  FROM agr_define
  WHERE agr_name IN @so_agr
  AND parent_agr IS NOT INITIAL
  INTO TABLE @DATA(lt_agr_define).
  IF sy-subrc IS INITIAL.
    SORT lt_agr_define BY agr_name.
    lt_child_role = VALUE #( FOR lwa_crole IN lt_agr_define
                    ( sign = 'I' option = 'EQ' low = lwa_crole-agr_name ) ).
    lt_parent_role = VALUE #( FOR lwa_prole IN lt_agr_define
                     ( sign = 'I' option = 'EQ' low = lwa_prole-parent_agr ) ).
  ENDIF.

  SORT lt_child_role BY low.
  DELETE ADJACENT DUPLICATES FROM lt_child_role COMPARING low.
  SORT lt_parent_role BY low.
  DELETE ADJACENT DUPLICATES FROM lt_parent_role COMPARING low.

  SELECT agr_name,
         object,
         auth,
         field,
         low,
         high,
         deleted
  FROM agr_1251
  WHERE agr_name IN @lt_child_role
  AND deleted IS INITIAL
  INTO TABLE @DATA(lt_agr_1251c).
  IF sy-subrc IS INITIAL.
    SORT lt_agr_1251c BY agr_name object field low high.
  ENDIF.

  SELECT agr_name,
         object,
         auth,
         field,
         low,
         high
  FROM agr_1251
  WHERE agr_name IN @lt_parent_role
  AND deleted IS INITIAL
  INTO TABLE @DATA(lt_agr_1251p).
  IF sy-subrc IS INITIAL.
    SORT lt_agr_1251p BY agr_name object field low high.
  ENDIF.

  LOOP AT lt_agr_1251c ASSIGNING FIELD-SYMBOL(<lfs_agr_c>).
    READ TABLE lt_agr_define INTO DATA(lwa_agr_define) WITH KEY
               agr_name = <lfs_agr_c>-agr_name BINARY SEARCH.
    IF sy-subrc IS INITIAL.
      READ TABLE lt_agr_1251p ASSIGNING FIELD-SYMBOL(<lfs_agr_1251_p>) WITH KEY
                 agr_name = lwa_agr_define-parent_agr
                 object = <lfs_agr_c>-object
                 field = <lfs_agr_c>-field
                 low = <lfs_agr_c>-low
                 high = <lfs_agr_c>-high BINARY SEARCH.
      IF sy-subrc IS NOT INITIAL.
        lwa_derive_role-role   = <lfs_agr_c>-agr_name.
        lwa_derive_role-parent = lwa_agr_define-parent_agr.
        lwa_derive_role-object = <lfs_agr_c>-object.
        lwa_derive_role-auth   = <lfs_agr_c>-auth.
        lwa_derive_role-field  = <lfs_agr_c>-field.
        lwa_derive_role-low    = <lfs_agr_c>-low.
        lwa_derive_role-high   = <lfs_agr_c>-high.
        lwa_derive_role-status = 'Present in Child Role'.

        APPEND lwa_derive_role TO gt_derive_role.
        CLEAR : lwa_derive_role.
      ENDIF.
    ENDIF.
  ENDLOOP.

  SORT lt_agr_define BY parent_agr.

  LOOP AT lt_agr_1251p INTO DATA(lwa_agr_p).

    READ TABLE lt_agr_define INTO lwa_agr_define WITH KEY
               parent_agr = lwa_agr_p-agr_name BINARY SEARCH.
    IF sy-subrc IS INITIAL.
      DATA(lv_index) = sy-tabix.
    ENDIF.

    LOOP AT lt_agr_define INTO lwa_agr_define FROM lv_index.

      IF lwa_agr_p-agr_name <> lwa_agr_define-parent_agr.
        EXIT.
      ENDIF.

      READ TABLE lt_agr_1251c INTO DATA(lwa_agr_c) WITH KEY agr_name = lwa_agr_define-agr_name
                 object = lwa_agr_p-object
                 field = lwa_agr_p-field
                 low = lwa_agr_p-low
                 high = lwa_agr_p-high BINARY SEARCH.
      IF sy-subrc IS NOT INITIAL.

        lwa_derive_role-role   = lwa_agr_define-agr_name.
        lwa_derive_role-parent = lwa_agr_define-parent_agr.
        lwa_derive_role-object = lwa_agr_p-object.
        lwa_derive_role-auth   = lwa_agr_p-auth.
        lwa_derive_role-field  = lwa_agr_p-field.
        lwa_derive_role-low    = lwa_agr_p-low.
        lwa_derive_role-high   = lwa_agr_p-high.
        lwa_derive_role-status = 'Not present in Child Role'.

        APPEND lwa_derive_role TO gt_derive_role.
        CLEAR : lwa_derive_role.

      ENDIF.
    ENDLOOP.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9026
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9026 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  IF o_conttainer_9026 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9026
      EXPORTING
        container_name = 'CC_9026'.
  ENDIF.

  IF o_conttainer_9026 IS BOUND AND o_grid_9026 IS NOT BOUND.
    CREATE OBJECT o_grid_9026
      EXPORTING
        i_parent = o_conttainer_9026.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-cwidth_opt = abap_true.

  ls_catalog-col_pos = 1.
  ls_catalog-fieldname = 'ROLE'.
  ls_catalog-reptext = 'Role Name'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 2.
  ls_catalog-fieldname = 'OBJECT'.
  ls_catalog-reptext = 'Object'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 3.
  ls_catalog-fieldname = 'FIELD'.
  ls_catalog-reptext = 'Field'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 4.
  ls_catalog-fieldname = 'LOW'.
  ls_catalog-reptext = 'Auth value Low'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-col_pos = 5.
  ls_catalog-fieldname = 'HIGH'.
  ls_catalog-reptext = 'Auth value High'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9026 IS BOUND.
    IF g_9026_first IS INITIAL.
      g_9026_first = abap_true.
      CALL METHOD o_grid_9026->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_org_field.
    ELSE.
      o_grid_9026->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form org_field_change
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM org_field_change .

  SELECT field
  FROM usorg
  INTO TABLE @DATA(lit_usorg)
  ORDER BY field.
  IF sy-subrc IS INITIAL.
    SELECT agr_name,
           object,
           field,
           low,
           high
    FROM agr_1251
    FOR ALL ENTRIES IN @lit_usorg
    WHERE field = @lit_usorg-field
    AND modified = 'M'
    AND agr_name IN @so_agr1
    INTO TABLE @DATA(lit_agr_1251).
    IF sy-subrc IS INITIAL.
      SORT lit_agr_1251 BY agr_name object field low high.
    ENDIF.
  ENDIF.

  IF lit_agr_1251 IS NOT INITIAL.
    gt_org_field = VALUE #( FOR lwa_agr_1251 IN lit_agr_1251
                          ( role = lwa_agr_1251-agr_name object = lwa_agr_1251-object
                            field = lwa_agr_1251-field low = lwa_agr_1251-low
                            high = lwa_agr_1251-high ) ).
  ENDIF.

ENDFORM.

FORM show_result_9027.

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  IF o_conttainer_9027 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9027
      EXPORTING
        container_name = 'CC_9027'.
  ENDIF.

  IF o_conttainer_9027 IS BOUND AND o_grid_9027 IS NOT BOUND.
    CREATE OBJECT o_grid_9027
      EXPORTING
        i_parent = o_conttainer_9027.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'ICON'.
  ls_catalog-key       = abap_true.
  ls_catalog-outputlen  = 2.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname  = 'FUSER'.
  ls_catalog-reptext    = 'From User'.
  ls_catalog-outputlen  = 15.
  ls_catalog-key        = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname  = 'TUSER'.
  ls_catalog-reptext    = 'New User'.
  ls_catalog-outputlen  = 15.
  ls_catalog-key        = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname  = 'MESG'.
  ls_catalog-reptext    = 'Message'.
  ls_catalog-outputlen  = 50.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.


  IF o_grid_9027 IS BOUND.
    IF g_9027_first IS INITIAL.
      g_9027_first = abap_true.
      CALL METHOD o_grid_9027->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_outtab_9027.
    ELSE.
      o_grid_9027->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDFORM.

FORM show_result_9028.

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  IF o_conttainer_9028 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9028
      EXPORTING
        container_name = 'CC_9028'.
  ENDIF.

  IF o_conttainer_9028 IS BOUND AND o_grid_9028 IS NOT BOUND.
    CREATE OBJECT o_grid_9028
      EXPORTING
        i_parent = o_conttainer_9028.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname  = 'USER'.
  ls_catalog-reptext    = 'User Name'.
  ls_catalog-col_opt    = 'A'.
  ls_catalog-key        = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname  = 'ROLE'.
  ls_catalog-reptext    = 'Role Name'.
  ls_catalog-col_opt    = 'A'.
  ls_catalog-key        = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'PROFILE'.
  ls_catalog-reptext = 'Profile Name'.
  ls_catalog-col_opt    = 'A'.
  ls_catalog-key        = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ADATE'.
  ls_catalog-reptext = 'Assigned On'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ATIME'.
  ls_catalog-reptext = 'Assigned At'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'AERNAM'.
  ls_catalog-reptext = 'Assigned By'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'DURATION'.
  ls_catalog-reptext = 'Access Duration'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'DDATE'.
  ls_catalog-reptext = 'Removed On'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'DTIME'.
  ls_catalog-reptext = 'Removed At'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'DERNAM'.
  ls_catalog-reptext = 'Removed By'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ATCODE'.
  ls_catalog-reptext = 'Added using Tcode'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'DTCODE'.
  ls_catalog-reptext = 'Deleted using TCode'.
  ls_catalog-col_opt    = 'A'.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.


  IF o_grid_9028 IS BOUND.
    IF g_9028_first IS INITIAL.
      g_9028_first = abap_true.
      CALL METHOD o_grid_9028->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_outtab_9028.
    ELSE.
      o_grid_9028->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9028
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9028.

  TYPES:
    BEGIN OF lty_cdata,
      bname     TYPE xubname,
      modda     TYPE xumoddate,
      modti     TYPE xumodtime,
      modbe     TYPE xumodifier,
      action    TYPE char100,
      old_val   TYPE cdfldvalo,
      new_val   TYPE cdfldvaln,
      tcode     TYPE tcode,
      agr_fdate TYPE suid_change_from_dat,
      timestamp TYPE timestamp,
    END OF lty_cdata,

    BEGIN OF lty_profile,
      profile TYPE xuprofile,
    END OF lty_profile.



  DATA:
    lv_fdate        TYPE cddatum,
    lv_tdate        TYPE cddatum,
    lv_enddate      TYPE cddatum,
    lv_endtime      TYPE cduzeit,
    lv_ftime        TYPE cduzeit VALUE '000000',
    lv_ttime        TYPE cduzeit VALUE '235959',
    lv_seconds      TYPE p DECIMALS 0,
    lv_timestamp    TYPE timestamp,
    lv_second       TYPE i,
    lv_dif_hrs      TYPE i,
    lv_dif_min      TYPE i,
    lv_dif_sec      TYPE i,

    li_profile      TYPE TABLE OF lty_profile,
    li_cdred_output TYPE TABLE OF usrcd,
    li_cdata_add    TYPE TABLE OF lty_cdata,
    li_cdata_del    TYPE TABLE OF lty_cdata.

  CASE abap_true.
    WHEN lmonth.
      CALL FUNCTION 'OIL_LAST_DAY_OF_PREVIOUS_MONTH'
        EXPORTING
          i_date_old = sy-datum
        IMPORTING
          e_date_new = lv_tdate.
      lv_fdate = lv_tdate.
      lv_fdate+6(2) = '01'.

    WHEN cmonth.
      lv_tdate = sy-datum.
      lv_fdate = lv_tdate.
      lv_fdate+6(2) = '01'.

    WHEN lweek.
      lv_fdate = sy-datum.
      SUBTRACT 7 FROM lv_fdate.
      CALL FUNCTION 'GET_WEEK_INFO_BASED_ON_DATE'
        EXPORTING
          date   = lv_fdate
        IMPORTING
          monday = lv_fdate
          sunday = lv_tdate.

    WHEN cweek.
      CALL FUNCTION 'GET_WEEK_INFO_BASED_ON_DATE'
        IMPORTING
          monday = lv_fdate
          sunday = lv_tdate.

    WHEN yesterday.
      lv_tdate = sy-datum - 1.
      lv_fdate = sy-datum - 1.

    WHEN today.
      lv_tdate = sy-datum.
      lv_fdate = sy-datum.

    WHEN custom.
      lv_tdate = date2.
      lv_fdate = date1.
  ENDCASE.

  lv_seconds = hrs * 3600.

  CLEAR: li_cdred_output, li_cdata_add, li_cdata_del.
  CALL FUNCTION 'SUSR_CHANGE_DOC_USERS'
    EXPORTING
      iv_fdate        = lv_fdate
      iv_tdate        = lv_tdate
      iv_ftime        = lv_ftime
      iv_ttime        = lv_ttime
      iv_prof_ass     = abap_true
      iv_prof_del     = abap_true
    IMPORTING
      et_cdred_output = li_cdred_output.

  LOOP AT li_cdred_output INTO DATA(lw_cdred_output).
    APPEND INITIAL LINE TO li_cdata_add ASSIGNING FIELD-SYMBOL(<lfs_cdata>).
    MOVE-CORRESPONDING lw_cdred_output TO <lfs_cdata>.
    <lfs_cdata>-timestamp = |{ lw_cdred_output-modda }{ lw_cdred_output-modti }|.

    APPEND INITIAL LINE TO li_profile ASSIGNING FIELD-SYMBOL(<lfs_profile>).
    <lfs_profile>-profile = lw_cdred_output-new_val.

  ENDLOOP.

  SORT li_profile.
  DELETE ADJACENT DUPLICATES FROM li_profile.
  DELETE li_profile WHERE profile IS INITIAL.
  IF li_profile IS NOT INITIAL.
    SELECT *
      FROM agr_1016
      FOR ALL ENTRIES IN @li_profile
      WHERE profile = @li_profile-profile
    INTO TABLE @DATA(li_agr_prof).
    IF sy-subrc IS INITIAL.
      SORT li_agr_prof BY profile.
    ENDIF.
  ENDIF.

  li_cdata_del = li_cdata_add.

  DELETE li_cdata_add WHERE action NE 'Profile added'.
  DELETE li_cdata_del WHERE action NE 'Profile deleted'.

  IF li_cdata_del IS NOT INITIAL.
    LOOP AT li_cdata_add INTO DATA(lw_cdata_add).

      CALL FUNCTION 'C14Z_CALC_DATE_TIME'
        EXPORTING
          i_add_seconds = lv_seconds
          i_uzeit       = lw_cdata_add-modti
          i_datum       = lw_cdata_add-modda
        IMPORTING
          e_datum       = lv_enddate
          e_uzeit       = lv_endtime.

      lv_timestamp = |{ lv_enddate }{ lv_endtime }|.

      SELECT SINGLE *
        FROM @li_cdata_del AS deleted
        WHERE bname = @lw_cdata_add-bname
          AND ( timestamp LE @lv_timestamp AND timestamp GE @lw_cdata_add-timestamp )
          AND old_val = @lw_cdata_add-new_val
        INTO @DATA(lw_deleted_profile).

      IF sy-subrc IS INITIAL.
        APPEND INITIAL LINE TO gt_outtab_9028 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9028>).
        <lfs_outtab_9028>-user    = lw_cdata_add-bname.
        <lfs_outtab_9028>-profile = lw_cdata_add-new_val.
        <lfs_outtab_9028>-agr_fdate = lw_cdata_add-agr_fdate.
        <lfs_outtab_9028>-adate   = lw_cdata_add-modda.
        <lfs_outtab_9028>-atime   = lw_cdata_add-modti.
        <lfs_outtab_9028>-ddate   = lw_deleted_profile-modda.
        <lfs_outtab_9028>-dtime   = lw_deleted_profile-modti.
        CALL FUNCTION 'SALP_SM_CALC_TIME_DIFFERENCE'
          EXPORTING
            date_1  = lw_cdata_add-modda
            time_1  = lw_cdata_add-modti
            date_2  = lw_deleted_profile-modda
            time_2  = lw_deleted_profile-modti
          IMPORTING
            seconds = lv_second.
        lv_dif_sec = lv_second MOD 60.
        lv_dif_min = lv_second DIV 60.
        lv_dif_min = lv_dif_min MOD 60.
        lv_dif_hrs = lv_second DIV 3600.
        IF lv_dif_hrs IS NOT INITIAL.
          <lfs_outtab_9028>-duration = |{ lv_dif_hrs }hrs { lv_dif_min }mins { lv_dif_sec }sec|.
        ELSE.
          IF lv_dif_min IS NOT INITIAL.
            <lfs_outtab_9028>-duration = |{ lv_dif_min }mins { lv_dif_sec }sec|.
          ELSE.
            <lfs_outtab_9028>-duration = |{ lv_dif_sec }sec|.
          ENDIF.
        ENDIF.
        <lfs_outtab_9028>-atcode   = lw_cdata_add-tcode.
        <lfs_outtab_9028>-dtcode   = lw_deleted_profile-tcode.
        <lfs_outtab_9028>-aernam   = lw_cdata_add-modbe.
        <lfs_outtab_9028>-dernam   = lw_deleted_profile-modbe.

        READ TABLE li_agr_prof INTO DATA(lw_agr_prof) WITH KEY profile = <lfs_outtab_9028>-profile BINARY SEARCH.
        IF sy-subrc IS INITIAL.
          <lfs_outtab_9028>-role = lw_agr_prof-agr_name.
          CLEAR <lfs_outtab_9028>-profile.
        ENDIF.

      ENDIF.
    ENDLOOP.


  ENDIF.


  CLEAR: li_cdred_output, li_cdata_add, li_cdata_del.
  CALL FUNCTION 'SUSR_CHANGE_DOC_ROLES'
    EXPORTING
      iv_fdate        = lv_fdate
      iv_tdate        = lv_tdate
      iv_ftime        = lv_ftime
      iv_ttime        = lv_ttime
    IMPORTING
      et_cdred_output = li_cdred_output.

  LOOP AT li_cdred_output INTO lw_cdred_output.
    APPEND INITIAL LINE TO li_cdata_add ASSIGNING <lfs_cdata>.
    MOVE-CORRESPONDING lw_cdred_output TO <lfs_cdata>.
    <lfs_cdata>-timestamp = |{ lw_cdred_output-modda }{ lw_cdred_output-modti }|.
  ENDLOOP.
  li_cdata_del = li_cdata_add.

  DELETE li_cdata_add WHERE action NE 'Role added'.
  DELETE li_cdata_del WHERE action NE 'Role deleted'.

  IF li_cdata_del IS NOT INITIAL.
    LOOP AT li_cdata_add INTO lw_cdata_add.

      CALL FUNCTION 'C14Z_CALC_DATE_TIME'
        EXPORTING
          i_add_seconds = lv_seconds
          i_uzeit       = lw_cdata_add-modti
          i_datum       = lw_cdata_add-modda
        IMPORTING
          e_datum       = lv_enddate
          e_uzeit       = lv_endtime.

      lv_timestamp = |{ lv_enddate }{ lv_endtime }|.

      SELECT SINGLE *
        FROM @li_cdata_del AS deleted
        WHERE bname = @lw_cdata_add-bname
          AND ( timestamp LE @lv_timestamp AND timestamp GE @lw_cdata_add-timestamp )
          AND old_val = @lw_cdata_add-new_val
        INTO @DATA(lw_deleted_role).

      IF sy-subrc IS INITIAL.
        APPEND INITIAL LINE TO gt_outtab_9028 ASSIGNING <lfs_outtab_9028>.
        <lfs_outtab_9028>-user    = lw_cdata_add-bname.
        <lfs_outtab_9028>-role    = lw_cdata_add-new_val.
        <lfs_outtab_9028>-agr_fdate = lw_cdata_add-agr_fdate.
        <lfs_outtab_9028>-adate   = lw_cdata_add-modda.
        <lfs_outtab_9028>-atime   = lw_cdata_add-modti.
        <lfs_outtab_9028>-ddate   = lw_deleted_role-modda.
        <lfs_outtab_9028>-dtime   = lw_deleted_role-modti.
        CALL FUNCTION 'SALP_SM_CALC_TIME_DIFFERENCE'
          EXPORTING
            date_1  = lw_cdata_add-modda
            time_1  = lw_cdata_add-modti
            date_2  = lw_deleted_role-modda
            time_2  = lw_deleted_role-modti
          IMPORTING
            seconds = lv_second.
        lv_dif_sec = lv_second MOD 60.
        lv_dif_min = lv_second DIV 60.
        lv_dif_min = lv_dif_min MOD 60.
        lv_dif_hrs = lv_second DIV 3600.
        IF lv_dif_hrs IS NOT INITIAL.
          <lfs_outtab_9028>-duration = |{ lv_dif_hrs }hrs { lv_dif_min }mins { lv_dif_sec }sec|.
        ELSE.
          IF lv_dif_min IS NOT INITIAL.
            <lfs_outtab_9028>-duration = |{ lv_dif_min }mins { lv_dif_sec }sec|.
          ELSE.
            <lfs_outtab_9028>-duration = |{ lv_dif_sec }sec|.
          ENDIF.
        ENDIF.
        <lfs_outtab_9028>-atcode   = lw_cdata_add-tcode.
        <lfs_outtab_9028>-dtcode   = lw_deleted_role-tcode.
        <lfs_outtab_9028>-aernam   = lw_cdata_add-modbe.
        <lfs_outtab_9028>-dernam   = lw_deleted_role-modbe.

        IF <lfs_outtab_9028>-agr_fdate NOT BETWEEN <lfs_outtab_9028>-adate AND <lfs_outtab_9028>-ddate.
          CLEAR <lfs_outtab_9028>.
        ENDIF.

      ENDIF.
    ENDLOOP.
    DELETE gt_outtab_9028 WHERE user IS INITIAL.
  ENDIF.

  SORT gt_outtab_9028.
  DELETE ADJACENT DUPLICATES FROM gt_outtab_9028 COMPARING
  user
  role
  profile
  adate
  atime
  ddate
  dtime
  duration
  atcode
  dtcode
  aernam
  dernam.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9028
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9028 .

  DATA:
    li_users        TYPE zacg_t_copy_user,
    li_users_return TYPE zacg_t_copy_user,
    li_excel        TYPE STANDARD TABLE OF alsmex_tabline.

  IF p_fcufr IS NOT INITIAL.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = p_fcufr
        i_begin_col             = 1
        i_begin_row             = 2
        i_end_col               = 2
        i_end_row               = 99999
      TABLES
        intern                  = li_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.
    IF sy-subrc IS INITIAL.

      LOOP AT li_excel INTO DATA(lwa_excel1).
        AT NEW row.
          APPEND INITIAL LINE TO li_users ASSIGNING FIELD-SYMBOL(<lfs_users>).

        ENDAT.
        ASSIGN COMPONENT lwa_excel1-col OF STRUCTURE <lfs_users> TO FIELD-SYMBOL(<lfs_val>).
        IF <lfs_val> IS ASSIGNED.
          <lfs_val> = lwa_excel1-value.
        ENDIF.
        UNASSIGN <lfs_val>.
      ENDLOOP.

    ENDIF.

  ELSE.
    LOOP AT so_cufr[] INTO so_cufr.
      APPEND INITIAL LINE TO li_users ASSIGNING <lfs_users>.
      <lfs_users>-from_user = p_cufr.
      <lfs_users>-to_user   = so_cufr-low.
    ENDLOOP.
  ENDIF.

  CLEAR: gt_outtab_9027.

  IF li_users IS NOT INITIAL.

    CALL FUNCTION 'ZACG_USER_COPY'
      EXPORTING
        it_users = li_users
      IMPORTING
        et_users = li_users_return.

    LOOP AT li_users_return INTO DATA(lw_users_return).
      APPEND INITIAL LINE TO gt_outtab_9027 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9027>).
      <lfs_outtab_9027>-icon  = lw_users_return-icon.
      <lfs_outtab_9027>-fuser = lw_users_return-from_user.
      <lfs_outtab_9027>-tuser = lw_users_return-to_user.
      <lfs_outtab_9027>-mesg  = lw_users_return-message.
    ENDLOOP.

  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9029
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9029 .

  IF sy-ucomm = 'EXE'.
    CLEAR i_outtab_7001.
    CALL SCREEN 7001 STARTING AT 40 8 ENDING AT 99 13.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9030
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9030.

  IF sy-ucomm = 'EXE'.
    PERFORM raise_bulk_request.
  ELSEIF sy-ucomm = 'D930'.
    PERFORM download_template USING co_file_9030
                                    co_trans_name_9030.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_9029
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_9029.

  DATA lv_message TYPE string.

  IF sy-ucomm = 'EXE'.
    IF p_nuser IS INITIAL.
      " Check User Provided
      CLEAR sy-ucomm.
      SET CURSOR FIELD 'P_NUSER'.
      MESSAGE 'Please provide User Id' TYPE 'E'.
    ELSE.
      " Check Valid User
      SELECT SINGLE bname
        FROM usr02
        WHERE bname = @p_nuser
          AND gltgv <= @sy-datum
          AND ( gltgb >= @sy-datum OR gltgb IS INITIAL )
          AND ustyp IN ('A','S')
          AND uflag IN (0,128)
        INTO @DATA(lv_user).
      IF sy-subrc IS NOT INITIAL.
        CLEAR sy-ucomm.
        SET CURSOR FIELD 'P_NUSER'.
        MESSAGE 'Please provide a valid User Id' TYPE 'E'.
      ELSE.
        SORT s_nrole[] BY low.
        DELETE ADJACENT DUPLICATES FROM s_nrole[] COMPARING low.
        DELETE s_nrole[] WHERE low IS INITIAL.
        IF s_nrole[] IS INITIAL.
          CLEAR sy-ucomm.
          SET CURSOR FIELD 'S_NROLE-LOW'.
          MESSAGE 'Please provide Role' TYPE 'E'.
        ELSE.
          " Check All provided roles are valid
          SELECT agr_name
            FROM agr_define
            INTO TABLE @DATA(li_valid_agr)
          WHERE agr_name IN @s_nrole[].
          IF sy-subrc IS INITIAL.
            LOOP AT s_nrole[] INTO s_nrole.
              READ TABLE li_valid_agr TRANSPORTING
              NO FIELDS WITH KEY agr_name = s_nrole-low.
              IF sy-subrc IS NOT INITIAL.
                CLEAR sy-ucomm.
                SET CURSOR FIELD 'S_NROLE-LOW'.
                lv_message = |Role { s_nrole-low } is not valid|.
                MESSAGE lv_message TYPE 'E'.
              ENDIF.
            ENDLOOP.

            " Check Line Manager maintained
            SELECT SINGLE manager
              FROM zacg_manager
              INTO @DATA(lv_manager)
              WHERE userid = @p_nuser.
            IF sy-subrc IS NOT INITIAL.
              CLEAR sy-ucomm.
              SET CURSOR FIELD 'P_NUSER'.
              MESSAGE 'User does not have any Line Manager' TYPE 'E'.
            ENDIF.

            " Check Role Owners are maintained
            SELECT *
              FROM zacg_role_owners
              INTO TABLE @DATA(li_role_owner)
              WHERE agr_name IN @s_nrole[].
            IF sy-subrc IS INITIAL.
              LOOP AT s_nrole[] INTO s_nrole.
                READ TABLE li_role_owner TRANSPORTING NO FIELDS
                WITH KEY agr_name = s_nrole-low.
                IF sy-subrc IS NOT INITIAL.
                  CLEAR sy-ucomm.
                  SET CURSOR FIELD 'S_NROLE-LOW'.
                  lv_message = |Role owner not found for { s_nrole-low }|.
                  MESSAGE lv_message TYPE 'E'.
                ENDIF.
              ENDLOOP.

            ELSE.
              CLEAR sy-ucomm.
              SET CURSOR FIELD 'S_NROLE-LOW'.
              MESSAGE 'Role owner not found' TYPE 'E'.
            ENDIF.
          ELSE.
            CLEAR sy-ucomm.
            SET CURSOR FIELD 'S_NROLE-LOW'.
            MESSAGE 'Please provide a valid Role' TYPE 'E'.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.




  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_9030
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_9030.

  DATA: lv_count          TYPE i,
        lv_ex_date        TYPE datum,
        lv_role_owner     TYPE xubname,
        li_excel          TYPE STANDARD TABLE OF alsmex_tabline,
        li_file_data_9030 TYPE STANDARD TABLE OF ty_file_data_9030.

  CHECK g_ucomm = 'EXE'.
  CLEAR: i_outtab_9030, i_file_data_9030.

  IF p_file30 IS NOT INITIAL.

    DATA(lv_len) = strlen( p_file30 ) - 4.
    TRANSLATE p_file30+lv_len(4) TO UPPER CASE.
    IF p_file30+lv_len(4) = '.XLS'.

      DATA(lv_text) = 'Reading file'.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING
          percentage = 10
          text       = lv_text.

      CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
        EXPORTING
          filename                = p_file30
          i_begin_col             = 1
          i_begin_row             = 1
          i_end_col               = 4
          i_end_row               = 10
        TABLES
          intern                  = li_excel
        EXCEPTIONS
          inconsistent_parameters = 1
          upload_ole              = 2
          OTHERS                  = 3.
      IF sy-subrc <> 0.
        CLEAR: sy-ucomm, g_ucomm.
        MESSAGE 'Please provide valid file' TYPE 'E'.
      ELSE.

        lv_text = 'Validating header'.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING
            percentage = 100
            text       = lv_text.


        LOOP AT li_excel INTO DATA(lwa_excel).

          IF lwa_excel-row = '0002'.
            EXIT.
          ENDIF.

          lv_count = lv_count + 1.

          CASE lwa_excel-col.
            WHEN '0001'.
              IF lwa_excel-value NE 'User'.
                APPEND INITIAL LINE TO i_outtab_9030
                ASSIGNING FIELD-SYMBOL(<lfs_file_error_9030>).
                <lfs_file_error_9030>-index = lwa_excel-row.
                <lfs_file_error_9030>-error = '1st column should name as User'.
                CLEAR lwa_excel.
              ENDIF.
            WHEN '0002'.
              IF lwa_excel-value NE 'Role'.
                APPEND INITIAL LINE TO i_outtab_9030 ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lwa_excel-row.
                <lfs_file_error_9030>-error = '2nd column should name as Role'.
                CLEAR lwa_excel.
              ENDIF.
            WHEN '0003'.
              IF lwa_excel-value(10) NE 'Start Date'.
                APPEND INITIAL LINE TO i_outtab_9030 ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lwa_excel-row.
                <lfs_file_error_9030>-error = '3rd column should name as Start Date'.
                CLEAR lwa_excel.
              ENDIF.
            WHEN '0004'.
              IF lwa_excel-value(8) NE 'End Date'.
                APPEND INITIAL LINE TO i_outtab_9030 ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lwa_excel-row.
                <lfs_file_error_9030>-error = '4th column should name as End Date'.
                CLEAR lwa_excel.
              ENDIF.
          ENDCASE.
        ENDLOOP.

        IF lv_count <> 4.

          APPEND INITIAL LINE TO i_outtab_9030 ASSIGNING <lfs_file_error_9030>.
          <lfs_file_error_9030>-index = lv_count.
          <lfs_file_error_9030>-error = |Column #{ lv_count + 1 } of header line can not be blank|.
          CLEAR lwa_excel.
        ENDIF.

        IF i_outtab_9030 IS NOT INITIAL.
          CLEAR: sy-ucomm, g_ucomm, li_excel.
        ELSE.
          DELETE li_excel WHERE row = '0001'.


          LOOP AT li_excel INTO DATA(lwa_excel1).

            lwa_excel = lwa_excel1.
            AT NEW row.
              APPEND INITIAL LINE TO li_file_data_9030 ASSIGNING FIELD-SYMBOL(<lfs_file_data_9030>).
            ENDAT.
            ASSIGN COMPONENT lwa_excel-col OF STRUCTURE <lfs_file_data_9030> TO FIELD-SYMBOL(<lfs_value>).
            IF <lfs_value> IS ASSIGNED.
              <lfs_value> = lwa_excel-value.
            ENDIF.

            UNASSIGN <lfs_value>.

          ENDLOOP.


          lv_text = 'Validating file content'.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING
              percentage = 50
              text       = lv_text.

          SELECT agr_name
            FROM agr_define
            INTO TABLE @DATA(li_valid_agr)
            ORDER BY agr_name.

          SELECT *
            FROM zacg_role_owners
            INTO TABLE @DATA(li_role_owner)
            WHERE agr_bowner <> @space
            ORDER BY agr_name.

          LOOP AT li_file_data_9030 ASSIGNING <lfs_file_data_9030>.

            DATA(lv_tabix) = sy-tabix.


            IF <lfs_file_data_9030>-user IS INITIAL.
              APPEND INITIAL LINE TO i_outtab_9030
                  ASSIGNING <lfs_file_error_9030>.
              <lfs_file_error_9030>-index = lv_tabix + 1.
              <lfs_file_error_9030>-error = |User can not be blank|.
            ELSE.
              SELECT SINGLE bname
              FROM usr02
              WHERE bname = @<lfs_file_data_9030>-user
                AND gltgv <= @sy-datum
                AND ( gltgb >= @sy-datum OR gltgb IS INITIAL )
                AND ustyp IN ('A','S')
                AND uflag IN (0,128)
              INTO @DATA(lv_user).
              IF sy-subrc IS NOT INITIAL.
                APPEND INITIAL LINE TO i_outtab_9030
                    ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lv_tabix + 1.
                <lfs_file_error_9030>-error = |User { <lfs_file_data_9030>-user } is invalid|.
              ELSE.
                SELECT SINGLE bmanager
                  FROM zacg_manager
                  INTO @DATA(lv_manager)
                  WHERE userid = @<lfs_file_data_9030>-user.
                IF lv_manager IS INITIAL.
                  APPEND INITIAL LINE TO i_outtab_9030
                  ASSIGNING <lfs_file_error_9030>.
                  <lfs_file_error_9030>-index = lv_tabix + 1.
                  <lfs_file_error_9030>-error = |User { <lfs_file_data_9030>-user } does not have any Line Manager|.
                ELSE.
                  <lfs_file_data_9030>-manager = lv_manager.
                ENDIF.
              ENDIF.
            ENDIF.

            IF <lfs_file_data_9030>-role IS INITIAL.
              APPEND INITIAL LINE TO i_outtab_9030
                  ASSIGNING <lfs_file_error_9030>.
              <lfs_file_error_9030>-index = lv_tabix + 1.
              <lfs_file_error_9030>-error = |Role can not be blank|.
            ELSE.
              READ TABLE li_valid_agr TRANSPORTING
              NO FIELDS WITH KEY agr_name = <lfs_file_data_9030>-role BINARY SEARCH.
              IF sy-subrc IS NOT INITIAL.
                APPEND INITIAL LINE TO i_outtab_9030
              ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lv_tabix + 1.
                <lfs_file_error_9030>-error = |Role { <lfs_file_data_9030>-role } is invalid|.
              ENDIF.

              READ TABLE li_role_owner INTO DATA(lwa_role_owner)
              WITH KEY agr_name = <lfs_file_data_9030>-role BINARY SEARCH.
              IF sy-subrc IS NOT INITIAL.
                APPEND INITIAL LINE TO i_outtab_9030
                ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lv_tabix + 1.
                <lfs_file_error_9030>-error = |Role { <lfs_file_data_9030>-role } does not have any Owner assigned|.
              ELSE.
                <lfs_file_data_9030>-owner = lwa_role_owner-agr_bowner.
              ENDIF.

            ENDIF.

            IF <lfs_file_data_9030>-start IS INITIAL.
              APPEND INITIAL LINE TO i_outtab_9030
              ASSIGNING <lfs_file_error_9030>.
              <lfs_file_error_9030>-index = lv_tabix + 1.
              <lfs_file_error_9030>-error = |Start date can not be blank|.
            ELSE.
              SPLIT <lfs_file_data_9030>-start AT '.'
              INTO DATA(lv_date) DATA(lv_month) DATA(lv_year).
              DATA(lv_ch_date) = |{ lv_year }{ lv_month }{ lv_date }|.
              CLEAR: lv_date, lv_month, lv_year.
              CLEAR lv_ex_date.
              lv_ex_date = lv_ch_date.
              CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
                EXPORTING
                  date                      = lv_ex_date
                EXCEPTIONS
                  plausibility_check_failed = 1
                  OTHERS                    = 2.
              IF sy-subrc <> 0.
                APPEND INITIAL LINE TO i_outtab_9030
                ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lv_tabix + 1.
                <lfs_file_error_9030>-error = |Please provide correct start date { <lfs_file_data_9030>-start
                } in DD.MM.YYYY format|.
              ELSE.

                IF lv_ex_date = '99991231'.
                  APPEND INITIAL LINE TO i_outtab_9030
                  ASSIGNING <lfs_file_error_9030>.
                  <lfs_file_error_9030>-index = lv_tabix + 1.
                  <lfs_file_error_9030>-error = |Invalid start date 31.12.9999|.
                ELSEIF lv_ex_date < sy-datum.
                  APPEND INITIAL LINE TO i_outtab_9030
                  ASSIGNING <lfs_file_error_9030>.
                  <lfs_file_error_9030>-index = lv_tabix + 1.
                  <lfs_file_error_9030>-error = |Start date can not be in the past|.
                ELSE.
                  <lfs_file_data_9030>-start = lv_ex_date.
                ENDIF.
              ENDIF.

            ENDIF.

            IF <lfs_file_data_9030>-end IS INITIAL.
              <lfs_file_data_9030>-end = '99991231'.
            ELSE.
              SPLIT <lfs_file_data_9030>-end AT '.'
              INTO lv_date lv_month lv_year.
              lv_ch_date = |{ lv_year }{ lv_month }{ lv_date }|.
              CLEAR: lv_date, lv_month, lv_year.
              CLEAR lv_ex_date.
              lv_ex_date = lv_ch_date.
              CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
                EXPORTING
                  date                      = lv_ex_date
                EXCEPTIONS
                  plausibility_check_failed = 1
                  OTHERS                    = 2.
              IF sy-subrc <> 0.
                APPEND INITIAL LINE TO i_outtab_9030
                ASSIGNING <lfs_file_error_9030>.
                <lfs_file_error_9030>-index = lv_tabix + 1.
                <lfs_file_error_9030>-error = |Please provide correct end date { <lfs_file_data_9030>-start
                } in DD.MM.YYYY format|.
              ELSE.
                IF lv_ex_date < sy-datum.
                  APPEND INITIAL LINE TO i_outtab_9030
                  ASSIGNING <lfs_file_error_9030>.
                  <lfs_file_error_9030>-index = lv_tabix + 1.
                  <lfs_file_error_9030>-error = |End date can not be in the past|.
                ELSE.
                  <lfs_file_data_9030>-end = lv_ex_date.
                ENDIF.
              ENDIF.
            ENDIF.

            CLEAR : lv_manager.
          ENDLOOP.


          DATA(li_unique_manager) = li_file_data_9030.
          DELETE li_unique_manager WHERE manager IS INITIAL.
          SORT li_unique_manager BY manager.
          DELETE ADJACENT DUPLICATES FROM li_unique_manager COMPARING manager.
          IF lines( li_unique_manager ) > 1.
            APPEND INITIAL LINE TO i_outtab_9030
            ASSIGNING <lfs_file_error_9030>.
            <lfs_file_error_9030>-error = |Multiple Line Manager found in Config|.
          ENDIF.

          li_unique_manager = li_file_data_9030.
          DELETE li_unique_manager WHERE owner IS INITIAL.
          SORT li_unique_manager BY owner.
          DELETE ADJACENT DUPLICATES FROM li_unique_manager COMPARING owner.
          IF lines( li_unique_manager ) > 1.
            APPEND INITIAL LINE TO i_outtab_9030
            ASSIGNING <lfs_file_error_9030>.
            <lfs_file_error_9030>-error = |Multiple Role Owner found in Config|.
          ENDIF.

          IF i_outtab_9030 IS INITIAL.
            i_file_data_9030 = li_file_data_9030.
          ELSE.
            CLEAR sy-ucomm.
          ENDIF.


        ENDIF.

      ENDIF.

    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide valid file' TYPE 'E'.
    ENDIF.
  ELSE.
    CLEAR: sy-ucomm, g_ucomm.
    MESSAGE 'Please provide a file' TYPE 'E'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_alv_9029
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9029.


  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.


  IF o_conttainer_9029 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9029
      EXPORTING
        container_name = 'CC_9029'.
  ENDIF.

  IF o_conttainer_9029 IS BOUND AND o_grid_9029 IS NOT BOUND.
    CREATE OBJECT o_grid_9029
      EXPORTING
        i_parent = o_conttainer_9029.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'REQ_NO'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Request No'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'USER'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Requested For'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ROLE'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Requested Role'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'BEGDA'.
  ls_catalog-coltext   = 'Requested Start Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ENDDA'.
  ls_catalog-coltext   = 'Requested End Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'STATUST'.
  ls_catalog-coltext   = 'Status'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'APPROVER'.
  ls_catalog-coltext   = 'Action Owner'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ERNAM'.
  ls_catalog-coltext   = 'Last Action Taken By'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ERDAT'.
  ls_catalog-coltext   = 'Last Action Taken On'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9029 IS BOUND.
    IF g_9029_first IS INITIAL.
      g_9029_first = abap_true.
      CALL METHOD o_grid_9029->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_outtab_9029.
    ELSE.

      CALL METHOD o_grid_9029->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9029->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9029->refresh_table_display( ).
    ENDIF.
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9029
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9029 .

  CLEAR gt_outtab_9029.

  SELECT *
    FROM zacg_req_aprover
    INTO TABLE @DATA(li_req_aprover)
      WHERE userid = @sy-uname
        AND status EQ '02'
        AND action_taken = @space.
  IF li_req_aprover IS NOT INITIAL.
    SELECT domvalue_l,
           ddtext
      FROM dd07t
      INTO TABLE @DATA(li_status)
      WHERE domname = 'ZACG_ACC_REQ_ST'
        AND ddlanguage = @sy-langu
      ORDER BY domvalue_l.

    SELECT domvalue_l,
           ddtext
      FROM dd07t
      INTO TABLE @DATA(li_approver)
      WHERE domname = 'ZACG_APPROVER_ROLE'
        AND ddlanguage = @sy-langu
      ORDER BY domvalue_l.

    CLEAR gt_outtab_9029.
    LOOP AT li_req_aprover INTO DATA(lwa_req_aprover).

      APPEND INITIAL LINE TO gt_outtab_9029 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9029>).

      <lfs_outtab_9029>-req_no        = lwa_req_aprover-req_no.
      <lfs_outtab_9029>-role          = lwa_req_aprover-agr_name.
      <lfs_outtab_9029>-user          = lwa_req_aprover-userid.
      <lfs_outtab_9029>-begda         = lwa_req_aprover-begda.
      <lfs_outtab_9029>-endda         = lwa_req_aprover-endda.
      <lfs_outtab_9029>-status        = lwa_req_aprover-status.
      READ TABLE li_status INTO DATA(lwa_status)
              WITH KEY domvalue_l = lwa_req_aprover-status BINARY SEARCH.
      IF lwa_req_aprover-status = '02'.
        <lfs_outtab_9029>-statust = |{ lwa_status-ddtext } with|.
      ELSEIF lwa_req_aprover-status = '03' OR
             lwa_req_aprover-status = '04'.
        <lfs_outtab_9029>-statust = |{ lwa_status-ddtext } by|.
      ENDIF.
      READ TABLE li_approver INTO DATA(lwa_approver)
            WITH KEY domvalue_l = lwa_req_aprover-approver_role BINARY SEARCH.
      <lfs_outtab_9029>-statust  = |{ <lfs_outtab_9029>-statust } { lwa_approver-ddtext }|.
      <lfs_outtab_9029>-approver  = lwa_req_aprover-approver.
      <lfs_outtab_9029>-ernam = lwa_req_aprover-aename.
      <lfs_outtab_9029>-erdat = lwa_req_aprover-aedate.
    ENDLOOP.

  ENDIF.


  IF p_nuser IS INITIAL.
    p_nuser = sy-uname.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9031
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9031 .

  PERFORM populate_data_9031.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9031
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9031.

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.


  IF o_conttainer_9031 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9031
      EXPORTING
        container_name = 'CC_9031'.
  ENDIF.

  IF o_conttainer_9031 IS BOUND AND o_grid_9031 IS NOT BOUND.
    CREATE OBJECT o_grid_9031
      EXPORTING
        i_parent = o_conttainer_9031.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'REQ_NO'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Request No'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'USER'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Requested For'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ROLE'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Requested Role'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'BEGDA'.
  ls_catalog-coltext   = 'Requested Start Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ENDDA'.
  ls_catalog-coltext   = 'Requested End Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'STATUST'.
  ls_catalog-coltext   = 'Status'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'APPROVER'.
  ls_catalog-coltext   = 'Action Owner'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ERNAM'.
  ls_catalog-coltext   = 'Last Action Taken By'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ERDAT'.
  ls_catalog-coltext   = 'Last Action Taken On'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9031 IS BOUND.
    IF g_9031_first IS INITIAL.
      g_9031_first = abap_true.
      CALL METHOD o_grid_9031->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = gt_outtab_9031.
    ELSE.
      CALL METHOD o_grid_9031->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9031->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9031->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9031
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9031 .

  TYPES:
    BEGIN OF lty_request,
      req_no   TYPE zacg_acc_req,
      agr_name TYPE agr_name,
    END OF lty_request,

    BEGIN OF lty_risk,
      risk TYPE zrisk,
    END OF lty_risk.

  DATA:
    lv_valid       TYPE flag,
    lv_common      TYPE flag,
    lv_message     TYPE string,
    li_request     TYPE STANDARD TABLE OF lty_request,
    li_rolerequest TYPE STANDARD TABLE OF zacg_req_aprover,
    lr_request     TYPE RANGE OF zacg_acc_req,
    li_user_role   TYPE zacg_t_user_role,
    lt_risk        TYPE STANDARD TABLE OF lty_risk.

  CLEAR g_mitigated.

  CASE sy-ucomm.

    WHEN 'SREQ'. " When Radiobutton is clicked

      PERFORM populate_data_9031.

    WHEN 'SRCH'. " When Search Button is pressed

      IF r_sreq = abap_true.

        CLEAR gt_outtab_9031.

      ENDIF.

    WHEN 'APPR'. " When approved by Line Manager

      o_grid_9031->get_selected_rows(
        IMPORTING
          et_index_rows = DATA(li_index_rows)
          et_row_no     = DATA(li_row_no) ).

      IF li_row_no IS NOT INITIAL.
        LOOP AT li_row_no INTO DATA(lwa_row_no).
          READ TABLE gt_outtab_9031 INTO DATA(lwa_outtab_9031) INDEX lwa_row_no-row_id.
          IF sy-subrc IS INITIAL.
            IF lwa_outtab_9031-status = '02'.
              IF lwa_outtab_9031-app_role = '1' AND
                 lwa_outtab_9031-approver = sy-uname AND
                 lwa_outtab_9031-action_taken = space.
                APPEND INITIAL LINE TO li_request ASSIGNING FIELD-SYMBOL(<lfs_request>).
                <lfs_request>-req_no = lwa_outtab_9031-req_no.
                <lfs_request>-agr_name = lwa_outtab_9031-role.  "" ++ Rounak on 26-08-2025
              ELSE.
                lv_message = |You are not the line manager to approve for request: { lwa_outtab_9031-req_no }|.
                MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
                EXIT.
              ENDIF.
            ELSE.
              lv_message = |No apprval is required for Request: { lwa_outtab_9031-req_no }|.
              MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
              EXIT.
            ENDIF.
          ENDIF.
        ENDLOOP.

        IF lv_message IS INITIAL.
          SORT li_request.
          DELETE ADJACENT DUPLICATES FROM li_request.

          IF li_request IS NOT INITIAL.

            SELECT *
              FROM zacg_role_owners
              INTO TABLE @DATA(li_owners)
            ORDER BY agr_name.

*** Start of Change by Rounak
            SELECT child_req_no
            FROM zacg_req_blk_map
            INTO TABLE @DATA(li_req_blk_map)
            FOR ALL ENTRIES IN @li_request
            WHERE req_no = @li_request-req_no.
            IF sy-subrc IS INITIAL.
              APPEND LINES OF li_req_blk_map TO li_request.
            ENDIF.
*** End of Change by Rounak

            SELECT *
              FROM zacg_req_aprover
              INTO TABLE @DATA(li_req_aprover)
              FOR ALL ENTRIES IN @li_request
              WHERE req_no = @li_request-req_no
                AND agr_name = @li_request-agr_name "" ++ Rounak on 26-08-2025
                AND status = '02'
                AND approver = @sy-uname
                AND approver_role = '1'
                AND action_taken = @abap_false.
            IF sy-subrc IS INITIAL.

              LOOP AT li_req_aprover INTO DATA(lwa_req_aprover).

                READ TABLE li_rolerequest TRANSPORTING NO FIELDS
                WITH KEY req_no = lwa_req_aprover-req_no.

                CHECK sy-subrc IS NOT INITIAL.

                SELECT *
                  FROM @li_req_aprover AS request
                  WHERE req_no = @lwa_req_aprover-req_no
                  AND agr_name = @lwa_req_aprover-agr_name  "" ++ Rounak on 26-08-2025
                  INTO TABLE @DATA(li_req_aprover_tmp).

                LOOP AT li_req_aprover_tmp INTO DATA(lwa_req_aprover_tmp).

                  APPEND INITIAL LINE TO li_rolerequest ASSIGNING
                    FIELD-SYMBOL(<lfs_rolerequest>).

                  " Approval line item action taken
                  MOVE-CORRESPONDING lwa_req_aprover_tmp TO <lfs_rolerequest>.
                  <lfs_rolerequest>-action_taken = abap_true.

                  " New Line item for approved
                  UNASSIGN <lfs_rolerequest>.
                  APPEND INITIAL LINE TO li_rolerequest ASSIGNING <lfs_rolerequest>.
                  MOVE-CORRESPONDING lwa_req_aprover_tmp TO <lfs_rolerequest>.
                  <lfs_rolerequest>-seqnr        = lwa_req_aprover_tmp-seqnr + 1.
                  <lfs_rolerequest>-action_taken = abap_true.
                  <lfs_rolerequest>-status       = '03'.
                  <lfs_rolerequest>-aename       = sy-uname.
                  <lfs_rolerequest>-aedate       = sy-datum.
                  <lfs_rolerequest>-aetim        = sy-uzeit.

                  " New line item for Role Owner
                  UNASSIGN <lfs_rolerequest>.
                  APPEND INITIAL LINE TO li_rolerequest ASSIGNING <lfs_rolerequest>.
                  MOVE-CORRESPONDING lwa_req_aprover_tmp TO <lfs_rolerequest>.
                  <lfs_rolerequest>-seqnr         = lwa_req_aprover_tmp-seqnr + 2.
                  <lfs_rolerequest>-approver_role = 2.
                  <lfs_rolerequest>-status        = '02'.
                  <lfs_rolerequest>-aename        = sy-uname.
                  <lfs_rolerequest>-aedate        = sy-datum.
                  <lfs_rolerequest>-aetim         = sy-uzeit.
                  READ TABLE li_owners INTO DATA(lwa_owners)
                  WITH KEY agr_name = lwa_req_aprover_tmp-agr_name BINARY SEARCH.
                  IF sy-subrc IS INITIAL.
                    IF lwa_req_aprover-req_no(1) = 'N'.
                      <lfs_rolerequest>-approver = lwa_owners-agr_owner.
                    ELSEIF lwa_req_aprover-req_no(1) = 'B'.
                      <lfs_rolerequest>-approver = lwa_owners-agr_bowner.
                    ENDIF.

                  ENDIF.
                ENDLOOP.
              ENDLOOP.

              IF li_rolerequest IS NOT INITIAL.
                MODIFY zacg_req_aprover FROM TABLE li_rolerequest.
                COMMIT WORK AND WAIT.
                MESSAGE 'Requests are approved and sent to Role Owners' TYPE 'S'.
              ENDIF.

              SORT li_rolerequest BY req_no.
              DELETE ADJACENT DUPLICATES FROM li_rolerequest COMPARING req_no.
              LOOP AT li_rolerequest INTO DATA(lwa_rolerequest).
                CALL FUNCTION 'ZACG_NOTIFY_USERS_FOR_ROLE_REQ'
                  EXPORTING
                    iv_action  = 'MA'
                    iv_request = lwa_rolerequest-req_no.
              ENDLOOP.

              CASE abap_true.

                WHEN r_preq.  " Request actions pending on me

                  CLEAR gt_outtab_9031.
                  SELECT *
                    FROM zacg_req_aprover
                    INTO TABLE @li_req_aprover
                    WHERE approver = @sy-uname
                      AND status EQ '02'
                      AND action_taken = @abap_false.
                  IF li_req_aprover IS INITIAL.
                  ENDIF.

                WHEN r_rreq.  " Request raised by me

                  CLEAR gt_outtab_9031.
                  CLEAR gt_outtab_9031.
                  SELECT req_no
                    FROM zacg_req_aprover
                    INTO TABLE @li_request
                    WHERE aename = @sy-uname
                      AND seqnr = 001.
                  IF sy-subrc IS NOT INITIAL.
                    MESSAGE 'You have not raised any request' TYPE 'S' DISPLAY LIKE 'E'.
                  ELSE.
                    SORT li_request.
                    DELETE ADJACENT DUPLICATES FROM li_request.
                    IF li_request IS NOT INITIAL.
                      SELECT *
                        FROM zacg_req_aprover
                        INTO TABLE li_req_aprover
                        FOR ALL ENTRIES IN li_request
                        WHERE req_no = li_request-req_no.
                      IF sy-subrc IS INITIAL.
                        SORT li_req_aprover BY req_no agr_name seqnr DESCENDING.
                        DELETE ADJACENT DUPLICATES FROM li_req_aprover COMPARING req_no agr_name.
                      ENDIF.
                    ENDIF.
                  ENDIF.

                WHEN r_creq.  " Request completed by me

                  CLEAR gt_outtab_9031.

                WHEN r_sreq.  " Request search

                  CLEAR gt_outtab_9031.

              ENDCASE.

              IF li_req_aprover IS NOT INITIAL.
                SELECT domvalue_l,
                       ddtext
                  FROM dd07t
                  INTO TABLE @DATA(li_status)
                  WHERE domname = 'ZACG_ACC_REQ_ST'
                    AND ddlanguage = @sy-langu
                  ORDER BY domvalue_l.

                SELECT domvalue_l,
                       ddtext
                  FROM dd07t
                  INTO TABLE @DATA(li_approver)
                  WHERE domname = 'ZACG_APPROVER_ROLE'
                    AND ddlanguage = @sy-langu
                  ORDER BY domvalue_l.

                LOOP AT li_req_aprover INTO lwa_req_aprover.

                  APPEND INITIAL LINE TO gt_outtab_9031 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9031>).

                  <lfs_outtab_9031>-req_no        = lwa_req_aprover-req_no.
                  <lfs_outtab_9031>-role          = lwa_req_aprover-agr_name.
                  <lfs_outtab_9031>-user          = lwa_req_aprover-userid.
                  <lfs_outtab_9031>-begda         = lwa_req_aprover-begda.
                  <lfs_outtab_9031>-endda         = lwa_req_aprover-endda.
                  <lfs_outtab_9031>-status        = lwa_req_aprover-status.
                  <lfs_outtab_9031>-approver      = lwa_req_aprover-approver.
                  <lfs_outtab_9031>-app_role      = lwa_req_aprover-approver_role.

                  READ TABLE li_status INTO DATA(lwa_status)
                    WITH KEY domvalue_l = lwa_req_aprover-status BINARY SEARCH.
                  IF lwa_req_aprover-approver = sy-uname.
                    <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } as|.
                  ELSE.
                    IF lwa_req_aprover-status = '01' OR
                        lwa_req_aprover-status = '02'.
                      <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } with|.
                    ELSEIF lwa_req_aprover-status = '03' OR
                       lwa_req_aprover-status = '04'.
                      <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } by|.
                    ENDIF.
                  ENDIF.

                  READ TABLE li_approver INTO DATA(lwa_approver)
                        WITH KEY domvalue_l = lwa_req_aprover-approver_role BINARY SEARCH.
                  <lfs_outtab_9031>-statust  = |{ <lfs_outtab_9031>-statust } { lwa_approver-ddtext }|.
                  <lfs_outtab_9031>-ernam = lwa_req_aprover-aename.
                  <lfs_outtab_9031>-erdat = lwa_req_aprover-aedate.

                ENDLOOP.

                SORT gt_outtab_9031 BY req_no.

              ENDIF.

            ENDIF.

          ENDIF.

        ENDIF.

      ELSE.
        MESSAGE 'Please select the line you want to Approve' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.

    WHEN 'RJCT'.

      o_grid_9031->get_selected_rows(
        IMPORTING
          et_index_rows = li_index_rows
          et_row_no     = li_row_no ).

      IF li_row_no IS NOT INITIAL.
        LOOP AT li_row_no INTO lwa_row_no.
          READ TABLE gt_outtab_9031 INTO lwa_outtab_9031 INDEX lwa_row_no-row_id.
          IF sy-subrc IS INITIAL.
            IF lwa_outtab_9031-status = '02'.
              IF lwa_outtab_9031-app_role = '1' AND
                 lwa_outtab_9031-approver = sy-uname AND
                 lwa_outtab_9031-action_taken = space.
                APPEND INITIAL LINE TO li_request ASSIGNING <lfs_request>.
                <lfs_request> = lwa_outtab_9031-req_no.
              ELSE.
                lv_message = |You are not the line manager to reject for request: { lwa_outtab_9031-req_no }|.
                MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
                EXIT.
              ENDIF.
            ELSE.
              lv_message = |No rejection is required for Request: { lwa_outtab_9031-req_no }|.
              MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
              EXIT.
            ENDIF.
          ENDIF.
        ENDLOOP.

        IF lv_message IS INITIAL.
          SORT li_request.
          DELETE ADJACENT DUPLICATES FROM li_request.

          IF li_request IS NOT INITIAL.

            CLEAR gv_rejection_reason.
            CALL SCREEN 7004 STARTING AT 5 2 ENDING AT 105 3.

            IF gv_rejection_reason IS NOT INITIAL.

              SELECT *
                FROM zacg_role_owners
                INTO TABLE @li_owners
              ORDER BY agr_name.

              SELECT *
                FROM zacg_req_aprover
                INTO TABLE @li_req_aprover
                FOR ALL ENTRIES IN @li_request
                WHERE req_no = @li_request-req_no
                  AND status = '02'
                  AND approver = @sy-uname
                  AND approver_role = '1'
                  AND action_taken = @abap_false.
              IF sy-subrc IS INITIAL.

                LOOP AT li_req_aprover INTO lwa_req_aprover.

                  READ TABLE li_rolerequest TRANSPORTING NO FIELDS
                  WITH KEY req_no = lwa_req_aprover-req_no.

                  CHECK sy-subrc IS NOT INITIAL.

                  SELECT *
                    FROM @li_req_aprover AS request
                    WHERE req_no = @lwa_req_aprover-req_no
                    INTO TABLE @li_req_aprover_tmp.

                  LOOP AT li_req_aprover_tmp INTO lwa_req_aprover_tmp.

                    APPEND INITIAL LINE TO li_rolerequest ASSIGNING <lfs_rolerequest>.

                    " Rejection line item action taken
                    MOVE-CORRESPONDING lwa_req_aprover_tmp TO <lfs_rolerequest>.
                    <lfs_rolerequest>-action_taken = abap_true.

                    " New Line item for rejected
                    UNASSIGN <lfs_rolerequest>.
                    APPEND INITIAL LINE TO li_rolerequest ASSIGNING <lfs_rolerequest>.
                    MOVE-CORRESPONDING lwa_req_aprover_tmp TO <lfs_rolerequest>.
                    <lfs_rolerequest>-seqnr        = lwa_req_aprover_tmp-seqnr + 1.
                    <lfs_rolerequest>-action_taken = abap_true.
                    <lfs_rolerequest>-status       = '04'.
                    <lfs_rolerequest>-rj_rsn       = gv_rejection_reason.
                    <lfs_rolerequest>-aename       = sy-uname.
                    <lfs_rolerequest>-aedate       = sy-datum.
                    <lfs_rolerequest>-aetim        = sy-uzeit.

                  ENDLOOP.
                ENDLOOP.

                IF li_rolerequest IS NOT INITIAL.
                  MODIFY zacg_req_aprover FROM TABLE li_rolerequest.
                  COMMIT WORK AND WAIT.
                  MESSAGE 'Selected requests are rejected' TYPE 'S'.
                ENDIF.

                SORT li_rolerequest BY req_no.
                DELETE ADJACENT DUPLICATES FROM li_rolerequest COMPARING req_no.
                LOOP AT li_rolerequest INTO lwa_rolerequest.
                  CALL FUNCTION 'ZACG_NOTIFY_USERS_FOR_ROLE_REQ'
                    EXPORTING
                      iv_action           = 'MR'
                      iv_request          = lwa_rolerequest-req_no
                      iv_rejection_reason = gv_rejection_reason.
                ENDLOOP.


                CASE abap_true.

                  WHEN r_preq.  " Request actions pending on me

                    CLEAR gt_outtab_9031.
                    SELECT *
                      FROM zacg_req_aprover
                      INTO TABLE @li_req_aprover
                      WHERE approver = @sy-uname
                        AND status EQ '02'
                        AND action_taken = @abap_false.
                    IF li_req_aprover IS INITIAL.
                    ENDIF.

                  WHEN r_rreq.  " Request raised by me

                    CLEAR gt_outtab_9031.
                    CLEAR gt_outtab_9031.
                    SELECT req_no
                      FROM zacg_req_aprover
                      INTO TABLE @li_request
                      WHERE aename = @sy-uname
                        AND seqnr = 001.
                    IF sy-subrc IS NOT INITIAL.
                      MESSAGE 'You have not raised any request' TYPE 'S' DISPLAY LIKE 'E'.
                    ELSE.
                      SORT li_request.
                      DELETE ADJACENT DUPLICATES FROM li_request.
                      IF li_request IS NOT INITIAL.
                        SELECT *
                          FROM zacg_req_aprover
                          INTO TABLE li_req_aprover
                          FOR ALL ENTRIES IN li_request
                          WHERE req_no = li_request-req_no.
                        IF sy-subrc IS INITIAL.
                          SORT li_req_aprover BY req_no agr_name seqnr DESCENDING.
                          DELETE ADJACENT DUPLICATES FROM li_req_aprover COMPARING req_no agr_name.
                        ENDIF.
                      ENDIF.
                    ENDIF.

                  WHEN r_creq.  " Request completed by me

                    CLEAR gt_outtab_9031.

                  WHEN r_sreq.  " Request search

                    CLEAR gt_outtab_9031.

                ENDCASE.

                IF li_req_aprover IS NOT INITIAL.
                  SELECT domvalue_l,
                         ddtext
                    FROM dd07t
                    INTO TABLE @li_status
                    WHERE domname = 'ZACG_ACC_REQ_ST'
                      AND ddlanguage = @sy-langu
                    ORDER BY domvalue_l.

                  SELECT domvalue_l,
                         ddtext
                    FROM dd07t
                    INTO TABLE @li_approver
                    WHERE domname = 'ZACG_APPROVER_ROLE'
                      AND ddlanguage = @sy-langu
                    ORDER BY domvalue_l.

                  LOOP AT li_req_aprover INTO lwa_req_aprover.

                    APPEND INITIAL LINE TO gt_outtab_9031 ASSIGNING <lfs_outtab_9031>.

                    <lfs_outtab_9031>-req_no        = lwa_req_aprover-req_no.
                    <lfs_outtab_9031>-role          = lwa_req_aprover-agr_name.
                    <lfs_outtab_9031>-user          = lwa_req_aprover-userid.
                    <lfs_outtab_9031>-begda         = lwa_req_aprover-begda.
                    <lfs_outtab_9031>-endda         = lwa_req_aprover-endda.
                    <lfs_outtab_9031>-status        = lwa_req_aprover-status.
                    <lfs_outtab_9031>-approver      = lwa_req_aprover-approver.
                    <lfs_outtab_9031>-app_role      = lwa_req_aprover-approver_role.
                    <lfs_outtab_9031>-action_taken  = lwa_req_aprover-action_taken.

                    READ TABLE li_status INTO lwa_status
                      WITH KEY domvalue_l = lwa_req_aprover-status BINARY SEARCH.
                    IF lwa_req_aprover-approver = sy-uname.
                      <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } as|.
                    ELSE.
                      IF lwa_req_aprover-status = '01' OR
                          lwa_req_aprover-status = '02'.
                        <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } with|.
                      ELSEIF lwa_req_aprover-status = '03' OR
                         lwa_req_aprover-status = '04'.
                        <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } by|.
                      ENDIF.
                    ENDIF.
                    CLEAR lwa_approver.
                    READ TABLE li_approver INTO lwa_approver
                          WITH KEY domvalue_l = lwa_req_aprover-approver_role BINARY SEARCH.
                    <lfs_outtab_9031>-statust  = |{ <lfs_outtab_9031>-statust } { lwa_approver-ddtext }|.
                    <lfs_outtab_9031>-ernam = lwa_req_aprover-aename.
                    <lfs_outtab_9031>-erdat = lwa_req_aprover-aedate.

                  ENDLOOP.

                  SORT gt_outtab_9031 BY req_no.

                ENDIF.

              ENDIF.

            ENDIF.

          ENDIF.

        ENDIF.

      ELSE.
        MESSAGE 'Please select the line you want to Reject' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.

    WHEN 'RANL'.

      o_grid_9031->get_selected_rows(
        IMPORTING
          et_index_rows = li_index_rows
          et_row_no     = li_row_no ).
      IF li_row_no IS NOT INITIAL.

        IF lines( li_row_no ) > 1 .

          MESSAGE 'Please select single role for Risk Analysis' TYPE 'S' DISPLAY LIKE 'E'.

        ELSE.

          READ TABLE li_row_no INTO lwa_row_no INDEX 1.
          READ TABLE gt_outtab_9031 INTO lwa_outtab_9031 INDEX lwa_row_no-row_id.
          IF sy-subrc IS INITIAL.

            IF lwa_outtab_9031-status = '02'.
              IF lwa_outtab_9031-app_role = '2' AND
                 lwa_outtab_9031-approver = sy-uname AND
                 lwa_outtab_9031-action_taken = space.

                SELECT *
                  FROM agr_users
                  INTO TABLE @DATA(li_exist_roles)
                  WHERE uname = @lwa_outtab_9031-user.

                SELECT *
                  FROM zacg_req_aprover
                  INTO TABLE @DATA(li_all_appr_roles)
*** Start of Change Rounak
*                  WHERE req_no = @lwa_outtab_9031-req_no
                  WHERE req_no = @lwa_outtab_9031-org_req_no
*** End of Change Rounak
                    AND approver_role = 2
                    AND status = 03
                    AND action_taken = @abap_true.

                LOOP AT li_all_appr_roles INTO DATA(lwa_all_appr_roles).
                  READ TABLE li_exist_roles INTO DATA(lwa_exist_roles)
                  WITH KEY agr_name = lwa_all_appr_roles-agr_name
                           uname    = lwa_all_appr_roles-userid
                           from_dat = lwa_all_appr_roles-begda
                           to_dat   = lwa_all_appr_roles-endda.
                  IF sy-subrc IS NOT INITIAL.
                    lv_message = |Role assignment is in progress for { lwa_all_appr_roles-agr_name }, please wait|.
                    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
                    EXIT.
                  ENDIF.
                ENDLOOP.

                IF lv_message IS INITIAL.
                  APPEND INITIAL LINE TO li_user_role
                  ASSIGNING FIELD-SYMBOL(<lfs_user_role>).
                  <lfs_user_role>-bname    = lwa_outtab_9031-user.
                  <lfs_user_role>-agr_name = lwa_outtab_9031-role.
                ENDIF.

              ELSE.
                lv_message = |You are not the Role Owner for { lwa_outtab_9031-req_no }|.
                MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
                EXIT.
              ENDIF.
            ELSE.
              lv_message = |Risk Analysis is not available for { lwa_outtab_9031-req_no }|.
              MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
              EXIT.
            ENDIF.

            g_request_number = lwa_outtab_9031-req_no.
            PERFORM enqueue_request USING g_request_number CHANGING lv_message.

          ENDIF.




          IF lv_message IS INITIAL.

            SELECT a~bname, b~agr_name, b~from_dat, b~to_dat
                    FROM usr02 AS a
                    INNER JOIN agr_users AS b
                    ON a~bname EQ b~uname
                    WHERE a~bname   = @lwa_outtab_9031-user
                      AND a~gltgv   <= @sy-datum
                      AND ( a~gltgb >= @sy-datum OR a~gltgb IS INITIAL )
                      AND a~ustyp IN ('A','S')
                      AND a~uflag IN (0,128)
                    INTO TABLE @DATA(li_user_role_exist).
            IF sy-subrc IS INITIAL.

              "Check if new request date fall in between existing roles period

              LOOP AT li_user_role_exist ASSIGNING FIELD-SYMBOL(<lfs_user_role_exist>).
                CLEAR lv_common.
                IF lwa_outtab_9031-begda BETWEEN <lfs_user_role_exist>-from_dat
                                             AND <lfs_user_role_exist>-to_dat.
                  lv_common = abap_true.
                ENDIF.
                IF lwa_outtab_9031-endda BETWEEN <lfs_user_role_exist>-from_dat
                                             AND <lfs_user_role_exist>-to_dat.
                  lv_common = abap_true.
                ENDIF.
                IF lv_common = abap_false.
                  CLEAR <lfs_user_role_exist>-bname.
                ENDIF.
              ENDLOOP.

              DELETE li_user_role_exist WHERE bname IS INITIAL.

              LOOP AT li_user_role_exist INTO DATA(lwa_user_role_exist).
                APPEND INITIAL LINE TO li_user_role ASSIGNING <lfs_user_role>.
                <lfs_user_role>-bname    = lwa_user_role_exist-bname.
                <lfs_user_role>-agr_name = lwa_user_role_exist-agr_name.
              ENDLOOP.

            ENDIF.

            SORT li_user_role BY bname agr_name.
            DELETE ADJACENT DUPLICATES FROM li_user_role COMPARING bname agr_name.

            CLEAR i_summary_9031.
            CALL FUNCTION 'ZACG_RISK_USERS' DESTINATION 'NONE'
              EXPORTING
                it_user_role    = li_user_role
                iv_summary      = abap_true
              IMPORTING
                et_risk_summary = i_summary_9031.

            SELECT SINGLE *
              FROM zacg_req_aprover
              INTO @lwa_req_aprover
*** Start of Change by Rounak
*              WHERE req_no   = @lwa_outtab_9031-req_no
              WHERE req_no   = @lwa_outtab_9031-org_req_no
*** End of Chnage by Rounak
                AND approver = @lwa_outtab_9031-approver
                AND agr_name = @lwa_outtab_9031-role
                AND begda    = @lwa_outtab_9031-begda
                AND endda    = @lwa_outtab_9031-endda
                AND approver_role = 2
                AND action_taken  = @space.

            LOOP AT i_summary_9031 INTO DATA(lwa_summary_9031).
              APPEND INITIAL LINE TO lt_risk ASSIGNING FIELD-SYMBOL(<lfs_risk>).
              <lfs_risk>-risk = lwa_summary_9031-risk.
            ENDLOOP.
            SORT lt_risk.
            DELETE lt_risk WHERE risk IS INITIAL.
            DELETE ADJACENT DUPLICATES FROM lt_risk.
            IF lt_risk IS NOT INITIAL.
              SELECT *
                FROM zacg_mitg_log
                INTO TABLE @DATA(li_mitg_log)
              FOR ALL ENTRIES IN @lt_risk
              WHERE risk = @lt_risk-risk.
              IF sy-subrc IS INITIAL.
                SORT li_mitg_log BY userid risk seqnr DESCENDING.
                DELETE ADJACENT DUPLICATES FROM li_mitg_log COMPARING userid risk.
              ENDIF.
            ENDIF.


            READ TABLE i_summary_9031 TRANSPORTING NO FIELDS
            WITH KEY composite = lwa_outtab_9031-role.
            IF sy-subrc IS NOT INITIAL.
              READ TABLE i_summary_9031 TRANSPORTING NO FIELDS
              WITH KEY agr_name = lwa_outtab_9031-role.
              IF sy-subrc IS NOT INITIAL.
                APPEND INITIAL LINE TO i_summary_9031 ASSIGNING FIELD-SYMBOL(<lfs_summary_9031>).
                <lfs_summary_9031>-user     = lwa_outtab_9031-user.
                <lfs_summary_9031>-agr_name = lwa_outtab_9031-role.
              ENDIF.
            ENDIF.

            SORT i_summary_9031.
            DELETE ADJACENT DUPLICATES FROM i_summary_9031 COMPARING ALL FIELDS.

            CLEAR i_outtab_8007.
            LOOP AT i_summary_9031 INTO lwa_summary_9031.

              APPEND INITIAL LINE TO i_outtab_8007 ASSIGNING
              FIELD-SYMBOL(<lfs_outtab_8007>).
              MOVE-CORRESPONDING lwa_summary_9031 TO <lfs_outtab_8007>.
              <lfs_outtab_8007>-req_no = lwa_outtab_9031-req_no.
              IF lwa_summary_9031-composite IS NOT INITIAL.
                <lfs_outtab_8007>-agr_name = lwa_summary_9031-composite.
              ENDIF.
              IF <lfs_outtab_8007>-agr_name = lwa_req_aprover-agr_name.
                <lfs_outtab_8007>-approver = lwa_req_aprover-approver.
                <lfs_outtab_8007>-reqtype  = 'New Role'.
                <lfs_outtab_8007>-begda    = lwa_req_aprover-begda.
                <lfs_outtab_8007>-endda    = lwa_req_aprover-endda.
              ELSE.
                <lfs_outtab_8007>-reqtype  = 'Existing Role'.
              ENDIF.

              READ TABLE li_mitg_log INTO DATA(lwa_mitg_log)
              WITH KEY userid = lwa_summary_9031-user
                       risk   = lwa_summary_9031-risk.
              IF sy-subrc IS INITIAL.
                <lfs_outtab_8007>-mowner = lwa_mitg_log-owner.
              ENDIF.

              IF <lfs_outtab_8007>-risk IS INITIAL.
                <lfs_outtab_8007>-risk = 'No Risk'.
              ENDIF.

            ENDLOOP.

            DELETE i_outtab_8007 WHERE reqtype  = 'Existing Role'.

            SORT i_outtab_8007.
            DELETE ADJACENT DUPLICATES FROM i_outtab_8007 COMPARING ALL FIELDS.
            CALL SCREEN 8007.

          ENDIF.

        ENDIF.

      ELSE.

        MESSAGE 'Please select the line for Risk Analysis' TYPE 'S' DISPLAY LIKE 'E'.

      ENDIF.

    WHEN 'DELA'. "Delegation of Manager
      o_grid_9031->get_selected_rows(
        IMPORTING
          et_index_rows = li_index_rows
          et_row_no     = li_row_no ).

      LOOP AT li_row_no INTO lwa_row_no. " Loop at selected line
        CLEAR lwa_outtab_9031.
        READ TABLE gt_outtab_9031 INTO lwa_outtab_9031 INDEX lwa_row_no-row_id.
        IF sy-subrc IS INITIAL.

        ENDIF.
      ENDLOOP.

      PERFORM authority_check USING 'ADRQ' CHANGING lv_valid. " SAdmin authorization for delation
      IF sy-subrc IS INITIAL.

      ELSE.
        PERFORM authority_check USING 'ADRQ' CHANGING lv_valid. " Individual authorization for dekegation

      ENDIF.




    WHEN 'DELO'. " Delegation of Rolw Owner
      o_grid_9031->get_selected_rows(
        IMPORTING
          et_index_rows = li_index_rows
          et_row_no     = li_row_no ).

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_8007
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_8007.

  DATA:
    lw_layout TYPE lvc_s_layo,
    li_fcat   TYPE lvc_t_fcat.

  LOOP AT i_outtab_8007 ASSIGNING FIELD-SYMBOL(<lfs_outtab_8007>).
    IF <lfs_outtab_8007>-reqtype = 'Existing Role'.
      CLEAR: <lfs_outtab_8007>-req_no, <lfs_outtab_8007>-approver.
    ENDIF.
  ENDLOOP.


  CREATE OBJECT o_conttainer_8007
    EXPORTING
      container_name = 'CC_8007'.

  CREATE OBJECT o_grid_8007
    EXPORTING
      i_parent = o_conttainer_8007.

  lw_layout-zebra      = abap_true.
  lw_layout-cwidth_opt = abap_true.
  lw_layout-box_fname  = 'SEL'.
  lw_layout-sel_mode   = 'A'.


  PERFORM build_fact CHANGING li_fcat.

  g_8007_first = abap_true.
  CALL METHOD o_grid_8007->set_table_for_first_display
    EXPORTING
      is_layout       = lw_layout
    CHANGING
      it_outtab       = i_outtab_8007
      it_fieldcatalog = li_fcat.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_8007
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_8007.

  g_ucomm = sy-ucomm.
  CASE g_ucomm.
    WHEN 'BACK' OR 'EXIT'.
      CLEAR: g_ucomm.
      PERFORM dequeue_request USING g_request_number.
      CLEAR g_request_number.
      LEAVE TO SCREEN 0.
    WHEN '&APR'.
      PERFORM approve_after_risk_analysis.
    WHEN '&RJT'.
      PERFORM reject_after_risk_anaysis.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form build_fact
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LI_FCAT
*&---------------------------------------------------------------------*
FORM build_fact  CHANGING p_li_fcat TYPE lvc_t_fcat.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING FIELD-SYMBOL(<lfs_fcat>).
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'REQ_NO'.
  <lfs_fcat>-coltext   = 'Request No'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'USER'.
  <lfs_fcat>-coltext   = 'Requested For'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'AGR_NAME'.
  <lfs_fcat>-coltext   = 'Requested Role'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'APPROVER'.
  <lfs_fcat>-coltext   = 'Role Owner'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'BEGDA'.
  <lfs_fcat>-coltext   = 'Requested Start Date'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'ENDDA'.
  <lfs_fcat>-coltext   = 'Requested End Date'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'MOWNER'.
  <lfs_fcat>-coltext   = 'Mitigation Owner'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-key       = abap_true.
  <lfs_fcat>-fieldname = 'RISK'.
  <lfs_fcat>-coltext   = 'Risk ID'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-fieldname = 'RISKD'.
  <lfs_fcat>-coltext   = 'Description'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-fieldname = 'LEVELD'.
  <lfs_fcat>-coltext   = 'Severity'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-fieldname = 'TYPED'.
  <lfs_fcat>-coltext   = 'Risk Type'.
  <lfs_fcat>-col_opt   = abap_true.

  APPEND INITIAL LINE TO p_li_fcat ASSIGNING <lfs_fcat>.
  <lfs_fcat>-fieldname = 'MODULED'.
  <lfs_fcat>-coltext   = 'Process Area'.
  <lfs_fcat>-col_opt   = abap_true.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form populate_data_7001
*&---------------------------------------------------------------------*
*& Builds the "new request" role table (I_OUTTAB_7001) on screen 7001
*& from the roles selected in S_NROLE, defaulting validity to
*& today..9999-12-31, and refreshes the table-control line count.
*&---------------------------------------------------------------------*
FORM populate_data_7001 .

  LOOP AT s_nrole[] INTO s_nrole.
    READ TABLE i_outtab_7001 TRANSPORTING NO FIELDS
    WITH KEY role = s_nrole-low.
    IF sy-subrc IS NOT INITIAL.
      APPEND INITIAL LINE TO i_outtab_7001
      ASSIGNING FIELD-SYMBOL(<lfs_outtab_7001>).
      <lfs_outtab_7001>-role = s_nrole-low.
      <lfs_outtab_7001>-begda = sy-datum.
      <lfs_outtab_7001>-endda = '99991231'.
    ENDIF.
  ENDLOOP.
  table_7001-lines = lines( i_outtab_7001 ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form raise_new_request
*&---------------------------------------------------------------------*
*& Raises a new role access request.
*&
*& Draws a request number from number-range object ZACG_RREQ
*& (NUMBER_GET_NEXT), determines the requester's line manager from
*& ZACG_MANAGER, and writes one approver row per requested role into
*& ZACG_REQ_APROVER (status '02' = pending, manager as first approver),
*& then commits. Finally triggers asynchronous notification
*& (ZACG_NOTIFY_USERS_FOR_ROLE_REQ, action 'RQ').
*& Side effect: inserts request/approver rows in the database.
*&---------------------------------------------------------------------*
FORM raise_new_request .

  DATA:

    lv_nrnr        TYPE nrnr VALUE '01',
    lv_object      TYPE nrobj VALUE 'ZACG_RREQ',
    lv_new_number  TYPE zacg_req,
    lv_message     TYPE string,
    lv_new_request TYPE zacg_acc_req,

    li_req_aprover TYPE STANDARD TABLE OF zacg_req_aprover.

  SELECT agr_name
    FROM agr_define
    INTO TABLE @DATA(li_agr)
    WHERE agr_name IN @s_nrole[].

  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr             = lv_nrnr
      object                  = lv_object
    IMPORTING
      number                  = lv_new_number
    EXCEPTIONS
      interval_not_found      = 1
      number_range_not_intern = 2
      object_not_found        = 3
      quantity_is_0           = 4
      quantity_is_not_1       = 5
      interval_overflow       = 6
      buffer_overflow         = 7
      OTHERS                  = 8.
  IF sy-subrc = 0.

    lv_new_request = |NRQ{ lv_new_number }|.

    SELECT SINGLE manager
      FROM zacg_manager
      INTO @DATA(lv_manager)
      WHERE userid = @p_nuser.

    LOOP AT li_agr INTO DATA(lwa_agr).

      APPEND INITIAL LINE TO li_req_aprover ASSIGNING FIELD-SYMBOL(<lfs_req_aprover>).
      <lfs_req_aprover>-req_no        = lv_new_request.
      <lfs_req_aprover>-agr_name      = lwa_agr-agr_name.
      <lfs_req_aprover>-seqnr         = 1.
      <lfs_req_aprover>-userid        = p_nuser.
      <lfs_req_aprover>-approver      = lv_manager.
      <lfs_req_aprover>-approver_role = 1.
      <lfs_req_aprover>-status        = '02'.
      <lfs_req_aprover>-aename        = sy-uname.
      <lfs_req_aprover>-aedate        = sy-datum.
      <lfs_req_aprover>-aetim         = sy-uzeit.

      READ TABLE i_outtab_7001 INTO DATA(lwa_outtab_7001)
      WITH KEY role = <lfs_req_aprover>-agr_name.
      IF sy-subrc IS INITIAL.
        <lfs_req_aprover>-begda = lwa_outtab_7001-begda.
        <lfs_req_aprover>-endda = lwa_outtab_7001-endda.
      ENDIF.

    ENDLOOP.

    MODIFY zacg_req_aprover FROM TABLE li_req_aprover.
    COMMIT WORK.

    CALL FUNCTION 'ZACG_NOTIFY_USERS_FOR_ROLE_REQ' STARTING NEW TASK 'TASK01'
      EXPORTING
        iv_action  = 'RQ'
        iv_request = lv_new_request.

    lv_message = |{ lv_new_request } has been initiated|.
    MESSAGE lv_message TYPE 'S'.

  ELSE.

    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_message.
    lv_message = |'Tech Error: { lv_message }|.
    MESSAGE lv_message TYPE 'E'.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_7001
*&---------------------------------------------------------------------*
*& Validates a single new-request row (screen 7001) before it is added:
*& checks the From/To dates (present, not in the past, From <= To), that
*& there is no pending/open request for the same role+user+period
*& (ZACG_REQ_APROVER) and that the role is not already assigned to the
*& user for an overlapping period (AGR_USERS). Raises an error and keeps
*& the cursor on the offending field otherwise.
*&---------------------------------------------------------------------*
FORM validate_7001.

  MODIFY i_outtab_7001 FROM wa_outtab_7001 INDEX table_7001-current_line.
  CHECK sy-ucomm = 'OKAY'.

  IF wa_outtab_7001-begda IS INITIAL.
    SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
    CLEAR sy-ucomm.
    MESSAGE 'Provide Valid From Date' TYPE 'E'.
  ELSE.
    IF wa_outtab_7001-begda < sy-datum.
      SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
      CLEAR sy-ucomm.
      MESSAGE 'Valid From Date can not be in the past' TYPE 'E'.
    ELSE.
      IF wa_outtab_7001-endda IS INITIAL.
        SET CURSOR FIELD 'WA_OUTTAB_7001-ENDDA'.
        CLEAR sy-ucomm.
        MESSAGE 'Provide Valid To Date' TYPE 'E'.
      ELSE.
        IF wa_outtab_7001-begda GT wa_outtab_7001-endda.
          SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
          CLEAR sy-ucomm.
          MESSAGE 'Valid To Date should be greater than Valid From Date' TYPE 'E'.
        ENDIF.
      ENDIF.
    ENDIF.

    SELECT SINGLE *
      FROM zacg_req_aprover
      INTO @DATA(lwa_open_request)
      WHERE agr_name = @wa_outtab_7001-role
        AND userid = @p_nuser
        AND action_taken = @space.
    IF sy-subrc IS INITIAL.
      IF wa_outtab_7001-begda >= lwa_open_request-begda AND
         wa_outtab_7001-begda <= lwa_open_request-endda.
        SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
        CLEAR sy-ucomm.
        DATA(lv_message) = |Open Request { lwa_open_request-req_no } is pending. New Request is not allowed'|.
        MESSAGE lv_message TYPE 'E'.

      ELSEIF wa_outtab_7001-endda <= lwa_open_request-endda AND
             wa_outtab_7001-endda >= lwa_open_request-begda.
        SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
        CLEAR sy-ucomm.
        lv_message = |Open Request { lwa_open_request-req_no } is pending. New Request is not allowed'|.
        MESSAGE lv_message TYPE 'E'.

      ELSEIF wa_outtab_7001-begda <= lwa_open_request-begda AND
             wa_outtab_7001-endda >= lwa_open_request-endda.
        SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
        CLEAR sy-ucomm.
        lv_message = |Open Request { lwa_open_request-req_no } is pending. New Request is not allowed'|.
        MESSAGE lv_message TYPE 'E'.

      ENDIF.

    ENDIF.

    SELECT agr_name, from_dat, to_dat
    FROM agr_users
    WHERE agr_name = @wa_outtab_7001-role
      AND uname    = @p_nuser
    INTO TABLE @DATA(li_existing_role).
    LOOP AT li_existing_role INTO DATA(lwa_existing_role).

      IF wa_outtab_7001-begda >= lwa_existing_role-from_dat AND
         wa_outtab_7001-begda <= lwa_existing_role-to_dat.
        SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
        CLEAR sy-ucomm.
        lv_message = |Role { wa_outtab_7001-role } is already assigned to User { p_nuser }. New Request is not allowed'|.
        MESSAGE lv_message TYPE 'E'.

      ELSEIF wa_outtab_7001-endda <= lwa_existing_role-to_dat AND
             wa_outtab_7001-endda >= lwa_existing_role-from_dat.
        SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
        CLEAR sy-ucomm.
        lv_message = |Role { wa_outtab_7001-role } is already assigned to User { p_nuser }. New Request is not allowed'|.
        MESSAGE lv_message TYPE 'E'.

      ELSEIF wa_outtab_7001-begda <= lwa_existing_role-from_dat AND
             wa_outtab_7001-endda >= lwa_existing_role-to_dat.
        SET CURSOR FIELD 'WA_OUTTAB_7001-BEGDA'.
        CLEAR sy-ucomm.
        lv_message = |Role { wa_outtab_7001-role } is already assigned to User { p_nuser }. New Request is not allowed'|.
        MESSAGE lv_message TYPE 'E'.

      ENDIF.

    ENDLOOP.

  ENDIF.




ENDFORM.
*&---------------------------------------------------------------------*
*& Form approve_after_risk_analysis
*&---------------------------------------------------------------------*
*& Role-owner approval step (from the risk-analysis grid, screen 8007).
*&
*& Validates that the current user (SY-UNAME) is the approver for each
*& selected role, gathers the residual SoD risks for those roles and, if
*& any risk remains, opens the mitigation pop-up (screen 7002) to capture
*& mitigation; otherwise flags the request as mitigated. Prepares
*& I_OUTTAB_7002 (user / risk / mitigation owner) for that pop-up.
*&---------------------------------------------------------------------*
FORM approve_after_risk_analysis.



  DATA: lv_message TYPE string,
        lr_role    TYPE RANGE OF agr_name,
        li_8007    TYPE STANDARD TABLE OF ty_8007.


  o_grid_8007->get_selected_rows(
    IMPORTING
      et_index_rows = DATA(li_index_rows)
      et_row_no     = DATA(li_row_no) ).

  CLEAR: i_outtab_8007_sel_line, i_outtab_7002.

  IF li_row_no IS NOT INITIAL.
    LOOP AT li_row_no INTO DATA(lwa_row_no).
      READ TABLE i_outtab_8007 INTO DATA(lwa_outtab_8007) INDEX lwa_row_no-row_id.
      IF sy-subrc IS INITIAL.
        IF lwa_outtab_8007-approver NE sy-uname.
          lv_message = 'You do not have authorisation to approve the role'.
          lv_message = |{ lv_message } { lwa_outtab_8007-agr_name }|.
          MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
          CLEAR i_outtab_8007_sel_line.
          EXIT.
        ELSE.
          APPEND INITIAL LINE TO li_8007 ASSIGNING FIELD-SYMBOL(<lfs_8007>).
          <lfs_8007>-request  = lwa_outtab_8007-req_no.
          <lfs_8007>-user     = lwa_outtab_8007-user.
          <lfs_8007>-risk     = lwa_outtab_8007-risk.
          <lfs_8007>-owner    = lwa_outtab_8007-mowner.
          <lfs_8007>-role     = lwa_outtab_8007-agr_name.
          <lfs_8007>-approver = lwa_outtab_8007-approver.
        ENDIF.
      ENDIF.
    ENDLOOP.


    IF lv_message IS INITIAL.
      i_outtab_8007_sel_line = li_8007.
      SORT i_outtab_8007_sel_line BY role.
      DELETE ADJACENT DUPLICATES FROM i_outtab_8007_sel_line COMPARING role.
      SORT li_8007.
      DELETE ADJACENT DUPLICATES FROM li_8007 COMPARING ALL FIELDS.
      READ TABLE li_8007 INTO DATA(lwa_8007) INDEX 1.
      IF sy-subrc IS INITIAL.
        lr_role = VALUE #( FOR lwa_role IN li_8007 (
                            sign = 'I'
                            option = 'EQ'
                            low = lwa_role-role ) ).
        DELETE lr_role WHERE low IS INITIAL.
        SORT lr_role.
        DELETE ADJACENT DUPLICATES FROM lr_role COMPARING ALL FIELDS.

        SELECT req_no, user, risk, mowner, agr_name
          FROM @i_outtab_8007 AS all_risk
          WHERE agr_name IN @lr_role
          INTO TABLE @DATA(li_outtab_8007).
        IF sy-subrc IS INITIAL.

        ENDIF.

        SORT li_outtab_8007.
        DELETE ADJACENT DUPLICATES FROM li_outtab_8007 COMPARING ALL FIELDS.

        SELECT *
          FROM zacg_req_aprover
          INTO TABLE @DATA(li_approver_8007)
          WHERE req_no = @lwa_8007-request
            AND approver = @sy-uname
            AND approver_role = 2
            AND action_taken = @space.
        IF sy-subrc IS INITIAL.
          LOOP AT li_outtab_8007 INTO DATA(lwa_outtab).
            READ TABLE li_approver_8007 TRANSPORTING NO FIELDS
            WITH KEY req_no = lwa_outtab-req_no
                     agr_name = lwa_outtab-agr_name.
            IF sy-subrc IS INITIAL.
              APPEND INITIAL LINE TO i_outtab_7002 ASSIGNING FIELD-SYMBOL(<lfs_outtab_7002>).
              <lfs_outtab_7002>-userid = lwa_outtab-user.
              <lfs_outtab_7002>-risk   = lwa_outtab-risk.
              <lfs_outtab_7002>-owner  = lwa_outtab-mowner.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.

      SORT i_outtab_7002 BY userid risk owner.
      DELETE ADJACENT DUPLICATES FROM i_outtab_7002 COMPARING ALL FIELDS.
      DELETE i_outtab_7002 WHERE risk IS INITIAL.
      DELETE i_outtab_7002 WHERE risk = 'No Risk'.
      SORT i_outtab_7002 BY userid owner DESCENDING risk.

      IF i_outtab_7002 IS NOT INITIAL.
        CALL SCREEN 7002 STARTING AT 40 8 ENDING AT 99 15.
      ELSE.
        g_mitigated = abap_true.
        PERFORM assign_after_popup.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE 'Please select atleast one line to approve' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_7002
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_7002 .
  MODIFY i_outtab_7002 FROM wa_outtab_7002 INDEX table_7002-current_line.

  CHECK sy-ucomm = 'OKAY'.

  IF wa_outtab_7002-owner IS INITIAL.
    CLEAR sy-ucomm.
    SET CURSOR FIELD 'WA_OUTTAB_7002-OWNER'.
    MESSAGE 'Provide Mitigation Owner' TYPE 'E'.
  ELSE.
    SELECT SINGLE bname
      FROM zacg_mitg_owners
      INTO @DATA(lv_mowner)
      WHERE bname = @wa_outtab_7002-owner.
    IF sy-subrc IS NOT INITIAL.
      CLEAR sy-ucomm.
      SET CURSOR FIELD 'WA_OUTTAB_7002-OWNER'.
      DATA(lv_message) = |'Mitigation Owner' { wa_outtab_7002-owner } 'is invalid'|.
      MESSAGE lv_message TYPE 'E'.
    ELSE.

    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form assign_after_popup
*&---------------------------------------------------------------------*
*& Finalises role-owner approval after the mitigation pop-up (screen
*& 7002).
*&
*& Marks the matching ZACG_REQ_APROVER rows as actioned (ACTION_TAKEN,
*& status '03', next sequence number), writes/updates mitigation records
*& in ZACG_MITG_LOG (new entry on owner change or first mitigation), and
*& triggers the workflow notification (ZACG_NOTIFY_USERS_FOR_ROLE_REQ,
*& action 'RA') with the approved roles and mitigation owners.
*& Runs only when g_mitigated is set.
*& Side effect: updates approver and mitigation-log tables.
*&---------------------------------------------------------------------*
FORM assign_after_popup .

  DATA:
    lv_message        TYPE string,
    li_mit_log_upd    TYPE STANDARD TABLE OF zacg_mitg_log,
    li_approver_upd   TYPE STANDARD TABLE OF zacg_req_aprover,
    li_mitigation     TYPE zacg_t_mitigation_owner,
    li_approved_roles TYPE zacg_t_requested_roles.

  CHECK g_mitigated IS NOT INITIAL.
  READ TABLE i_outtab_8007_sel_line INTO DATA(lwa_outtab_8007_sel_line) INDEX 1.
  SELECT *
    FROM zacg_mitg_log
    INTO TABLE @DATA(li_mit_log)
    WHERE userid = @lwa_outtab_8007_sel_line-user.
  IF sy-subrc IS INITIAL.
    SORT li_mit_log BY userid risk seqnr DESCENDING.
    DELETE ADJACENT DUPLICATES FROM li_mit_log COMPARING userid risk.
  ENDIF.

  SELECT *
    FROM zacg_req_aprover
    INTO TABLE @DATA(li_req_approver)
    FOR ALL ENTRIES IN @i_outtab_8007_sel_line
    WHERE req_no        = @i_outtab_8007_sel_line-request
      AND agr_name      = @i_outtab_8007_sel_line-role
      AND approver_role = 2
      AND action_taken  = @space
      AND approver      = @sy-uname.
  LOOP AT li_req_approver ASSIGNING FIELD-SYMBOL(<lfs_req_approver>).
    <lfs_req_approver>-action_taken = abap_true.
    APPEND INITIAL LINE TO li_approver_upd ASSIGNING FIELD-SYMBOL(<lfs_approver_upd>).
    <lfs_approver_upd> = <lfs_req_approver>.
    <lfs_approver_upd>-status = '03'.
    <lfs_approver_upd>-seqnr  = <lfs_req_approver>-seqnr + 1.
    <lfs_approver_upd>-aename = sy-uname.
    <lfs_approver_upd>-aedate = sy-datum.
    <lfs_approver_upd>-aetim  = sy-uzeit.

    lv_message = |{ lv_message }, { <lfs_req_approver>-agr_name }|.

    CLEAR lwa_outtab_8007_sel_line.
    READ TABLE i_outtab_8007_sel_line INTO lwa_outtab_8007_sel_line WITH KEY
    role     = <lfs_req_approver>-agr_name
    approver = sy-uname.
    IF sy-subrc IS INITIAL.
      LOOP AT i_outtab_8007 INTO DATA(lwa_outtab_8007) WHERE
        agr_name = lwa_outtab_8007_sel_line-role AND
        approver = lwa_outtab_8007_sel_line-approver.
        READ TABLE li_mit_log INTO DATA(lwa_mit_log)
        WITH KEY userid = lwa_outtab_8007-user
                 risk   = lwa_outtab_8007-risk.
        IF sy-subrc IS INITIAL.
          READ TABLE i_outtab_7002 INTO DATA(lwa_outtab_7002) WITH KEY
          userid = <lfs_req_approver>-userid
          risk = lwa_outtab_8007-risk.
          IF sy-subrc IS INITIAL.
            IF lwa_outtab_7002-owner NE lwa_mit_log-owner.
              READ TABLE li_mit_log_upd TRANSPORTING NO FIELDS
              WITH KEY userid = <lfs_req_approver>-userid
                       risk   = lwa_outtab_7002-risk
                       owner  = lwa_outtab_7002-owner.
              IF sy-subrc IS NOT INITIAL.
                " If Owner Change then new Entry
                APPEND INITIAL LINE TO li_mit_log_upd ASSIGNING FIELD-SYMBOL(<lfs_mit_log_upd>).
                <lfs_mit_log_upd>-req_no  = <lfs_req_approver>-req_no.
                <lfs_mit_log_upd>-userid  = lwa_outtab_7002-userid.
                <lfs_mit_log_upd>-risk    = lwa_outtab_7002-risk.
                <lfs_mit_log_upd>-seqnr   = lwa_mit_log-seqnr + 1.
                <lfs_mit_log_upd>-owner   = lwa_outtab_7002-owner.
                <lfs_mit_log_upd>-begda   = lwa_outtab_8007-begda.
                <lfs_mit_log_upd>-endda   = lwa_outtab_8007-endda.
                <lfs_mit_log_upd>-erdat   = sy-datum.
                <lfs_mit_log_upd>-ernam   = sy-uname.
              ENDIF.
            ENDIF.
          ENDIF.
        ELSE.
          CLEAR lwa_outtab_7002.
          READ TABLE i_outtab_7002 INTO lwa_outtab_7002 WITH KEY
          userid = <lfs_req_approver>-userid
          risk = lwa_outtab_8007-risk.
          IF sy-subrc IS INITIAL.
            READ TABLE li_mit_log_upd TRANSPORTING NO FIELDS
            WITH KEY userid = <lfs_req_approver>-userid
                     risk   = lwa_outtab_7002-risk
                     owner  = lwa_outtab_7002-owner.
            IF sy-subrc IS NOT INITIAL.
              " Fresh Entry
              APPEND INITIAL LINE TO li_mit_log_upd ASSIGNING <lfs_mit_log_upd>.
              <lfs_mit_log_upd>-req_no  = <lfs_req_approver>-req_no.
              <lfs_mit_log_upd>-userid  = lwa_outtab_7002-userid.
              <lfs_mit_log_upd>-risk    = lwa_outtab_7002-risk.
              <lfs_mit_log_upd>-seqnr   = 001.
              <lfs_mit_log_upd>-owner   = lwa_outtab_7002-owner.
              <lfs_mit_log_upd>-begda   = lwa_outtab_8007-begda.
              <lfs_mit_log_upd>-endda   = lwa_outtab_8007-endda.
              <lfs_mit_log_upd>-erdat   = sy-datum.
              <lfs_mit_log_upd>-ernam   = sy-uname.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDLOOP.

    ENDIF.
  ENDLOOP.


  LOOP AT i_outtab_8007 ASSIGNING FIELD-SYMBOL(<lfs_outtab_8007>).
    READ TABLE li_mit_log_upd INTO DATA(lwa_mit_log_upd) WITH KEY
    risk = <lfs_outtab_8007>-risk.
    IF sy-subrc IS INITIAL.
      <lfs_outtab_8007>-mowner = lwa_mit_log_upd-owner.
    ENDIF.
  ENDLOOP.


  IF li_approver_upd IS NOT INITIAL.
    APPEND LINES OF li_approver_upd TO li_req_approver.
    MODIFY zacg_req_aprover FROM TABLE li_req_approver.
    MODIFY zacg_mitg_log FROM TABLE li_mit_log_upd.

    " Trigger Workflow.
    CLEAR: lwa_outtab_7002, lwa_outtab_8007_sel_line.
    LOOP AT i_outtab_7002 INTO lwa_outtab_7002.
      APPEND INITIAL LINE TO li_mitigation ASSIGNING FIELD-SYMBOL(<lfs_mitigation>).
      <lfs_mitigation>-risk  = lwa_outtab_7002-risk.
      <lfs_mitigation>-owner = lwa_outtab_7002-owner.
    ENDLOOP.

    LOOP AT i_outtab_8007_sel_line INTO lwa_outtab_8007_sel_line.
      APPEND INITIAL LINE TO li_approved_roles ASSIGNING FIELD-SYMBOL(<lfs_approved_roles>).
      <lfs_approved_roles>-role = lwa_outtab_8007_sel_line-role.
    ENDLOOP.
    SORT li_approved_roles BY role.
    DELETE ADJACENT DUPLICATES FROM li_approved_roles COMPARING role.

    CALL FUNCTION 'ZACG_NOTIFY_USERS_FOR_ROLE_REQ'
      EXPORTING
        iv_action         = 'RA'
        iv_request        = lwa_outtab_8007_sel_line-request
        it_mitigation     = li_mitigation
        it_approved_roles = li_approved_roles.

    SHIFT lv_message LEFT DELETING LEADING space.
    SHIFT lv_message LEFT DELETING LEADING ','.
    lv_message = |Role { lv_message } successfully approved|.
    MESSAGE lv_message TYPE 'S'.

  ENDIF.




ENDFORM.
*&---------------------------------------------------------------------*
*& Form reject_after_risk_anaysis
*&---------------------------------------------------------------------*
*& Rejection counterpart of approve_after_risk_analysis (from the
*& risk-analysis grid, screen 8007).
*&
*& Validates the current user is the approver, collects the selected
*& roles into I_OUTTAB_7003 and opens the rejection-reason pop-up
*& (screen 7003). The actual rejection is committed in reject_after_popup.
*&---------------------------------------------------------------------*
FORM reject_after_risk_anaysis .

  TYPES: BEGIN OF lty_8007,
           request TYPE zacg_acc_req,
           role    TYPE agr_name,
         END OF lty_8007.

  DATA: lv_message TYPE string,
        lr_role    TYPE RANGE OF agr_name,
        li_8007    TYPE STANDARD TABLE OF lty_8007.


  o_grid_8007->get_selected_rows(
    IMPORTING
      et_index_rows = DATA(li_index_rows)
      et_row_no     = DATA(li_row_no) ).

  CLEAR i_outtab_7003.

  IF li_row_no IS NOT INITIAL.
    LOOP AT li_row_no INTO DATA(lwa_row_no).
      READ TABLE i_outtab_8007 INTO DATA(lwa_outtab_8007) INDEX lwa_row_no-row_id.
      IF sy-subrc IS INITIAL.
        IF lwa_outtab_8007-approver NE sy-uname.
          lv_message = 'You do not have authorisation to reject the role'.
          lv_message = |{ lv_message } { lwa_outtab_8007-agr_name }|.
          MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
          EXIT.
        ELSE.
          APPEND INITIAL LINE TO li_8007 ASSIGNING FIELD-SYMBOL(<lfs_8007>).
          <lfs_8007>-request = lwa_outtab_8007-req_no.
          <lfs_8007>-role = lwa_outtab_8007-agr_name.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lv_message IS INITIAL.
      SORT li_8007.
      DELETE ADJACENT DUPLICATES FROM li_8007 COMPARING ALL FIELDS.
      READ TABLE li_8007 INTO DATA(lwa_8007) INDEX 1.
      IF sy-subrc IS INITIAL.
        lr_role = VALUE #( FOR lwa_role IN li_8007 (
                            sign = 'I'
                            option = 'EQ'
                            low = lwa_role-role ) ).
        DELETE lr_role WHERE low IS INITIAL.
        SORT lr_role.
        DELETE ADJACENT DUPLICATES FROM lr_role COMPARING ALL FIELDS.

        SELECT req_no, agr_name
          FROM @i_outtab_8007 AS all_risk
          WHERE agr_name IN @lr_role
          INTO TABLE @DATA(li_outtab_8007).
        IF sy-subrc IS INITIAL.

        ENDIF.

        SORT li_outtab_8007.
        DELETE ADJACENT DUPLICATES FROM li_outtab_8007 COMPARING ALL FIELDS.

        SELECT *
          FROM zacg_req_aprover
          INTO TABLE @DATA(li_approver_8007)
          WHERE req_no = @lwa_8007-request
            AND approver = @sy-uname
            AND approver_role = 2
            AND action_taken = @space.
        IF sy-subrc IS INITIAL.
          LOOP AT li_outtab_8007 INTO DATA(lwa_outtab).
            READ TABLE li_approver_8007 TRANSPORTING NO FIELDS
            WITH KEY req_no = lwa_outtab-req_no
                     agr_name = lwa_outtab-agr_name.
            IF sy-subrc IS INITIAL.
              APPEND INITIAL LINE TO i_outtab_7003 ASSIGNING FIELD-SYMBOL(<lfs_outtab_7003>).
              <lfs_outtab_7003>-role = lwa_outtab-agr_name.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.

      SORT i_outtab_7003.
      DELETE ADJACENT DUPLICATES FROM i_outtab_7003 COMPARING ALL FIELDS.
      IF i_outtab_7003 IS NOT INITIAL.
        CALL SCREEN 7003 STARTING AT 40 8 ENDING AT 124 15.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE 'Please select atleast one line to reject' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form reject_after_popup
*&---------------------------------------------------------------------*
*& Commits the rejection captured on the screen-7003 pop-up.
*&
*& Marks the ZACG_REQ_APROVER row as actioned and inserts a follow-up row
*& with status 4 (rejected) and the rejection reason, commits, and
*& triggers the workflow notification (ZACG_NOTIFY_USERS_FOR_ROLE_REQ,
*& action 'RR') with the rejected roles.
*& Side effect: updates approver rows in the database.
*&---------------------------------------------------------------------*
FORM reject_after_popup.

  DATA:
    lv_message        TYPE string,
    lwa_req_aprover   TYPE zacg_req_aprover,
    li_req_aprover    TYPE STANDARD TABLE OF zacg_req_aprover,
    li_rejected_roles TYPE zacg_t_requested_roles.

  READ TABLE i_outtab_7003 INTO DATA(lwa_outtab_7003) INDEX 1.

  READ TABLE i_outtab_8007 INTO DATA(lwa_outtab_8007) WITH KEY
    agr_name = lwa_outtab_7003-role
    approver = sy-uname.
  IF sy-subrc IS INITIAL.
    SELECT SINGLE *
      FROM zacg_req_aprover
      INTO lwa_req_aprover
      WHERE req_no = lwa_outtab_8007-req_no
        AND agr_name = lwa_outtab_7003-role
        AND approver = sy-uname
        AND approver_role = 2
        AND status   = 2
        AND action_taken = abap_false.
    IF sy-subrc IS INITIAL.

      lwa_req_aprover-action_taken = abap_true.
      APPEND lwa_req_aprover TO li_req_aprover.

      lwa_req_aprover-seqnr  = lwa_req_aprover-seqnr + 1.
      lwa_req_aprover-status = 4.
      lwa_req_aprover-rj_rsn = lwa_outtab_7003-reason.
      lwa_req_aprover-aename = sy-uname.
      lwa_req_aprover-aedate = sy-datum.
      lwa_req_aprover-aetim  = sy-uzeit.
      APPEND lwa_req_aprover TO li_req_aprover.

      MODIFY zacg_req_aprover FROM TABLE li_req_aprover.
      COMMIT WORK AND WAIT.

      lv_message = |{ lwa_outtab_7003-role } has been rejected|.
      MESSAGE lv_message TYPE 'S'.

      CLEAR lwa_outtab_7003.
      LOOP AT i_outtab_7003 INTO lwa_outtab_7003.
        APPEND INITIAL LINE TO li_rejected_roles ASSIGNING FIELD-SYMBOL(<lfs_rejected_roles>).
        <lfs_rejected_roles>-role = lwa_outtab_7003-role.
      ENDLOOP.

      CALL FUNCTION 'ZACG_NOTIFY_USERS_FOR_ROLE_REQ'
        EXPORTING
          iv_action         = 'RR'
          iv_request        = lwa_outtab_8007-req_no
          it_rejected_roles = li_rejected_roles.

    ENDIF.
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_7003
*&---------------------------------------------------------------------*
*& Validates the rejection-reason pop-up row (screen 7003): the reason
*& must be supplied and at least 10 characters long. Saves the row back
*& to I_OUTTAB_7003.
*&---------------------------------------------------------------------*
FORM validate_7003 .
  MODIFY i_outtab_7003 FROM wa_outtab_7003 INDEX table_7003-current_line.

  CHECK sy-ucomm = 'OKAY'.

  IF wa_outtab_7003-reason IS INITIAL.
    CLEAR sy-ucomm.
    SET CURSOR FIELD 'WA_OUTTAB_7003-REASON'.
    MESSAGE 'Provide Rejection Reason' TYPE 'E'.
  ELSE.
    IF strlen( wa_outtab_7003-reason ) < 10.
      CLEAR sy-ucomm.
      SET CURSOR FIELD 'WA_OUTTAB_7003-REASON'.
      MESSAGE 'Rejection Reason must be of minimum 10 characters' TYPE 'E'.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form populate_data_9031
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM populate_data_9031 .

  TYPES:
    BEGIN OF lty_request,
      req_no   TYPE zacg_acc_req,
      agr_name TYPE agr_name,
    END OF lty_request,

    BEGIN OF lty_risk,
      risk TYPE zrisk,
    END OF lty_risk.

  DATA:
    lv_message     TYPE string,
    li_request     TYPE STANDARD TABLE OF lty_request,
    li_rolerequest TYPE STANDARD TABLE OF zacg_req_aprover,
    lr_request     TYPE RANGE OF zacg_acc_req,
    li_user_role   TYPE zacg_t_user_role,
    lt_risk        TYPE STANDARD TABLE OF lty_risk.

  IF r_preq = abap_true. " Request actions pending on me

    CLEAR gt_outtab_9031.
    SELECT *
      FROM zacg_req_aprover
      INTO TABLE @DATA(li_req_aprover)
      WHERE approver = @sy-uname
        AND status IN ('01','02')
        AND action_taken = @abap_false.
    IF sy-subrc IS NOT INITIAL.
      MESSAGE 'You do not have any pending request' TYPE 'S'.
    ENDIF.

  ELSEIF r_rreq = abap_true. " Request Raised by me

    CLEAR gt_outtab_9031.
    SELECT req_no
      FROM zacg_req_aprover
      INTO TABLE @li_request
      WHERE aename = @sy-uname
        AND seqnr = 001.
    IF sy-subrc IS NOT INITIAL.
      MESSAGE 'You have not raised any request' TYPE 'S'.
    ELSE.
      SORT li_request.
      DELETE ADJACENT DUPLICATES FROM li_request.
      IF li_request IS NOT INITIAL.
        SELECT *
          FROM zacg_req_aprover
          INTO TABLE li_req_aprover
          FOR ALL ENTRIES IN li_request
          WHERE req_no = li_request-req_no.
        IF sy-subrc IS INITIAL.
          SORT li_req_aprover BY req_no agr_name seqnr DESCENDING.
          DELETE ADJACENT DUPLICATES FROM li_req_aprover COMPARING req_no agr_name.
        ENDIF.
      ENDIF.
    ENDIF.

  ELSEIF r_creq = abap_true. " Request completed by me

    CLEAR gt_outtab_9031.

    SELECT req_no, agr_name
      FROM zacg_req_aprover
      INTO TABLE @li_request
      WHERE approver = @sy-uname
        AND status IN ('03','04')
        AND action_taken = @abap_true.
    IF sy-subrc IS NOT INITIAL.
      MESSAGE 'You do not have any completed request' TYPE 'S'.
    ELSE.
      SORT li_request.
      DELETE ADJACENT DUPLICATES FROM li_request.
      IF li_request IS NOT INITIAL.
        SELECT *
          FROM zacg_req_aprover
          INTO TABLE li_req_aprover
          FOR ALL ENTRIES IN li_request
          WHERE req_no   = li_request-req_no
            AND agr_name = li_request-agr_name.
        IF sy-subrc IS INITIAL.
          SORT li_req_aprover BY req_no agr_name seqnr DESCENDING.
          DELETE ADJACENT DUPLICATES FROM li_req_aprover COMPARING req_no agr_name.
        ENDIF.
      ENDIF.
    ENDIF.


  ELSEIF r_sreq IS NOT INITIAL. " Search any request

    CLEAR gt_outtab_9031.
    IF s_sreq[] IS NOT INITIAL OR s_susr[] IS NOT INITIAL.

      SELECT req_no,
             child_req_no
      FROM zacg_req_blk_map
      INTO TABLE @DATA(lt_req_blk_map)
      WHERE req_no IN @s_sreq.

      SELECT *
        FROM zacg_req_aprover
        INTO TABLE @li_req_aprover
        WHERE req_no IN @s_sreq
          AND userid IN @s_susr
        ORDER BY req_no, agr_name, seqnr DESCENDING.
      IF lt_req_blk_map IS NOT INITIAL.
        SELECT *
          FROM zacg_req_aprover
          APPENDING TABLE @li_req_aprover
          FOR ALL ENTRIES IN @lt_req_blk_map
          WHERE req_no = @lt_req_blk_map-child_req_no
            AND userid IN @s_susr.
      ENDIF.
      SORT li_req_aprover BY req_no agr_name seqnr DESCENDING.

      IF li_req_aprover IS INITIAL.
        MESSAGE 'No request found for given criteria' TYPE 'S'.
      ELSE.
        DELETE ADJACENT DUPLICATES FROM li_req_aprover COMPARING req_no agr_name.
      ENDIF.
    ENDIF.

  ENDIF.

  IF li_req_aprover IS NOT INITIAL.

    SELECT domvalue_l,
           ddtext
      FROM dd07t
      INTO TABLE @DATA(li_status)
      WHERE domname = 'ZACG_ACC_REQ_ST'
        AND ddlanguage = @sy-langu
      ORDER BY domvalue_l.

    SELECT domvalue_l,
           ddtext
      FROM dd07t
      INTO TABLE @DATA(li_approver)
      WHERE domname = 'ZACG_APPROVER_ROLE'
        AND ddlanguage = @sy-langu
      ORDER BY domvalue_l.

*** Start of Change Rounak
    SELECT req_no,
           child_req_no
    FROM zacg_req_blk_map
    INTO TABLE @DATA(lt_req_blk_map1)
    FOR ALL ENTRIES IN @li_req_aprover
    WHERE child_req_no = @li_req_aprover-req_no.
    IF sy-subrc IS INITIAL.
      SORT lt_req_blk_map1 BY child_req_no.
    ENDIF.
*** End of Change Rounak

    LOOP AT li_req_aprover INTO DATA(lwa_req_aprover).

      APPEND INITIAL LINE TO gt_outtab_9031 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9031>).

      READ TABLE lt_req_blk_map1 INTO DATA(lwa_req_blk_map) WITH KEY child_req_no = lwa_req_aprover-req_no.
      IF sy-subrc IS INITIAL.
        <lfs_outtab_9031>-req_no        = lwa_req_blk_map-req_no.
        <lfs_outtab_9031>-org_req_no    = lwa_req_aprover-req_no.  "++ Rounak
      ELSE.
        <lfs_outtab_9031>-req_no        = lwa_req_aprover-req_no.
        <lfs_outtab_9031>-org_req_no    = lwa_req_aprover-req_no.  "++ Rounak
      ENDIF.

      <lfs_outtab_9031>-role          = lwa_req_aprover-agr_name.
      <lfs_outtab_9031>-user          = lwa_req_aprover-userid.
      <lfs_outtab_9031>-begda         = lwa_req_aprover-begda.
      <lfs_outtab_9031>-endda         = lwa_req_aprover-endda.
      <lfs_outtab_9031>-status        = lwa_req_aprover-status.
      <lfs_outtab_9031>-approver      = lwa_req_aprover-approver.
      <lfs_outtab_9031>-app_role      = lwa_req_aprover-approver_role.
      <lfs_outtab_9031>-action_taken  = lwa_req_aprover-action_taken.

      READ TABLE li_status INTO DATA(lwa_status)
        WITH KEY domvalue_l = lwa_req_aprover-status BINARY SEARCH.
      IF lwa_req_aprover-approver = sy-uname.
        <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } as|.
      ELSE.
        IF lwa_req_aprover-status = '01' OR
            lwa_req_aprover-status = '02'.
          <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } with|.
        ELSEIF lwa_req_aprover-status = '03' OR
           lwa_req_aprover-status = '04'.
          <lfs_outtab_9031>-statust = |{ lwa_status-ddtext } by|.
        ENDIF.
      ENDIF.

      READ TABLE li_approver INTO DATA(lwa_approver)
            WITH KEY domvalue_l = lwa_req_aprover-approver_role BINARY SEARCH.
      <lfs_outtab_9031>-statust  = |{ <lfs_outtab_9031>-statust } { lwa_approver-ddtext }|.

      <lfs_outtab_9031>-ernam = lwa_req_aprover-aename.
      <lfs_outtab_9031>-erdat = lwa_req_aprover-aedate.
    ENDLOOP.
    SORT gt_outtab_9031 BY req_no.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form paste_from_clipboard
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM paste_from_clipboard.
  DATA:
        li_clipdata TYPE STANDARD TABLE OF file_table.

  CLEAR sy-ucomm.
  CALL METHOD cl_gui_frontend_services=>clipboard_import
    IMPORTING
      data                 = li_clipdata
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.
  IF sy-subrc = 3.
    MESSAGE e888(db).
    EXIT.
  ELSEIF sy-subrc <> 0.
    MESSAGE e889(db) WITH 'CLIPBOARD_IMPORT'.
    EXIT.
  ENDIF.

  SORT i_outtab_7002 BY userid owner DESCENDING risk.

  LOOP AT i_outtab_7002 INTO DATA(lwa_outtab_7002).
    DATA(lv_tabix) = sy-tabix.
    IF lwa_outtab_7002-owner IS INITIAL.
      EXIT.
    ENDIF.
  ENDLOOP.

  LOOP AT li_clipdata INTO DATA(lwa_clipdata).
    READ TABLE i_outtab_7002 ASSIGNING FIELD-SYMBOL(<lfs_outtab_7002>)
    INDEX lv_tabix.
    IF sy-subrc IS INITIAL.
      <lfs_outtab_7002>-owner = lwa_clipdata-filename.
    ENDIF.
    lv_tabix = lv_tabix + 1.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_request
*&---------------------------------------------------------------------*
*& Locks an access request (ENQUEUE_EZACG_REQ_APRV) so two approvers
*& cannot process it at the same time.
*&   -->  FP_REQUEST  Request number to lock.
*&   <--  FP_MESSAGE  Set to ABAP_TRUE if the lock could not be acquired
*&                    (a message is also displayed).
*&---------------------------------------------------------------------*
FORM enqueue_request  USING    fp_request   TYPE zacg_acc_req
                      CHANGING fp_message   TYPE string.

  DATA:
        lwa_lock TYPE zacg_lock_req.

  CALL FUNCTION 'ENQUEUE_EZACG_REQ_APRV'
    EXPORTING
      req_no         = fp_request
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    sy-msgv2 = fp_request.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.
    fp_message = abap_true.
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form deque_request
*&---------------------------------------------------------------------*
*& Releases the lock on an access request (DEQUEUE_EZACG_REQ_APRV).
*&   -->  FP_REQUEST  Request number to unlock.
*&---------------------------------------------------------------------*
FORM dequeue_request USING fp_request TYPE zacg_acc_req.

  CALL FUNCTION 'DEQUEUE_EZACG_REQ_APRV'
    EXPORTING
      req_no = fp_request.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_7004
*&---------------------------------------------------------------------*
*& Validates the manager rejection-reason pop-up (screen 7004):
*& GV_REJECTION_REASON must be supplied and longer than 10 characters.
*&---------------------------------------------------------------------*
FORM validate_7004 .

  CHECK sy-ucomm = 'OKAY'.
  IF gv_rejection_reason IS INITIAL.
    CLEAR sy-ucomm.
    SET CURSOR FIELD 'GV_REJECTION_REASON'.
    MESSAGE 'Provide reason for rejection' TYPE 'E'.
  ELSE.
    IF strlen( gv_rejection_reason ) LE 10.
      CLEAR sy-ucomm.
      SET CURSOR FIELD 'GV_REJECTION_REASON'.
      MESSAGE 'Reason for rejection must be at least 10 character' TYPE 'E'.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_7004
*&---------------------------------------------------------------------*
*& PAI handler for the manager rejection pop-up (screen 7004). Leaves on
*& EXIT/CANC; on OKAY leaves and calls update_rejection_from_manager.
*&---------------------------------------------------------------------*
FORM user_command_7004 .

  CASE sy-ucomm.
    WHEN 'EXIT' OR 'CANC'.
      CLEAR sy-ucomm.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'OKAY'.
      CLEAR sy-ucomm.
      SET SCREEN 0.
      LEAVE SCREEN.
      PERFORM update_rejection_from_manager.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form update_rejection_from_manager
*&---------------------------------------------------------------------*
*& Intended to persist a manager's rejection of a request. Currently an
*& empty placeholder (no implementation).
*&---------------------------------------------------------------------*
FORM update_rejection_from_manager .

ENDFORM.
*&---------------------------------------------------------------------*
*& Form populate_data_9033
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM populate_data_9033.

  DATA:
        lv_user TYPE xubname.

  CALL FUNCTION 'ICON_CREATE'
    EXPORTING
      name   = 'ICON_REFRESH'
    IMPORTING
      result = g_refresh_9033.

  CLEAR i_outtab_9033.

  lv_user = sy-uname.

  SELECT _user~agr_name, _role~ffid
  FROM agr_users AS _user
  INNER JOIN zacg_ffid_hdr AS _role
  ON _user~agr_name = _role~agr_name
  WHERE _user~uname    = @lv_user
    AND _user~from_dat <= @sy-datum
    AND _user~to_dat   >= @sy-datum
  INTO TABLE @DATA(li_existing_role).
  IF sy-subrc IS INITIAL.
    LOOP AT li_existing_role INTO DATA(lwa_existing_role).
      APPEND INITIAL LINE TO i_outtab_9033 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9033>).
      <lfs_outtab_9033>-ffid = lwa_existing_role-ffid.
    ENDLOOP.
  ENDIF.

  IF i_outtab_9033 IS NOT INITIAL.

    SELECT *
      FROM zacg_ffid_log
      FOR ALL ENTRIES IN @li_existing_role
      WHERE userid = @lv_user
        AND ffid   = @li_existing_role-ffid
        AND active = @abap_true
      INTO TABLE @DATA(li_ffid_log).
    IF sy-subrc IS INITIAL.
      SORT li_ffid_log BY userid ffid logindt DESCENDING.
      DELETE ADJACENT DUPLICATES FROM li_ffid_log COMPARING userid ffid.
    ENDIF.
  ENDIF.


  LOOP AT i_outtab_9033 ASSIGNING <lfs_outtab_9033>.

    READ TABLE li_ffid_log INTO DATA(lwa_ffid_log)
    WITH KEY ffid = <lfs_outtab_9033>-ffid.
    IF sy-subrc IS INITIAL.
      <lfs_outtab_9033>-loid = lwa_ffid_log-userid.

      SELECT SINGLE a~name_text
        INTO <lfs_outtab_9033>-lonm
        FROM usr21 AS u
        INNER JOIN adrp AS a
        ON u~persnumber = a~persnumber
        WHERE u~bname = <lfs_outtab_9033>-loid.
    ENDIF.

    SELECT SINGLE a~name_text
      INTO <lfs_outtab_9033>-ffnm
      FROM usr21 AS u
      INNER JOIN adrp AS a
      ON u~persnumber = a~persnumber
      WHERE u~bname = <lfs_outtab_9033>-ffid.

    IF <lfs_outtab_9033>-loid IS NOT INITIAL.
      <lfs_outtab_9033>-stat = '@0A@'.
      CALL FUNCTION 'ICON_CREATE'
        EXPORTING
          name   = 'ICON_CANCEL'
          text   = 'Logout'
        IMPORTING
          result = <lfs_outtab_9033>-logn.

    ELSE.
      <lfs_outtab_9033>-stat = '@08@'.
      CALL FUNCTION 'ICON_CREATE'
        EXPORTING
          name   = 'ICON_OKAY'
          text   = 'Login'
        IMPORTING
          result = <lfs_outtab_9033>-logn.

    ENDIF.


  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_9033
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_9033.

  DATA:
    lv_line      TYPE i,
    lv_rc        TYPE i,
    lv_rz_param  TYPE pfeparname,
    lv_param_val TYPE pfepvalue.

  CLEAR wa_selected_line_9033.

  GET CURSOR LINE lv_line.
  IF sy-ucomm = '&LGN'.
    READ TABLE i_outtab_9033 INTO DATA(lwa_outtab_9033) INDEX lv_line.
    IF sy-subrc IS INITIAL.
      IF lwa_outtab_9033-loid IS NOT INITIAL. " Someone in Already logged In
        IF lwa_outtab_9033-loid NE sy-uname.
          MESSAGE 'You can not logout for another user' TYPE 'E'.
        ELSE.
          MOVE-CORRESPONDING lwa_outtab_9033 TO wa_selected_line_9033.
          wa_selected_line_9033-logedin = abap_true.
          wa_selected_line_9033-ucomm   = '&LGO'.
          wa_selected_line_9033-index   = lv_line.
        ENDIF.
      ELSE.
        MOVE-CORRESPONDING lwa_outtab_9033 TO wa_selected_line_9033.
        wa_selected_line_9033-logedin = abap_false.
        wa_selected_line_9033-ucomm   = '&LGI'.
        wa_selected_line_9033-index   = lv_line.
      ENDIF.
    ENDIF.
  ENDIF.

  IF wa_selected_line_9033-ucomm = '&LGI'.

    DATA(lo_server_info) = NEW cl_server_info( ).
    DATA(li_session_list) = lo_server_info->get_session_list(
      tenant                = sy-mandt
      with_application_info = 1 ).

    DELETE li_session_list WHERE user_name NE sy-uname.

    lv_rz_param = 'rdisp/max_alt_modes'.

    CALL FUNCTION 'TH_GET_PARAMETER'
      EXPORTING
        parameter_name  = lv_rz_param
      IMPORTING
        parameter_value = lv_param_val
        rc              = lv_rc
      EXCEPTIONS
        not_authorized  = 1
        OTHERS          = 2.
    IF sy-subrc <> 0.
    ENDIF.

    IF lv_param_val <= lines( li_session_list ).
      MESSAGE 'Maximum number of GUI sessions reached' TYPE 'E'.
    ENDIF.

  ELSEIF wa_selected_line_9033-ucomm   = '&LGO'.

  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9033
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9033.

  CASE wa_selected_line_9033-ucomm.
    WHEN '&LGI'.

      CALL SCREEN 7005 STARTING AT 10 5 ENDING AT 70 9.

    WHEN '&LGO'.

      PERFORM emergency_logout.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form hide_row_9033
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM hide_row_9033.

  READ TABLE i_outtab_9033 TRANSPORTING NO FIELDS
  INDEX table_9033-current_line.
  IF sy-subrc IS NOT INITIAL.
    LOOP AT table_9033-cols ASSIGNING FIELD-SYMBOL(<lfs_table_9033>).
      <lfs_table_9033>-screen-invisible = 0.
      <lfs_table_9033>-screen-active    = 0.
    ENDLOOP.
  ELSE.
    LOOP AT table_9033-cols ASSIGNING <lfs_table_9033>.
      <lfs_table_9033>-screen-invisible = 0.
      <lfs_table_9033>-screen-active    = 1.
    ENDLOOP.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form emergency_login
*&---------------------------------------------------------------------*
*& Firefighter (emergency-access) login (screen 7005 / 9033).
*&
*& Reads the login reason from the text editor, pings the firefighter
*& target system (RFC_PING on ZACG_FFID_HDR-FFDST) and opens a remote
*& session there (SYSTEM_REMOTE_LOGIN). On success it generates a
*& session id (GUID_CREATE) and writes an active row to the firefighter
*& log ZACG_FFID_LOG (user, FFID, session, reason, host/IP, timestamps).
*& Side effect: starts a remote FFID session and logs it.
*&---------------------------------------------------------------------*
FORM emergency_login .

  DATA:
    lv_error      TYPE rfcoptions,
    lv_text       TYPE string,

    lwa_login_log TYPE zacg_ffid_log,

    li_text       TYPE TABLE OF char255,
    lv_session_id TYPE guid_32.

  CALL METHOD o_textedit_7005->get_text_as_r3table
    IMPORTING
      table                  = li_text
    EXCEPTIONS
      error_dp               = 1
      error_cntl_call_method = 2
      error_dp_create        = 3
      potential_data_loss    = 4
      OTHERS                 = 5.
  IF sy-subrc IS INITIAL.
  ENDIF.

  LOOP AT li_text INTO DATA(lwa_text).
    lv_text = |{ lv_text }  { lwa_text }|.
  ENDLOOP.
  SHIFT lv_text LEFT DELETING LEADING space.


  SELECT *
    FROM zacg_ffid_log
    INTO TABLE @DATA(li_login_log)
  WHERE userid = @sy-uname.

  SELECT SINGLE *
    FROM zacg_ffid_hdr
    INTO @DATA(lwa_ffid_hdr)
  WHERE ffid = @wa_selected_line_9033-ffid.
  IF sy-subrc IS INITIAL.

    CALL FUNCTION 'RFC_PING' DESTINATION lwa_ffid_hdr-ffdst
      EXCEPTIONS
        system_failure        = 1
        communication_failure = 2
        OTHERS                = 3.
    IF sy-subrc IS INITIAL.
      CALL FUNCTION 'SYSTEM_REMOTE_LOGIN'
        EXPORTING
          destination          = lwa_ffid_hdr-ffdst
        IMPORTING
          error_message        = lv_error
        EXCEPTIONS
          cannot_start         = 1
          parameter_incomplete = 2
          OTHERS               = 3.
      IF sy-subrc = 0.

        DATA(lo_server_info) = NEW cl_server_info( ).
        DATA(li_session_list) = lo_server_info->get_session_list(
          tenant                = sy-mandt
          with_application_info = 1 ).

        READ TABLE li_session_list INTO DATA(lwa_session_list) WITH KEY
        user_name   = sy-uname
        application = 'ZACG'.
        IF sy-subrc IS INITIAL.
          READ TABLE li_session_list INTO DATA(lwa_session_new) WITH KEY
          user_name     = wa_selected_line_9033-ffid
          location_info = lwa_session_list-location_info.
          IF sy-subrc IS INITIAL.
            "Generate GUID for Session ID
            CALL FUNCTION 'GUID_CREATE'
              IMPORTING
                ev_guid_32 = lv_session_id.
            lwa_login_log-userid    = sy-uname.
            lwa_login_log-ffid      = wa_selected_line_9033-ffid.
            lwa_login_log-session_id = lv_session_id.
            lwa_login_log-reason    = lv_text.
            lwa_login_log-clnt_host = lwa_session_new-location_info.
            lwa_login_log-clnt_ip   = lwa_session_new-client_ip_addr.
            lwa_login_log-active    = abap_true.
            lwa_login_log-logindt   = sy-datum.
            lwa_login_log-logintm   = sy-uzeit.
            MODIFY zacg_ffid_log FROM lwa_login_log.
            COMMIT WORK.

            CLEAR lv_text.
            lv_text = |User { wa_selected_line_9033-ffid } Login is successful|.
            MESSAGE lv_text TYPE 'S'.
          ENDIF.
        ENDIF.

        READ TABLE i_outtab_9033 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9033>)
        INDEX wa_selected_line_9033-index.
        IF sy-subrc IS INITIAL.
          <lfs_outtab_9033>-loid = sy-uname.
        ENDIF.
      ELSE.
        MESSAGE 'Communication Failure. Report to your admin' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    ELSE.
      MESSAGE 'Communication Failure. Report to your admin' TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ELSE.
    MESSAGE 'Communication Failure. Report to your admin' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form emergency_logout
*&---------------------------------------------------------------------*
*& Firefighter (emergency-access) logout (screen 9033).
*&
*& For the selected active FFID session (ZACG_FFID_LOG) it asks for
*& confirmation, terminates the firefighter's sessions on the target
*& system (TH_DELETE_USER) and closes the log entry (ACTIVE = '',
*& logout date/time). Side effect: ends the FFID session and updates the
*& log.
*&---------------------------------------------------------------------*
FORM emergency_logout .

  DATA:
    lv_uname     TYPE sy-uname,
    lv_message   TYPE string,
    lv_answer(1) TYPE c.

  READ TABLE i_outtab_9033 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9033>)
  INDEX wa_selected_line_9033-index.
  IF sy-subrc IS INITIAL.

    SELECT SINGLE *
      FROM zacg_ffid_log
      INTO @DATA(lwa_ffid_log)
      WHERE userid = @sy-uname
        AND ffid   = @wa_selected_line_9033-ffid
        AND active = @abap_true.
    IF sy-subrc IS INITIAL.

      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = ' '
          text_question         = 'Do you want to log off?'
          text_button_1         = 'Yes'
          icon_button_1         = 'ICON_OKAY'
          text_button_2         = 'No'
          icon_button_2         = 'ICON_CANCEL'
          display_cancel_button = ' '
        IMPORTING
          answer                = lv_answer
        EXCEPTIONS
          text_not_found        = 1
          OTHERS                = 2.
      IF sy-subrc <> 0.
      ENDIF.

      IF lv_answer = 1.

        lwa_ffid_log-active   = abap_false.
        lwa_ffid_log-lgoutdt  = sy-datum.
        lwa_ffid_log-lgouttm  = sy-uzeit.

        lv_uname = wa_selected_line_9033-ffid.
        CALL FUNCTION 'TH_DELETE_USER'
          EXPORTING
            client           = sy-mandt
            user             = lv_uname
            only_pooled_user = ' '.

        MODIFY zacg_ffid_log FROM lwa_ffid_log.
        COMMIT WORK AND WAIT.

        lv_message = |User { lv_uname } successfully loged out|.
        MESSAGE lv_message TYPE 'S'.
      ENDIF.

    ENDIF.
    <lfs_outtab_9033>-loid = abap_false.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form status_7005
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM status_7005 .

  DATA:
        li_text TYPE TABLE OF char255.

  IF o_conttainer_7005 IS NOT BOUND.
    CREATE OBJECT o_conttainer_7005
      EXPORTING
        container_name              = 'CC_7005'
        repid                       = sy-repid
        dynnr                       = sy-dynnr
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc IS INITIAL.
    ENDIF.
  ENDIF.

  IF o_textedit_7005 IS NOT BOUND.
    CREATE OBJECT o_textedit_7005
      EXPORTING
        parent                 = o_conttainer_7005
        max_number_chars       = 1000
      EXCEPTIONS
        error_cntl_create      = 1
        error_cntl_init        = 2
        error_cntl_link        = 3
        error_dp_create        = 4
        gui_type_not_supported = 5
        OTHERS                 = 6.
    IF sy-subrc IS INITIAL.
    ENDIF.
  ENDIF.

  IF o_textedit_7005 IS BOUND.
    CALL METHOD o_textedit_7005->set_selected_text_as_r3table
      EXPORTING
        table           = li_text
      EXCEPTIONS
        error_dp        = 1
        error_dp_create = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
    ENDIF.

  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form user_command_7005
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_7005 .

  CASE sy-ucomm.
    WHEN 'OKAY'.
      PERFORM emergency_login.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'CANC'.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN OTHERS.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_7005
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_7005 .

  DATA:
    lv_text TYPE string,
    li_text TYPE TABLE OF char255.

  CALL METHOD o_textedit_7005->get_text_as_r3table
    IMPORTING
      table                  = li_text
    EXCEPTIONS
      error_dp               = 1
      error_cntl_call_method = 2
      error_dp_create        = 3
      potential_data_loss    = 4
      OTHERS                 = 5.
  IF sy-subrc IS INITIAL.
  ENDIF.

  LOOP AT li_text INTO DATA(lwa_text).
    lv_text = |{ lv_text }  { lwa_text }|.
  ENDLOOP.
  SHIFT lv_text LEFT DELETING LEADING space.

  IF strlen( lv_text ) < 20.
    MESSAGE 'Reason must be at least of 20 characters' TYPE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9034
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9034.
  DATA : lv_answer(1) TYPE c,
         lt_tlog_up   TYPE STANDARD TABLE OF zacg_ffid_tlog,
         lt_tlog_fin  TYPE STANDARD TABLE OF zacg_ffid_tlog.

  CASE sy-ucomm.
    WHEN '&APR'.
      CALL METHOD o_grid_9034->get_selected_rows(
        IMPORTING
          et_index_rows = DATA(li_index_rows)
          et_row_no     = DATA(li_row_no) ).

      IF li_row_no IS NOT INITIAL.
        CLEAR : lt_tlog_up.
        LOOP AT li_row_no INTO DATA(lwa_row_no).
          READ TABLE i_outtab_9034 INTO DATA(lwa_outtab_9034) INDEX lwa_row_no-row_id.
          IF sy-subrc IS INITIAL.
            lt_tlog_up = VALUE #( BASE lt_tlog_up ( session_id = lwa_outtab_9034-session_id
            tcode = lwa_outtab_9034-tcode  ) ).
          ENDIF.
        ENDLOOP.
        IF lt_tlog_up IS NOT INITIAL.
          SORT lt_tlog_up BY session_id.
          SELECT * FROM zacg_ffid_tlog FOR ALL ENTRIES IN @lt_tlog_up
            WHERE session_id = @lt_tlog_up-session_id
            AND tcode = @lt_tlog_up-tcode INTO TABLE @DATA(lt_tlog_modify).
          IF sy-subrc = 0.
            CLEAR : lt_tlog_fin.
            lt_tlog_fin = VALUE #( FOR lwa_tlog_modify
            IN lt_tlog_modify ( mandt = sy-mandt
            session_id = lwa_tlog_modify-session_id
            tcode = lwa_tlog_modify-tcode
            times = lwa_tlog_modify-times
            action = 'A'
            actiondt = sy-datum
            actiontm = sy-uzeit
            approver = sy-uname ) ).
          ENDIF.
        ENDIF.
        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar              = ' '
            text_question         = 'Do you want to approve?'
            text_button_1         = 'Yes'
            icon_button_1         = 'ICON_OKAY'
            text_button_2         = 'No'
            icon_button_2         = 'ICON_CANCEL'
            display_cancel_button = ' '
          IMPORTING
            answer                = lv_answer
          EXCEPTIONS
            text_not_found        = 1
            OTHERS                = 2.
        IF sy-subrc <> 0.
        ENDIF.
        IF lv_answer = 1.
          IF lt_tlog_fin IS NOT INITIAL.
            MODIFY zacg_ffid_tlog FROM TABLE lt_tlog_fin.
          ENDIF.
        ENDIF.
      ELSE.
        MESSAGE 'Please select the line you want to Approve' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    WHEN '&RJC'.
      CALL METHOD o_grid_9034->get_selected_rows(
        IMPORTING
          et_index_rows = li_index_rows
          et_row_no     = li_row_no ).
      IF li_row_no IS NOT INITIAL.
        CLEAR : i_outtab_7006.
        LOOP AT li_row_no INTO lwa_row_no.
          READ TABLE i_outtab_9034 INTO lwa_outtab_9034 INDEX lwa_row_no-row_id.
          IF sy-subrc IS INITIAL.
            APPEND INITIAL LINE TO i_outtab_7006 ASSIGNING FIELD-SYMBOL(<lfs_outtab_7006>).
            <lfs_outtab_7006>-session_id = lwa_outtab_9034-session_id.
            <lfs_outtab_7006>-userid = lwa_outtab_9034-userid.
            <lfs_outtab_7006>-ffid   = lwa_outtab_9034-ffid.
            <lfs_outtab_7006>-tcode  = lwa_outtab_9034-tcode.
            <lfs_outtab_7006>-times  = lwa_outtab_9034-times.
            <lfs_outtab_7006>-owner  = lwa_outtab_9034-owner.
          ENDIF.
        ENDLOOP.
        CALL SCREEN 7006 STARTING AT 5 5 ENDING AT 120 15.
      ELSE.
        MESSAGE 'Please select the line you want to Reject' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9034
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9034.

  CLEAR i_outtab_9034.

  SELECT hdr~ffid, hdr~owner,
         log~userid, log~session_id,
         log~logindt, log~logintm, log~lgoutdt, log~lgouttm,
         tlog~tcode, tlog~times
    FROM zacg_ffid_hdr AS hdr
    INNER JOIN zacg_ffid_log AS log
    ON hdr~ffid = log~ffid
    INNER JOIN zacg_ffid_tlog AS tlog
    ON log~session_id = tlog~session_id
    INTO TABLE @i_outtab_9034
    WHERE hdr~owner   = @sy-uname
      AND tlog~action = @abap_false.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_934
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9034 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.


  IF o_conttainer_9034 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9034
      EXPORTING
        container_name = 'CC_9034'.
  ENDIF.

  IF o_conttainer_9034 IS BOUND AND o_grid_9034 IS NOT BOUND.
    CREATE OBJECT o_grid_9034
      EXPORTING
        i_parent = o_conttainer_9034.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'FFID'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Emergency ID'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'USERID'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Logged in User'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'SESSION_ID'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Session id'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'LOGINDT'.
  ls_catalog-coltext   = 'Logged in on'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'LOGINTM'.
  ls_catalog-coltext   = 'Logged in at'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'LGOUTDT'.
  ls_catalog-coltext   = 'Logged out On'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'LGOUTTM'.
  ls_catalog-coltext   = 'Logged out at'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TCODE'.
  ls_catalog-coltext   = 'Transaction Code'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TIMES'.
  ls_catalog-coltext   = 'Number of times'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9034 IS BOUND.
    IF g_9034_first IS INITIAL.
      g_9034_first = abap_true.
      CALL METHOD o_grid_9034->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = i_outtab_9034.
    ELSE.
      CALL METHOD o_grid_9034->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9034->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9034->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form update_tlog_reject
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM update_tlog_reject .
  DATA: lt_tlog TYPE STANDARD TABLE OF zacg_ffid_tlog.
  LOOP AT i_outtab_7006 ASSIGNING FIELD-SYMBOL(<lfs_outtab_7006>).
    APPEND INITIAL LINE TO lt_tlog ASSIGNING FIELD-SYMBOL(<lfs_tlog>).
    <lfs_tlog>-action = 'R'.
    <lfs_tlog>-actiondt = sy-datum.
    <lfs_tlog>-actiontm = sy-uzeit.
    <lfs_tlog>-approver = sy-uname.
    <lfs_tlog>-mandt = sy-mandt.
    <lfs_tlog>-reject_reason = <lfs_outtab_7006>-reason.
    <lfs_tlog>-session_id =  <lfs_outtab_7006>-session_id.
    <lfs_tlog>-tcode =  <lfs_outtab_7006>-tcode.
    <lfs_tlog>-times =  <lfs_outtab_7006>-times.
  ENDLOOP.
  IF lt_tlog IS NOT INITIAL.
    MODIFY zacg_ffid_tlog FROM TABLE lt_tlog.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form validate_7006
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_7006 .
  MODIFY i_outtab_7006 FROM wa_outtab_7006 INDEX table_7006-current_line.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_9035
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_9035.

  CASE sy-ucomm.
    WHEN 'EXE'.
      IF s_dat35 IS INITIAL.
        CLEAR sy-ucomm.
        SET CURSOR FIELD 'S_DAT35-LOW'.
        MESSAGE 'Provide date' TYPE 'E'.
      ENDIF.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9035
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9035.

  DATA:
    lv_dlydy       TYPE dlydy VALUE '07',
    lv_dlymo       TYPE dlymo,
    lv_dlyyr       TYPE dlyyr,
    lt_catalog     TYPE lvc_t_fcat,
    lt_fieldvalues TYPE STANDARD TABLE OF  dynpread,
    ls_catalog     TYPE lvc_s_fcat.


  IF s_dat35 IS INITIAL.
    CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
      EXPORTING
        date      = sy-datum
        days      = lv_dlydy
        months    = lv_dlymo
        signum    = '-'
        years     = lv_dlyyr
      IMPORTING
        calc_date = s_dat35-low.
    s_dat35-high = sy-datum.
    s_dat35-sign = 'I'.
    s_dat35-option = 'BT'.
    APPEND s_dat35 TO s_dat35[].

  ENDIF.

  IF o_conttainer_9035 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9035
      EXPORTING
        container_name = 'CC_9035'.
  ENDIF.

  IF o_conttainer_9035 IS BOUND AND o_grid_9035 IS NOT BOUND.
    CREATE OBJECT o_grid_9035
      EXPORTING
        i_parent = o_conttainer_9035.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'LOGINDT'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Login Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'LOGINTM'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Login Time'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'LGOUTDT'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Logout Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'LGOUTTM'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Logout Time'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'USERID'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Login User'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'FFID'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Emergency ID'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ASSESSOR'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Assessor'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ASSESSED'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Assessment Status'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'FRSN'.
  ls_catalog-coltext   = 'Reason for Login'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-just      = 'C'.
  ls_catalog-hotspot   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'CLNT_IP'.
  ls_catalog-coltext   = 'User IP Address'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ASSMNTDTL'.
  ls_catalog-coltext   = 'Assessment Detail'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-just      = 'C'.
  ls_catalog-hotspot   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.


  IF o_grid_9035 IS BOUND.
    IF g_9035_first IS INITIAL.
      g_9035_first = abap_true.

      DATA(lo_grid_event) = NEW lcl_event_receiver( ).
      SET HANDLER lo_grid_event->handle_hot_spot FOR o_grid_9035.
*      SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_9035.
      SET HANDLER lo_grid_event->handle_user_command FOR o_grid_9035.

      CALL METHOD o_grid_9035->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = i_outtab_9035.
    ELSE.
      CALL METHOD o_grid_9035->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9035->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9035->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9035
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9035.

  CLEAR i_outtab_9035.

  SELECT *
    FROM zacg_ffid_hdr
    INTO TABLE @DATA(li_ffid_hdr).

  SELECT *
    FROM zacg_ffid_log
    INTO TABLE @DATA(li_ffid_log)
    WHERE session_id NE @space
      AND userid IN @s_usr35[]
      AND ffid IN @s_fid35[]
      AND logindt IN @s_dat35[].

  IF li_ffid_log IS NOT INITIAL.
    SELECT *
      FROM zacg_ffid_tlog
      FOR ALL ENTRIES IN @li_ffid_log
      WHERE session_id = @li_ffid_log-session_id
      INTO TABLE @DATA(li_ffid_tlog).
    IF sy-subrc IS INITIAL.
      SORT li_ffid_tlog BY session_id.
    ENDIF.
  ENDIF.

  LOOP AT li_ffid_log INTO DATA(lwa_ffid_log).
    READ TABLE li_ffid_tlog TRANSPORTING NO FIELDS WITH KEY session_id = lwa_ffid_log-session_id BINARY SEARCH.
    CHECK sy-subrc IS INITIAL.
    READ TABLE li_ffid_hdr INTO DATA(lwa_ffid_hdr) WITH KEY ffid = lwa_ffid_log-ffid.
    IF sy-subrc IS INITIAL.
      APPEND INITIAL LINE TO i_outtab_9035 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9035>).
      <lfs_outtab_9035>-session   = lwa_ffid_log-session_id.
      <lfs_outtab_9035>-userid    = lwa_ffid_log-userid.
      <lfs_outtab_9035>-clnt_ip   = lwa_ffid_log-clnt_ip.
      <lfs_outtab_9035>-ffid      = lwa_ffid_log-ffid.

      <lfs_outtab_9035>-assessor  = lwa_ffid_hdr-owner.
      <lfs_outtab_9035>-reason    = lwa_ffid_log-reason.
      <lfs_outtab_9035>-frsn      = '@0P@'.
      <lfs_outtab_9035>-logindt   = lwa_ffid_log-logindt.
      <lfs_outtab_9035>-logintm   = lwa_ffid_log-logintm.
      <lfs_outtab_9035>-lgoutdt   = lwa_ffid_log-lgoutdt.
      <lfs_outtab_9035>-lgouttm   = lwa_ffid_log-lgouttm.

      SELECT tcode, action
        FROM zacg_ffid_tlog
        INTO TABLE @DATA(li_total_count)
        WHERE session_id = @lwa_ffid_log-session_id.

      SELECT COUNT( * )
        FROM @li_total_count AS assessed
        WHERE action IS NOT INITIAL.
      DATA(lv_total_count) = sy-dbcnt.
      IF lines( li_total_count ) EQ lv_total_count.
        <lfs_outtab_9035>-assessed  = 'Fully Assessed'.
      ELSE.
        IF lv_total_count > 0.
          <lfs_outtab_9035>-assessed  = 'Partially Assessed'.
        ELSE.
          <lfs_outtab_9035>-assessed  = 'Pending Assessment'.
        ENDIF.
      ENDIF.
      <lfs_outtab_9035>-assmntdtl = '@3R@'.
    ENDIF.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_ffid_login_reason
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM display_ffid_login_reason USING row TYPE lvc_s_row.

  DATA:
        li_reason TYPE STANDARD TABLE OF text100.

  READ TABLE i_outtab_9035 INTO DATA(lwa_line_data) INDEX row-index.

  CALL FUNCTION 'RKD_WORD_WRAP'
    EXPORTING
      textline            = lwa_line_data-reason
      outputlen           = 100
    TABLES
      out_lines           = li_reason
    EXCEPTIONS
      outputlen_too_large = 1
      OTHERS              = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.


  CALL FUNCTION 'POPUP_WITH_TABLE'
    EXPORTING
      endpos_col   = 120
      endpos_row   = 20
      startpos_col = 30
      startpos_row = 10
      titletext    = 'Reason for Login'
    TABLES
      valuetab     = li_reason
    EXCEPTIONS
      break_off    = 1
      OTHERS       = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_ffid_assessment
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> E_ROW_ID
*&---------------------------------------------------------------------*
FORM display_ffid_assessment  USING  row TYPE lvc_s_row.

  TYPES:
    BEGIN OF lty_assessment,
      tcode    TYPE tcode,
      status   TYPE char10,
      reason   TYPE text100,
      approver TYPE xubname,
      actiondt TYPE datum,
      actiontm TYPE uzeit,
    END OF lty_assessment.

  DATA:
        li_assessment TYPE STANDARD TABLE OF lty_assessment.

  READ TABLE i_outtab_9035 INTO DATA(lwa_line_data) INDEX row-index.
  SELECT *
    FROM zacg_ffid_tlog
    INTO TABLE @DATA(li_ffid_tlog)
    WHERE session_id = @lwa_line_data-session.
*    AND tcode IN @s_tcd35[].
  IF sy-subrc IS INITIAL.

    LOOP AT li_ffid_tlog INTO DATA(lwa_ffid_tlog).
      APPEND INITIAL LINE TO li_assessment ASSIGNING FIELD-SYMBOL(<lfs_assessment>).
      <lfs_assessment>-tcode    = lwa_ffid_tlog-tcode.
      IF lwa_ffid_tlog-action = 'A'.
        <lfs_assessment>-status   = 'Approved'.
      ELSEIF lwa_ffid_tlog-action = 'R'.
        <lfs_assessment>-status   = 'Rejected'.
      ELSE.
        <lfs_assessment>-status   = 'Pending'.
      ENDIF.
      <lfs_assessment>-reason   = lwa_ffid_tlog-reject_reason.
      <lfs_assessment>-approver = lwa_ffid_tlog-approver.
      <lfs_assessment>-actiondt = lwa_ffid_tlog-actiondt.
      <lfs_assessment>-actiontm = lwa_ffid_tlog-actiontm.
    ENDLOOP.

    cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_cl_alv)
                            CHANGING  t_table      = li_assessment ).

    lo_cl_alv->set_screen_popup(
      start_column = 20
      end_column   = 100
      start_line   = 10
      end_line     = 20 ).

    DATA(lo_columns) = lo_cl_alv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    TRY.
        DATA(lo_column) = lo_columns->get_column( 'TCODE' ).
        lo_column->set_short_text( 'TCode' ).
        lo_column->set_medium_text( 'Transaction' ).
        lo_column->set_long_text( 'Transaction' ).

        lo_column = lo_columns->get_column( 'STATUS' ).
        lo_column->set_short_text( 'Status' ).
        lo_column->set_medium_text( 'Status' ).
        lo_column->set_long_text( 'Status' ).

        lo_column = lo_columns->get_column( 'REASON' ).
        lo_column->set_short_text( 'Reason' ).
        lo_column->set_medium_text( 'Reason for Rejection' ).
        lo_column->set_long_text( 'Reason for Rejection' ).

        lo_column = lo_columns->get_column( 'APPROVER' ).
        lo_column->set_short_text( 'Assessor' ).
        lo_column->set_medium_text( 'Assessed By' ).
        lo_column->set_long_text( 'Assessed By' ).

        lo_column = lo_columns->get_column( 'ACTIONDT' ).
        lo_column->set_short_text( 'Date' ).
        lo_column->set_medium_text( 'Assessed On' ).
        lo_column->set_long_text( 'Assessed On' ).

        lo_column = lo_columns->get_column( 'ACTIONTM' ).
        lo_column->set_short_text( 'Time' ).
        lo_column->set_medium_text( 'Assessed At' ).
        lo_column->set_long_text( 'Assessed At' ).

      CATCH cx_salv_not_found INTO DATA(lo_error).
        MESSAGE lo_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

    DATA(alv_functions) = lo_cl_alv->get_functions( ).
    DATA(alv_selections) = lo_cl_alv->get_selections( ).
    alv_selections->set_selection_mode( cl_salv_selections=>row_column ).

    lo_cl_alv->display( ).

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9036
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9036.


  DATA:
    lt_catalog     TYPE lvc_t_fcat,
    lt_fieldvalues TYPE STANDARD TABLE OF  dynpread,
    ls_catalog     TYPE lvc_s_fcat.


  IF o_conttainer_9036 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9036
      EXPORTING
        container_name = 'CC_9036'.
  ENDIF.

  IF o_conttainer_9036 IS BOUND AND o_grid_9036 IS NOT BOUND.
    CREATE OBJECT o_grid_9036
      EXPORTING
        i_parent = o_conttainer_9036.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'SAL_DATE'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Login Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'SLGUSER'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'User'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TCODE'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Transaction'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TIMES'.
  ls_catalog-coltext   = 'Number of Times'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9036 IS BOUND.
    IF g_9036_first IS INITIAL.
      g_9036_first = abap_true.

      CALL METHOD o_grid_9036->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = i_outtab_9036.
    ELSE.
      CALL METHOD o_grid_9036->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9036->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9036->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_data_9036
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9036.

  CLEAR i_outtab_9036.
  IF s_dat36[] IS NOT INITIAL.
    SELECT slguser sal_date tcode times
      FROM zacg_tusg_dlog
      INTO TABLE i_outtab_9036
    WHERE slguser IN s_usr36[]
      AND sal_date IN s_dat36[]
      AND tcode IN s_tcd36[].
  ENDIF.
  SORT i_outtab_9036 BY sal_date DESCENDING slguser tcode times DESCENDING.

ENDFORM.

FORM set_selection_9036.

  DATA:
    lv_dlydy  TYPE dlydy,
    lv_dlymo  TYPE dlymo,
    lv_dlyyr  TYPE dlyyr,
    lr_dat_36 TYPE RANGE OF datum.


  CASE sy-ucomm.
    WHEN 'RUSG'.
      CASE abap_true.
        WHEN rb_1y_36.
          CLEAR: s_dat36, s_dat36[].
          lv_dlyyr = '01'.

        WHEN rb_1m_36.
          CLEAR: s_dat36, s_dat36[].
          lv_dlymo = '01'.

        WHEN rb_1w_36.
          CLEAR: s_dat36, s_dat36[].
          lv_dlydy = '07'.

        WHEN rb_cd_36.
          IF s_dat36 IS INITIAL.
            CLEAR: s_dat36[].
            lv_dlydy = '02'.
          ENDIF.
      ENDCASE.

      IF lv_dlyyr IS INITIAL AND lv_dlymo IS INITIAL AND lv_dlydy IS INITIAL.
      ELSE.
        CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
          EXPORTING
            date      = sy-datum
            days      = lv_dlydy
            months    = lv_dlymo
            signum    = '-'
            years     = lv_dlyyr
          IMPORTING
            calc_date = s_dat36-low.
        s_dat36-high    = sy-datum - 1.
        s_dat36-sign    = 'I'.
        s_dat36-option  = 'BT'.
        APPEND s_dat36 TO s_dat36[].
        lr_dat_36[] = s_dat36[].
      ENDIF.

    WHEN 'EXE'.
      IF rb_cd_36 IS NOT INITIAL.
        IF s_dat36 IS INITIAL.
          CLEAR sy-ucomm.
          MESSAGE 'Provide date range' TYPE 'S' DISPLAY LIKE 'E'.
        ELSE.
          lr_dat_36[] = s_dat36[].
        ENDIF.
      ELSE.
        CASE abap_true.
          WHEN rb_1y_36.
            CLEAR: s_dat36, s_dat36[].
            lv_dlyyr = '01'.

          WHEN rb_1m_36.
            CLEAR: s_dat36, s_dat36[].
            lv_dlymo = '01'.

          WHEN rb_1w_36.
            CLEAR: s_dat36, s_dat36[].
            lv_dlydy = '07'.

        ENDCASE.

        IF lv_dlyyr IS INITIAL AND lv_dlymo IS INITIAL AND lv_dlydy IS INITIAL.
        ELSE.
          CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
            EXPORTING
              date      = sy-datum
              days      = lv_dlydy
              months    = lv_dlymo
              signum    = '-'
              years     = lv_dlyyr
            IMPORTING
              calc_date = s_dat36-low.
          s_dat36-high    = sy-datum - 1.
          s_dat36-sign    = 'I'.
          s_dat36-option  = 'BT'.
          APPEND s_dat36 TO s_dat36[].
          lr_dat_36[] = s_dat36[].
        ENDIF.
      ENDIF.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form adjust_fieldcatalog
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM adjust_fieldcatalog .

  DATA:
        lwa_fieldcat TYPE lvc_s_fcat.

  CALL METHOD o_grid_8005->get_frontend_fieldcatalog
    IMPORTING
      et_fieldcatalog = DATA(li_fieldcat).

  DATA(li_summary) = i_summary_9001.
  DELETE li_summary WHERE composite IS INITIAL.
  IF li_summary IS INITIAL.
    DELETE li_fieldcat WHERE fieldname = 'COMPOSITE'.
  ELSE.
    READ TABLE li_fieldcat TRANSPORTING NO FIELDS
    WITH KEY fieldname = 'COMPOSITE'.
    IF sy-subrc IS NOT INITIAL.
      READ TABLE li_fieldcat TRANSPORTING NO FIELDS
      WITH KEY fieldname = 'AGR_NAME'.
      IF sy-subrc IS INITIAL.
        DATA(lv_index) = sy-tabix.
        lwa_fieldcat-fieldname = 'COMPOSITE'.
        lwa_fieldcat-tabname   = 'AGR_1251'.
        lwa_fieldcat-rollname  = 'AGR_NAME'.
        lwa_fieldcat-ref_table = 'AGR_1251'.
        lwa_fieldcat-ref_field = 'AGR_NAME'.
        lwa_fieldcat-scrtext_l = 'Composite Role'.
        lwa_fieldcat-scrtext_m = 'Composite Role'.
        lwa_fieldcat-scrtext_s = 'Composite Role'.
        lwa_fieldcat-col_opt   = abap_true.
        INSERT lwa_fieldcat INTO li_fieldcat INDEX lv_index.
      ENDIF.
    ENDIF.
  ENDIF.

  LOOP AT li_fieldcat ASSIGNING FIELD-SYMBOL(<lfs_fieldcat>).
    <lfs_fieldcat>-col_pos = sy-tabix.
  ENDLOOP.

  CALL METHOD o_grid_8005->set_frontend_fieldcatalog
    EXPORTING
      it_fieldcatalog = li_fieldcat.

ENDFORM.

FORM show_result_9030.


  DATA:
    lt_catalog     TYPE lvc_t_fcat,
    lt_fieldvalues TYPE STANDARD TABLE OF  dynpread,
    ls_catalog     TYPE lvc_s_fcat.


  IF o_conttainer_9030 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9030
      EXPORTING
        container_name = 'CC_9030'.
  ENDIF.

  IF o_conttainer_9030 IS BOUND AND o_grid_9030 IS NOT BOUND.
    CREATE OBJECT o_grid_9030
      EXPORTING
        i_parent = o_conttainer_9030.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'INDEX'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Row Number'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ERROR'.
  ls_catalog-coltext   = 'Error Message'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  IF o_grid_9030 IS BOUND.
    IF g_9030_first IS INITIAL.
      g_9030_first = abap_true.

      CALL METHOD o_grid_9030->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = i_outtab_9030.
    ELSE.
      CALL METHOD o_grid_9030->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9030->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9030->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form raise_bulk_request
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM raise_bulk_request.

  DATA:

    lv_nrnr          TYPE nrnr VALUE '01',
    lv_object        TYPE nrobj VALUE 'ZACG_BREQ',
    lv_nrnr_c        TYPE nrnr VALUE '01',
    lv_object_c      TYPE nrobj VALUE 'ZACG_CREQ',
    lv_new_number    TYPE zacg_req,
    lv_new_number_c  TYPE zacg_req,
    lv_message       TYPE string,
    lv_new_request   TYPE zacg_acc_req,
    lv_new_request_c TYPE zacg_acc_req,
    li_req_aprover   TYPE STANDARD TABLE OF zacg_req_aprover,
    li_req_blk_map   TYPE STANDARD TABLE OF zacg_req_blk_map.

  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr             = lv_nrnr
      object                  = lv_object
    IMPORTING
      number                  = lv_new_number
    EXCEPTIONS
      interval_not_found      = 1
      number_range_not_intern = 2
      object_not_found        = 3
      quantity_is_0           = 4
      quantity_is_not_1       = 5
      interval_overflow       = 6
      buffer_overflow         = 7
      OTHERS                  = 8.
  IF sy-subrc = 0.

    lv_new_request = |BRQ{ lv_new_number }|.

    SORT i_file_data_9030 BY user.

    LOOP AT i_file_data_9030 INTO DATA(lwa_file_data_9030).

      DATA(lv_index) = sy-tabix - 1.
      READ TABLE i_file_data_9030 INTO DATA(lwa_file_data_90301) INDEX lv_index.
      IF sy-subrc IS NOT INITIAL.
        CLEAR : lwa_file_data_90301.
      ENDIF.

      IF lwa_file_data_9030-user <> lwa_file_data_90301-user.

        CALL FUNCTION 'NUMBER_GET_NEXT'
          EXPORTING
            nr_range_nr             = lv_nrnr_c
            object                  = lv_object_c
          IMPORTING
            number                  = lv_new_number_c
          EXCEPTIONS
            interval_not_found      = 1
            number_range_not_intern = 2
            object_not_found        = 3
            quantity_is_0           = 4
            quantity_is_not_1       = 5
            interval_overflow       = 6
            buffer_overflow         = 7
            OTHERS                  = 8.
        IF sy-subrc IS INITIAL.

          lv_new_request_c = |CRQ{ lv_new_number_c }|.
          APPEND INITIAL LINE TO li_req_blk_map ASSIGNING FIELD-SYMBOL(<lfs_req_blk_map>).
          <lfs_req_blk_map>-req_no = lv_new_request.
          <lfs_req_blk_map>-child_req_no = lv_new_request_c.

        ENDIF.
      ENDIF.

      APPEND INITIAL LINE TO li_req_aprover ASSIGNING FIELD-SYMBOL(<lfs_req_aprover>).
      <lfs_req_aprover>-req_no        = lv_new_request_c.
      <lfs_req_aprover>-agr_name      = lwa_file_data_9030-role.
      <lfs_req_aprover>-seqnr         = 1.
      <lfs_req_aprover>-userid        = lwa_file_data_9030-user.
      <lfs_req_aprover>-approver      = lwa_file_data_9030-manager.
      <lfs_req_aprover>-approver_role = 1.
      <lfs_req_aprover>-status        = '02'.
      <lfs_req_aprover>-aename        = sy-uname.
      <lfs_req_aprover>-aedate        = sy-datum.
      <lfs_req_aprover>-aetim         = sy-uzeit.
      <lfs_req_aprover>-begda         = lwa_file_data_9030-start.
      <lfs_req_aprover>-endda         = lwa_file_data_9030-end.

    ENDLOOP.

    MODIFY zacg_req_aprover FROM TABLE li_req_aprover.
    MODIFY zacg_req_blk_map FROM TABLE li_req_blk_map.
    COMMIT WORK.

    CALL FUNCTION 'ZACG_NOTIFY_USERS_FOR_ROLE_REQ' STARTING NEW TASK 'TASK01'
      EXPORTING
        iv_action  = 'RQ'
        iv_request = lv_new_request.

    lv_message = |{ lv_new_request } has been initiated|.
    MESSAGE lv_message TYPE 'S'.

  ELSE.

    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_message.
    lv_message = |'Tech Error: { lv_message }|.
    MESSAGE lv_message TYPE 'E'.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9037
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9037.

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.


  IF o_conttainer_9037 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9037
      EXPORTING
        container_name = 'CC_9037'.
  ENDIF.

  IF o_conttainer_9037 IS BOUND AND o_grid_9037 IS NOT BOUND.
    CREATE OBJECT o_grid_9037
      EXPORTING
        i_parent = o_conttainer_9037.
  ENDIF.

  wa_layout-col_opt    = abap_true.
  wa_layout-box_fname  = 'BOX'.
  wa_layout-sel_mode   = 'A'.

  ls_catalog-fieldname = 'REQ_NO'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Request No'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'USER'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Requested For'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ROLE'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Requested Role'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'BEGDA'.
  ls_catalog-coltext   = 'Requested Start Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ENDDA'.
  ls_catalog-coltext   = 'Requested End Date'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'STATUST'.
  ls_catalog-coltext   = 'Status'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'APPROVER'.
  ls_catalog-coltext   = 'Action Owner'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ERNAM'.
  ls_catalog-coltext   = 'Last Action Taken By'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'ERDAT'.
  ls_catalog-coltext   = 'Last Action Taken On'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'REQACT'.
  ls_catalog-coltext   = 'Action Required'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.


  IF o_grid_9037 IS BOUND.
    IF g_9037_first IS INITIAL.
      g_9037_first = abap_true.
      CALL METHOD o_grid_9037->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = i_outtab_9037.
    ELSE.
      CALL METHOD o_grid_9037->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9037->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9037->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form user_command_9037
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_command_9037.

  CASE sy-ucomm.
    WHEN 'SH37'.
      PERFORM get_data_9037.
    WHEN 'CN37'.
      PERFORM cancel_req_9037.
    WHEN 'AR37'.
      PERFORM approve_req_9037.
    WHEN OTHERS.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9037
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9037.

  CLEAR : i_outtab_9037.

  SELECT *
  FROM zacg_req_aprover
  INTO TABLE @DATA(li_req_aprover)
  WHERE req_no IN @s_req37
  AND agr_name IN @s_rol37
  AND userid IN @s_usr37
  ORDER BY req_no.

  SELECT req_no,
         child_req_no
  FROM zacg_req_blk_map
  INTO TABLE @DATA(li_req_blk_map)
  WHERE req_no IN @s_req37.
  IF sy-subrc IS INITIAL.
    SELECT *
    FROM zacg_req_aprover
    APPENDING TABLE @li_req_aprover
    FOR ALL ENTRIES IN @li_req_blk_map
    WHERE req_no = @li_req_blk_map-child_req_no
    AND agr_name IN @s_rol37
    AND userid IN @s_usr37.
    IF sy-subrc IS INITIAL.

    ENDIF.
  ENDIF.

  IF li_req_aprover IS NOT INITIAL.
    SORT li_req_aprover BY req_no agr_name seqnr.
    DELETE ADJACENT DUPLICATES FROM li_req_aprover COMPARING req_no agr_name seqnr.

    SELECT req_no,
           child_req_no
    FROM zacg_req_blk_map
    INTO TABLE @li_req_blk_map
    FOR ALL ENTRIES IN @li_req_aprover
    WHERE child_req_no = @li_req_aprover-req_no.
    IF sy-subrc IS INITIAL.
      SORT li_req_blk_map BY child_req_no.
    ENDIF.
  ENDIF.

  IF li_req_aprover IS NOT INITIAL.

    LOOP AT li_req_aprover INTO DATA(lwa_req_aprover).

      APPEND INITIAL LINE TO i_outtab_9037 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9037>).

      READ TABLE li_req_blk_map INTO DATA(lwa_req_blk_map)
           WITH KEY child_req_no = lwa_req_aprover-req_no BINARY SEARCH.
      IF sy-subrc IS INITIAL.
        <lfs_outtab_9037>-req_no        = lwa_req_blk_map-req_no.
        <lfs_outtab_9037>-org_req_no    = lwa_req_aprover-req_no.
      ELSE.
        <lfs_outtab_9037>-req_no        = lwa_req_aprover-req_no.
        <lfs_outtab_9037>-org_req_no    = lwa_req_aprover-req_no.
      ENDIF.
      <lfs_outtab_9037>-role          = lwa_req_aprover-agr_name.
      <lfs_outtab_9037>-user          = lwa_req_aprover-userid.
      <lfs_outtab_9037>-begda         = lwa_req_aprover-begda.
      <lfs_outtab_9037>-endda         = lwa_req_aprover-endda.
      <lfs_outtab_9037>-approver      = lwa_req_aprover-approver.
      <lfs_outtab_9037>-app_role      = lwa_req_aprover-approver_role.
      <lfs_outtab_9037>-status        = lwa_req_aprover-status.
      <lfs_outtab_9037>-action_taken  = lwa_req_aprover-action_taken.
      <lfs_outtab_9037>-ernam         = lwa_req_aprover-aename.
      <lfs_outtab_9037>-erdat         = lwa_req_aprover-aedate.
      <lfs_outtab_9037>-aetim         = lwa_req_aprover-aetim.
      <lfs_outtab_9037>-seqnr         = lwa_req_aprover-seqnr.
      <lfs_outtab_9037>-rj_rsn        = lwa_req_aprover-rj_rsn.

      CASE lwa_req_aprover-approver_role.
        WHEN 1.
          IF lwa_req_aprover-status = 02.
            <lfs_outtab_9037>-statust = 'Pending with Line Manager'.
          ELSEIF lwa_req_aprover-status = 03.
            <lfs_outtab_9037>-statust = 'Approved by Line Manager'.
          ELSEIF lwa_req_aprover-status = 04.
            <lfs_outtab_9037>-statust = 'Rejected by Line Manager'.
          ENDIF.
        WHEN 2.
          IF lwa_req_aprover-status = 02.
            <lfs_outtab_9037>-statust = 'Pending with Role Owner'.
          ELSEIF lwa_req_aprover-status = 03.
            <lfs_outtab_9037>-statust = 'Approved by Role Owner'.
          ELSEIF lwa_req_aprover-status = 04.
            <lfs_outtab_9037>-statust = 'Rejected by Role Owner'.
          ENDIF.
        WHEN 3.
          IF lwa_req_aprover-status = 02.
            <lfs_outtab_9037>-statust = 'Pending with Admin'.
          ELSEIF lwa_req_aprover-status = 03.
            <lfs_outtab_9037>-statust = 'Approved by Admin'.
          ELSEIF lwa_req_aprover-status = 05.
            <lfs_outtab_9037>-statust = 'Cancelled by Admin'.
          ENDIF.
        WHEN OTHERS.
      ENDCASE.


      IF lwa_req_aprover-action_taken = abap_true.
        <lfs_outtab_9037>-reqact = 'No'.
      ELSE.
        <lfs_outtab_9037>-reqact = 'Yes'.
      ENDIF.

    ENDLOOP.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form update_message_dins
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LO_MSG_BUFFER
*&      --> LWA_NODE_ROOT_>ROLE
*&      --> P_
*&---------------------------------------------------------------------*
FORM update_message_dins  USING io_msg_buffer TYPE REF TO if_spcg_msg_buffer
                                iv_role       TYPE agr_name
                                iv_object     TYPE xuobject
                                iv_auth       TYPE agauth.

  DATA : lt_message   TYPE if_spcg_msg_buffer=>tt_messages,
         lwa_auth_val TYPE ty_auth_val,
         lt_auth_val  TYPE TABLE OF ty_auth_val.

  IF iv_role IS INITIAL.
    lt_message = io_msg_buffer->get_messages( ).
  ELSE.
    lt_message = io_msg_buffer->get_messages( iv_role = iv_role ).
  ENDIF.

  IF lt_message IS INITIAL.

    lwa_auth_val-role = iv_role.
    lwa_auth_val-type = 'Success'.
    IF pa_din IS NOT INITIAL.
      lwa_auth_val-message = |Object Deactivated for instance { iv_auth }|.
    ELSEIF pa_adi IS NOT INITIAL.
      lwa_auth_val-message = |Object Activated for instance { iv_auth }|.
    ENDIF.

    lwa_auth_val-object  = iv_object.

    APPEND lwa_auth_val TO lt_auth_val.
    CLEAR : lwa_auth_val.

  ELSE.

    LOOP AT lt_message INTO DATA(lwa_message).

      lwa_auth_val-role = lwa_message-role.
      IF lwa_message-msgty = 'S'.
        lwa_auth_val-type = 'Success'.
      ELSEIF lwa_message-msgty = 'E'.
        lwa_auth_val-type = 'Error'.
      ELSE.
        lwa_auth_val-type = lwa_message-msgty.
      ENDIF.
      lwa_auth_val-message = lwa_message-message.
      lwa_auth_val-object  = iv_object.

      APPEND lwa_auth_val TO lt_auth_val.
      CLEAR : lwa_auth_val.

    ENDLOOP.

  ENDIF.
  IF lt_auth_val IS NOT INITIAL.
    APPEND LINES OF lt_auth_val TO gt_auth_val.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form cancel_req_9037
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM cancel_req_9037 .

  DATA : lv_message  TYPE string.

  o_grid_9037->get_selected_rows(
    IMPORTING
      et_index_rows = DATA(li_index_rows)
      et_row_no     = DATA(li_row_no) ).

  IF li_row_no IS NOT INITIAL.

    SELECT *
    FROM zacg_req_aprover
    INTO TABLE @DATA(li_req_aprover)
    FOR ALL ENTRIES IN @i_outtab_9037
    WHERE req_no = @i_outtab_9037-org_req_no
    AND agr_name = @i_outtab_9037-role
    AND seqnr = @i_outtab_9037-seqnr.
    IF sy-subrc IS INITIAL.
      SORT li_req_aprover BY req_no agr_name seqnr.
      DATA(li_req_aprover_new) = li_req_aprover.
    ENDIF.

    LOOP AT li_row_no INTO DATA(lwa_row_no).
      READ TABLE i_outtab_9037 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9037>) INDEX lwa_row_no-row_id.
      IF sy-subrc IS INITIAL.
        IF <lfs_outtab_9037>-action_taken = abap_true.
          lv_message = |Action already taken for the selected line item.|.
          MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT li_row_no INTO lwa_row_no.
      READ TABLE i_outtab_9037 ASSIGNING <lfs_outtab_9037> INDEX lwa_row_no-row_id.
      IF sy-subrc IS INITIAL.
        IF <lfs_outtab_9037>-action_taken = abap_false.
          READ TABLE li_req_aprover_new ASSIGNING FIELD-SYMBOL(<lfs_req_aprover>) WITH KEY
                                    req_no = <lfs_outtab_9037>-org_req_no
                                    agr_name = <lfs_outtab_9037>-role
                                    seqnr    = <lfs_outtab_9037>-seqnr BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            <lfs_req_aprover>-action_taken = abap_true.
            APPEND INITIAL LINE TO li_req_aprover_new ASSIGNING FIELD-SYMBOL(<lfs_req_aprover_n>).
            IF <lfs_req_aprover_n> IS ASSIGNED.
              <lfs_req_aprover_n>               = <lfs_req_aprover>.
              <lfs_req_aprover_n>-action_taken  = abap_true.
              <lfs_req_aprover_n>-status        = 05.
              <lfs_req_aprover_n>-approver_role = 3.
              <lfs_req_aprover_n>-seqnr         = <lfs_req_aprover>-seqnr + 1.
              <lfs_req_aprover_n>-approver      = sy-uname.
              <lfs_req_aprover_n>-aedate        = sy-datum.
              <lfs_req_aprover_n>-aetim         = sy-uzeit.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF li_req_aprover <> li_req_aprover_new.
      MODIFY zacg_req_aprover FROM TABLE li_req_aprover_new.
      IF sy-subrc IS INITIAL.
        COMMIT WORK AND WAIT.
        PERFORM get_data_9037.
      ENDIF.
    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form approve_req_9037
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM approve_req_9037 .

  DATA : lv_message  TYPE string.

  BREAK : rounak.

  o_grid_9037->get_selected_rows(
    IMPORTING
      et_index_rows = DATA(li_index_rows)
      et_row_no     = DATA(li_row_no) ).

  IF li_row_no IS NOT INITIAL.

    SELECT *
    FROM zacg_req_aprover
    INTO TABLE @DATA(li_req_aprover)
    FOR ALL ENTRIES IN @i_outtab_9037
    WHERE req_no = @i_outtab_9037-org_req_no
    AND agr_name = @i_outtab_9037-role
    AND seqnr = @i_outtab_9037-seqnr.
    IF sy-subrc IS INITIAL.
      SORT li_req_aprover BY req_no agr_name seqnr.
      DATA(li_req_aprover_new) = li_req_aprover.
    ENDIF.

    LOOP AT li_row_no INTO DATA(lwa_row_no).
      READ TABLE i_outtab_9037 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9037>) INDEX lwa_row_no-row_id.
      IF sy-subrc IS INITIAL.
        IF <lfs_outtab_9037>-action_taken = abap_true.
          lv_message = |Action already taken for the selected line item.|.
          MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF i_outtab_9037 IS NOT INITIAL.
      SELECT *
      FROM zacg_role_owners
      INTO TABLE @DATA(li_owners)
      FOR ALL ENTRIES IN @i_outtab_9037
      WHERE agr_name = @i_outtab_9037-role.
      IF sy-subrc IS INITIAL.
        SORT li_owners BY agr_name.
      ENDIF.
    ENDIF.

    LOOP AT li_row_no INTO lwa_row_no.
      READ TABLE i_outtab_9037 ASSIGNING <lfs_outtab_9037> INDEX lwa_row_no-row_id.
      IF sy-subrc IS INITIAL.
        IF <lfs_outtab_9037>-action_taken = abap_false.
          READ TABLE li_req_aprover_new ASSIGNING FIELD-SYMBOL(<lfs_req_aprover>) WITH KEY
                                    req_no = <lfs_outtab_9037>-org_req_no
                                    agr_name = <lfs_outtab_9037>-role
                                    seqnr    = <lfs_outtab_9037>-seqnr BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            <lfs_req_aprover>-action_taken = abap_true.
            CASE <lfs_req_aprover>-approver_role.
              WHEN 1.
                <lfs_req_aprover>-status        = 03.
                <lfs_req_aprover>-approver_role = 3.

                APPEND INITIAL LINE TO li_req_aprover_new ASSIGNING FIELD-SYMBOL(<lfs_req_aprover_n>).
                IF <lfs_req_aprover_n> IS ASSIGNED.
                  <lfs_req_aprover_n>               = <lfs_req_aprover>.
                  <lfs_req_aprover_n>-action_taken  = abap_false.
                  <lfs_req_aprover_n>-status        = 02.
                  <lfs_req_aprover_n>-approver_role = 2.

                  <lfs_req_aprover_n>-seqnr         = <lfs_req_aprover>-seqnr + 1.
                  READ TABLE li_owners INTO DATA(lwa_owners)
                      WITH KEY agr_name = <lfs_outtab_9037>-role BINARY SEARCH.
                  IF sy-subrc IS INITIAL.
                    IF <lfs_req_aprover>-req_no(1) = 'N'.
                      <lfs_req_aprover_n>-approver = lwa_owners-agr_owner.
                    ELSEIF <lfs_req_aprover>-req_no(1) = 'B'.
                      <lfs_req_aprover_n>-approver = lwa_owners-agr_bowner.
                    ENDIF.
                  ENDIF.
                  <lfs_req_aprover_n>-aedate        = sy-datum.
                  <lfs_req_aprover_n>-aetim         = sy-uzeit.
                ENDIF.

              WHEN 2.
                <lfs_req_aprover>-status        = 03.
                <lfs_req_aprover>-approver_role = 3.
              WHEN OTHERS.
            ENDCASE.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF li_req_aprover <> li_req_aprover_new.
      MODIFY zacg_req_aprover FROM TABLE li_req_aprover_new.
      IF sy-subrc IS INITIAL.
        COMMIT WORK AND WAIT.
        PERFORM get_data_9037.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9041
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9041.

  PERFORM sub_get_combine_file_data.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form validate_9041
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_9041 .

  DATA : lv_count               TYPE i,
         lv_error               TYPE char1,
         lv_file411             TYPE string,
         lv_file412             TYPE string,
         li_excel               TYPE STANDARD TABLE OF alsmex_tabline,
         li_file_data_9041_r    TYPE STANDARD TABLE OF ty_file_data_9041_r,
         li_file_data_9041_u    TYPE STANDARD TABLE OF ty_file_data_9041_u,
         li_file_data_90412_txt TYPE STANDARD TABLE OF ty_file_data_90412_txt,
         li_file_data_90411_txt TYPE STANDARD TABLE OF ty_file_data_90411_txt,
         li_type                TYPE truxs_t_text_data.


  CHECK g_ucomm = 'EXE'.

  DATA: lt_xtab     TYPE cpt_x255,
        lv_filename TYPE string,
        lv_size     TYPE i.

*** Excel Upload
  IF rb_xls41 IS NOT INITIAL.
*** Role File Path
    IF p_fil412 IS NOT INITIAL.

      DATA(lv_len) = strlen( p_fil412 ) - 4.
      DATA(lv_len1) = strlen( p_fil412 ) - 5.
      TRANSLATE p_fil412+lv_len(4) TO UPPER CASE.
      TRANSLATE p_fil412+lv_len1(5) TO UPPER CASE.
      IF p_fil412+lv_len(4) = '.XLS' OR p_fil412+lv_len1(5) = '.XLSX'.

        CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
          EXPORTING
            i_tab_raw_data       = li_type
            i_filename           = p_fil412
          TABLES
            i_tab_converted_data = li_file_data_9041_r
          EXCEPTIONS
            conversion_failed    = 1
            OTHERS               = 2.
        IF sy-subrc = 0.
          LOOP AT li_file_data_9041_r ASSIGNING FIELD-SYMBOL(<lfs_data_xls_r>).
            IF sy-tabix = 1.
              ASSIGN COMPONENT 1 OF STRUCTURE <lfs_data_xls_r> TO FIELD-SYMBOL(<lfs_value>).
              IF <lfs_value> IS ASSIGNED.
                IF <lfs_value> NE 'Role'.
                  MESSAGE '1st column should name as Role' TYPE 'I' DISPLAY LIKE 'E'.
                  lv_error = abap_true.
                  EXIT.
                ENDIF.
              ENDIF.
              ASSIGN COMPONENT 2 OF STRUCTURE <lfs_data_xls_r> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                IF <lfs_value> NE 'Object'.
                  MESSAGE '2nd column should name as Object' TYPE 'I' DISPLAY LIKE 'E'.
                  lv_error = abap_true.
                  EXIT.
                ENDIF.
              ENDIF.
              ASSIGN COMPONENT 3 OF STRUCTURE <lfs_data_xls_r> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                IF <lfs_value> NE 'Field name'.
                  MESSAGE '3rd column should name as Field name' TYPE 'I'  DISPLAY LIKE 'E'.
                  lv_error = abap_true.
                  EXIT.
                ENDIF.
              ENDIF.
              ASSIGN COMPONENT 4 OF STRUCTURE <lfs_data_xls_r> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                IF <lfs_value> NE 'Authorization value'.
                  MESSAGE '4th column should name as Authorization value' TYPE 'I' DISPLAY LIKE 'E'.
                  lv_error = abap_true.
                  EXIT.
                ENDIF.
              ENDIF.
            ELSE.
              APPEND INITIAL LINE TO i_file_data_9041_r ASSIGNING FIELD-SYMBOL(<lfs_file_data_9041_r>).

              ASSIGN COMPONENT 1 OF STRUCTURE <lfs_data_xls_r> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                <lfs_file_data_9041_r>-agr_name = <lfs_value>.
              ENDIF.
              ASSIGN COMPONENT 2 OF STRUCTURE <lfs_data_xls_r> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                <lfs_file_data_9041_r>-object = <lfs_value>.
              ENDIF.
              ASSIGN COMPONENT 3 OF STRUCTURE <lfs_data_xls_r> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                <lfs_file_data_9041_r>-field = <lfs_value>.
              ENDIF.
              ASSIGN COMPONENT 4 OF STRUCTURE <lfs_data_xls_r> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                <lfs_file_data_9041_r>-value = <lfs_value>.
              ENDIF.

            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide a file' TYPE 'E'.
    ENDIF.

    IF p_fil411 IS NOT INITIAL.
      lv_len = strlen( p_fil411 ) - 4.
      lv_len1 = strlen( p_fil411 ) - 5.
      TRANSLATE p_fil411+lv_len(4) TO UPPER CASE.
      TRANSLATE p_fil411+lv_len1(5) TO UPPER CASE.
      IF p_fil411+lv_len(4) = '.XLS' OR p_fil411+lv_len1(5) = '.XLSX'.

        CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
          EXPORTING
            i_tab_raw_data       = li_type
            i_filename           = p_fil411
          TABLES
            i_tab_converted_data = li_file_data_9041_u
          EXCEPTIONS
            conversion_failed    = 1
            OTHERS               = 2.
        IF sy-subrc = 0.
          LOOP AT li_file_data_9041_u ASSIGNING FIELD-SYMBOL(<lfs_data_xls_u>).
            IF sy-tabix = 1.
              ASSIGN COMPONENT 1 OF STRUCTURE <lfs_data_xls_u> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                IF <lfs_value> NE 'User'.
                  MESSAGE '1st column should name as User' TYPE 'I' DISPLAY LIKE 'E'.
                  lv_error = abap_true.
                  EXIT.
                ENDIF.
              ENDIF.
              ASSIGN COMPONENT 2 OF STRUCTURE <lfs_data_xls_u> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                IF <lfs_value> NE 'Role'.
                  MESSAGE '1st column should name as Role' TYPE 'I' DISPLAY LIKE 'E'.
                  lv_error = abap_true.
                  EXIT.
                ENDIF.
              ENDIF.
            ELSE.
              APPEND INITIAL LINE TO i_file_data_9041_u ASSIGNING FIELD-SYMBOL(<lfs_file_data_9041_u>).

              ASSIGN COMPONENT 1 OF STRUCTURE <lfs_data_xls_u> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                <lfs_file_data_9041_u>-user = <lfs_value>.
              ENDIF.

              ASSIGN COMPONENT 2 OF STRUCTURE <lfs_data_xls_u> TO <lfs_value>.
              IF <lfs_value> IS ASSIGNED.
                <lfs_file_data_9041_u>-role = <lfs_value>.
              ENDIF.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide a file' TYPE 'E'.
    ENDIF.

  ELSE.

    IF p_fil412 IS NOT INITIAL.

      lv_len = strlen( p_fil412 ) - 4.
      TRANSLATE p_fil412+lv_len(4) TO UPPER CASE.
      IF p_fil412+lv_len(4) = '.TXT'.

        lv_file412 = p_fil412.

        CALL FUNCTION 'GUI_UPLOAD'
          EXPORTING
            filename                = lv_file412
            filetype                = 'ASC'
            has_field_separator     = 'X'
          TABLES
            data_tab                = li_file_data_90412_txt
          EXCEPTIONS
            file_open_error         = 1
            file_read_error         = 2
            no_batch                = 3
            gui_refuse_filetransfer = 4
            invalid_type            = 5
            no_authority            = 6
            unknown_error           = 7
            bad_data_format         = 8
            header_not_allowed      = 9
            separator_not_allowed   = 10
            header_too_long         = 11
            unknown_dp_error        = 12
            access_denied           = 13
            dp_out_of_memory        = 14
            disk_full               = 15
            dp_timeout              = 16
            OTHERS                  = 17.
        IF sy-subrc = 0.
          DELETE li_file_data_90412_txt FROM 1 TO 5.
          IF li_file_data_90412_txt IS NOT INITIAL.
            CLEAR : i_file_data_9041_r.
            LOOP AT li_file_data_90412_txt INTO DATA(lwa_file_data_90412_txt).
              APPEND INITIAL LINE TO i_file_data_9041_r ASSIGNING
              <lfs_file_data_9041_r>.
              MOVE-CORRESPONDING lwa_file_data_90412_txt TO <lfs_file_data_9041_r>.
            ENDLOOP.
          ENDIF.
        ELSE.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide a file' TYPE 'E'.
    ENDIF.

    IF p_fil411 IS NOT INITIAL.

      lv_len = strlen( p_fil411 ) - 4.
      TRANSLATE p_fil411+lv_len(4) TO UPPER CASE.
      IF p_fil411+lv_len(4) = '.TXT'.

        lv_file411 = p_fil411.
        CALL FUNCTION 'GUI_UPLOAD'
          EXPORTING
            filename                = lv_file411
            filetype                = 'ASC'
            has_field_separator     = 'X'
          TABLES
            data_tab                = li_file_data_90411_txt
          EXCEPTIONS
            file_open_error         = 1
            file_read_error         = 2
            no_batch                = 3
            gui_refuse_filetransfer = 4
            invalid_type            = 5
            no_authority            = 6
            unknown_error           = 7
            bad_data_format         = 8
            header_not_allowed      = 9
            separator_not_allowed   = 10
            header_too_long         = 11
            unknown_dp_error        = 12
            access_denied           = 13
            dp_out_of_memory        = 14
            disk_full               = 15
            dp_timeout              = 16
            OTHERS                  = 17.
        IF sy-subrc = 0.
          DELETE li_file_data_90411_txt FROM 1 TO 5.
          IF li_file_data_90411_txt IS NOT INITIAL.
            CLEAR : i_file_data_9041_u.
            LOOP AT li_file_data_90411_txt INTO DATA(lwa_file_data_90411_txt).
              APPEND INITIAL LINE TO i_file_data_9041_u ASSIGNING
              <lfs_file_data_9041_u>.
              MOVE-CORRESPONDING lwa_file_data_90411_txt TO <lfs_file_data_9041_u>.
            ENDLOOP.
          ENDIF.
        ELSE.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide a file' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form sub_get_combine_file_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM sub_get_combine_file_data.

  TYPES : BEGIN OF lty_role_user,
            priority  TYPE zacg_rule_prio,
            rule_desc TYPE zacg_rule_desc,
            agr_name  TYPE agr_name,
            user      TYPE xubname,
            object    TYPE agobject,
            value     TYPE agval,
          END OF lty_role_user.

  DATA : li_role_user TYPE TABLE OF lty_role_user.

  IF i_file_data_9041_r IS NOT INITIAL.
    SELECT *
    FROM zacg_fue_rul_set
    INTO TABLE @DATA(li_rule_set)
    FOR ALL ENTRIES IN @i_file_data_9041_r
    WHERE object = @i_file_data_9041_r-object
    AND field = @i_file_data_9041_r-field
    AND value = @i_file_data_9041_r-value
    ORDER BY PRIMARY KEY.
    IF sy-subrc IS INITIAL.

    ENDIF.

*** Get Activity Data for * Activities
    DATA(li_file_data_star) = i_file_data_9041_r.
    DELETE li_file_data_star WHERE value NE '*'.
    DELETE i_file_data_9041_r WHERE value EQ '*'.

    IF li_file_data_star IS NOT INITIAL.

      SELECT brobj,
             actvt
      FROM tactz
      INTO TABLE @DATA(li_tactz)
      FOR ALL ENTRIES IN @li_file_data_star
      WHERE brobj = @li_file_data_star-object.
      IF sy-subrc IS INITIAL.
        SORT li_tactz BY brobj.
      ENDIF.

      LOOP AT li_file_data_star INTO DATA(lwa_file_data_star).
        READ TABLE li_tactz TRANSPORTING NO FIELDS WITH KEY brobj = lwa_file_data_star-object
        BINARY SEARCH.
        IF sy-subrc IS INITIAL.
          DATA(lv_tabix1) = sy-tabix.
          LOOP AT li_tactz INTO DATA(lwa_tactz) FROM lv_tabix1.
            IF lwa_tactz-brobj NE lwa_file_data_star-object.
              EXIT.
            ELSE.
              APPEND INITIAL LINE TO i_file_data_9041_r
              ASSIGNING FIELD-SYMBOL(<lfs_role_val_star>).
              <lfs_role_val_star>-agr_name = lwa_file_data_star-agr_name.
              <lfs_role_val_star>-object   = lwa_file_data_star-object.
              <lfs_role_val_star>-field    = lwa_file_data_star-field.
              <lfs_role_val_star>-value    = lwa_tactz-actvt.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDLOOP.
      CLEAR li_file_data_star.

      SORT i_file_data_9041_r.
      DELETE ADJACENT DUPLICATES FROM i_file_data_9041_r COMPARING ALL FIELDS.

*** Fill Output Table 4.
      LOOP AT i_file_data_9041_r ASSIGNING <lfs_role_val_star>.
        APPEND INITIAL LINE TO i_outtab_9041_s4 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9041_s4>).
        <lfs_outtab_9041_s4>-agr_name = <lfs_role_val_star>-agr_name.
        <lfs_outtab_9041_s4>-object   = <lfs_role_val_star>-object.
        <lfs_outtab_9041_s4>-value    = <lfs_role_val_star>-value.
        READ TABLE li_rule_set INTO DATA(lwa_rule_set) WITH KEY
        object  = <lfs_role_val_star>-object
        field   = <lfs_role_val_star>-field
        value   = <lfs_role_val_star>-value BINARY SEARCH.
        IF sy-subrc IS INITIAL.
          <lfs_outtab_9041_s4>-priority  = lwa_rule_set-priority.
          <lfs_outtab_9041_s4>-rule_desc = lwa_rule_set-rule_desc.
        ELSE.
          IF <lfs_role_val_star>-value = '03'.
            <lfs_outtab_9041_s4>-priority  = 3.
            <lfs_outtab_9041_s4>-rule_desc = 'GD Self-Service Use'.
          ELSE.
            <lfs_outtab_9041_s4>-priority  = 4.
            <lfs_outtab_9041_s4>-rule_desc = 'Not Classified'.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF i_outtab_9041_s4 IS NOT INITIAL.
        SORT i_outtab_9041_s4 BY priority agr_name object value.
        SORT i_file_data_9041_u BY role.

        LOOP AT i_outtab_9041_s4 INTO DATA(lwa_outtab_9041_s4).
          READ TABLE i_file_data_9041_u TRANSPORTING NO FIELDS WITH KEY role = lwa_outtab_9041_s4-agr_name BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            DATA(lv_tabix) = sy-tabix.
            LOOP AT i_file_data_9041_u INTO DATA(lwa_file_9041_u).
              IF lwa_file_9041_u-role <> lwa_outtab_9041_s4-agr_name.
                EXIT.
              ELSE.
                APPEND INITIAL LINE TO li_role_user ASSIGNING FIELD-SYMBOL(<lfs_role_user>).
                <lfs_role_user>-priority  = lwa_outtab_9041_s4-priority .
                <lfs_role_user>-rule_desc = lwa_outtab_9041_s4-rule_desc.
                <lfs_role_user>-agr_name  = lwa_outtab_9041_s4-agr_name.
                <lfs_role_user>-object    = lwa_outtab_9041_s4-object.
                <lfs_role_user>-value     = lwa_outtab_9041_s4-value.
                <lfs_role_user>-user      = lwa_file_9041_u-user.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDLOOP.

        IF li_role_user IS NOT INITIAL.
          SELECT priority,
                 rule_desc,
                 user,
                 agr_name,
             COUNT( object ) AS no_of_object
          FROM @li_role_user AS role_user
          GROUP BY priority, rule_desc, user, agr_name
          INTO TABLE @i_outtab_9041_s3.
          IF sy-subrc IS INITIAL.
            SORT i_outtab_9041_s3 BY user agr_name priority.
          ENDIF.

          SELECT priority,
                 rule_desc,
                 user,
            COUNT( object ) AS no_of_object
          FROM @li_role_user AS role_user
          GROUP BY priority, rule_desc, user
          INTO TABLE @i_outtab_9041_s2.
          IF sy-subrc IS INITIAL.
            SORT i_outtab_9041_s2 BY user priority.
          ENDIF.
        ENDIF.

        DATA(li_outtab_9041_s2) = i_outtab_9041_s2.
        SORT li_outtab_9041_s2 BY user priority.
        DELETE ADJACENT DUPLICATES FROM li_outtab_9041_s2 COMPARING user.

        DATA(li_prio_count) = li_outtab_9041_s2.
        DELETE li_prio_count WHERE priority NE 1.
        DATA(lv_advance) = lines( li_prio_count ).

        li_prio_count = li_outtab_9041_s2.
        DELETE li_prio_count WHERE priority NE 2.
        DATA(lv_core) = lines( li_prio_count ).

        li_prio_count = li_outtab_9041_s2.
        DELETE li_prio_count WHERE priority NE 3.
        DATA(lv_self) = lines( li_prio_count ).

        li_prio_count = li_outtab_9041_s2.
        DELETE li_prio_count WHERE priority NE 4.
        DATA(lv_not_class) = lines( li_prio_count ).

        APPEND VALUE ty_outtab_9041( head = 'No of Users'
                                   gb_advance = lv_advance
                                   gc_core    = lv_core
                                   gd_self    = lv_self
                                   not_class  = lv_not_class
                                   tot_class  = ( lv_advance + lv_core + lv_self )
                                   total      = ( lv_advance + lv_core + lv_self + lv_not_class ) ) TO i_outtab_9041.

        APPEND VALUE ty_outtab_9042( head = 'No of FUE'
                                      gb_advance = lv_advance
                                      gc_core    = lv_core / 5
                                      gd_self    = lv_self / 30
                                      not_class  = 0
                                      tot_class  = ceil( CONV f( lv_advance + lv_core / 5 + lv_self / 30 ) )
                                      total      = 0 ) TO i_outtab_9042.

        PERFORM show_result_9041.

      ENDIF.
    ENDIF.
  ENDIF.



ENDFORM.
*&---------------------------------------------------------------------*
*& Form validate_9042
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_9042 .

  DATA : lv_count              TYPE i,
         lv_error              TYPE char1,
         lv_file42             TYPE string,

         li_excel              TYPE STANDARD TABLE OF alsmex_tabline,
         li_file_data_9042     TYPE STANDARD TABLE OF ty_file_data_9042,
         li_file_data_9042_txt TYPE STANDARD TABLE OF ty_file_data_9042_txt.


  CHECK g_ucomm = 'EXE'.

  DATA: lt_xtab     TYPE cpt_x255,
        lv_filename TYPE string,
        lv_size     TYPE i.

  IF rb_xls42 IS NOT INITIAL.
    IF p_file42 IS NOT INITIAL.
      DATA(lv_len) = strlen( p_file42 ) - 4.
      DATA(lv_len1) = strlen( p_file42 ) - 5.
      TRANSLATE p_file42+lv_len(4) TO UPPER CASE.
      TRANSLATE p_file42+lv_len1(5) TO UPPER CASE.
      IF p_file42+lv_len(4) = '.XLS' OR p_file42+lv_len1(5) = '.XLSX'.

        lv_filename = p_file42.

        cl_gui_frontend_services=>gui_upload(
          EXPORTING
            filename             = lv_filename
            filetype             = 'BIN'
          IMPORTING
            filelength           = lv_size
          CHANGING
            data_tab             = lt_xtab
          EXCEPTIONS
            file_open_error      = 1
            file_read_error      = 2
            error_no_gui         = 3
            not_supported_by_gui = 4
            OTHERS               = 5 ).
        IF sy-subrc <> 0.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ELSE.
          cl_scp_change_db=>xtab_to_xstr(
            EXPORTING
              im_xtab    = lt_xtab
              im_size    = lv_size
            IMPORTING
              ex_xstring = DATA(lv_xstring) ).

          DATA(lo_excel) = NEW cl_fdt_xl_spreadsheet(
            document_name = lv_filename
            xdocument     = lv_xstring ).

          lo_excel->if_fdt_doc_spreadsheet~get_worksheet_names(
            IMPORTING
              worksheet_names = DATA(lt_worksheets) ).

          DATA(rt_table) = lo_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet( lt_worksheets[ 1 ] ).

          ASSIGN rt_table->* TO FIELD-SYMBOL(<lfs_data_tab>).
          IF <lfs_data_tab> IS ASSIGNED.
            LOOP AT <lfs_data_tab> ASSIGNING FIELD-SYMBOL(<lfs_data>).
              IF sy-tabix = 1.
                ASSIGN COMPONENT 1 OF STRUCTURE <lfs_data> TO FIELD-SYMBOL(<lfs_value>).
                IF <lfs_value> IS ASSIGNED.
                  IF <lfs_value> NE 'Role'.
                    MESSAGE '1st column should name as Role' TYPE 'I' DISPLAY LIKE 'E'.
                    lv_error = abap_true.
                    EXIT.
                  ENDIF.
                ENDIF.
                ASSIGN COMPONENT 2 OF STRUCTURE <lfs_data> TO <lfs_value>.
                IF <lfs_value> IS ASSIGNED.
                  IF <lfs_value> NE 'Object'.
                    MESSAGE '2nd column should name as Object' TYPE 'I' DISPLAY LIKE 'E'.
                    lv_error = abap_true.
                    EXIT.
                  ENDIF.
                ENDIF.
                ASSIGN COMPONENT 3 OF STRUCTURE <lfs_data> TO <lfs_value>.
                IF <lfs_value> IS ASSIGNED.
                  IF <lfs_value> NE 'Field name'.
                    MESSAGE '3rd column should name as Field name' TYPE 'I'  DISPLAY LIKE 'E'.
                    lv_error = abap_true.
                    EXIT.
                  ENDIF.
                ENDIF.
                ASSIGN COMPONENT 4 OF STRUCTURE <lfs_data> TO <lfs_value>.
                IF <lfs_value> IS ASSIGNED.
                  IF <lfs_value> NE 'Authorization value'.
                    MESSAGE '4th column should name as Authorization value' TYPE 'I' DISPLAY LIKE 'E'.
                    lv_error = abap_true.
                    EXIT.
                  ENDIF.
                ENDIF.

              ELSE.

                APPEND INITIAL LINE TO i_file_data_9042 ASSIGNING FIELD-SYMBOL(<lfs_file_data_9042>).

                ASSIGN COMPONENT 1 OF STRUCTURE <lfs_data> TO <lfs_value>.
                IF <lfs_value> IS ASSIGNED.
                  <lfs_file_data_9042>-agr_name = <lfs_value>.
                ENDIF.
                ASSIGN COMPONENT 2 OF STRUCTURE <lfs_data> TO <lfs_value>.
                IF <lfs_value> IS ASSIGNED.
                  <lfs_file_data_9042>-object = <lfs_value>.
                ENDIF.
                ASSIGN COMPONENT 3 OF STRUCTURE <lfs_data> TO <lfs_value>.
                IF <lfs_value> IS ASSIGNED.
                  <lfs_file_data_9042>-field = <lfs_value>.
                ENDIF.
                ASSIGN COMPONENT 4 OF STRUCTURE <lfs_data> TO <lfs_value>.
                IF <lfs_value> IS ASSIGNED.
                  <lfs_file_data_9042>-value = <lfs_value>.
                ENDIF.
              ENDIF.
            ENDLOOP.
          ENDIF.

        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide a file' TYPE 'E'.
    ENDIF.

  ELSE.

    IF p_file42 IS NOT INITIAL.
      lv_len = strlen( p_file42 ) - 4.
      TRANSLATE p_file42+lv_len(4) TO UPPER CASE.
      IF p_file42+lv_len(4) = '.TXT'.

        lv_file42 = p_file42.

        CALL FUNCTION 'GUI_UPLOAD'
          EXPORTING
            filename                = lv_file42
            filetype                = 'ASC'
            has_field_separator     = 'X'
          TABLES
            data_tab                = li_file_data_9042_txt
          EXCEPTIONS
            file_open_error         = 1
            file_read_error         = 2
            no_batch                = 3
            gui_refuse_filetransfer = 4
            invalid_type            = 5
            no_authority            = 6
            unknown_error           = 7
            bad_data_format         = 8
            header_not_allowed      = 9
            separator_not_allowed   = 10
            header_too_long         = 11
            unknown_dp_error        = 12
            access_denied           = 13
            dp_out_of_memory        = 14
            disk_full               = 15
            dp_timeout              = 16
            OTHERS                  = 17.
        IF sy-subrc = 0.
          DELETE li_file_data_9042_txt FROM 1 TO 5.
          IF li_file_data_9042_txt IS NOT INITIAL.
            CLEAR : i_file_data_9042.
            LOOP AT li_file_data_9042_txt INTO DATA(lwa_file_data_9042_txt).
              APPEND INITIAL LINE TO i_file_data_9042 ASSIGNING
              <lfs_file_data_9042>.
              MOVE-CORRESPONDING lwa_file_data_9042_txt TO <lfs_file_data_9042>.
            ENDLOOP.
          ENDIF.
        ELSE.
          CLEAR: sy-ucomm, g_ucomm.
          MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.
      ENDIF.
    ELSE.
      CLEAR: sy-ucomm, g_ucomm.
      MESSAGE 'Please provide a file' TYPE 'E'.
    ENDIF.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data_9042
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data_9042 .

  DATA : li_role_val_star TYPE TABLE OF ty_file_data_9042.

  CLEAR : i_outtab_9042, i_outtab_9042_s2, i_outtab_9042_s3.

  DELETE i_file_data_9042 WHERE agr_name IS INITIAL.


  IF i_file_data_9042 IS NOT INITIAL.

    SELECT *
    FROM zacg_fue_rul_set
    INTO TABLE @DATA(li_rule_set)
    FOR ALL ENTRIES IN @i_file_data_9042
    WHERE object = @i_file_data_9042-object
    AND field = @i_file_data_9042-field
    AND value = @i_file_data_9042-value
    ORDER BY PRIMARY KEY.
    IF sy-subrc IS INITIAL.
    ENDIF.

*** Get Activity Data for * Activities
    DATA(li_file_data_star) = i_file_data_9042.
    DELETE li_file_data_star WHERE value NE '*'.
    DELETE i_file_data_9042 WHERE value EQ '*'.

    IF li_file_data_star IS NOT INITIAL.

      SELECT brobj,
             actvt
      FROM tactz
      INTO TABLE @DATA(li_tactz)
      FOR ALL ENTRIES IN @li_file_data_star
      WHERE brobj = @li_file_data_star-object.
      IF sy-subrc IS INITIAL.
        SORT li_tactz BY brobj.
      ENDIF.

      LOOP AT li_file_data_star INTO DATA(lwa_file_data_star).
        READ TABLE li_tactz TRANSPORTING NO FIELDS WITH KEY brobj = lwa_file_data_star-object
        BINARY SEARCH.
        IF sy-subrc IS INITIAL.
          DATA(lv_tabix1) = sy-tabix.
          LOOP AT li_tactz INTO DATA(lwa_tactz) FROM lv_tabix1.
            IF lwa_tactz-brobj NE lwa_file_data_star-object.
              EXIT.
            ELSE.
              APPEND INITIAL LINE TO i_file_data_9042
              ASSIGNING FIELD-SYMBOL(<lfs_role_val_star>).
              <lfs_role_val_star>-agr_name = lwa_file_data_star-agr_name.
              <lfs_role_val_star>-object   = lwa_file_data_star-object.
              <lfs_role_val_star>-field    = lwa_file_data_star-field.
              <lfs_role_val_star>-value    = lwa_tactz-actvt.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDLOOP.
      CLEAR li_file_data_star.
      SORT i_file_data_9042.
      DELETE ADJACENT DUPLICATES FROM i_file_data_9042 COMPARING ALL FIELDS.

    ENDIF.

*** Fill Output Table 3.
    LOOP AT i_file_data_9042 ASSIGNING <lfs_role_val_star>.
      APPEND INITIAL LINE TO i_outtab_9042_s3 ASSIGNING FIELD-SYMBOL(<lfs_outtab_9042_s3>).
      <lfs_outtab_9042_s3>-agr_name = <lfs_role_val_star>-agr_name.
      <lfs_outtab_9042_s3>-object   = <lfs_role_val_star>-object.
      <lfs_outtab_9042_s3>-value    = <lfs_role_val_star>-value.
      READ TABLE li_rule_set INTO DATA(lwa_rule_set) WITH KEY
      object  = <lfs_role_val_star>-object
      field   = <lfs_role_val_star>-field
      value   = <lfs_role_val_star>-value BINARY SEARCH.
      IF sy-subrc IS INITIAL.
        <lfs_outtab_9042_s3>-priority  = lwa_rule_set-priority.
        <lfs_outtab_9042_s3>-rule_desc = lwa_rule_set-rule_desc.
      ELSE.
        IF <lfs_role_val_star>-value = '03'.
          <lfs_outtab_9042_s3>-priority  = 3.
          <lfs_outtab_9042_s3>-rule_desc = 'GD Self-Service Use'.
        ELSE.
          <lfs_outtab_9042_s3>-priority  = 4.
          <lfs_outtab_9042_s3>-rule_desc = 'Not Classified'.
        ENDIF.
      ENDIF.
    ENDLOOP.


    IF i_outtab_9042_s3 IS NOT INITIAL.
      SORT i_outtab_9042_s3 BY priority agr_name object value.

*** Fill Output Table 2
      SELECT priority,
             rule_desc,
             agr_name,
         COUNT( object ) AS no_of_object
      FROM @i_outtab_9042_s3 AS outtab_s3
      GROUP BY agr_name, priority, rule_desc
      INTO TABLE @i_outtab_9042_s2.
      IF sy-subrc IS INITIAL.
        SORT i_outtab_9042_s2 BY agr_name priority no_of_object.
      ENDIF.

*** Fill Output Table 1
      DATA(li_outtab_9042_s2) = i_outtab_9042_s2.
      SORT li_outtab_9042_s2 BY agr_name priority.
      DELETE ADJACENT DUPLICATES FROM li_outtab_9042_s2 COMPARING agr_name.


      DATA(li_prio_count) = li_outtab_9042_s2.
      DELETE li_prio_count WHERE priority NE 1.
      DATA(lv_advance) = lines( li_prio_count ).

      li_prio_count = li_outtab_9042_s2.
      DELETE li_prio_count WHERE priority NE 2.
      DATA(lv_core) = lines( li_prio_count ).

      li_prio_count = li_outtab_9042_s2.
      DELETE li_prio_count WHERE priority NE 3.
      DATA(lv_self) = lines( li_prio_count ).

      li_prio_count = li_outtab_9042_s2.
      DELETE li_prio_count WHERE priority NE 4.
      DATA(lv_not_class) = lines( li_prio_count ).


      APPEND VALUE ty_outtab_9042( head = 'No of Roles'
                                   gb_advance = lv_advance
                                   gc_core    = lv_core
                                   gd_self    = lv_self
                                   not_class  = lv_not_class
                                   tot_class  = ( lv_advance + lv_core + lv_self )
                                   total      = ( lv_advance + lv_core + lv_self + lv_not_class ) ) TO i_outtab_9042.

      APPEND VALUE ty_outtab_9042( head = 'No of FUE'
                                      gb_advance = lv_advance
                                      gc_core    = lv_core / 5
                                      gd_self    = lv_self / 30
                                      not_class  = 0
                                      tot_class  = ceil( CONV f( lv_advance + lv_core / 5 + lv_self / 30 ) )
                                      total      = 0 ) TO i_outtab_9042.


      PERFORM show_result_9042.


    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_8008
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_8008 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  CREATE OBJECT o_conttainer_8008
    EXPORTING
      container_name = 'CC_8008'.

  CREATE OBJECT o_grid_8008
    EXPORTING
      i_parent = o_conttainer_8008.

  ls_catalog-fieldname = 'AGR_NAME'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Role'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'RULE_DESC'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Classification Type'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.
*
  ls_catalog-fieldname = 'NO_OF_OBJECT'.
  ls_catalog-coltext   = 'Number of Objects'.
  ls_catalog-col_opt   = abap_true.

  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

*
  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8008.
  SET HANDLER lo_grid_event->handle_hot_spot_8008 FOR o_grid_8008.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8008.

  CALL METHOD o_grid_8008->set_table_for_first_display
    EXPORTING
      is_layout       = wa_layout
    CHANGING
      it_fieldcatalog = lt_catalog
      it_outtab       = i_outtab_8008.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9042
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9042 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.


  IF o_conttainer_9042 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9042
      EXPORTING
        container_name = 'CC_9042'.
  ENDIF.

  IF o_conttainer_9042 IS BOUND AND o_grid_9042 IS NOT BOUND.
    CREATE OBJECT o_grid_9042
      EXPORTING
        i_parent = o_conttainer_9042.
  ENDIF.

  ls_catalog-fieldname = 'HEAD'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = ''.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'GB_ADVANCE'.
  ls_catalog-coltext   = 'GB Advanced Use'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'GC_CORE'.
  ls_catalog-coltext   = 'GC Core Use'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'GD_SELF'.
  ls_catalog-coltext   = 'GD Self-Service Use'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'NOT_CLASS'.
  ls_catalog-coltext   = 'Not Classified'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TOT_CLASS'.
  ls_catalog-coltext   = 'Total Classified'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TOTAL'.
  ls_catalog-coltext   = 'Total'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).

  SET HANDLER lo_grid_event->handle_hot_spot FOR o_grid_9042.

  IF o_grid_9042 IS BOUND.
    IF g_9042_first IS INITIAL.
      g_9042_first = abap_true.
      CALL METHOD o_grid_9042->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = i_outtab_9042.
    ELSE.
      CALL METHOD o_grid_9042->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9042->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9042->refresh_table_display( ).
    ENDIF.
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_6001
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_6001 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  CREATE OBJECT o_conttainer_6001
    EXPORTING
      container_name = 'CC_6001'.

  CREATE OBJECT o_grid_6001
    EXPORTING
      i_parent = o_conttainer_6001.

  ls_catalog-fieldname = 'AGR_NAME'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Role'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'RULE_DESC'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Classification Type'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.
*
  ls_catalog-fieldname = 'OBJECT'.
  ls_catalog-coltext   = 'Object'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'VALUE'.
  ls_catalog-coltext   = 'Value'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  CALL METHOD o_grid_6001->set_table_for_first_display
    EXPORTING
      is_layout       = wa_layout
    CHANGING
      it_fieldcatalog = lt_catalog
      it_outtab       = i_outtab_6001.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result_9041
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_result_9041 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.


  IF o_conttainer_9041 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9041
      EXPORTING
        container_name = 'CC_9041'.
  ENDIF.

  IF o_conttainer_9041 IS BOUND AND o_grid_9041 IS NOT BOUND.
    CREATE OBJECT o_grid_9041
      EXPORTING
        i_parent = o_conttainer_9041.
  ENDIF.

  wa_layout-col_opt = abap_true.
  wa_layout-cwidth_opt = abap_true.

  ls_catalog-fieldname = 'HEAD'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = ''.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'GB_ADVANCE'.
  ls_catalog-coltext   = 'GB Advanced Use'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'GC_CORE'.
  ls_catalog-coltext   = 'GC Core Use'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'GD_SELF'.
  ls_catalog-coltext   = 'GD Self-Service Use'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'NOT_CLASS'.
  ls_catalog-coltext   = 'Not Classified'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TOT_CLASS'.
  ls_catalog-coltext   = 'Total Classified'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'TOTAL'.
  ls_catalog-coltext   = 'Total'.
  ls_catalog-col_opt   = abap_true.
  ls_catalog-hotspot   = abap_true.
  ls_catalog-no_zero   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).

  SET HANDLER lo_grid_event->handle_hot_spot FOR o_grid_9041.

  IF o_grid_9041 IS BOUND.
    IF g_9041_first IS INITIAL.
      g_9041_first = abap_true.
      CALL METHOD o_grid_9041->set_table_for_first_display
        EXPORTING
          is_layout       = wa_layout
        CHANGING
          it_fieldcatalog = lt_catalog
          it_outtab       = i_outtab_9041.
    ELSE.
      CALL METHOD o_grid_9041->get_frontend_layout
        IMPORTING
          es_layout = wa_layout.
      wa_layout-cwidth_opt = abap_true.
      CALL METHOD o_grid_9041->set_frontend_layout
        EXPORTING
          is_layout = wa_layout.
      o_grid_9041->refresh_table_display( ).
    ENDIF.
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_8009
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_8009 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  CREATE OBJECT o_conttainer_8009
    EXPORTING
      container_name = 'CC_8009'.

  CREATE OBJECT o_grid_8009
    EXPORTING
      i_parent = o_conttainer_8009.


  ls_catalog-fieldname = 'USER'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'User ID'.
  ls_catalog-col_opt   = abap_true.

  ls_catalog-fieldname = 'RULE_DESC'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Classification Type'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  DATA(lo_grid_event) = NEW lcl_event_receiver( ).
  SET HANDLER lo_grid_event->handle_toolbar FOR o_grid_8009.
  SET HANDLER lo_grid_event->handle_hot_spot_8008 FOR o_grid_8009.
  SET HANDLER lo_grid_event->handle_user_command FOR o_grid_8009.

  CALL METHOD o_grid_8009->set_table_for_first_display
    EXPORTING
      is_layout       = wa_layout
    CHANGING
      it_fieldcatalog = lt_catalog
      it_outtab       = i_outtab_8009.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_6002
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_6002 .

  DATA : lt_catalog TYPE lvc_t_fcat,
         ls_catalog TYPE lvc_s_fcat.

  CREATE OBJECT o_conttainer_6002
    EXPORTING
      container_name = 'CC_6002'.

  CREATE OBJECT o_grid_6002
    EXPORTING
      i_parent = o_conttainer_6002.

  ls_catalog-fieldname = 'AGR_NAME'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Role'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'RULE_DESC'.
  ls_catalog-key       = abap_true.
  ls_catalog-coltext   = 'Classification Type'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.
*
  ls_catalog-fieldname = 'OBJECT'.
  ls_catalog-coltext   = 'Object'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  ls_catalog-fieldname = 'VALUE'.
  ls_catalog-coltext   = 'Value'.
  ls_catalog-col_opt   = abap_true.
  APPEND ls_catalog TO lt_catalog.
  CLEAR ls_catalog.

  CALL METHOD o_grid_6002->set_table_for_first_display
    EXPORTING
      is_layout       = wa_layout
    CHANGING
      it_fieldcatalog = lt_catalog
      it_outtab       = i_outtab_6002.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form maintain_add_in_all_object
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: adds the authorization value to every
*& instance of the given object in the role (PFCG role API) and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_add_in_all_object .

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            value  TYPE agval,
          END OF lty_auth_val.

  DATA:

    lwa_auth_auth       TYPE if_pfcg_role=>node_st_auth_auths,
    lwa_auth_values_new TYPE if_pfcg_role=>node_st_auth_values,
    lwa_message         TYPE if_spcg_msg_buffer=>ty_messages,

    lt_messages         TYPE if_spcg_msg_buffer=>tt_messages,
    lt_init_excel       TYPE TABLE OF lty_auth_val,
    lt_init_object      TYPE TABLE OF lty_auth_val,
    lt_pfcg_role        TYPE if_pfcg_role=>tt_pfcg_role,
    lt_nodes_prefetch   TYPE if_pfcg_role=>tt_node,
    lt_node_root        TYPE if_pfcg_role=>node_tt_root,
    lt_change_values    TYPE if_pfcg_role=>node_tt_auth_values,
    lt_message          TYPE if_spcg_msg_buffer=>tt_messages.

*  CHECK sy-uname = 'KALLOL'.

  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.

    LOOP AT i_upload_file INTO DATA(lwa_upload_file).
      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
      <lfs_data>-role   = lwa_upload_file-field1.
      <lfs_data>-object = lwa_upload_file-field2.
      <lfs_data>-field  = lwa_upload_file-field3.
      <lfs_data>-value  = lwa_upload_file-field4.
    ENDLOOP.
    SORT lt_init_excel  BY role object field value.
    DELETE ADJACENT DUPLICATES FROM lt_init_excel COMPARING ALL FIELDS.
    lt_init_object = lt_init_excel.
    SORT lt_init_object BY role object.
    DELETE ADJACENT DUPLICATES FROM lt_init_object COMPARING role object.

    lt_pfcg_role = VALUE #( FOR lwa_role IN lt_init_excel ( role = lwa_role-role ) ).
    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    TRY.
        CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
          EXPORTING
            it_pfcg_role      = lt_pfcg_role
            it_nodes_prefetch = lt_nodes_prefetch
          IMPORTING
            et_node_root      = lt_node_root
            eo_msg_buffer     = DATA(lo_msg_buffer).

      CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

        DATA(lv_text) = lo_pfcg_role->get_text( ).
        lwa_message-msgty  = 'E'.
        lwa_message-msgid  = '01'.
        lwa_message-msgno  = '319'.
        lwa_message-msgv1  = lv_text.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        CLEAR lwa_message.

    ENDTRY.

    IF lt_node_root IS NOT INITIAL.

      SORT lt_node_root BY role.

      LOOP AT lt_node_root INTO DATA(lwa_node_root_data).

        DATA(lv_root_index) = sy-tabix.
        READ TABLE lt_node_root REFERENCE INTO DATA(lwa_node_root) INDEX lv_root_index.

        READ TABLE lt_init_object TRANSPORTING NO FIELDS
        WITH KEY role = lwa_node_root_data-role BINARY SEARCH.
        IF sy-subrc IS INITIAL.

          DATA(lv_role_tabix) = sy-tabix.

          CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
            IMPORTING
              et_auth_auths = DATA(lt_auth_auths)
              eo_msg_buffer = lo_msg_buffer.
          PERFORM add_message USING lwa_message lo_msg_buffer.
          DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.

          " Check and add message

          LOOP AT lt_init_object INTO DATA(lwa_init_object) FROM lv_role_tabix.

            IF lwa_init_object-role NE lwa_node_root_data-role.
              EXIT.
            ELSE.

              CLEAR lwa_auth_auth.
              READ TABLE lt_auth_auths INTO lwa_auth_auth WITH KEY
              object = lwa_init_object-object.
              IF sy-subrc IS NOT INITIAL. " Autorization Object does not exist

                " Check if Object is not present then add the object
                CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~add_manual_auth
                  EXPORTING
                    iv_object     = lwa_init_object-object
                  IMPORTING
                    es_auth_auths = lwa_auth_auth
                    eo_msg_buffer = lo_msg_buffer.
                PERFORM add_message USING lwa_message lo_msg_buffer.
              ENDIF.

            ENDIF.

          ENDLOOP.

          CLEAR lt_auth_auths.
          CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
            IMPORTING
              et_auth_auths = lt_auth_auths
              eo_msg_buffer = lo_msg_buffer.
          PERFORM add_message USING lwa_message lo_msg_buffer.
          DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.

          READ TABLE lt_init_excel TRANSPORTING NO FIELDS WITH KEY
          role = lwa_node_root_data-role BINARY SEARCH.
          IF sy-subrc IS INITIAL.

            DATA(lv_role_index) = sy-tabix.

            LOOP AT lt_init_excel INTO DATA(lwa_init_excel) FROM lv_role_index.

              IF lwa_init_excel-role NE lwa_node_root_data-role.
                EXIT.
              ELSE.

                CLEAR lwa_auth_auth.
                READ TABLE lt_auth_auths INTO lwa_auth_auth WITH KEY
                object = lwa_init_excel-object.
                IF sy-subrc IS INITIAL.

                  CLEAR lt_change_values.
                  lwa_auth_values_new-field       = lwa_init_excel-field.
                  lwa_auth_values_new-low         = lwa_init_excel-value.
                  lwa_auth_values_new-change_mode = 'I'.
                  APPEND lwa_auth_values_new TO lt_change_values.
                  CLEAR lwa_auth_values_new.

                  CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                    EXPORTING
                      is_auth        = lwa_auth_auth
                      it_auth_values = lt_change_values
                    IMPORTING
                      eo_msg_buffer  = lo_msg_buffer.

                  PERFORM add_message USING lwa_message lo_msg_buffer.

                ENDIF.

              ENDIF.

            ENDLOOP.

          ENDIF.


        ENDIF.

      ENDLOOP. " End of Each Role


      READ TABLE gt_auth_val TRANSPORTING NO FIELDS
      WITH KEY type = 'Error'.
      IF sy-subrc IS INITIAL.
        DATA(lv_rejected) = abap_true.
      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_check
          IMPORTING
            ev_rejected   = lv_rejected
            eo_msg_buffer = lo_msg_buffer.

        lt_message = lo_msg_buffer->get_messages( ).
        READ TABLE lt_message TRANSPORTING NO FIELDS
        WITH KEY msgty  = 'E'.
        IF sy-subrc IS INITIAL.
          lv_rejected = abap_true.
        ENDIF.

      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_save
          EXPORTING
            iv_update_task = abap_false
          IMPORTING
            ev_rejected    = lv_rejected
            eo_msg_buffer  = lo_msg_buffer.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        COMMIT WORK AND WAIT.

      ELSE.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        ROLLBACK WORK.

      ENDIF.

    ENDIF.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_add_in_spec_inst
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: adds the authorization value to one specific
*& authorization instance of the object in the role and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_add_in_spec_inst .

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            auth   TYPE agauth,
            value  TYPE agval,
          END OF lty_auth_val.

  DATA : lt_init_excel     TYPE TABLE OF lty_auth_val,
         lt_pfcg_role      TYPE if_pfcg_role=>tt_pfcg_role,
         lt_nodes_prefetch TYPE if_pfcg_role=>tt_node,
         lt_node_root      TYPE if_pfcg_role=>node_tt_root,
         lt_change_values  TYPE if_pfcg_role=>node_tt_auth_values,
         lt_message        TYPE if_spcg_msg_buffer=>tt_messages,
         lwa_message       TYPE if_spcg_msg_buffer=>ty_messages,
         lwa_auth_values   TYPE if_pfcg_role=>node_st_auth_values.

**pa_adi

  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.

    LOOP AT i_upload_file INTO DATA(lwa_upload_file).
      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
      <lfs_data>-role   = lwa_upload_file-field1.
      <lfs_data>-object = lwa_upload_file-field2.
      <lfs_data>-field  = lwa_upload_file-field3.
      <lfs_data>-auth   = lwa_upload_file-field4.
      <lfs_data>-value  = lwa_upload_file-field5.
    ENDLOOP.
    SORT lt_init_excel  BY role object field value.
    DELETE ADJACENT DUPLICATES FROM lt_init_excel COMPARING ALL FIELDS.

    lt_pfcg_role = VALUE #( FOR lwa_role IN lt_init_excel ( role = lwa_role-role ) ).
    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    TRY.
        CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
          EXPORTING
            it_pfcg_role      = lt_pfcg_role
            it_nodes_prefetch = lt_nodes_prefetch
          IMPORTING
            et_node_root      = lt_node_root
            eo_msg_buffer     = DATA(lo_msg_buffer).

      CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

        DATA(lv_text) = lo_pfcg_role->get_text( ).
        lwa_message-msgty  = 'E'.
        lwa_message-msgid  = '01'.
        lwa_message-msgno  = '319'.
        lwa_message-msgv1  = lv_text.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        CLEAR lwa_message.

    ENDTRY.

    IF lt_node_root IS NOT INITIAL.

      LOOP AT lt_pfcg_role INTO DATA(lwa_pfcg_role).
        READ TABLE lt_node_root REFERENCE INTO DATA(lo_node_root)
                     WITH KEY role = lwa_pfcg_role-role.
        IF sy-subrc IS INITIAL.
          CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~get_auths
            IMPORTING
              et_auth_auths = DATA(lt_auth_auths)
              eo_msg_buffer = lo_msg_buffer.

          DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.

          READ TABLE lt_init_excel TRANSPORTING NO FIELDS
                                    WITH KEY role = lwa_pfcg_role-role.
          IF sy-subrc IS INITIAL.
            DATA(lv_role_index) = sy-tabix.

            LOOP AT lt_init_excel INTO DATA(lwa_init_excel) FROM lv_role_index.

              IF lwa_init_excel-role EQ lwa_pfcg_role-role.
                READ TABLE lt_auth_auths INTO DATA(lt_each_object_line)
                    WITH KEY object = lwa_init_excel-object
                             auth = lwa_init_excel-auth.
                IF sy-subrc IS INITIAL.
                  lwa_auth_values-field       = lwa_init_excel-field.
                  lwa_auth_values-low         = lwa_init_excel-value.
                  lwa_auth_values-change_mode = 'I'.
                  APPEND lwa_auth_values TO lt_change_values.

                  TRY.
                      CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                        EXPORTING
                          is_auth        = lt_each_object_line
                          it_auth_values = lt_change_values
                        IMPORTING
                          eo_msg_buffer  = lo_msg_buffer.

                      CLEAR lt_change_values.

                      PERFORM update_message USING lo_msg_buffer lo_node_root->role lwa_init_excel-object.

                    CATCH cx_pfcg_role INTO lo_pfcg_role.

                      lv_text = lo_pfcg_role->get_text( ).
                      lwa_message-msgty  = 'E'.
                      lwa_message-msgid  = '01'.
                      lwa_message-msgno  = '319'.
                      lwa_message-msgv1  = lv_text.
                      PERFORM add_message USING lwa_message lo_msg_buffer.
                      CLEAR lwa_message.

                    CATCH cx_pfcg_role_scc4.

                  ENDTRY.
                ENDIF.
              ELSE.
                "Go to the next Role
                EXIT.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.
      ENDLOOP. " End of Each Role

      READ TABLE gt_auth_val TRANSPORTING NO FIELDS
      WITH KEY type = 'Error'.
      IF sy-subrc IS INITIAL.
        DATA(lv_rejected) = abap_true.
      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_check
          IMPORTING
            ev_rejected   = lv_rejected
            eo_msg_buffer = lo_msg_buffer.

        lt_message = lo_msg_buffer->get_messages( ).
        READ TABLE lt_message TRANSPORTING NO FIELDS
        WITH KEY msgty  = 'E'.
        IF sy-subrc IS INITIAL.
          lv_rejected = abap_true.
        ENDIF.

      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_save
          EXPORTING
            iv_update_task = abap_false
          IMPORTING
            ev_rejected    = lv_rejected
            eo_msg_buffer  = lo_msg_buffer.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        COMMIT WORK AND WAIT.

      ELSE.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        ROLLBACK WORK.

      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_add_new_object
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: inserts a new authorization object (with the
*& given field/value) into the role and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_add_new_object .

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            value  TYPE agval,
          END OF lty_auth_val,
          tt_tpr01 TYPE SORTED TABLE OF tpr01 WITH UNIQUE KEY low high,
          BEGIN OF ty_mod_values,
            object TYPE xuobject,
            field  TYPE xufield,
            varbl  TYPE usorg-varbl,
            action TYPE char01,
            valrep TYPE tt_tpr01,
            val    TYPE tt_tpr01,
          END OF ty_mod_values.

  DATA : lt_init_excel     TYPE TABLE OF lty_auth_val,
         lt_pfcg_role      TYPE if_pfcg_role=>tt_pfcg_role,
         lt_nodes_prefetch TYPE if_pfcg_role=>tt_node,
         lwa_message       TYPE if_spcg_msg_buffer=>ty_messages,
         lt_node_root      TYPE if_pfcg_role=>node_tt_root,
         lt_messages       TYPE if_spcg_msg_buffer=>tt_messages,
         lt_val            TYPE TABLE OF tpr01,
         lwa_val           TYPE tpr01,
         lt_mod_values     TYPE TABLE OF ty_mod_values,
         lwa_mod_values    TYPE ty_mod_values,
         lt_auth_auths     TYPE if_pfcg_role=>node_tt_auth_auths,
         lt_change_values  TYPE if_pfcg_role=>node_tt_auth_values,
         lwa_auth_values   TYPE if_pfcg_role=>node_st_auth_values.


  " pa_ins

  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.

    LOOP AT i_upload_file INTO DATA(lwa_upload_file).

      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
      <lfs_data>-role   = lwa_upload_file-field1.
      <lfs_data>-object = lwa_upload_file-field2.
      <lfs_data>-field  = lwa_upload_file-field3.
      <lfs_data>-value  = lwa_upload_file-field4.

    ENDLOOP.

    SORT lt_init_excel  BY role object field value.
    DELETE ADJACENT DUPLICATES FROM lt_init_excel COMPARING ALL FIELDS.

    lt_pfcg_role = VALUE #( FOR lwa_role IN lt_init_excel ( role = lwa_role-role ) ).
    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    TRY.
        CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
          EXPORTING
            it_pfcg_role      = lt_pfcg_role
            it_nodes_prefetch = lt_nodes_prefetch
          IMPORTING
            et_node_root      = lt_node_root
            eo_msg_buffer     = DATA(lo_msg_buffer).

      CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

        DATA(lv_text) = lo_pfcg_role->get_text( ).
        lwa_message-msgty  = 'E'.
        lwa_message-msgid  = '01'.
        lwa_message-msgno  = '319'.
        lwa_message-msgv1  = lv_text.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        CLEAR lwa_message.

    ENDTRY.

    IF lt_node_root IS NOT INITIAL.

      SORT lt_node_root BY role.

      LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
        DATA(lv_index) = sy-tabix + 1.
        READ TABLE lt_init_excel INTO DATA(lwa_init_excel1) INDEX lv_index.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel1.
        ENDIF.

        TRY .

            lwa_val-low = lwa_init_excel-value.
            APPEND lwa_val TO lt_val.
            CLEAR : lwa_val.

            IF lwa_init_excel-role <> lwa_init_excel1-role OR lwa_init_excel-object
                  <> lwa_init_excel1-object OR lwa_init_excel-field <> lwa_init_excel1-field.

              lwa_mod_values-object = lwa_init_excel-object.
              lwa_mod_values-field  = lwa_init_excel-field.
              lwa_mod_values-valrep = VALUE #( ( low = '*' ) ).
              lwa_mod_values-val    = lt_val.

              APPEND lwa_mod_values TO lt_mod_values.
              CLEAR : lwa_mod_values,lt_val.

              IF lwa_init_excel-role <> lwa_init_excel1-role .

                READ TABLE lt_node_root REFERENCE INTO DATA(lo_node_root)
                    WITH KEY role = lwa_init_excel-role BINARY SEARCH.
                IF sy-subrc IS INITIAL.
                  DATA(lt_mod_values1) = lt_mod_values.
                  SORT lt_mod_values1 BY object.
                  DELETE ADJACENT DUPLICATES FROM lt_mod_values1 COMPARING object.
*** Add New Instance
                  LOOP AT lt_mod_values1 INTO lwa_mod_values.

                    CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~add_manual_auth
                      EXPORTING
                        iv_object     = lwa_mod_values-object
                      IMPORTING
                        es_auth_auths = DATA(lwa_auth_auth)
                        eo_msg_buffer = lo_msg_buffer.

                    PERFORM update_message USING lo_msg_buffer lo_node_root->role ''.
*
                    APPEND lwa_auth_auth TO lt_auth_auths.
                    CLEAR : lwa_auth_auth.

**********************************************************************
*Additional code can be written to filter out the instance
**********************************************************************
                    LOOP AT lt_auth_auths REFERENCE INTO DATA(lwa_auth_auths).

                      READ TABLE lt_mod_values WITH KEY object = lwa_auth_auths->object TRANSPORTING NO FIELDS.
                      IF sy-subrc NE 0.
                        CONTINUE.
                      ENDIF.

                      " Read current values for auth
                      CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                        EXPORTING
                          is_auth        = lwa_auth_auths->*
                        IMPORTING
                          et_auth_values = DATA(lt_auth_values_old)
                          eo_msg_buffer  = lo_msg_buffer.

                      CLEAR: lt_change_values.

                      LOOP AT lt_mod_values REFERENCE INTO DATA(lo_mod_values) WHERE object = lwa_auth_auths->object.
                        LOOP AT lo_mod_values->val REFERENCE INTO DATA(lo_val).
                          " Check for '*' first
                          READ TABLE lt_auth_values_old
                            WITH KEY field = lo_mod_values->field
                                     low   = '*'
                            TRANSPORTING NO FIELDS BINARY SEARCH.
                          IF sy-subrc EQ 0.
                            CONTINUE.
                          ENDIF.
                          " Check value
                          READ TABLE lt_auth_values_old
                            WITH KEY field = lo_mod_values->field
                                     low   = lo_val->low
                                     high  = lo_val->high
                            TRANSPORTING NO FIELDS BINARY SEARCH.
                          IF sy-subrc NE 0.
                            lwa_auth_values-field       = lo_mod_values->field.
                            lwa_auth_values-low         = lo_val->low.
                            lwa_auth_values-high        = lo_val->high.
                            lwa_auth_values-change_mode = 'I'.
                            APPEND lwa_auth_values TO lt_change_values.
                          ENDIF.
                        ENDLOOP.
                      ENDLOOP.
                      IF lt_change_values IS NOT INITIAL.
                        CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                          EXPORTING
                            is_auth        = lwa_auth_auths->*
                            it_auth_values = lt_change_values
                          IMPORTING
                            eo_msg_buffer  = lo_msg_buffer.

                        PERFORM update_message USING lo_msg_buffer lo_node_root->role lwa_auth_auths->object.

                        CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                          EXPORTING
                            is_auth        = lwa_auth_auths->*
                          IMPORTING
                            et_auth_values = DATA(lt_auth_values_new)
                            eo_msg_buffer  = lo_msg_buffer.

                        PERFORM update_message1 USING lwa_init_excel-role lwa_auth_auths->object lt_change_values.
                      ELSE.
                        lt_auth_values_new = lt_auth_values_old.
                      ENDIF.
                    ENDLOOP.
                    CLEAR : lt_mod_values.
                  ENDLOOP.
                ENDIF.
              ENDIF.

            ENDIF.


          CATCH cx_pfcg_role INTO lo_pfcg_role.

            lv_text = lo_pfcg_role->get_text( ).
            lwa_message-msgty  = 'E'.
            lwa_message-msgid  = '01'.
            lwa_message-msgno  = '319'.
            lwa_message-msgv1  = lv_text.
            APPEND lwa_message TO lt_messages.

          CATCH cx_pfcg_role_scc4.

        ENDTRY.
      ENDLOOP.

      READ TABLE gt_auth_val TRANSPORTING NO FIELDS
      WITH KEY type = 'Error'.
      IF sy-subrc IS INITIAL.
        DATA(lv_rejected) = abap_true.
      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_check
          IMPORTING
            ev_rejected   = lv_rejected
            eo_msg_buffer = lo_msg_buffer.

        DATA(lt_message) = lo_msg_buffer->get_messages( ).

        READ TABLE lt_message TRANSPORTING NO FIELDS
        WITH KEY msgty  = 'E'.
        IF sy-subrc IS INITIAL.
          lv_rejected = abap_true.
        ENDIF.

      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_save
          EXPORTING
            iv_update_task = abap_false
          IMPORTING
            ev_rejected    = lv_rejected
            eo_msg_buffer  = lo_msg_buffer.

        PERFORM add_message USING lwa_message lo_msg_buffer.
        COMMIT WORK AND WAIT.

      ELSE.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        ROLLBACK WORK.

      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_del_all_insts
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: deletes the authorization value from every
*& instance of the object in the role and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_del_all_insts .

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            value  TYPE agval,
          END OF lty_auth_val,
          tt_tpr01 TYPE SORTED TABLE OF tpr01 WITH UNIQUE KEY low high,
          BEGIN OF ty_mod_values,
            object TYPE xuobject,
            field  TYPE xufield,
            varbl  TYPE usorg-varbl,
            action TYPE char01,
            valrep TYPE tt_tpr01,
            val    TYPE tt_tpr01,
          END OF ty_mod_values.


  DATA : lt_init_excel     TYPE TABLE OF lty_auth_val,
         lt_pfcg_role      TYPE if_pfcg_role=>tt_pfcg_role,
         lt_nodes_prefetch TYPE if_pfcg_role=>tt_node,
         lt_node_root      TYPE if_pfcg_role=>node_tt_root,
         lwa_message       TYPE if_spcg_msg_buffer=>ty_messages,
         lt_messages       TYPE if_spcg_msg_buffer=>tt_messages,
         lt_val            TYPE TABLE OF tpr01,
         lwa_val           TYPE tpr01,
         lt_mod_values     TYPE TABLE OF ty_mod_values,
         lwa_mod_values    TYPE ty_mod_values,
         lt_auth_auths     TYPE if_pfcg_role=>node_tt_auth_auths,
         lt_change_values  TYPE if_pfcg_role=>node_tt_auth_values,
         lwa_auth_values   TYPE if_pfcg_role=>node_st_auth_values.


  "pa_del
  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.
    LOOP AT i_upload_file INTO DATA(lwa_upload_file).
      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
      <lfs_data>-role   = lwa_upload_file-field1.
      <lfs_data>-object = lwa_upload_file-field2.
      <lfs_data>-field  = lwa_upload_file-field3.
      <lfs_data>-value  = lwa_upload_file-field4.
    ENDLOOP.

    SORT lt_init_excel  BY role object field value.

    lt_pfcg_role = VALUE #( FOR lwa_role IN lt_init_excel ( role = lwa_role-role ) ).

    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    TRY.
        CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
          EXPORTING
            it_pfcg_role      = lt_pfcg_role
            it_nodes_prefetch = lt_nodes_prefetch
          IMPORTING
            et_node_root      = lt_node_root
            eo_msg_buffer     = DATA(lo_msg_buffer).

      CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

        DATA(lv_text) = lo_pfcg_role->get_text( ).
        lwa_message-msgty  = 'E'.
        lwa_message-msgid  = '01'.
        lwa_message-msgno  = '319'.
        lwa_message-msgv1  = lv_text.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        CLEAR lwa_message.

    ENDTRY.

    IF lt_node_root IS NOT INITIAL.
      SORT lt_node_root BY role.

      LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
        DATA(lv_index) = sy-tabix + 1.
        READ TABLE lt_init_excel INTO DATA(lwa_init_excel1) INDEX lv_index.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel1.
        ENDIF.
        TRY .

            lwa_val-low = lwa_init_excel-value.
            APPEND lwa_val TO lt_val.
            CLEAR : lwa_val.

            IF lwa_init_excel-role <> lwa_init_excel1-role OR lwa_init_excel-object
                  <> lwa_init_excel1-object OR lwa_init_excel-field <> lwa_init_excel1-field.

              lwa_mod_values-object = lwa_init_excel-object.
              lwa_mod_values-field  = lwa_init_excel-field.
              lwa_mod_values-valrep = VALUE #( ( low = '*' ) ).
              lwa_mod_values-val    = lt_val.

              APPEND lwa_mod_values TO lt_mod_values.
              CLEAR : lwa_mod_values,lt_val.

              IF lwa_init_excel-role <> lwa_init_excel1-role .

                READ TABLE lt_node_root REFERENCE INTO DATA(lo_node_root)
                    WITH KEY role = lwa_init_excel-role BINARY SEARCH.
                IF sy-subrc IS INITIAL.
*** Read authorizations of current role
                  CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~get_auths
                    IMPORTING
                      et_auth_auths = lt_auth_auths
                      eo_msg_buffer = lo_msg_buffer.
**** Delete Inactive Authorization
                  DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.
*** Populate Message
                  PERFORM update_message USING lo_msg_buffer lo_node_root->role ''.

                  LOOP AT lt_auth_auths REFERENCE INTO DATA(lo_auth_auths).

                    READ TABLE lt_mod_values WITH KEY object = lo_auth_auths->object TRANSPORTING NO FIELDS.
                    IF sy-subrc NE 0.
                      CONTINUE.
                    ENDIF.

                    " Read current values for auth
                    CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                      EXPORTING
                        is_auth        = lo_auth_auths->*
                      IMPORTING
                        et_auth_values = DATA(lt_auth_values_old)
                        eo_msg_buffer  = lo_msg_buffer.

                    CLEAR: lt_change_values.

                    LOOP AT lt_mod_values REFERENCE INTO DATA(lo_mod_values) WHERE object = lo_auth_auths->object.
                      LOOP AT lo_mod_values->val REFERENCE INTO DATA(lo_val).
                        READ TABLE lt_auth_values_old
                          WITH KEY field = lo_mod_values->field
                                   low   = lo_val->low
                                   high  = lo_val->high
                          TRANSPORTING NO FIELDS BINARY SEARCH.
                        IF sy-subrc EQ 0.
                          lwa_auth_values-field       = lo_mod_values->field.
                          lwa_auth_values-low         = lo_val->low.
                          lwa_auth_values-high        = lo_val->high.
                          lwa_auth_values-change_mode = 'D'.
                          APPEND lwa_auth_values TO lt_change_values.
                          CLEAR : lwa_auth_values.
                        ENDIF.
                      ENDLOOP.
                    ENDLOOP.
                    IF lt_change_values IS NOT INITIAL.
                      CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                        EXPORTING
                          is_auth        = lo_auth_auths->*
                          it_auth_values = lt_change_values
                        IMPORTING
                          eo_msg_buffer  = lo_msg_buffer.

                      PERFORM update_message USING lo_msg_buffer lo_node_root->role lo_auth_auths->object.

                      CALL METHOD lo_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                        EXPORTING
                          is_auth        = lo_auth_auths->*
                        IMPORTING
                          et_auth_values = DATA(lt_auth_values_new)
                          eo_msg_buffer  = lo_msg_buffer.

                      PERFORM update_message1 USING lwa_init_excel-role lo_auth_auths->object lt_change_values.
                    ELSE.
                      lt_auth_values_new = lt_auth_values_old.
                    ENDIF.
                  ENDLOOP.
                  CLEAR : lt_mod_values.
                ENDIF.
              ENDIF.
            ENDIF.

          CATCH cx_pfcg_role INTO lo_pfcg_role.

            lv_text = lo_pfcg_role->get_text( ).
            lwa_message-msgty  = 'E'.
            lwa_message-msgid  = '01'.
            lwa_message-msgno  = '319'.
            lwa_message-msgv1  = lv_text.
            APPEND lwa_message TO lt_messages.

          CATCH cx_pfcg_role_scc4.

        ENDTRY.
      ENDLOOP.

      READ TABLE gt_auth_val TRANSPORTING NO FIELDS
      WITH KEY type = 'Error'.
      IF sy-subrc IS INITIAL.
        DATA(lv_rejected) = abap_true.
      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_check
          IMPORTING
            ev_rejected   = lv_rejected
            eo_msg_buffer = lo_msg_buffer.

        DATA(lt_message) = lo_msg_buffer->get_messages( ).

        READ TABLE lt_message TRANSPORTING NO FIELDS
        WITH KEY msgty  = 'E'.
        IF sy-subrc IS INITIAL.
          lv_rejected = abap_true.
        ENDIF.

      ENDIF.

      IF lv_rejected EQ abap_false.

        CALL METHOD cl_pfcg_role_factory=>do_save
          EXPORTING
            iv_update_task = abap_false
          IMPORTING
            ev_rejected    = lv_rejected
            eo_msg_buffer  = lo_msg_buffer.

        PERFORM add_message USING lwa_message lo_msg_buffer.
        COMMIT WORK AND WAIT.

      ELSE.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        ROLLBACK WORK.

      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_del_from_spec_inst
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: deletes the authorization value from one
*& specific instance of the object in the role and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_del_from_spec_inst .

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            value  TYPE agval,
          END OF lty_auth_val,
          BEGIN OF lty_auth_val1,
            role   TYPE agr_name,
            object TYPE xuobject,
            field  TYPE agrfield,
            auth   TYPE agauth,
            value  TYPE agval,
          END OF lty_auth_val1,
          tt_tpr01 TYPE SORTED TABLE OF tpr01 WITH UNIQUE KEY low high,
          BEGIN OF ty_mod_values,
            object TYPE xuobject,
            field  TYPE xufield,
            varbl  TYPE usorg-varbl,
            action TYPE char01,
            valrep TYPE tt_tpr01,
            val    TYPE tt_tpr01,
          END   OF ty_mod_values.

  DATA : lt_init_excel     TYPE TABLE OF lty_auth_val1,
*         lt_init_excel1    TYPE TABLE OF lty_auth_val1,
         lt_excel          TYPE STANDARD TABLE OF alsmex_tabline,
*         lv_subrc          TYPE sy-subrc,
         lwa_message       TYPE if_spcg_msg_buffer=>ty_messages,
         lt_messages       TYPE if_spcg_msg_buffer=>tt_messages,
         lt_messages1      TYPE if_spcg_msg_buffer=>tt_messages,
         lt_nodes_prefetch TYPE if_pfcg_role=>tt_node,
         lt_pfcg_role      TYPE if_pfcg_role=>tt_pfcg_role,
         lt_node_root      TYPE if_pfcg_role=>node_tt_root,
         it_mod_values     TYPE TABLE OF ty_mod_values,
         lwa_mod_values    TYPE ty_mod_values,
         lt_change_values  TYPE if_pfcg_role=>node_tt_auth_values,
         lwa_val           TYPE tpr01,
         lt_val            TYPE TABLE OF tpr01,
         lr_mod_values     TYPE REF TO ty_mod_values,
         lr_val            TYPE REF TO tpr01,
         ls_auth_values    TYPE if_pfcg_role=>node_st_auth_values,
         lwa_auth_auth     TYPE if_pfcg_role=>node_st_auth_auths,
         lt_auth_auths     TYPE if_pfcg_role=>node_tt_auth_auths.


  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.

    LOOP AT i_upload_file INTO DATA(lwa_upload_file).
      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data1>).
      <lfs_data1>-role   = lwa_upload_file-field1.
      <lfs_data1>-object = lwa_upload_file-field2.
      <lfs_data1>-field  = lwa_upload_file-field3.
      <lfs_data1>-auth   = lwa_upload_file-field4.
      <lfs_data1>-value  = lwa_upload_file-field5.
    ENDLOOP.

    SORT lt_init_excel BY role object auth field value.

*** Get Unique Role
    lt_pfcg_role = VALUE #( FOR lwa_role1 IN lt_init_excel ( role = lwa_role1-role ) ).
    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
      EXPORTING
        it_pfcg_role      = lt_pfcg_role
        it_nodes_prefetch = lt_nodes_prefetch
      IMPORTING
        et_node_root      = lt_node_root
        eo_msg_buffer     = DATA(lo_msg_buffer).

*** Populate Message
    PERFORM update_message USING lo_msg_buffer '' ''.

    IF lt_node_root IS NOT INITIAL.
      SORT lt_node_root BY role.

      LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
        DATA(lv_index)     = sy-tabix + 1.
        DATA(lv_index_prv) = sy-tabix - 1.

        READ TABLE lt_init_excel INTO DATA(lwa_init_excel1_nxt) INDEX lv_index.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel1_nxt.
        ENDIF.

        READ TABLE lt_init_excel INTO DATA(lwa_init_excel1_prv) INDEX lv_index_prv.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel1_prv.
        ENDIF.

*** Start of a New Role
        IF lwa_init_excel-role <> lwa_init_excel1_prv-role.
          READ TABLE lt_node_root REFERENCE INTO DATA(lwa_node_root)
                  WITH KEY role = lwa_init_excel-role BINARY SEARCH.
          IF sy-subrc IS INITIAL.
*** Read authorizations of current role
            CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
              IMPORTING
                et_auth_auths = lt_auth_auths
                eo_msg_buffer = lo_msg_buffer.
**** Delete Inactive Authorization
            DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.
*** Populate Message
            PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.
          ENDIF.
        ENDIF.

        TRY .
            lwa_val-low = lwa_init_excel-value.
            APPEND lwa_val TO lt_val.
            CLEAR : lwa_val.

            IF lwa_init_excel-role   <> lwa_init_excel1_nxt-role OR
               lwa_init_excel-object <> lwa_init_excel1_nxt-object OR
               lwa_init_excel-auth   <> lwa_init_excel1_nxt-auth OR
               lwa_init_excel-field  <> lwa_init_excel1_nxt-field.

              lwa_mod_values-object = lwa_init_excel-object.
              lwa_mod_values-field  = lwa_init_excel-field.
              lwa_mod_values-valrep = VALUE #( ( low = '*' ) ).
              lwa_mod_values-val    = lt_val.

              APPEND lwa_mod_values TO it_mod_values.
              CLEAR : lwa_mod_values, lt_val.

*** At End of a Role
              IF lwa_init_excel-role   <> lwa_init_excel1_nxt-role OR
                 lwa_init_excel-object <> lwa_init_excel1_nxt-object OR
                 lwa_init_excel-auth   <> lwa_init_excel1_nxt-auth.

                READ TABLE lt_node_root REFERENCE INTO lwa_node_root
                  WITH KEY role = lwa_init_excel-role BINARY SEARCH.
                IF sy-subrc IS INITIAL.

                  READ TABLE lt_auth_auths REFERENCE INTO DATA(lwa_auth_auths) WITH KEY object = lwa_init_excel-object
                                                                                        auth   = lwa_init_excel-auth.
                  IF sy-subrc IS INITIAL.
*                  " Read current values for auth
                    CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                      EXPORTING
                        is_auth        = lwa_auth_auths->*
                      IMPORTING
                        et_auth_values = DATA(lt_auth_values_old)
                        eo_msg_buffer  = lo_msg_buffer.

                    CLEAR: lt_change_values.

                    LOOP AT it_mod_values REFERENCE INTO lr_mod_values WHERE object = lwa_auth_auths->object.
                      LOOP AT lr_mod_values->val REFERENCE INTO lr_val.
                        READ TABLE lt_auth_values_old
                          WITH KEY field = lr_mod_values->field
                                   low   = lr_val->low
                                   high  = lr_val->high
                          TRANSPORTING NO FIELDS BINARY SEARCH.
                        IF sy-subrc EQ 0.
                          ls_auth_values-field       = lr_mod_values->field.
                          ls_auth_values-low         = lr_val->low.
                          ls_auth_values-high        = lr_val->high.
                          ls_auth_values-change_mode = 'D'.
                          APPEND ls_auth_values TO lt_change_values.
                        ENDIF.
                      ENDLOOP.
                    ENDLOOP.

                    IF lt_change_values IS NOT INITIAL.
                      CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                        EXPORTING
                          is_auth        = lwa_auth_auths->*
                          it_auth_values = lt_change_values
                        IMPORTING
                          eo_msg_buffer  = lo_msg_buffer.

                      PERFORM update_message USING lo_msg_buffer lwa_node_root->role lwa_auth_auths->object.

                      CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                        EXPORTING
                          is_auth        = lwa_auth_auths->*
                        IMPORTING
                          et_auth_values = DATA(lt_auth_values_new)
                          eo_msg_buffer  = lo_msg_buffer.

                      PERFORM update_message1 USING lwa_init_excel-role lwa_auth_auths->object lt_change_values.
                    ENDIF.
                  ENDIF.
                  CLEAR : it_mod_values.
                ENDIF.
              ENDIF.
            ENDIF.

          CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).
            DATA(lv_text) = lo_pfcg_role->get_text( ).
            lwa_message-msgty  = 'E'.
            lwa_message-msgid  = '01'.
            lwa_message-msgno  = '319'.
            lwa_message-msgv1  = lv_text.
            APPEND lwa_message TO lt_messages.

          CATCH cx_pfcg_role_scc4.

        ENDTRY.
      ENDLOOP.

*** Check and Save
      CALL METHOD cl_pfcg_role_factory=>do_check
        IMPORTING
          ev_rejected   = DATA(lv_rejected)
          eo_msg_buffer = lo_msg_buffer.
      CLEAR lt_messages.

      lt_messages1 = lo_msg_buffer->get_messages( ).
      APPEND LINES OF lt_messages1 TO lt_messages.

      IF lv_rejected EQ abap_false.
        CALL METHOD cl_pfcg_role_factory=>do_save
          EXPORTING
            iv_update_task = abap_false
          IMPORTING
            ev_rejected    = lv_rejected
            eo_msg_buffer  = lo_msg_buffer.

        CLEAR: lt_messages.
        lt_messages = lo_msg_buffer->get_messages( ).
        APPEND LINES OF lt_messages TO lt_messages1.

        COMMIT WORK.
      ELSE.
        ROLLBACK WORK.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_dct_from_spec_inst
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: deactivates the authorization in one
*& specific instance of the object in the role and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_dct_from_spec_inst .

  " pa_din

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            auth   TYPE agauth,
          END OF lty_auth_val.

  DATA : lt_init_excel     TYPE TABLE OF lty_auth_val,
         lwa_message       TYPE if_spcg_msg_buffer=>ty_messages,
         lt_messages       TYPE if_spcg_msg_buffer=>tt_messages,
         lt_messages1      TYPE if_spcg_msg_buffer=>tt_messages,
         lt_nodes_prefetch TYPE if_pfcg_role=>tt_node,
         lt_pfcg_role      TYPE if_pfcg_role=>tt_pfcg_role,
         lt_node_root      TYPE if_pfcg_role=>node_tt_root,
         lv_new_status     TYPE tpr_st_del,
         lt_auth_auths     TYPE if_pfcg_role=>node_tt_auth_auths.

  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.

    LOOP AT i_upload_file INTO DATA(lwa_upload_file).
      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
      <lfs_data>-role   = lwa_upload_file-field1.
      <lfs_data>-object = lwa_upload_file-field2.
      <lfs_data>-auth   = lwa_upload_file-field3.
    ENDLOOP.

    SORT lt_init_excel BY role object auth.

*** Get Unique Role
    lt_pfcg_role = VALUE #( FOR lwa_role IN lt_init_excel ( role = lwa_role-role ) ).
    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    TRY.
        CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
          EXPORTING
            it_pfcg_role      = lt_pfcg_role
            it_nodes_prefetch = lt_nodes_prefetch
          IMPORTING
            et_node_root      = lt_node_root
            eo_msg_buffer     = DATA(lo_msg_buffer).

      CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

        DATA(lv_text) = lo_pfcg_role->get_text( ).
        lwa_message-msgty  = 'E'.
        lwa_message-msgid  = '01'.
        lwa_message-msgno  = '319'.
        lwa_message-msgv1  = lv_text.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        CLEAR lwa_message.

    ENDTRY.

    IF lt_node_root IS NOT INITIAL.
      SORT lt_node_root BY role.

*** Deactivate Object Instance
      LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
        DATA(lv_index) = sy-tabix - 1.
        READ TABLE lt_init_excel INTO DATA(lwa_init_excel1) INDEX lv_index.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel1.
        ENDIF.

        TRY.
            IF lwa_init_excel-role <> lwa_init_excel1-role.
              READ TABLE lt_node_root REFERENCE INTO DATA(lwa_node_root)
                WITH KEY role = lwa_init_excel-role BINARY SEARCH.
              IF sy-subrc IS INITIAL.
*** Read Role
                CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
                  IMPORTING
                    et_auth_auths = lt_auth_auths
                    eo_msg_buffer = lo_msg_buffer.

**** Delete Inactive Authorization (keep only active ones to deactivate)
                DELETE lt_auth_auths WHERE st_inactiv IS NOT INITIAL.

*** Populate Message
                PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.

              ENDIF.
            ENDIF.

            READ TABLE lt_auth_auths ASSIGNING FIELD-SYMBOL(<lfs_auth_auths>)
                     WITH KEY object = lwa_init_excel-object
                              auth   = lwa_init_excel-auth.
            IF sy-subrc IS INITIAL.
              <lfs_auth_auths>-st_inactiv = abap_true.
              lv_new_status = abap_true.

              CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_active_auth_status
                EXPORTING
                  is_auth       = <lfs_auth_auths>
                  iv_new_status = lv_new_status
                IMPORTING
                  es_auth       = DATA(lt_ex_auth)
                  eo_msg_buffer = lo_msg_buffer.

              PERFORM update_message_dins USING lo_msg_buffer
                                                lwa_node_root->role
                                                lwa_init_excel-object
                                                lwa_init_excel-auth.

            ENDIF.

          CATCH cx_pfcg_role INTO lo_pfcg_role.

            lv_text = lo_pfcg_role->get_text( ).
            lwa_message-msgty  = 'E'.
            lwa_message-msgid  = '01'.
            lwa_message-msgno  = '319'.
            lwa_message-msgv1  = lv_text.
            APPEND lwa_message TO lt_messages.

          CATCH cx_pfcg_role_scc4.

        ENDTRY.
      ENDLOOP.

*** Check and Save
      CALL METHOD cl_pfcg_role_factory=>do_check
        IMPORTING
          ev_rejected   = DATA(lv_rejected)
          eo_msg_buffer = lo_msg_buffer.
      CLEAR lt_messages.

      lt_messages1 = lo_msg_buffer->get_messages( ).
      APPEND LINES OF lt_messages1 TO lt_messages.

      IF lv_rejected EQ abap_false.
        CALL METHOD cl_pfcg_role_factory=>do_save
          EXPORTING
            iv_update_task = abap_false
          IMPORTING
            ev_rejected    = lv_rejected
            eo_msg_buffer  = lo_msg_buffer.

        CLEAR: lt_messages.
        lt_messages = lo_msg_buffer->get_messages( ).
        APPEND LINES OF lt_messages TO lt_messages1.

        COMMIT WORK.
      ELSE.
        ROLLBACK WORK.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_act_from_spec_inst
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: (re)activates the authorization in one
*& specific instance of the object in the role and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_act_from_spec_inst .

  TYPES : BEGIN OF lty_auth_val,
            role   TYPE agr_name,
            object TYPE xuobject,
            auth   TYPE agauth,
          END OF lty_auth_val.

  DATA : lt_init_excel     TYPE TABLE OF lty_auth_val,
         lt_excel          TYPE STANDARD TABLE OF alsmex_tabline,
         lwa_message       TYPE if_spcg_msg_buffer=>ty_messages,
         lt_messages       TYPE if_spcg_msg_buffer=>tt_messages,
         lt_messages1      TYPE if_spcg_msg_buffer=>tt_messages,
         lt_nodes_prefetch TYPE if_pfcg_role=>tt_node,
         lt_pfcg_role      TYPE if_pfcg_role=>tt_pfcg_role,
         lt_node_root      TYPE if_pfcg_role=>node_tt_root,
         lv_new_status     TYPE tpr_st_del,
         lt_auth_auths     TYPE if_pfcg_role=>node_tt_auth_auths.

  "ain

  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.

    LOOP AT i_upload_file INTO DATA(lwa_upload_file).
      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
      <lfs_data>-role   = lwa_upload_file-field1.
      <lfs_data>-object = lwa_upload_file-field2.
      <lfs_data>-auth   = lwa_upload_file-field3.
    ENDLOOP.

    SORT lt_init_excel BY role object auth.

*** Get Unique Role
    lt_pfcg_role = VALUE #( FOR lwa_role2 IN lt_init_excel ( role = lwa_role2-role ) ).
    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    TRY.
        CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
          EXPORTING
            it_pfcg_role      = lt_pfcg_role
            it_nodes_prefetch = lt_nodes_prefetch
          IMPORTING
            et_node_root      = lt_node_root
            eo_msg_buffer     = DATA(lo_msg_buffer).

      CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

        DATA(lv_text) = lo_pfcg_role->get_text( ).
        lwa_message-msgty  = 'E'.
        lwa_message-msgid  = '01'.
        lwa_message-msgno  = '319'.
        lwa_message-msgv1  = lv_text.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        CLEAR lwa_message.

    ENDTRY.

    IF lt_node_root IS NOT INITIAL.
      SORT lt_node_root BY role.

*** Activate Object Instance
      LOOP AT lt_init_excel INTO DATA(lwa_init_excel).
        DATA(lv_index2) = sy-tabix - 1.
        READ TABLE lt_init_excel INTO DATA(lwa_init_excel1) INDEX lv_index2.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel1.
        ENDIF.

        TRY.
            IF lwa_init_excel-role <> lwa_init_excel1-role.
              READ TABLE lt_node_root REFERENCE INTO DATA(lwa_node_root)
                WITH KEY role = lwa_init_excel-role BINARY SEARCH.
              IF sy-subrc IS INITIAL.
*** Read Role
                CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_auths
                  IMPORTING
                    et_auth_auths = lt_auth_auths
                    eo_msg_buffer = lo_msg_buffer.

**** Delete Active Authorization (keep only inactive ones to activate)
                DELETE lt_auth_auths WHERE st_inactiv IS INITIAL.

*** Populate Message
                PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.

              ENDIF.
            ENDIF.

            READ TABLE lt_auth_auths ASSIGNING FIELD-SYMBOL(<lfs_auth_auths>)
                     WITH KEY object = lwa_init_excel-object
                              auth   = lwa_init_excel-auth.
            IF sy-subrc IS INITIAL.
              <lfs_auth_auths>-st_inactiv = abap_false.
              lv_new_status = abap_false.

              CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_active_auth_status
                EXPORTING
                  is_auth       = <lfs_auth_auths>
                  iv_new_status = lv_new_status
                IMPORTING
                  es_auth       = DATA(lt_ex_auth)
                  eo_msg_buffer = lo_msg_buffer.

              PERFORM update_message_dins USING lo_msg_buffer
                                                lwa_node_root->role
                                                lwa_init_excel-object
                                                lwa_init_excel-auth.

            ENDIF.

          CATCH cx_pfcg_role INTO lo_pfcg_role.

            lv_text = lo_pfcg_role->get_text( ).
            lwa_message-msgty  = 'E'.
            lwa_message-msgid  = '01'.
            lwa_message-msgno  = '319'.
            lwa_message-msgv1  = lv_text.
            APPEND lwa_message TO lt_messages.

          CATCH cx_pfcg_role_scc4.

        ENDTRY.
      ENDLOOP.

*** Check and Save
      CALL METHOD cl_pfcg_role_factory=>do_check
        IMPORTING
          ev_rejected   = DATA(lv_rejected)
          eo_msg_buffer = lo_msg_buffer.
      CLEAR lt_messages.

      lt_messages1 = lo_msg_buffer->get_messages( ).
      APPEND LINES OF lt_messages1 TO lt_messages.

      IF lv_rejected EQ abap_false.
        CALL METHOD cl_pfcg_role_factory=>do_save
          EXPORTING
            iv_update_task = abap_false
          IMPORTING
            ev_rejected    = lv_rejected
            eo_msg_buffer  = lo_msg_buffer.

        CLEAR: lt_messages.
        lt_messages = lo_msg_buffer->get_messages( ).
        APPEND LINES OF lt_messages TO lt_messages1.

        COMMIT WORK.
      ELSE.
        ROLLBACK WORK.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form maintain_add_in_new_inst
*&---------------------------------------------------------------------*
*& Mass-maintenance helper: adds the authorization value in a new
*& authorization instance of the object in the role and commits.
*& Called from maintain_auth_values.
*&---------------------------------------------------------------------*
FORM maintain_add_in_new_inst .

  "pa_ani

  TYPES : BEGIN OF lty_auth_val,
            role     TYPE agr_name,
            object   TYPE xuobject,
            field    TYPE agrfield,
            group(3) TYPE n,
            value    TYPE agval,
          END OF lty_auth_val.

  DATA : lt_init_excel        TYPE TABLE OF lty_auth_val,
         lt_excel             TYPE STANDARD TABLE OF alsmex_tabline,
         lv_subrc             TYPE sy-subrc,
         lwa_message          TYPE if_spcg_msg_buffer=>ty_messages,
         lt_messages          TYPE if_spcg_msg_buffer=>tt_messages,
         lt_messages1         TYPE if_spcg_msg_buffer=>tt_messages,
         lt_nodes_prefetch    TYPE if_pfcg_role=>tt_node,
         lt_pfcg_role         TYPE if_pfcg_role=>tt_pfcg_role,
         lt_node_root         TYPE if_pfcg_role=>node_tt_root,
         lt_change_values     TYPE if_pfcg_role=>node_tt_auth_values,
         ls_auth_values       TYPE if_pfcg_role=>node_st_auth_values,
         lv_atleast_on_succes TYPE flag.

  IF i_upload_file IS NOT INITIAL.

    DELETE i_upload_file INDEX 1.

    LOOP AT i_upload_file INTO DATA(lwa_upload_file).
      APPEND INITIAL LINE TO lt_init_excel ASSIGNING FIELD-SYMBOL(<lfs_data>).
      <lfs_data>-role   = lwa_upload_file-field1.
      <lfs_data>-object = lwa_upload_file-field2.
      <lfs_data>-field  = lwa_upload_file-field3.
      <lfs_data>-group  = lwa_upload_file-field4.
      <lfs_data>-value  = lwa_upload_file-field5.
    ENDLOOP.

    SORT lt_init_excel BY role object group field value.

*** Get Unique Role
    lt_pfcg_role = VALUE #( FOR lwa_role IN lt_init_excel ( role = lwa_role-role ) ).
    SORT lt_pfcg_role BY role.
    DELETE ADJACENT DUPLICATES FROM lt_pfcg_role COMPARING role.

    APPEND if_pfcg_role=>gc_node_auth_auths  TO lt_nodes_prefetch.
    APPEND if_pfcg_role=>gc_node_auth_values TO lt_nodes_prefetch.

*** Get Role
    TRY.
        CALL METHOD cl_pfcg_role_factory=>retrieve_for_update
          EXPORTING
            it_pfcg_role      = lt_pfcg_role
            it_nodes_prefetch = lt_nodes_prefetch
          IMPORTING
            et_node_root      = lt_node_root
            eo_msg_buffer     = DATA(lo_msg_buffer).

      CATCH cx_pfcg_role INTO DATA(lo_pfcg_role).

        DATA(lv_text) = lo_pfcg_role->get_text( ).
        lwa_message-msgty  = 'E'.
        lwa_message-msgid  = '01'.
        lwa_message-msgno  = '319'.
        lwa_message-msgv1  = lv_text.
        PERFORM add_message USING lwa_message lo_msg_buffer.
        CLEAR lwa_message.

    ENDTRY.

    IF lt_node_root IS NOT INITIAL.
      SORT lt_node_root BY role.

      LOOP AT lt_init_excel INTO DATA(lwa_init_excel).

        CLEAR: lv_text.
        DATA(lv_index_nxt) = sy-tabix + 1.
        DATA(lv_index_prv) = sy-tabix - 1.
*** Get Next Line Record
        READ TABLE lt_init_excel INTO DATA(lwa_init_excel_nxt) INDEX lv_index_nxt.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel_nxt.
        ENDIF.
*** Get Previous Line Record
        READ TABLE lt_init_excel INTO DATA(lwa_init_excel_prv) INDEX lv_index_prv.
        IF sy-subrc IS NOT INITIAL.
          CLEAR : lwa_init_excel_prv.
        ENDIF.

*** "AT NEW" role object group
        IF lwa_init_excel-role   <> lwa_init_excel_prv-role OR
           lwa_init_excel-object <> lwa_init_excel_prv-object OR
           lwa_init_excel-group  <> lwa_init_excel_prv-group.

          DATA(lv_object_add_error) = abap_false.

*** Add New Instance
          READ TABLE lt_node_root REFERENCE INTO DATA(lwa_node_root)
                     WITH KEY role = lwa_init_excel-role BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            TRY.
                CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~add_manual_auth
                  EXPORTING
                    iv_object     = lwa_init_excel-object
                  IMPORTING
                    es_auth_auths = DATA(lwa_auth_auth)
                    eo_msg_buffer = lo_msg_buffer.

                PERFORM update_message USING lo_msg_buffer lwa_node_root->role ''.

              CATCH cx_pfcg_role INTO lo_pfcg_role.

                lv_object_add_error = abap_true.

                lv_text = lo_pfcg_role->get_text( ).
                lwa_message-msgty  = 'E'.
                lwa_message-msgid  = '01'.
                lwa_message-msgno  = '319'.
                lwa_message-msgv1  = lv_text.
                APPEND lwa_message TO lt_messages.

              CATCH cx_pfcg_role_scc4.
                lv_object_add_error = abap_true.

            ENDTRY.
          ELSE.
            lv_object_add_error = abap_true.
          ENDIF.
        ENDIF.

        IF lv_object_add_error = abap_false.
*** Add Authorization Value
          ls_auth_values-field       = lwa_init_excel-field.
          ls_auth_values-low         = lwa_init_excel-value.
          ls_auth_values-change_mode = 'I'.
          APPEND ls_auth_values TO lt_change_values.

*** "AT END OF" Role Object Group
          IF lwa_init_excel-role   <> lwa_init_excel_nxt-role OR
             lwa_init_excel-object <> lwa_init_excel_nxt-object OR
             lwa_init_excel-group  <> lwa_init_excel_nxt-group.

            IF lt_change_values IS NOT INITIAL.

              TRY.
                  CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~set_values_for_auth
                    EXPORTING
                      is_auth        = lwa_auth_auth
                      it_auth_values = lt_change_values
                    IMPORTING
                      eo_msg_buffer  = lo_msg_buffer.

                  PERFORM update_message USING lo_msg_buffer lwa_node_root->role lwa_auth_auth-object.

                  CALL METHOD lwa_node_root->role_ref->if_pfcg_role_authorization~get_values_for_auth
                    EXPORTING
                      is_auth        = lwa_auth_auth
                    IMPORTING
                      et_auth_values = DATA(lt_auth_values_new_ani)
                      eo_msg_buffer  = lo_msg_buffer.

                  PERFORM update_message1 USING lwa_init_excel-role lwa_auth_auth-object lt_change_values.

                  lv_atleast_on_succes = abap_true.

                CATCH cx_pfcg_role INTO lo_pfcg_role.

                  lv_text = lo_pfcg_role->get_text( ).
                  lwa_message-msgty  = 'E'.
                  lwa_message-msgid  = '01'.
                  lwa_message-msgno  = '319'.
                  lwa_message-msgv1  = lv_text.
                  APPEND lwa_message TO lt_messages.

                CATCH cx_pfcg_role_scc4.

              ENDTRY.
            ENDIF.
            CLEAR : lt_change_values.
          ENDIF.
        ENDIF.

      ENDLOOP.

*** Check and Save (only if at least one success)
      IF lv_atleast_on_succes IS NOT INITIAL.
        CALL METHOD cl_pfcg_role_factory=>do_check
          IMPORTING
            ev_rejected   = DATA(lv_rejected)
            eo_msg_buffer = lo_msg_buffer.
        CLEAR lt_messages.

        lt_messages1 = lo_msg_buffer->get_messages( ).
        APPEND LINES OF lt_messages1 TO lt_messages.

        IF lv_rejected EQ abap_false.
          CALL METHOD cl_pfcg_role_factory=>do_save
            EXPORTING
              iv_update_task = abap_false
            IMPORTING
              ev_rejected    = lv_rejected
              eo_msg_buffer  = lo_msg_buffer.

          CLEAR: lt_messages.
          lt_messages = lo_msg_buffer->get_messages( ).
          APPEND LINES OF lt_messages TO lt_messages1.

          COMMIT WORK.
        ELSE.
          ROLLBACK WORK.
        ENDIF.
      ENDIF.

    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form add_message
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LWA_MESSAGE
*&      --> LO_MSG_BUFFER
*&---------------------------------------------------------------------*
FORM add_message  USING    p_lwa_message   TYPE if_spcg_msg_buffer=>ty_messages
                           p_lo_msg_buffer TYPE REF TO if_spcg_msg_buffer.

  TYPES:
    BEGIN OF lty_split,
      object TYPE agobject,
      auth   TYPE agauth,
      field  TYPE agrfield,
      low    TYPE agval,
    END OF lty_split.

  DATA:
    lwa_split  TYPE lty_split,

    lt_message TYPE if_spcg_msg_buffer=>tt_messages.

  IF p_lwa_message IS NOT INITIAL.
    APPEND INITIAL LINE TO gt_auth_val ASSIGNING FIELD-SYMBOL(<lfs_auth_val>).
    IF p_lwa_message-msgty  = 'E'.
      <lfs_auth_val>-type = 'Error'.
    ELSEIF p_lwa_message-msgty  = 'S'.
      <lfs_auth_val>-type = 'Success'.
    ENDIF.
    <lfs_auth_val>-message = p_lwa_message-message.
  ELSE.

    lt_message = p_lo_msg_buffer->get_messages( ).

    LOOP AT lt_message INTO DATA(lwa_message).

      APPEND INITIAL LINE TO gt_auth_val ASSIGNING <lfs_auth_val>.

      <lfs_auth_val>-role       = lwa_message-role.
      IF lwa_message-msgty      = 'S'.
        <lfs_auth_val>-type     = 'Success'.
      ELSEIF lwa_message-msgty  = 'E'.
        <lfs_auth_val>-type     = 'Error'.
      ELSE.
        <lfs_auth_val>-type     = lwa_message-msgty.
      ENDIF.
      <lfs_auth_val>-message    = lwa_message-message.

      lwa_split = lwa_message-key.
      <lfs_auth_val>-object  = lwa_split-object.
      <lfs_auth_val>-field   = lwa_split-field.
      <lfs_auth_val>-value   = lwa_split-low.

    ENDLOOP.

  ENDIF.



ENDFORM.
