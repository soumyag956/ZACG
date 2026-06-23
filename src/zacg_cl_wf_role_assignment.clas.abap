"! <p class="shorttext synchronized">ZACG Role-Request Workflow Business Object</p>
"! Workflow business object (BI_OBJECT / BI_PERSISTENT / IF_WORKFLOW) for
"! the ZACG access-request approval process. The instance key (KEY /
"! LPOR-INSTID) is the access-request number (ZACG_ACC_REQ).
"!
"! It exposes the helper methods used by the SAP Business Workflow to:
"!  - read the requested / approved / rejected roles and their texts,
"!  - determine the unique role owners and mitigation owners and iterate
"!    over them one-by-one (for dynamic parallel approval steps),
"!  - resolve approver / owner e-mail addresses, and
"!  - finally provision the approved roles (ASSIGN_ROLE) by scheduling
"!    report ZACG_ROLE_ASSIGNMENT as a background job.
"! The TRIGGER event carries the action and the parties to be notified.
class ZACG_CL_WF_ROLE_ASSIGNMENT definition
  public
  final
  create public .

public section.

  interfaces BI_OBJECT .
  interfaces BI_PERSISTENT .
  interfaces IF_WORKFLOW .

  data LPOR type SIBFLPOR .
  data KEY type ZACG_ACC_REQ .

  events TRIGGER
    exporting
      value(IV_ACTION) type ZACG_ROLE_REQUEST_ACTION
      value(IV_REQUEST) type ZACG_ACC_REQ
      value(IS_EMPLOYEE) type ZACG_RECIPIENT optional
      value(IS_LINE_MANAGER) type ZACG_RECIPIENT optional
      value(IT_MITIGATION_OWNER) type ZACG_T_MITIGATION_OWNER optional
      value(IT_APPROVED_ROLES) type ZACG_T_REQUESTED_ROLES optional
      value(IT_REJECTED_ROLES) type ZACG_T_REQUESTED_ROLES optional
      value(IV_REJECTION_REASON) type TEXT100 optional .

  methods GET_REQUESTED_ROLES
    importing
      !IV_REQUEST type ZACG_ACC_REQ
    exporting
      !ET_ROLES type ZACG_T_REQUESTED_ROLES .
  methods CONSTRUCTOR
    importing
      !ID type ZACG_ACC_REQ .
  methods GET_ROLE_OWNERS
    importing
      !IV_REQUEST type ZACG_ACC_REQ
      !IT_APPROVED_ROLES type ZACG_T_REQUESTED_ROLES
    exporting
      !ET_UNIQUE_ROLE_OWNER type ZACG_T_UNIQUE_ROLE_OWNER
      !EV_ROLE_OWNER_COUNT type INT4 .
  methods GET_ROLE_AND_ROLE_OWNER
    importing
      !IV_REQUEST type ZACG_ACC_REQ
      !IT_ROLE_MANAGER type ZACG_T_UNIQUE_ROLE_OWNER
    exporting
      !ES_ROLE_MANAGER_EMAIL type ZACG_RECIPIENT
      !ET_ROLES type ZACG_T_REQUESTED_ROLES
    changing
      !CV_ROLE_OWNER_COUNT type INT4 .
  methods ROLE_OWNER_APPROVAL
    importing
      !IV_REQUEST type ZACG_ACC_REQ
      !IV_WF_INITIATOR type SWP_INITIA
      !IT_APPROVED_ROLES type ZACG_T_REQUESTED_ROLES
    exporting
      !ES_ROLE_OWNER type ZACG_RECIPIENT
      !ET_ROLES type ZACG_T_REQUESTED_ROLES .
  methods ASSIGN_ROLE
    importing
      !IV_REQUEST type ZACG_ACC_REQ
      !IT_APPROVED_ROLES type ZACG_T_REQUESTED_ROLES .
  methods GET_UNIQUE_MITIGATION_OWNER
    importing
      !IT_MITIGATION_OWNER type ZACG_T_MITIGATION_OWNER
    exporting
      !ET_UNIQUE_MITIGATION type ZACG_T_MITIGATION_OWNER
      !EV_MITIGATION_COUNT type INT4 .
  methods GET_SINGLE_MITIGATION_OWNER
    importing
      !IT_UNIQUE_MITIGATION type ZACG_T_MITIGATION_OWNER
    exporting
      !ES_MITIGATION_OWNER type ZACG_MITIGATION_OWNER
    changing
      !CV_MITIGATION_COUNT type INT4 .
  methods ROLE_OWNER_REJECTION
    importing
      !IV_REQUEST type ZACG_ACC_REQ
      !IV_WF_INITIATOR type SWP_INITIA
      !IT_REJECTED_ROLES type ZACG_T_REQUESTED_ROLES
    exporting
      !ET_REJECTION_REASON type ZACG_T_REJECTION_REASON
      !ES_ROLE_OWNER type ZACG_RECIPIENT
      !ET_ROLES type ZACG_T_REQUESTED_ROLES .
