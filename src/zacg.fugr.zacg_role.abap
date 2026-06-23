FUNCTION zacg_role.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ROLE) TYPE  AGR_NAME
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"     VALUE(IT_LEVEL) TYPE  ZACG_T_LEVEL OPTIONAL
*"     VALUE(IT_MODULE) TYPE  ZACG_T_MODULE OPTIONAL
*"  EXPORTING
*"     VALUE(ET_RISK_SUMMARY) TYPE  ZACG_T_RISK_SUMMARY
*"     VALUE(ET_RISK_DETAIL) TYPE  ZACG_T_RISK_DETAIL
*"     VALUE(EV_FILE) TYPE  FLAG
*"----------------------------------------------------------------------

  TYPES : BEGIN OF lty_pfcg,
            agr_name TYPE agr_name,
            object   TYPE agobject,
            auth     TYPE agauth,
            field	   TYPE agrfield,
            low	     TYPE agval,
            high     TYPE agval,
          END OF lty_pfcg,

          BEGIN OF lty_usobhash,
            name     TYPE xupname,
            type     TYPE usobtype,
            obj_name TYPE char50,
          END OF lty_usobhash,

          BEGIN OF lty_lib_serv,
            tcode TYPE zacg_tcode,
          END OF lty_lib_serv,

          BEGIN OF lty_tcode_func,
            agr_name TYPE agr_name,
            risk     TYPE zrisk,
            riskd    TYPE zrisk_descr,
            func     TYPE zfunc,
            funcd    TYPE zfunc_descr,
            tcode    TYPE zacg_tcode,
            auth     TYPE agauth,
          END OF lty_tcode_func,

          BEGIN OF lty_join,
            pfcg_agr_name TYPE agr_name,
            pfcg_object   TYPE agobject,
            pfcg_auth     TYPE agauth,
            pfcg_field    TYPE agrfield,
            pfcg_low      TYPE agval,
            pfcg_high     TYPE agval,
            lib_func      TYPE zfunc,
            lib_tcode     TYPE zacg_tcode,
            lib_object    TYPE agobject,
            lib_field     TYPE agrfield,
            lib_low       TYPE agval,
            lib_high      TYPE agval,
            risk          TYPE zrisk,
            crit          TYPE flag,
          END OF lty_join.

  DATA:
    lv_tcode_rc         TYPE sy-subrc,
    lv_servc_rc         TYPE sy-subrc,
    lv_actvt_not_found  TYPE flag,
    lv_object_not_found TYPE flag,
    lv_func_not_found   TYPE flag,

    lr_tcode            TYPE RANGE OF zacg_tcode,
    lr_lib_tcode        TYPE RANGE OF zacg_tcode,
    lr_object_lib       TYPE RANGE OF agobject,
    lr_fval             TYPE RANGE OF agval,
    lr_pfcg_serv        TYPE RANGE OF zacg_tcode,
    lr_lib_srvc         TYPE RANGE OF zacg_tcode,
    lr_func             TYPE RANGE OF zfunc,
    lr_lib_obj          TYPE RANGE OF agobject,
    lr_instance         TYPE RANGE OF agauth,
    lr_risk             TYPE RANGE OF zrisk,
    lr_risk_no_sod      TYPE RANGE OF zrisk,
    lr_field            TYPE RANGE OF agrfield,
    lr_risk_func        TYPE RANGE OF zrisk,
    lr_low              TYPE RANGE OF agval,

    lit_pfcg_tmp        TYPE STANDARD TABLE OF lty_pfcg,
    lit_pfcg_tcd        TYPE STANDARD TABLE OF lty_pfcg,
    lit_pfcg            TYPE STANDARD TABLE OF lty_pfcg,
    lit_srv_lib_fval    TYPE STANDARD TABLE OF lty_usobhash,
    lit_join            TYPE STANDARD TABLE OF lty_join,
    lit_potential_obj   TYPE STANDARD TABLE OF lty_join,
    lit_potential_tcd   TYPE STANDARD TABLE OF lty_join,
    lit_potential_risk  TYPE STANDARD TABLE OF lty_join,
    lit_lib_serv        TYPE STANDARD TABLE OF lty_lib_serv,
    lit_tcode_func      TYPE STANDARD TABLE OF lty_tcode_func,
    lit_agrtcode        TYPE STANDARD TABLE OF lty_pfcg,
    lit_agr_srv         TYPE STANDARD TABLE OF lty_pfcg,
    lit_agr1251         TYPE STANDARD TABLE OF lty_pfcg.

  CLEAR: et_risk_summary, et_risk_detail.

  " Get Tcodes asscociated for the role
  SELECT agr_name, object, auth, field, low, high
    FROM agr_1251
    WHERE agr_name  EQ @iv_role
      AND deleted   EQ @space
  INTO TABLE @DATA(lit_agrt).
  IF sy-subrc IS NOT INITIAL.
    lv_tcode_rc = sy-subrc.
  ENDIF.

  IF lit_agrt IS NOT INITIAL.
    lit_agrtcode = VALUE #( FOR ls_pfcg IN lit_agrt WHERE ( object = 'S_TCODE' AND field = 'TCD' )
    (
      low = ls_pfcg-low
      high = ls_pfcg-high
     ) ).

    lit_agr_srv = VALUE #( FOR ls_pfcg IN lit_agrt WHERE ( object = 'S_SERVICE' AND field = 'SRV_NAME' )
   (
      low = ls_pfcg-low
    ) ).

    lit_agr1251 =  VALUE #( FOR ls_pfcg IN lit_agrt WHERE ( object <> 'S_SERVICE' AND field <> 'SRV_NAME' )
    ( agr_name = ls_pfcg-agr_name
      object = ls_pfcg-object
      auth = ls_pfcg-auth
      field = ls_pfcg-field
      low = ls_pfcg-low
      high = ls_pfcg-high ) ).

  ENDIF.
  CLEAR lit_agrt.

  " The role should contain either Tcode or Service
  CHECK lit_agrtcode IS NOT INITIAL OR lit_agr_srv IS NOT INITIAL.

  IF lit_agr_srv IS NOT INITIAL.
    lr_pfcg_serv = VALUE #( FOR ls_pfcg_serv IN lit_agr_srv ( sign = 'I' option = 'CP' low = ls_pfcg_serv-low ) ).
    SORT lr_pfcg_serv BY low.
    DELETE ADJACENT DUPLICATES FROM lr_pfcg_serv COMPARING low.
    DELETE lr_pfcg_serv WHERE low IS INITIAL.
  ENDIF.
  CLEAR lit_agr_srv.

  IF lr_pfcg_serv IS NOT INITIAL.
    SELECT name, type, obj_name
      FROM usobhash
      WHERE name IN @lr_pfcg_serv
        AND type = 'HT'
    ORDER BY obj_name
    INTO TABLE @lit_srv_lib_fval.

    DELETE lit_srv_lib_fval WHERE obj_name IS INITIAL.

    SELECT DISTINCT tcode
      FROM zacg_risk_lib
      WHERE tcode LIKE '[SVC]%'
        AND inact = @space
    INTO TABLE @lit_lib_serv.

    LOOP AT lit_srv_lib_fval INTO DATA(lwa_srv_lib_fval).
      DATA(lv_obj_name) = lwa_srv_lib_fval-obj_name.
      LOOP AT lit_lib_serv INTO DATA(lwa_lib_serv).
        DATA(lv_srv_tcode) = lwa_lib_serv-tcode.
        SHIFT lv_srv_tcode LEFT BY 5 PLACES.
        lv_srv_tcode = |{ lv_srv_tcode }| & |*|.
        IF lv_obj_name CP lv_srv_tcode.
          APPEND INITIAL LINE TO lr_lib_srvc ASSIGNING FIELD-SYMBOL(<lfs_lib_srvc>).
          <lfs_lib_srvc>-sign   = 'I'.
          <lfs_lib_srvc>-option = 'EQ'.
          <lfs_lib_srvc>-low    = lwa_lib_serv-tcode.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    SORT lr_lib_srvc BY low.
    DELETE ADJACENT DUPLICATES FROM lr_lib_srvc COMPARING low.
    DELETE lr_lib_srvc WHERE low IS INITIAL.
  ENDIF.
  CLEAR: lit_srv_lib_fval, lit_lib_serv.


  " Get all Risk Library data
  SELECT *
    FROM zacg_risk_lib
    WHERE inact = @space
    INTO TABLE @DATA(lit_risk_lib).
  IF sy-subrc IS INITIAL.
    lr_lib_tcode  = VALUE #( FOR lwa_risk_lib IN lit_risk_lib ( sign = 'I' option = 'EQ' low = lwa_risk_lib-tcode ) ).
    SORT lr_lib_tcode BY low.
    DELETE ADJACENT DUPLICATES FROM lr_lib_tcode COMPARING low.
    DELETE lr_lib_tcode WHERE low IS INITIAL.
  ENDIF.

  " Fill with possible values where range or * given in TCode in PFCG
  LOOP AT lit_agrtcode INTO DATA(lwa_agrtcode).

    CLEAR lr_tcode.

    IF lwa_agrtcode-high IS INITIAL AND lwa_agrtcode-low NA '*'. " Only Low with exact value
      READ TABLE lr_lib_tcode TRANSPORTING NO FIELDS WITH KEY low = lwa_agrtcode-low BINARY SEARCH.
      IF sy-subrc IS INITIAL.
        APPEND INITIAL LINE TO lit_pfcg_tcd ASSIGNING FIELD-SYMBOL(<lfs_pfcg>).
        <lfs_pfcg> = lwa_agrtcode.
        CONTINUE.
      ENDIF.
    ENDIF.

    IF lwa_agrtcode-high IS NOT INITIAL.
      lr_tcode = VALUE #( ( sign = 'I' option = 'BT' low = lwa_agrtcode-low high = lwa_agrtcode-high ) ).
    ELSEIF lwa_agrtcode-low CA '*'.
      lr_tcode = VALUE #( ( sign = 'I' option = 'CP' low = lwa_agrtcode-low ) ).
    ENDIF.

    IF lr_tcode IS NOT INITIAL.
      SELECT DISTINCT tcode
      FROM @lit_risk_lib AS tcode_lib
      WHERE tcode IN @lr_tcode
      INTO TABLE @DATA(lit_tcode_lib).
      IF sy-subrc IS INITIAL.
        lit_pfcg_tmp = VALUE #( FOR lwa_tcode_lib IN lit_tcode_lib (
                       low      = lwa_tcode_lib-tcode
                       ) ).
        APPEND LINES OF lit_pfcg_tmp TO lit_pfcg_tcd.
        CLEAR lit_pfcg_tmp.
      ENDIF.
    ENDIF.

  ENDLOOP.
  CLEAR lit_agrtcode.
  IF lit_pfcg_tcd IS NOT INITIAL.
    lr_tcode  = VALUE #( FOR ls_tcode IN lit_pfcg_tcd ( sign = 'I' option = 'EQ' low = ls_tcode-low ) ).
    CLEAR lit_pfcg_tcd.
    SORT lr_tcode BY low.
    DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
    DELETE lr_tcode WHERE low IS INITIAL.
  ENDIF.


  " Get all Risk Library data
  IF lr_tcode IS NOT INITIAL.
    SELECT *
      FROM @lit_risk_lib AS risk_tcode
      WHERE tcode IN @lr_tcode
      INTO TABLE @DATA(lit_risk_lib_tcode).
  ENDIF.

  IF lr_lib_srvc IS NOT INITIAL.
    SELECT *
      FROM @lit_risk_lib AS risk_serv
      WHERE tcode IN @lr_lib_srvc
     APPENDING TABLE @lit_risk_lib_tcode.
  ENDIF.

  lit_risk_lib = lit_risk_lib_tcode.
  CLEAR lit_risk_lib_tcode.

  " Get details of exact field values for KOART
  READ TABLE lit_agr1251 TRANSPORTING NO FIELDS WITH KEY low = '$KOART'.
  IF sy-subrc IS INITIAL.

    " Get Actual values maintained for KOART
    SELECT agr_name,
           low,
           high
    FROM agr_1252
    WHERE agr_name EQ @iv_role
    AND varbl EQ '$KOART'
    ORDER BY agr_name
    INTO TABLE @DATA(lit_agr1252).
    IF sy-subrc IS INITIAL.
      lit_pfcg_tmp = lit_agr1251.
      DELETE lit_pfcg_tmp WHERE low NE '$KOART'.
      SORT lit_agr1252 BY agr_name.
      LOOP AT lit_pfcg_tmp INTO DATA(lwa_pfcg_tmp).
        LOOP AT lit_agr1252 INTO DATA(lwa_agr1252) WHERE agr_name = lwa_pfcg_tmp-agr_name.
          lwa_pfcg_tmp-low  = lwa_agr1252-low.
          lwa_pfcg_tmp-high = lwa_agr1252-high.
          APPEND lwa_pfcg_tmp TO lit_agr1251.
        ENDLOOP.
      ENDLOOP.
      CLEAR lit_pfcg_tmp.
      DELETE lit_agr1251 WHERE low EQ '$KOART'.
    ENDIF.
  ENDIF.

  " Get all possible values
  SELECT object, field, low
    FROM zacg_obj_fval
  INTO TABLE @DATA(lit_obj_fval).

  lr_object_lib = VALUE #( FOR lwa_risk_lib IN lit_risk_lib ( sign = 'I' option = 'EQ' low = lwa_risk_lib-object ) ).
  SORT lr_object_lib BY low.
  DELETE ADJACENT DUPLICATES FROM lr_object_lib COMPARING low.
  DELETE lr_object_lib WHERE low IS INITIAL.

  IF lr_object_lib IS NOT INITIAL.
    " Add posible values for ACTVT field
    SELECT brobj AS object,
           'ACTVT' AS field,
           actvt AS per_val
      FROM tactz
      APPENDING TABLE @lit_obj_fval
      WHERE brobj IN @lr_object_lib.
  ENDIF.

  " Replace wild card values of values with range
  LOOP AT lit_agr1251 INTO DATA(lwa_agr1251).

    CLEAR lr_fval.

    IF lwa_agr1251-high IS NOT INITIAL.
      lr_fval = VALUE #( ( sign = 'I' option = 'BT' low = lwa_agr1251-low high = lwa_agr1251-high ) ).
    ELSEIF lwa_agr1251-low CA '*'.
      lr_fval = VALUE #( ( sign = 'I' option = 'CP' low = lwa_agr1251-low ) ).
    ENDIF.

    IF lr_fval IS NOT INITIAL.

      SELECT *
        FROM @lit_obj_fval AS premisible_value
      WHERE object    = @lwa_agr1251-object
            AND field = @lwa_agr1251-field
            AND low   IN @lr_fval
      INTO TABLE @DATA(lit_values).
      IF sy-subrc IS INITIAL.
        lit_pfcg_tmp = VALUE #( FOR lwa_values IN lit_values (
                            agr_name = lwa_agr1251-agr_name
                            object   = lwa_agr1251-object
                            auth     = lwa_agr1251-auth
                            field    = lwa_agr1251-field
                            low      = lwa_values-low ) ).

      ENDIF.
      APPEND LINES OF lit_pfcg_tmp TO lit_pfcg.
      CLEAR lit_pfcg_tmp.
    ELSE.
      IF lwa_agr1251-low(1) NE '$'.
        APPEND lwa_agr1251 TO lit_pfcg.
      ENDIF.

    ENDIF.

  ENDLOOP.
  lit_agr1251 = lit_pfcg.
  CLEAR: lit_pfcg, lit_obj_fval.

  APPEND LINES OF lr_lib_srvc TO lr_tcode.

  IF lr_tcode IS NOT INITIAL.
    SELECT pfcg~agr_name,
           pfcg~object,
           pfcg~auth,
           pfcg~field,
           pfcg~low,
           pfcg~high,
           lib~func,
           lib~tcode,
           lib~object,
           lib~field,
           lib~low,
           lib~high
      FROM @lit_agr1251 AS pfcg
      INNER JOIN zacg_risk_lib AS lib
      ON pfcg~object EQ lib~object
      AND pfcg~field EQ lib~field
      AND pfcg~low EQ lib~low
     WHERE lib~tcode IN @lr_tcode
      AND lib~inact = @space
     ORDER BY lib~func, lib~tcode, lib~object
     INTO TABLE @lit_join.
  ENDIF.
  CLEAR lit_agr1251.

  lr_tcode = VALUE #( FOR ls_join IN lit_join ( sign = 'I' option = 'EQ' low = ls_join-lib_tcode ) ).
  SORT lr_tcode BY low.
  DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
  DELETE lr_tcode WHERE low IS INITIAL.

  lr_func = VALUE #( FOR ls_func IN lit_join ( sign = 'I' option = 'EQ' low = ls_func-lib_func ) ).
  SORT lr_func BY low.
  DELETE ADJACENT DUPLICATES FROM lr_func COMPARING low.
  DELETE lr_func WHERE low IS INITIAL.


  IF lr_func IS NOT INITIAL AND lr_tcode IS NOT INITIAL.
    SELECT *
      FROM @lit_risk_lib AS risl_lib
      WHERE func  IN @lr_func
        AND tcode IN @lr_tcode
        AND inact EQ @space
     INTO TABLE @lit_risk_lib.
  ENDIF.

  LOOP AT lr_func INTO DATA(lwa_func). " Check for each function id

    CLEAR: lv_actvt_not_found.

    SELECT *
      FROM @lit_risk_lib AS lib_func_tcode
      WHERE func  EQ @lwa_func-low
    INTO TABLE @DATA(lit_lib_func).
    IF sy-subrc IS INITIAL.

      lr_tcode = VALUE #( FOR ls_lib_func IN lit_lib_func ( sign = 'I' option = 'EQ' low = ls_lib_func-tcode ) ).
      SORT lr_tcode BY low.
      DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
      DELETE lr_tcode WHERE low IS INITIAL.

      LOOP AT lr_tcode INTO DATA(lwa_tcode). " Check for each tcode within function

        SELECT *
          FROM @lit_lib_func AS lib_func_tcode
          WHERE tcode EQ @lwa_tcode-low
        INTO TABLE @DATA(lit_lib_func_tcode).
        IF sy-subrc IS INITIAL.

          lr_lib_obj = VALUE #( FOR ls_lib_obj IN lit_lib_func_tcode ( sign = 'I' option = 'EQ' low = ls_lib_obj-object ) ).
          SORT lr_lib_obj BY low.
          DELETE ADJACENT DUPLICATES FROM lr_lib_obj COMPARING low .
          DELETE lr_lib_obj WHERE low IS INITIAL.

          LOOP AT lr_lib_obj INTO DATA(lwa_lib_obj). " For each Object within the tcode

            SELECT *
              FROM @lit_join AS pfcg_func_tcode_obj
              WHERE lib_func   = @lwa_func-low
                AND lib_tcode  = @lwa_tcode-low
                AND lib_object = @lwa_lib_obj-low
             INTO TABLE @DATA(lit_pfcg_func_tcode_obj).
            IF sy-subrc IS INITIAL.

              lr_instance = VALUE #( FOR ls_pfcg_func_tcode_obj IN lit_pfcg_func_tcode_obj ( sign = 'I' option = 'EQ' low = ls_pfcg_func_tcode_obj-pfcg_auth ) ).
              SORT lr_instance BY low.
              DELETE ADJACENT DUPLICATES FROM lr_instance COMPARING low.
              DELETE lr_instance WHERE low IS INITIAL.

              LOOP AT lr_instance INTO DATA(lwa_instance). " For each Instance of the object

                CLEAR lv_actvt_not_found.

                SELECT *
                  FROM @lit_pfcg_func_tcode_obj AS pfcg_func_tcode_obj_ins
                  WHERE pfcg_auth = @lwa_instance-low
                INTO TABLE @DATA(lit_pfcg_func_tcode_obj_ins).
                IF sy-subrc IS INITIAL.

                  SELECT *
                    FROM @lit_lib_func_tcode AS lib_field
                    WHERE object = @lwa_lib_obj-low
                  INTO TABLE @DATA(lit_lib_func_tcode_obj).
                  IF sy-subrc IS INITIAL.

                    lr_field = VALUE #( FOR ls_lib_func_tcode_obj IN lit_lib_func_tcode_obj ( sign = 'I' option = 'EQ' low = ls_lib_func_tcode_obj-field ) ).
                    SORT lr_field BY low.
                    DELETE ADJACENT DUPLICATES FROM lr_field COMPARING low.
                    DELETE lr_field WHERE low IS INITIAL.

                    LOOP AT lr_field INTO DATA(lwa_field).
                      READ TABLE lit_pfcg_func_tcode_obj_ins INTO DATA(lwa_pfcg_func_tcode_obj_ins)
                      WITH KEY lib_field = lwa_field-low.
                      IF sy-subrc IS NOT INITIAL.
                        lv_actvt_not_found = abap_true.
                      ENDIF.
                    ENDLOOP.

                    IF lv_actvt_not_found EQ abap_false.
                      " Take the set for consideration.
                      APPEND LINES OF lit_pfcg_func_tcode_obj_ins TO lit_potential_obj.
                    ENDIF.


                  ENDIF.

                ENDIF.

              ENDLOOP. " end of instance

            ELSE.

              " Delete all combination of func + tcode
              DELETE lit_join WHERE lib_func = lwa_func-low AND lib_tcode  = lwa_tcode-low.

            ENDIF.

          ENDLOOP. " end of each object

          CLEAR lv_object_not_found.
          LOOP AT lr_lib_obj INTO lwa_lib_obj.

            READ TABLE lit_potential_obj TRANSPORTING NO FIELDS WITH KEY lib_object = lwa_lib_obj-low.
            IF sy-subrc IS NOT INITIAL.
              lv_object_not_found = abap_true.
              EXIT.
            ENDIF.

          ENDLOOP.

          IF lv_object_not_found = abap_false.
            APPEND LINES OF lit_potential_obj TO lit_potential_tcd.
          ENDIF.

        ELSE. " Tcode for that function should be excluded

        ENDIF.

        CLEAR lit_potential_obj.

      ENDLOOP. " end of each tcode check

    ELSE. " The func should be excluded

    ENDIF.

  ENDLOOP. " end of each function check

  lr_func = VALUE #( FOR ls_potential_tcd IN lit_potential_tcd ( sign = 'I' option = 'EQ' low = ls_potential_tcd-lib_func ) ).
  SORT lr_func BY low.
  DELETE ADJACENT DUPLICATES FROM lr_func COMPARING low.
  DELETE lr_func WHERE low IS INITIAL.

  CHECK lr_func IS NOT INITIAL.

  " Get all Risk associated with identified functiona
  SELECT *
    FROM zacg_risk_comb
    WHERE func IN @lr_func
  INTO TABLE @DATA(lit_risk).
  IF sy-subrc IS INITIAL.
    lr_risk = VALUE #( FOR ls_risk IN lit_risk ( sign = 'I' option = 'EQ' low = ls_risk-risk ) ).
    SORT lr_risk BY low.
    DELETE ADJACENT DUPLICATES FROM lr_risk COMPARING low.
    DELETE lr_risk WHERE low IS INITIAL.

  ENDIF.

  CHECK lr_risk IS NOT INITIAL.
  " Get the complete combination of the Risk
  SELECT *
    FROM zacg_risk_comb
    WHERE risk IN @lr_risk
  ORDER BY risk
  INTO TABLE @lit_risk.
  IF sy-subrc IS INITIAL.

    " Get unique Risk IDs
    DATA(lit_risk_sod) = lit_risk.

    " Sepated Critical Authorization Risk
    DATA(lit_risk_crit) = lit_risk.
    DELETE lit_risk_crit WHERE crit EQ abap_false.

    " Sepated Combination Risks
    DELETE lit_risk_sod WHERE crit EQ abap_true.
    lr_risk = VALUE #( FOR ls_risk IN lit_risk_sod ( sign = 'I' option = 'EQ' low = ls_risk-risk ) ).
    SORT lr_risk BY low.
    DELETE ADJACENT DUPLICATES FROM lr_risk COMPARING low.
    DELETE lr_risk WHERE low IS INITIAL.


  ENDIF.

  " Check for Combination Risk
  LOOP AT lr_risk INTO DATA(lwa_unique_risk).

    " Get function ids for speacific Risk
    SELECT *
      FROM @lit_risk_sod AS sod_check
      WHERE risk = @lwa_unique_risk-low
    INTO TABLE @DATA(lit_risk_combo).
    IF sy-subrc IS INITIAL.

      lr_risk_func = VALUE #( FOR ls_risk_combo IN lit_risk_combo ( sign = 'I' option = 'EQ' low = ls_risk_combo-func ) ).
      SORT lr_risk_func BY low.
      DELETE ADJACENT DUPLICATES FROM lr_risk_func COMPARING low.
      DELETE lr_risk_func WHERE low IS INITIAL.

      CLEAR lv_func_not_found.

      LOOP AT lr_risk_func INTO DATA(lwa_risk_func).

        READ TABLE lit_potential_tcd TRANSPORTING NO FIELDS WITH KEY lib_func = lwa_risk_func-low.
        IF sy-subrc IS NOT INITIAL.
          lv_func_not_found = abap_true.
        ENDIF.

      ENDLOOP.

      IF lv_func_not_found = abap_false.
        SELECT *
          FROM @lit_potential_tcd AS potential_tcd
          WHERE lib_func IN @lr_risk_func
        INTO TABLE @DATA(lit_risk_func).
        LOOP AT lit_risk_func ASSIGNING FIELD-SYMBOL(<lfs_risk_func>).
          <lfs_risk_func>-risk = lwa_unique_risk-low.
          APPEND <lfs_risk_func> TO lit_potential_risk.
        ENDLOOP.
      ENDIF.

    ENDIF.

  ENDLOOP.

  " Check for Critical Risk
  LOOP AT lit_risk_crit INTO DATA(lwa_risk_crit).
    LOOP AT lit_potential_tcd ASSIGNING FIELD-SYMBOL(<lfs_potential_tcd>) WHERE lib_func = lwa_risk_crit-func.
      <lfs_potential_tcd>-risk = lwa_risk_crit-risk.
      <lfs_potential_tcd>-crit = abap_true.
      APPEND <lfs_potential_tcd> TO lit_potential_risk.
    ENDLOOP.
  ENDLOOP.


  SORT lit_potential_risk.
  DELETE ADJACENT DUPLICATES FROM lit_potential_risk COMPARING ALL FIELDS.

  lr_risk = VALUE #( FOR ls_potential_risk IN lit_potential_risk ( sign = 'I' option = 'EQ' low = ls_potential_risk-risk ) ).
  SORT lr_risk BY low.
  DELETE ADJACENT DUPLICATES FROM lr_risk COMPARING low.
  DELETE lr_risk WHERE low IS INITIAL.
  IF lr_risk IS NOT INITIAL.
    SELECT *
      FROM zacg_risk_mstr
      WHERE risk IN @lr_risk
        AND rlevel IN @it_level
        AND rmodule IN @it_module
    ORDER BY risk
    INTO TABLE @DATA(lit_risk_mstr).

    SELECT *
    FROM dd07t
    INTO TABLE @DATA(lit_dd07t)
    WHERE domname IN ('ZRISK_LEVEL', 'ZRISK_PROC')
    ORDER BY domname, domvalue_l.

  ENDIF.

  SORT lit_potential_risk BY risk.

  IF iv_summary IS NOT INITIAL.
    LOOP AT lr_risk INTO DATA(lwa_risk).

      READ TABLE lit_potential_risk INTO DATA(lwa_potential_risk) WITH KEY risk = lwa_risk-low BINARY SEARCH.
      IF sy-subrc IS INITIAL.

        READ TABLE lit_risk_mstr INTO DATA(lwa_risk_mstr) WITH KEY risk = lwa_risk-low BINARY SEARCH.
        IF sy-subrc IS INITIAL.

          APPEND INITIAL LINE TO et_risk_summary ASSIGNING FIELD-SYMBOL(<lfs_risk_summary>).

          <lfs_risk_summary>-agr_name = iv_role.
          <lfs_risk_summary>-risk = lwa_risk-low.
          <lfs_risk_summary>-type = lwa_potential_risk-crit.

          <lfs_risk_summary>-riskd = lwa_risk_mstr-riskd.

          <lfs_risk_summary>-level = lwa_risk_mstr-rlevel.
          READ TABLE lit_dd07t INTO DATA(lwa_dd07t) WITH KEY domname = 'ZRISK_LEVEL'
                                                             domvalue_l = <lfs_risk_summary>-level BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            <lfs_risk_summary>-leveld = lwa_dd07t-ddtext.
          ENDIF.

          <lfs_risk_summary>-module = lwa_risk_mstr-rmodule.
          READ TABLE lit_dd07t INTO lwa_dd07t WITH KEY domname = 'ZRISK_PROC'
                                                       domvalue_l = <lfs_risk_summary>-module BINARY SEARCH.
          IF sy-subrc IS INITIAL.
            <lfs_risk_summary>-moduled = lwa_dd07t-ddtext.
          ENDIF.

          IF <lfs_risk_summary>-type IS NOT INITIAL.
            <lfs_risk_summary>-typed = 'Critical Authorization'.
          ELSE.
            <lfs_risk_summary>-typed = 'Critical Combination'.
          ENDIF.

        ENDIF.

      ENDIF.
    ENDLOOP.
  ENDIF.

  SORT et_risk_summary  BY risk.

  IF lit_potential_risk IS NOT INITIAL AND iv_detail IS NOT INITIAL.

    SELECT *
      FROM zacg_funct
      WHERE func IN @lr_func
    ORDER BY func
    INTO TABLE @DATA(li_funct).

    LOOP AT lit_potential_risk INTO lwa_potential_risk.

      READ TABLE et_risk_summary TRANSPORTING NO FIELDS WITH KEY risk = lwa_potential_risk-risk BINARY SEARCH.

      CHECK sy-subrc IS INITIAL.

      APPEND INITIAL LINE TO et_risk_detail ASSIGNING FIELD-SYMBOL(<lfs_risk_detail>).
      <lfs_risk_detail>-agr_name  = iv_role.
      <lfs_risk_detail>-risk      = lwa_potential_risk-risk.
      READ TABLE lit_risk_mstr INTO lwa_risk_mstr WITH KEY risk = lwa_potential_risk-risk BINARY SEARCH.
      IF sy-subrc IS INITIAL.
        <lfs_risk_detail>-riskd     = lwa_risk_mstr-riskd.
      ENDIF.
      <lfs_risk_detail>-func      = lwa_potential_risk-lib_func.
      READ TABLE li_funct INTO DATA(lwa_funct) WITH KEY func = lwa_potential_risk-lib_func BINARY SEARCH.
      IF sy-subrc IS INITIAL.
        <lfs_risk_detail>-funcd   = lwa_funct-funcd.
      ENDIF.
      <lfs_risk_detail>-tcode     = lwa_potential_risk-lib_tcode.
      <lfs_risk_detail>-object    = lwa_potential_risk-lib_object.
      <lfs_risk_detail>-field     = lwa_potential_risk-lib_field.
      <lfs_risk_detail>-low       = lwa_potential_risk-lib_low.

    ENDLOOP.

  ENDIF.


