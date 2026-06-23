*&---------------------------------------------------------------------*
*& Include          ZACG_MAINI01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_1000  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_1000 INPUT.

  PERFORM user_command_1000.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9001 INPUT.

  PERFORM user_command_9001.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9001 INPUT.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9002  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9002 INPUT.

  PERFORM user_command_9002.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9006  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9006 INPUT.
  IF sy-ucomm = 'EXE'.
    sy-ucomm = 'EXE1'.
  ENDIF.
  CASE sy-ucomm.
    WHEN 'EXE1'.
      PERFORM create_user.
    WHEN 'DFILE'.
      PERFORM f_dld_user_template.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9007  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9007 INPUT.
  IF sy-ucomm = 'EXE'.
    sy-ucomm = 'EXE2'.
  ENDIF.
  CASE sy-ucomm.
    WHEN 'EXE2'.
      IF p_file2 IS INITIAL.
        PERFORM set_reset_password_manual.
      ELSE.
        PERFORM set_reset_password_mass.
      ENDIF.
    WHEN 'DFILEPW'.
      PERFORM f_pwfile_template.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_PWFILE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_pwfile_validate INPUT.
  PERFORM p_pwfile_validate.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9008  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9008 INPUT.
  IF sy-ucomm = 'EXE'.
    sy-ucomm = 'EXE3'.
  ENDIF.
  CASE sy-ucomm.
    WHEN 'EXE3'.
      PERFORM show_lock_user_report.
      CLEAR sy-ucomm.
    WHEN 'LUSER'.
      PERFORM lock_user.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_8001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_8001 INPUT.

  PERFORM user_command_8001.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9009  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9009 INPUT.

  IF sy-ucomm EQ 'EXE'.
    IF p_initpw IS INITIAL.
      PERFORM set_prod_password_manual.
    ELSE.
      PERFORM set_prod_password_mass.
    ENDIF.



  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9009
                                    co_trans_name_9009.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_INITPW_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_initpw_validate INPUT.

  PERFORM p_initpw_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9010  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9010 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM update_user_details.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9010
                                    co_trans_name_9010.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_USUPD_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_usupd_validate INPUT.

  PERFORM p_usupd_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9011  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9011 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM change_description_of_roles.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9011
                                    co_trans_name_9011.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_CDROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_cdrole_validate INPUT.

  PERFORM p_cdrole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9012  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9012 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM derive_role_create.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9012
                                    co_trans_name_9012.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9013  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9013 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM delete_inheritance.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9013
                                    co_trans_name_9013.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9014  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9014 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM add_single_role_to_composite.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9014
                                    co_trans_name_9014.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9015  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9015 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM remove_single_from_composite.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9015
                                    co_trans_name_9015.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9016  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9016 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM delete_roles.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9016
                                    co_trans_name_9016.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9017  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9017 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM push_master_role.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9017
                                    co_trans_name_9017.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9018  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9018 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM create_composite_role.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9018
                                    co_trans_name_9018.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9019  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9019 INPUT.

  IF sy-ucomm EQ 'EXE'.
    PERFORM create_role_copy.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9019
                                    co_trans_name_9019.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_DRROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_drrole_validate INPUT.

  PERFORM p_drrole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9020  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9020 INPUT.

  IF sy-ucomm EQ 'EXE'.
    IF p_file13 IS INITIAL.
      PERFORM man_role_ass.
    ELSE.
      PERFORM file_role_ass.
    ENDIF.
  ELSEIF sy-ucomm EQ 'DWN'.
    PERFORM download_template USING co_file_9020
                                    co_trans_name_9020.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_7001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_7001 INPUT.
  CASE sy-ucomm.
    WHEN 'OKAY'.
      PERFORM raise_new_request.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'CANC'.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN OTHERS.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_DIROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_dirole_validate INPUT.

  PERFORM p_dirole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_ASROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_asrole_validate INPUT.

  PERFORM p_asrole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_RSROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_rsrole_validate INPUT.

  PERFORM p_rsrole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_RMROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_rmrole_validate INPUT.

  PERFORM p_rmrole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_PMROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_pmrole_validate INPUT.

  PERFORM p_pmrole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_CCROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_ccrole_validate INPUT.

  PERFORM p_ccrole_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_ROLE_ASSIGN_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_role_assign_validate INPUT.

  PERFORM p_role_assign_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_COPY_ROLE_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_copy_role_validate INPUT.

  PERFORM p_copy_role_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9022  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9022 INPUT.
  IF sy-ucomm EQ 'EXE'.
    PERFORM mbs.
  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_2024  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_2024 INPUT.

  DATA : lv_filename   TYPE string,
         lv_trans_name TYPE cxsltdesc.

  IF sy-ucomm EQ 'EXE'.

    CLEAR : gt_auth_val.