protected section.
private section.
ENDCLASS.



CLASS ZACG_CL_WF_ROLE_ASSIGNMENT IMPLEMENTATION.


METHOD assign_role.
* Provisions the approved roles for the request: reads the requester and
* validity dates from ZACG_REQ_APROVER, builds a selection table and
* schedules report ZACG_ROLE_ASSIGNMENT as a background job (user
* ZACG_ADMIN) to perform the actual BAPI_USER_ACTGROUPS_ASSIGN.
* NOTE: the trailing WHILE lines( it_approved_roles ) = sy-dbcnt loop is
* a busy-wait that can spin (it re-reads AGR_USERS with no exit/timeout);
* it should be reworked into a bounded poll with a wait/timeout.
  DATA: lv_jobcount TYPE btcjobcnt,
        lv_jobname  TYPE btcjob,
        li_seltab   TYPE STANDARD TABLE OF rsparams.

  CHECK it_approved_roles IS NOT INITIAL.

  SELECT agr_name, begda, endda, userid
    FROM zacg_req_aprover
    INTO TABLE @DATA(li_req_approver)
    FOR ALL ENTRIES IN @it_approved_roles
    WHERE req_no = @iv_request
      AND agr_name = @it_approved_roles-role.
  IF sy-subrc IS INITIAL.
    READ TABLE li_req_approver INTO DATA(lwa_user) INDEX 1.
    IF sy-subrc IS INITIAL.
      DATA(lv_user) = lwa_user-userid.
    ENDIF.
  ENDIF.


  APPEND INITIAL LINE TO li_seltab ASSIGNING FIELD-SYMBOL(<lfs_seltab>).
  <lfs_seltab>-selname = 'P_USER'.
  <lfs_seltab>-kind    = 'P'.
  <lfs_seltab>-sign    = 'I'.
  <lfs_seltab>-option  = 'EQ'.
  <lfs_seltab>-low     = lv_user.

  LOOP AT it_approved_roles INTO DATA(lwa_roles).
    APPEND INITIAL LINE TO li_seltab ASSIGNING <lfs_seltab>.
    <lfs_seltab>-selname = 'SO_ROLE'.
    <lfs_seltab>-kind    = 'S'.
    <lfs_seltab>-sign    = 'I'.
    <lfs_seltab>-option  = 'EQ'.
    <lfs_seltab>-low     = lwa_roles-role.
  ENDLOOP.

  APPEND INITIAL LINE TO li_seltab ASSIGNING <lfs_seltab>.
  <lfs_seltab>-selname = 'P_BEGDA'.
  <lfs_seltab>-kind    = 'P'.
  <lfs_seltab>-sign    = 'I'.
  <lfs_seltab>-option  = 'EQ'.
  <lfs_seltab>-low     = lwa_user-begda.

  APPEND INITIAL LINE TO li_seltab ASSIGNING <lfs_seltab>.
  <lfs_seltab>-selname = 'P_ENDDA'.
  <lfs_seltab>-kind    = 'P'.
  <lfs_seltab>-sign    = 'I'.
  <lfs_seltab>-option  = 'EQ'.
  <lfs_seltab>-low     = lwa_user-endda.

  lv_jobname = |ACG_ROLE_ASSIGNMENT_{ iv_request }_{ lv_user }|.

  CALL FUNCTION 'JOB_OPEN'
    EXPORTING
      jobname          = lv_jobname
      sdlstrtdt        = sy-datum
      sdlstrttm        = sy-uzeit
    IMPORTING
      jobcount         = lv_jobcount
    EXCEPTIONS
      cant_create_job  = 1
      invalid_job_data = 2
      jobname_missing  = 3
      OTHERS           = 4.
  IF sy-subrc = 0.
    SUBMIT zacg_role_assignment WITH SELECTION-TABLE li_seltab
                                VIA JOB lv_jobname
                                NUMBER lv_jobcount USER 'ZACG_ADMIN' AND RETURN.
    IF sy-subrc IS INITIAL.
      CALL FUNCTION 'JOB_CLOSE'
        EXPORTING
          jobcount             = lv_jobcount
          jobname              = lv_jobname
          strtimmed            = abap_true
        EXCEPTIONS
          cant_start_immediate = 1
          invalid_startdate    = 2
          jobname_missing      = 3
          job_close_failed     = 4
          job_nosteps          = 5
          job_notex            = 6
          lock_failed          = 7
          invalid_target       = 8
          invalid_time_zone    = 9
          OTHERS               = 10.
      IF sy-subrc IS INITIAL.

      ENDIF.
    ENDIF.
  ENDIF.

  WHILE lines( it_approved_roles ) = sy-dbcnt.
    SELECT agr_name
      FROM agr_users
      INTO TABLE @DATA(li_user_role)
      FOR ALL ENTRIES IN @li_req_approver
      WHERE agr_name = @li_req_approver-agr_name
        AND uname    = @lv_user
        AND from_dat = @li_req_approver-begda
        AND to_dat   = @li_req_approver-endda.

  ENDWHILE.

