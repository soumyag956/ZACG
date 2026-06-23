*&---------------------------------------------------------------------*
*& Report ZACG_ENCRIPT_PROG
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZACG_ENCRIPT_PROG.
TABLES: trdir.

SELECTION-SCREEN BEGIN OF BLOCK block.
SELECT-OPTIONS: s_prog FOR trdir-name OBLIGATORY NO INTERVALS.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(8) pwd.
SELECTION-SCREEN POSITION 35.
PARAMETERS: password(10) MODIF ID aaa.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK block.

DATA: message(120)       TYPE c,
      o_encryptor        TYPE REF TO cl_hard_wired_encryptor,
      o_cx_encrypt_error TYPE REF TO cx_encrypt_error,
      v_program            TYPE progname.
AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-group1 = 'AAA'.
      screen-invisible = '1'.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

INITIALIZATION.
  pwd = 'Password'.

START-OF-SELECTION.

  CREATE OBJECT o_encryptor.
  CREATE OBJECT o_cx_encrypt_error.

* User name and password check
  IF password <> 'P@SSW0RD1'.
    WRITE: / 'Wrong password'.
    EXIT.
  ENDIF.

* SAP owned?
*  IF NOT program CP 'Z*' AND NOT program CP 'Y*'.
*    WRITE: / 'Do not hide original SAP programs!'.
*    EXIT.
*  ENDIF.

* Exists?
*  SELECT SINGLE * FROM trdir WHERE name = program.
*  IF sy-subrc <> 0.
*    WRITE: / 'Program does not exists!'.
*    EXIT.
*  ENDIF.
  LOOP AT s_prog.
    v_program = s_prog-low.
* Does it have a current generated version?
    DATA: f1 TYPE d,
          f3 TYPE d.
    DATA: f2 TYPE t,
          f4 TYPE t.

    EXEC SQL.
      SELECT UDAT, UTIME, SDAT, STIME INTO :F1, :F2, :F3, :F4 FROM D010LINF
      WHERE PROG = :v_program
    ENDEXEC.

    IF f1 < f3 OR ( f1 = f3 AND f2 < f4 ).
      WRITE: / 'The program has no recent generated version!'.
      EXIT.
    ENDIF.

* Compose a new program name
    DATA: new_name(40),
          i            TYPE i,
          j            TYPE i,
          v_ac         TYPE string,
          v_en         TYPE string,
          v_error_msg  TYPE string.

    v_ac = v_program.

    TRY.
        CALL METHOD o_encryptor->encrypt_string2string
          EXPORTING
            the_string = v_ac
          RECEIVING
            result     = v_en.
      CATCH cx_encrypt_error INTO o_cx_encrypt_error.

        CALL METHOD o_cx_encrypt_error->if_message~get_text
          RECEIVING
            result = v_error_msg.
        MESSAGE v_error_msg TYPE 'E'.
    ENDTRY.

    CONCATENATE 'Z' v_en INTO new_name.
    TRANSLATE new_name TO UPPER CASE.

* Check if it is already hidden
    DATA: f5(30).
    EXEC SQL.
      SELECT PROG INTO :F5 FROM D010SINF WHERE PROG = :NEW_NAME
    ENDEXEC.

    IF f5 IS INITIAL.

* There is no such hidden program, hide it
      EXEC SQL.
        UPDATE D010SINF SET PROG = :NEW_NAME WHERE PROG = :v_program
      ENDEXEC.
      CONCATENATE 'Program' v_program 'was hidden into' new_name
      INTO message SEPARATED BY space.
    ELSE.

* There is already a hidden program there, unhide it
      EXEC SQL.
        UPDATE D010SINF SET PROG = :v_program WHERE PROG = :NEW_NAME
      ENDEXEC.

      CONCATENATE 'Program' v_program 'was restored.'
      INTO message SEPARATED BY space.

    ENDIF.

    WRITE:/ message.
    CLEAR new_name.
  ENDLOOP.