*  IF lit_potential_risk IS NOT INITIAL AND iv_detail IS NOT INITIAL.
*
*    SELECT *
*      FROM zacg_funct
*      WHERE func IN @lr_func
*    ORDER BY func
*    INTO TABLE @DATA(li_funct).
*
*    SELECT agr_name, object, auth, field, low, high
*          FROM agr_1251
*          FOR ALL ENTRIES IN @lit_potential_risk
*          WHERE agr_name  EQ @lit_potential_risk-pfcg_agr_name
*            AND object    EQ @lit_potential_risk-pfcg_object
*            AND auth      EQ @lit_potential_risk-pfcg_auth
*            AND field     EQ @lit_potential_risk-pfcg_field
*            AND deleted   EQ @space
*    INTO TABLE @DATA(lit_agr1251_detail).
*
*    SELECT object, auth, field, low, high
*      FROM agr_1251
*      WHERE agr_name = @iv_role
*      AND object IN ('S_TCODE', 'S_SERVICE')
*      AND deleted   EQ @space
*        INTO TABLE @DATA(lit_agr1251_tcode_service).
*    IF sy-subrc IS INITIAL.
*      SORT lit_agr1251_tcode_service BY object auth field low high.
*      DELETE ADJACENT DUPLICATES FROM lit_agr1251_tcode_service COMPARING ALL FIELDS.
*    ENDIF.
*
*    SORT lit_potential_risk BY pfcg_agr_name pfcg_object pfcg_auth pfcg_field.
*
*    LOOP AT lit_agr1251_detail INTO DATA(lwa_agr1251_detail).
*      READ TABLE lit_potential_risk ASSIGNING FIELD-SYMBOL(<lfs_risk>) WITH KEY
*                                                               pfcg_agr_name = lwa_agr1251_detail-agr_name
*                                                               pfcg_object   = lwa_agr1251_detail-object
*                                                               pfcg_auth     = lwa_agr1251_detail-auth
*                                                               pfcg_field    = lwa_agr1251_detail-field BINARY SEARCH.
*      IF sy-subrc EQ 0.
*        DATA(lv_tabix) =  sy-tabix.
*
*        LOOP AT lit_potential_risk INTO lwa_potential_risk FROM lv_tabix.
*          IF  lwa_potential_risk-pfcg_agr_name <> lwa_agr1251_detail-agr_name OR
*              lwa_potential_risk-pfcg_object   <> lwa_agr1251_detail-object OR
*              lwa_potential_risk-pfcg_auth     <> lwa_agr1251_detail-auth OR
*              lwa_potential_risk-pfcg_field    <> lwa_agr1251_detail-field.
*            EXIT.
*          ENDIF.
*
*          IF lwa_agr1251_detail-high IS NOT INITIAL.
*            lr_low  = VALUE #( ( sign = 'I' option = 'BT' low = lwa_agr1251_detail-low high = lwa_agr1251_detail-high ) ).
*          ELSEIF lwa_agr1251_detail-low CA '*'.
*            lr_low = VALUE #( ( sign = 'I' option = 'CP' low = lwa_agr1251_detail-low ) ).
*          ELSE.
*            lr_low = VALUE #( ( sign = 'I' option = 'EQ' low = lwa_agr1251_detail-low ) ).
*          ENDIF.
*
*          CHECK lwa_potential_risk-lib_low IN lr_low AND lr_low IS NOT INITIAL.
*
*          READ TABLE et_risk_summary TRANSPORTING NO FIELDS WITH KEY risk = lwa_potential_risk-risk BINARY SEARCH.
*
*          CHECK sy-subrc IS INITIAL.
*
*          APPEND INITIAL LINE TO et_risk_detail ASSIGNING FIELD-SYMBOL(<lfs_risk_detail>).
*          <lfs_risk_detail>-agr_name  = lwa_agr1251_detail-agr_name.
*          <lfs_risk_detail>-risk      = lwa_potential_risk-risk.
*          READ TABLE lit_risk_mstr INTO lwa_risk_mstr WITH KEY risk = lwa_potential_risk-risk BINARY SEARCH.
*          IF sy-subrc IS INITIAL.
*            <lfs_risk_detail>-riskd     = lwa_risk_mstr-riskd.
*          ENDIF.
*          <lfs_risk_detail>-func      = lwa_potential_risk-lib_func.
*          READ TABLE li_funct INTO DATA(lwa_funct) WITH KEY func = lwa_potential_risk-lib_func BINARY SEARCH.
*          IF sy-subrc IS INITIAL.
*            <lfs_risk_detail>-funcd   = lwa_funct-funcd.
*          ENDIF.
*          <lfs_risk_detail>-tcode     = lwa_potential_risk-lib_tcode.
*          <lfs_risk_detail>-object    = lwa_agr1251_detail-object.
*          <lfs_risk_detail>-auth      = lwa_agr1251_detail-auth.
*          <lfs_risk_detail>-field     = lwa_agr1251_detail-field.
*          <lfs_risk_detail>-low       = lwa_agr1251_detail-low.
*          <lfs_risk_detail>-high      = lwa_agr1251_detail-high.
*
*          APPEND INITIAL LINE TO lit_tcode_func ASSIGNING FIELD-SYMBOL(<lfs_tcode_func>).
*          <lfs_tcode_func>-agr_name = <lfs_risk_detail>-agr_name.
*          <lfs_tcode_func>-risk     = <lfs_risk_detail>-risk.
*          <lfs_tcode_func>-riskd    = <lfs_risk_detail>-riskd.
*          <lfs_tcode_func>-func     = <lfs_risk_detail>-func.
*          <lfs_tcode_func>-funcd    = <lfs_risk_detail>-funcd.
*          <lfs_tcode_func>-tcode    = <lfs_risk_detail>-tcode.
*          <lfs_tcode_func>-auth     = <lfs_risk_detail>-auth.
*
*        ENDLOOP.
*      ENDIF.
*    ENDLOOP.
*
*  ENDIF.
*
*  SORT et_risk_summary  BY risk.
*  SORT et_risk_detail   BY risk func tcode object field low high.
*  DELETE ADJACENT DUPLICATES FROM et_risk_detail COMPARING risk func tcode object field low high.
*  IF et_risk_detail IS NOT INITIAL.
*    SORT lit_tcode_func BY agr_name risk func tcode auth.
*    DELETE ADJACENT DUPLICATES FROM lit_tcode_func COMPARING agr_name risk func tcode auth.
*    LOOP AT lit_tcode_func INTO DATA(lwa_tcode_func).
*
*      IF lwa_tcode_func-tcode(1) EQ '['.
*        READ TABLE lit_agr1251_tcode_service INTO DATA(lwa_agr1251_tcode_service) WITH KEY object = 'S_SERVICE'.
*      ELSE.
*        READ TABLE lit_agr1251_tcode_service INTO lwa_agr1251_tcode_service WITH KEY object = 'S_TCODE'
*                                                                             low    = lwa_tcode_func-tcode.
*        DATA(lv_proceed) = abap_true.
*      ENDIF.
*
*
*      IF lv_proceed = abap_true.
*
*        APPEND INITIAL LINE TO et_risk_detail ASSIGNING <lfs_risk_detail>.
*        <lfs_risk_detail>-agr_name  = lwa_tcode_func-agr_name.
*        <lfs_risk_detail>-risk      = lwa_tcode_func-risk.
*        <lfs_risk_detail>-riskd     = lwa_tcode_func-riskd.
*        <lfs_risk_detail>-func      = lwa_tcode_func-func.
*        <lfs_risk_detail>-funcd     = lwa_tcode_func-funcd.
*        <lfs_risk_detail>-tcode     = lwa_tcode_func-tcode.
*        <lfs_risk_detail>-auth      = lwa_agr1251_tcode_service-auth.
*        IF lwa_tcode_func-tcode(1) EQ '['.
*          <lfs_risk_detail>-object    = 'S_SERVICE'.
*          <lfs_risk_detail>-field     = 'SRV_NAME'.
*        ELSE.
*          <lfs_risk_detail>-object    = 'S_TCODE'.
*          <lfs_risk_detail>-field     = 'TCD'.
*        ENDIF.
*        <lfs_risk_detail>-low       = lwa_tcode_func-tcode.
*
*      ENDIF.
*
*      CLEAR lv_proceed.
*
*    ENDLOOP.
*  ENDIF.

  SORT et_risk_detail   BY risk func tcode object field low.
  DELETE ADJACENT DUPLICATES FROM et_risk_detail COMPARING risk func tcode object field low.


ENDFUNCTION.