ENDMETHOD.


  METHOD bi_persistent~find_by_lpor.
*   Workflow persistence: re-instantiates the object from its persistent
*   object reference (the request number stored in LPOR-INSTID).
    CREATE OBJECT result TYPE zacg_cl_wf_role_assignment
      EXPORTING
        id = lpor-instid(10).

  ENDMETHOD.


  METHOD bi_persistent~lpor.

    result = me->lpor.

  ENDMETHOD.


  METHOD bi_persistent~refresh.
  ENDMETHOD.


  METHOD constructor.
*   Builds the persistent object reference from the request number (ID):
*   instance id = request, category 'CL', type = this class.
    lpor-instid = id.
    lpor-catid  = 'CL'.
    lpor-typeid = 'ZACG_CL_WF_ROLE_ASSIGNMENT'.

  ENDMETHOD.


  METHOD get_requested_roles.
*   Returns the roles of the request (first sequence) with their texts
*   (ZACG_REQ_APROVER joined to AGR_TEXTS in the logon language).
    SELECT _a~agr_name, _b~text
      FROM zacg_req_aprover AS _a
      INNER JOIN agr_texts AS _b
      ON _a~agr_name = _b~agr_name
      INTO TABLE @et_roles
      WHERE _a~req_no = @iv_request
        AND _a~seqnr = '001'
        AND _b~spras = @sy-langu.
    IF sy-subrc IS INITIAL.
    ENDIF.


  ENDMETHOD.


METHOD get_role_and_role_owner.
* Iterator step: returns the next role owner (by descending counter
* CV_ROLE_OWNER_COUNT) with their e-mail (PUSER002) and the roles still
* pending their approval, then decrements the counter. Used to drive a
* dynamic parallel "one branch per role owner" workflow step.
  CLEAR es_role_manager_email.

  READ TABLE it_role_manager INTO DATA(lwa_role_manager)
  WITH KEY index = cv_role_owner_count.
  IF sy-subrc IS INITIAL.
    SELECT SINGLE name_text, smtp_addr
      FROM puser002
      INTO @es_role_manager_email
      WHERE bname = @lwa_role_manager-role_owner_name.
    IF sy-subrc IS INITIAL.

    ENDIF.

    SELECT _a~agr_name, _b~text
      FROM zacg_req_aprover AS _a
      INNER JOIN agr_texts AS _b
      ON _a~agr_name = _b~agr_name
      INTO TABLE @et_roles
      WHERE _a~req_no        = @iv_request
        AND _a~approver      = @lwa_role_manager-role_owner_name
        AND _a~approver_role = 2
        AND _a~status        = 2
        AND _a~action_taken  = @space
        AND _b~spras         = @sy-langu.
    IF sy-subrc IS INITIAL.

    ENDIF.

    cv_role_owner_count = cv_role_owner_count - 1.
  ENDIF.