*    IF pa_adi IS NOT INITIAL OR pa_dli IS NOT INITIAL.
*      PERFORM maintain_auth_values USING 'X'.
*    ELSE.
*      IF sy-uname <> 'KALLOL'.
*        PERFORM maintain_auth_values USING ''.
*      ENDIF.
*    ENDIF.

    IF pa_add IS NOT INITIAL.

      " Add - In all existing Object
      PERFORM maintain_add_in_all_object.

    ELSEIF pa_adi IS NOT INITIAL.

      " Add - In specific instance Object
      PERFORM maintain_add_in_spec_inst.

    ELSEIF pa_ins IS NOT INITIAL.

      " Add in a new Object
      PERFORM maintain_add_new_object.

    ELSEIF pa_del IS NOT INITIAL.

      " Delete from all Instance
      PERFORM maintain_del_all_insts.

    ELSEIF pa_dli IS NOT INITIAL.

      " Delete from specific instance
      PERFORM maintain_del_from_spec_inst.

    ELSEIF pa_din IS NOT INITIAL.

      " Deactivate from specific instance
      PERFORM maintain_dct_from_spec_inst.

    ELSEIF pa_ain IS NOT INITIAL.

      " Activate from specific instance
      PERFORM maintain_act_from_spec_inst.

    ELSEIF pa_ani IS NOT INITIAL.

      " Add in new instance
      PERFORM maintain_add_in_new_inst.

    ENDIF.



  ELSEIF sy-ucomm EQ 'DWN'.
    IF pa_add IS NOT INITIAL.
      lv_filename = co_file_9024_add.
      lv_trans_name = co_trans_name_9024.
    ELSEIF pa_adi IS NOT INITIAL.
      lv_filename = co_file_9024_adi.
      lv_trans_name = co_trans_inst_9024.
    ELSEIF pa_del IS NOT INITIAL.
      lv_filename = co_file_9024_del.
      lv_trans_name = co_trans_name_9024.
    ELSEIF pa_dli IS NOT INITIAL.
      lv_filename = co_file_9024_dli.
      lv_trans_name = co_trans_inst_9024.
    ELSEIF pa_ins IS NOT INITIAL.
      lv_filename = co_file_9024_ins.
      lv_trans_name = co_trans_name_9024.
    ELSEIF pa_din IS NOT INITIAL.
      lv_filename = co_file_9024_din.
      lv_trans_name = co_trans_dinst_9024.
    ELSEIF pa_ain IS NOT INITIAL.
      lv_filename = co_file_9024_ain.
      lv_trans_name = co_trans_dinst_9024.
    ELSEIF pa_ani IS NOT INITIAL.
      lv_filename = co_file_9024_ani.
      lv_trans_name = co_trans_asninst_9024.
    ELSEIF pa_atc IS NOT INITIAL.
      lv_filename = co_file_9024_atc.
      lv_trans_name = co_trans_tcdagr_9024.
    ELSEIF pa_dtc IS NOT INITIAL.
      lv_filename = co_file_9024_dtc.
      lv_trans_name = co_trans_dtcdagr_9024.
    ELSEIF pa_csr IS NOT INITIAL.
      lv_filename = co_file_9024_csr.
      lv_trans_name = co_trans_csr_9024.
    ENDIF.
    PERFORM download_template USING lv_filename
                                    lv_trans_name.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  P_MASS_MAINTAIN_VALIDATE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE p_mass_maintain_validate INPUT.

  PERFORM mass_maintain_validate.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9025  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9025 INPUT.

  IF sy-ucomm = 'EXE'.
    CLEAR : gt_derive_role.
    PERFORM direct_change.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9026  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9026 INPUT.

  IF sy-ucomm = 'EXE'.
    CLEAR : gt_org_field.
    PERFORM org_field_change.
  ENDIF.

ENDMODULE.

MODULE user_command_9027 INPUT.

  IF sy-ucomm = 'EXE'.

    CLEAR gt_outtab_9027.
    PERFORM user_command_9028.

  ELSEIF sy-ucomm = 'DF927'.

    PERFORM download_template USING
          co_file_9027
          co_trans_name_9027.

  ENDIF.

ENDMODULE.

MODULE user_command_9028 INPUT.

  IF sy-ucomm = 'EXE'.
    CLEAR gt_outtab_9028.
    PERFORM get_data_9028.
  ENDIF.

ENDMODULE.

