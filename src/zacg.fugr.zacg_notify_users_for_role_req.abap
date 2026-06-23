FUNCTION zacg_notify_users_for_role_req.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ACTION) TYPE  ZACG_ROLE_REQUEST_ACTION
*"     VALUE(IV_REQUEST) TYPE  ZACG_ACC_REQ
*"     VALUE(IT_MITIGATION) TYPE  ZACG_T_MITIGATION_OWNER OPTIONAL
*"     VALUE(IT_APPROVED_ROLES) TYPE  ZACG_T_REQUESTED_ROLES OPTIONAL
*"     VALUE(IT_REJECTED_ROLES) TYPE  ZACG_T_REQUESTED_ROLES OPTIONAL
*"     VALUE(IV_REJECTION_REASON) TYPE  TEXT100 OPTIONAL
*"----------------------------------------------------------------------

  DATA:
    lv_objtype          TYPE sibftypeid VALUE 'ZACG_CL_WF_ROLE_ASSIGNMENT',
    lv_event            TYPE sibfevent  VALUE 'TRIGGER',
    lv_objkey           TYPE sibfinstid,
    lr_event_parameters TYPE REF TO if_swf_ifs_parameter_container,
    lv_param_name       TYPE swfdname,

    lwa_employee        TYPE zacg_recipient,
    lwa_manager         TYPE zacg_recipient,
    lwa_role_owner      TYPE zacg_recipient.


  DATA(lo_workflow) = NEW zacg_cl_wf_role_assignment( iv_request ).
  IF lo_workflow IS BOUND.

    TRY.
        CALL METHOD cl_swf_evt_event=>get_event_container
          EXPORTING
            im_objcateg  = cl_swf_evt_event=>mc_objcateg_cl
            im_objtype   = lv_objtype
            im_event     = lv_event
          RECEIVING
            re_reference = lr_event_parameters.



      CATCH cx_swf_cnt_cont_access_denied .
      CATCH cx_swf_cnt_elem_access_denied .
      CATCH cx_swf_cnt_elem_not_found .
      CATCH cx_swf_cnt_elem_type_conflict .
      CATCH cx_swf_cnt_unit_type_conflict .
      CATCH cx_swf_cnt_elem_def_invalid .
      CATCH cx_swf_cnt_container .
    ENDTRY.

    IF iv_action = 'RQ'.

      SELECT SINGLE *
        FROM zacg_req_aprover
        INTO @DATA(lwa_req_roles)
        WHERE req_no = @iv_request
        AND seqnr = '001'.
      IF sy-subrc IS INITIAL.

        " Get User details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_employee
          WHERE bname = @lwa_req_roles-userid.

        " Get Line Manger Details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_manager
          WHERE bname = @lwa_req_roles-approver.

      ENDIF.

    ELSEIF iv_action = 'MA'.

      SELECT *
        FROM zacg_req_aprover
        INTO TABLE @DATA(li_req_roles)
        WHERE req_no = @iv_request
        AND approver = @sy-uname
        AND approver_role = 1
        AND status = 2
        AND action_taken = @abap_true.

      IF sy-subrc IS INITIAL.

        READ TABLE li_req_roles INTO lwa_req_roles INDEX 1.

        " Get User details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_employee
          WHERE bname = @lwa_req_roles-userid.

        " Get Line Manger Details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_manager
          WHERE bname = @lwa_req_roles-approver.

        " All Roles Approved by Manager
        SELECT agr_name, text
          INTO TABLE @DATA(li_roles)
          FROM agr_texts
          FOR ALL ENTRIES IN @li_req_roles
          WHERE agr_name = @li_req_roles-agr_name
            AND spras = @sy-langu.
      ENDIF.

    ELSEIF iv_action = 'MR'.

      SELECT *
        FROM zacg_req_aprover
        INTO TABLE @li_req_roles
        WHERE req_no = @iv_request
        AND approver = @sy-uname
        AND approver_role = 1
        AND status = 2
        AND action_taken = @abap_true.

      IF sy-subrc IS INITIAL.

        READ TABLE li_req_roles INTO lwa_req_roles INDEX 1.

        " Get User details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_employee
          WHERE bname = @lwa_req_roles-userid.

        " Get Line Manger Details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_manager
          WHERE bname = @lwa_req_roles-approver.

        " All Roles Approved by Manager
        SELECT agr_name, text
          INTO TABLE @li_roles
          FROM agr_texts
          FOR ALL ENTRIES IN @li_req_roles
          WHERE agr_name = @li_req_roles-agr_name
            AND spras = @sy-langu.

      ENDIF.

    ELSEIF iv_action = 'RA'.

      SELECT *
        FROM zacg_req_aprover
        INTO TABLE @li_req_roles
        FOR ALL ENTRIES IN @it_approved_roles
        WHERE req_no = @iv_request
          AND agr_name = @it_approved_roles-role
          AND approver = @sy-uname
          AND approver_role = 2
          AND status = 3
          AND action_taken = @abap_true.
      IF sy-subrc IS INITIAL.

        READ TABLE li_req_roles INTO lwa_req_roles INDEX 1.

        " Get User details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_employee
          WHERE bname = @lwa_req_roles-userid.

        " Get Role Owner Details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_role_owner
          WHERE bname = @lwa_req_roles-approver.

        " All Roles Approved by Role Owner
        SELECT agr_name, text
          INTO TABLE @li_roles
          FROM agr_texts
          FOR ALL ENTRIES IN @li_req_roles
          WHERE agr_name = @li_req_roles-agr_name
            AND spras = @sy-langu.

      ENDIF.

      IF it_mitigation IS NOT INITIAL.
        DATA(li_mitigation) = it_mitigation.

        SELECT bname, name_text, smtp_addr
          FROM puser002
          INTO TABLE @DATA(li_mitigation_owner)
          FOR ALL ENTRIES IN @it_mitigation
          WHERE bname = @it_mitigation-owner.
        IF sy-subrc IS INITIAL.
          LOOP AT li_mitigation ASSIGNING FIELD-SYMBOL(<lfs_mitigation>).
            READ TABLE li_mitigation_owner INTO DATA(lwa_mitigation_owner)
            WITH KEY bname = <lfs_mitigation>-owner.
            IF sy-subrc IS INITIAL.
              <lfs_mitigation>-name  = lwa_mitigation_owner-name_text.
              <lfs_mitigation>-email = lwa_mitigation_owner-smtp_addr.
            ENDIF.
          ENDLOOP.
        ENDIF.

      ENDIF.

      lv_param_name = 'IT_APPROVED_ROLES'.
      CALL METHOD lr_event_parameters->set
        EXPORTING
          name  = lv_param_name
          value = li_roles.


      lv_param_name = 'IT_MITIGATION_OWNER'.
      CALL METHOD lr_event_parameters->set
        EXPORTING
          name  = lv_param_name
          value = li_mitigation.

    ELSEIF iv_action = 'RR'.

      SELECT *
        FROM zacg_req_aprover
        INTO TABLE @li_req_roles
        FOR ALL ENTRIES IN @it_rejected_roles
        WHERE req_no = @iv_request
          AND agr_name = @it_rejected_roles-role
          AND approver = @sy-uname
          AND approver_role = 2
          AND status = 4
          AND action_taken = @abap_true.
      IF sy-subrc IS INITIAL.

        READ TABLE li_req_roles INTO lwa_req_roles INDEX 1.

        " Get User details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_employee
          WHERE bname = @lwa_req_roles-userid.

        " Get Role Owner Details
        SELECT SINGLE name_text, smtp_addr
          FROM puser002
          INTO @lwa_role_owner
          WHERE bname = @lwa_req_roles-approver.


        " All Roles Approved by Role Owner
        SELECT agr_name, text
          INTO TABLE @li_roles
          FROM agr_texts
          FOR ALL ENTRIES IN @it_rejected_roles
          WHERE agr_name = @it_rejected_roles-role
            AND spras = @sy-langu.

        lv_param_name = 'IT_REJECTED_ROLES'.
        CALL METHOD lr_event_parameters->set
          EXPORTING
            name  = lv_param_name
            value = li_roles.

      ENDIF.

    ENDIF.

    lv_param_name = 'IV_ACTION'.
    CALL METHOD lr_event_parameters->set
      EXPORTING
        name  = lv_param_name
        value = iv_action.

    lv_param_name = 'IV_REQUEST'.
    CALL METHOD lr_event_parameters->set
      EXPORTING
        name  = lv_param_name
        value = iv_request.

    lv_param_name = 'IS_EMPLOYEE'.
    CALL METHOD lr_event_parameters->set
      EXPORTING
        name  = lv_param_name
        value = lwa_employee.

    lv_param_name = 'IS_LINE_MANAGER'.
    CALL METHOD lr_event_parameters->set
      EXPORTING
        name  = lv_param_name
        value = lwa_manager.

    lv_param_name = 'IV_REJECTION_REASON'.
    CALL METHOD lr_event_parameters->set
      EXPORTING
        name  = lv_param_name
        value = iv_rejection_reason.

    TRY.
        lv_objkey = iv_request.
        CALL METHOD cl_swf_evt_event=>raise
          EXPORTING
            im_objcateg        = cl_swf_evt_event=>mc_objcateg_cl
            im_objtype         = lv_objtype
            im_event           = lv_event
            im_objkey          = lv_objkey
            im_event_container = lr_event_parameters.
      CATCH cx_swf_evt_invalid_objtype .
      CATCH cx_swf_evt_invalid_event .
    ENDTRY.

    COMMIT WORK.

  ENDIF.


ENDFUNCTION.