ENDMETHOD.


METHOD get_role_owners.
* Returns the distinct role owners (approver_role 2, status 03) for the
* approved roles of the request, indexed 1..n, and their count - the
* input to the get_role_and_role_owner iterator.
  SELECT *
    FROM ZACG_REQ_APROVER
    INTO TABLE @DATA(li_role_owners)
    FOR ALL ENTRIES IN @it_approved_roles
    WHERE req_no = @iv_request
      AND agr_name = @it_approved_roles-role
      AND approver_role = 2
      AND status = 03
      AND action_taken = @abap_false.

  SORT li_role_owners BY approver.
  DELETE ADJACENT DUPLICATES FROM li_role_owners COMPARING approver.
  ev_role_owner_count = lines( li_role_owners ).
  LOOP AT li_role_owners INTO DATA(lwa_role_owners).
    DATA(lv_tabix) = sy-tabix.
    APPEND INITIAL LINE TO et_unique_role_owner ASSIGNING FIELD-SYMBOL(<lfs_unique_role_owner>).
    <lfs_unique_role_owner>-index = lv_tabix.
    <lfs_unique_role_owner>-role_owner_name = lwa_role_owners-approver.
  ENDLOOP.

ENDMETHOD.


METHOD get_single_mitigation_owner.
* Iterator step: returns the next mitigation owner (by descending counter
* CV_MITIGATION_COUNT) and decrements the counter.
  CLEAR es_mitigation_owner.

  READ TABLE it_unique_mitigation INTO DATA(lwa_mitigation) INDEX cv_mitigation_count.
  IF sy-subrc IS INITIAL.
    es_mitigation_owner = lwa_mitigation.

    cv_mitigation_count = cv_mitigation_count - 1.
  ENDIF.
ENDMETHOD.


METHOD get_unique_mitigation_owner.
* De-duplicates the mitigation owners and returns the unique list and its
* count - the input to the get_single_mitigation_owner iterator.
  CLEAR: et_unique_mitigation, ev_mitigation_count.

  et_unique_mitigation = it_mitigation_owner.
  SORT et_unique_mitigation BY owner name email.
  DELETE ADJACENT DUPLICATES FROM et_unique_mitigation COMPARING owner name email.
  ev_mitigation_count = lines( et_unique_mitigation ).

ENDMETHOD.


METHOD role_owner_approval.
* Resolves the workflow initiator (role owner) e-mail from PUSER002 and
* returns it together with the approved roles, for the approval
* notification.
  CLEAR: es_role_owner, et_roles.

  DATA(lv_initiator) = iv_wf_initiator.

  SHIFT lv_initiator LEFT BY 2 PLACES.

  SELECT SINGLE name_text, smtp_addr
    FROM puser002
    INTO @es_role_owner
    WHERE bname = @lv_initiator.
  IF sy-subrc IS INITIAL.

  ENDIF.

  et_roles = it_approved_roles.

ENDMETHOD.


METHOD role_owner_rejection.
* Counterpart of role_owner_approval: resolves the initiator e-mail and
* returns the rejected roles together with their rejection reasons
* (ZACG_REQ_APROVER status 4) for the rejection notification.
  CLEAR: et_rejection_reason, es_role_owner, et_roles.

  DATA(lv_initiator) = iv_wf_initiator.

  SHIFT lv_initiator LEFT BY 2 PLACES.

  SELECT SINGLE name_text, smtp_addr
    FROM puser002
    INTO @es_role_owner
    WHERE bname = @lv_initiator.
  IF sy-subrc IS INITIAL.

  ENDIF.

  IF it_rejected_roles IS NOT INITIAL.

    et_roles = it_rejected_roles.

    SELECT agr_name rj_rsn
      FROM zacg_req_aprover
      INTO TABLE et_rejection_reason
      FOR ALL ENTRIES IN it_rejected_roles
      WHERE req_no = iv_request
        AND agr_name = it_rejected_roles-role
        AND approver_role = 2
        AND status = 4
        AND action_taken = abap_true.

  ENDIF.

ENDMETHOD.
ENDCLASS.