MODULE validate_9028.
  IF sy-ucomm = 'EXE'.

    IF custom IS NOT INITIAL.
      IF date1 IS INITIAL.
        CLEAR sy-ucomm.
        SET CURSOR FIELD 'DATE1'.
        MESSAGE 'Please Provide From Date' TYPE 'E'.
      ENDIF.
      IF date2 IS INITIAL.
        CLEAR sy-ucomm.
        SET CURSOR FIELD 'DATE2'.
        MESSAGE 'Please Provide To Date' TYPE 'E'.
      ENDIF.
      IF date1 > date2.
        CLEAR sy-ucomm.
        SET CURSOR FIELD 'DATE2'.
        MESSAGE 'From Date can not be greater than To Date' TYPE 'E'.
      ENDIF.
    ENDIF.
    IF hrs IS INITIAL.
      CLEAR sy-ucomm.
      SET CURSOR FIELD 'HRS'.
      MESSAGE 'Please provide Durantion' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9029  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9029 INPUT.

  PERFORM validate_9029.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9029  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9029 INPUT.

  PERFORM user_command_9029.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9030  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9030 INPUT.

  PERFORM validate_9030.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9029  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9030 INPUT.

  PERFORM user_command_9030.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9031  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9031 INPUT.

  IF sy-ucomm = 'SRCH'.
    IF s_susr IS INITIAL AND s_sreq IS INITIAL.
      CLEAR sy-ucomm.
      SET CURSOR FIELD 'S_SUSR-LOW'.
      MESSAGE 'Plese provide either Request number or User' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9031  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9031 INPUT.

  PERFORM user_command_9031.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_8007  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_8007 INPUT.

  PERFORM user_command_8007.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_7001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_7001 INPUT.

  PERFORM validate_7001.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_7002  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_7002 INPUT.
  CASE sy-ucomm.
    WHEN 'OKAY'.
      g_mitigated = abap_true.
      PERFORM assign_after_popup.
      CLEAR sy-ucomm.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'CANC' OR 'EXIT'.
      CLEAR sy-ucomm.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'CLIP'.
      PERFORM paste_from_clipboard.

  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_7002  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_7002 INPUT.
  PERFORM validate_7002.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_7003  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_7003 INPUT.
  CASE sy-ucomm.
    WHEN 'OKAY'.
      g_mitigated = abap_true.
      PERFORM reject_after_popup.
      CLEAR sy-ucomm.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'CANC' OR 'EXIT'.
      CLEAR: sy-ucomm, g_mitigated.
      SET SCREEN 0.
      LEAVE SCREEN.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_7003  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_7003 INPUT.
  PERFORM validate_7003.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_7004  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_7004 INPUT.
  PERFORM validate_7004.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_7004  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_7004 INPUT.
  PERFORM user_command_7004.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9033  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9033 INPUT.

  PERFORM validate_9033.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9033  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9033 INPUT.

  PERFORM user_command_9033.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_7005  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_7005 INPUT.

  PERFORM user_command_7005.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_7005  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_7005 INPUT.

  PERFORM validate_7005.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9034  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9034 INPUT.

  PERFORM user_command_9034.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_7006  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_7006 INPUT.
  CASE sy-ucomm.
    WHEN 'OKAY'.
      PERFORM update_tlog_reject.
      CLEAR sy-ucomm.
      SET SCREEN 0.
      LEAVE SCREEN.
    WHEN 'CANC' OR 'EXIT'.
      CLEAR sy-ucomm.
      SET SCREEN 0.
      LEAVE SCREEN.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_7006  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_7006 INPUT.
  PERFORM validate_7006.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9035  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9035 INPUT.
  PERFORM validate_9035.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9035  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9035 INPUT.

  CASE sy-ucomm.
    WHEN 'EXE'.
      PERFORM get_data_9035.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9036  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9036 INPUT.

  CASE sy-ucomm.
    WHEN 'RUSG' OR 'EXE'.
      PERFORM set_selection_9036.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9037  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9037 INPUT.

  PERFORM user_command_9037.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_7007  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_7007 INPUT.

*  PERFORM user_command_7007.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9041  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9041 INPUT.

  CASE sy-ucomm.
    WHEN 'EXE'.
      PERFORM get_data_9041.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9041  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9041 INPUT.

  PERFORM validate_9041.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9042  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9042 INPUT.

  CASE sy-ucomm.
    WHEN 'EXE'.
      PERFORM get_data_9042.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  VALIDATE_9042  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE validate_9042 INPUT.

  PERFORM validate_9042.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_8008  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_8008 INPUT.

  g_ucomm = sy-ucomm.
  CASE g_ucomm.
    WHEN 'BACK' OR 'EXIT'.
      CLEAR: g_ucomm.
      LEAVE TO SCREEN 0.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_6001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_6001 INPUT.

  g_ucomm = sy-ucomm.
  CASE g_ucomm.
    WHEN 'BACK' OR 'EXIT'.
      CLEAR: g_ucomm.
      LEAVE TO SCREEN 0.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_8009  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_8009 INPUT.

  g_ucomm = sy-ucomm.
  CASE g_ucomm.
    WHEN 'BACK' OR 'EXIT'.
      CLEAR: g_ucomm.
      LEAVE TO SCREEN 0.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_6002  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_6002 INPUT.

  g_ucomm = sy-ucomm.
  CASE g_ucomm.
    WHEN 'BACK' OR 'EXIT'.
      CLEAR: g_ucomm.
      LEAVE TO SCREEN 0.
  ENDCASE.

ENDMODULE.
