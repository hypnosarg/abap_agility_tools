CLASS lcl_selscreen_utils DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS: check_mandatory_field IMPORTING iv_valuef TYPE clike iv_focusf TYPE clike OPTIONAL,
      reset_sel_screen,
      set_focus.
    CLASS-DATA: gv_focus(10).
ENDCLASS.

CLASS lcl_selscreen_utils IMPLEMENTATION.
  METHOD check_mandatory_field.
    CHECK sy-ucomm = 'ONLI'.
    ASSIGN (iv_valuef) TO FIELD-SYMBOL(<lv_value>).
    IF <lv_value> IS ASSIGNED  AND <lv_value> IS INITIAL.
      IF iv_focusf IS SUPPLIED.
        gv_focus = iv_focusf.
      ELSE.
        gv_focus = iv_valuef.
      ENDIF.
      IF sy-batch = abap_false.
        MESSAGE s055(00) DISPLAY LIKE 'E'.
        reset_sel_screen( ).
      ELSE.
        "In bach show full error so that the process does not lock up
        MESSAGE e055(00).
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD reset_sel_screen.
    LEAVE TO SCREEN sy-dynnr..
  ENDMETHOD.
  METHOD set_focus.
    CHECK gv_focus IS NOT INITIAL.
    SET CURSOR FIELD gv_focus.
    CLEAR gv_focus.
  ENDMETHOD.
ENDCLASS.

*USAGE EXAMPLE
*AT SELECTION-SCREEN OUTPUT.
*  LOOP AT SCREEN.
*    IF screen-group1 = 'OON'.
*      "OUtput only
*      screen-input = 0.
*      "And only visible when getting from app server
*      screen-invisible = SWITCH i( p_aps WHEN 'X' THEN 0 ELSE 1 ).
*      MODIFY SCREEN.
*    ENDIF.
*  ENDLOOP.
*  IF p_aps = abap_on.
*    go_handler ?= NEW lcl_file_handler_srv( iv_lpath = gc_path_main ).
*    p_root = |{ go_handler->get_root_folder( ) }|.
*  ELSE.
*    go_handler ?= NEW lcl_file_handler_lcl( ).
*  ENDIF.
*  lcl_selscreen_utils=>set_focus( ).
*  go_handler->set_mask( go_handler->get_mask_for_extensions( VALUE string_table( ( gc_valid_ext ) ) ) ).
*
*AT SELECTION-SCREEN.
*  IF sy-ucomm = 'MODE'.
*    CLEAR p_path.
*  ENDIF.
*
*AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_path.
*  p_path =  go_handler->file_sh( p_root ) .
*
*AT SELECTION-SCREEN ON p_path.
*  IF p_prs = abap_on.
*    lcl_selscreen_utils=>check_mandatory_field( 'P_PATH' ).
*  ENDIF .
