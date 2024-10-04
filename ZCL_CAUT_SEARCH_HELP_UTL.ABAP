********************************************************************
*zcl_caut_search_help_utl: Provides tools to present search helps
******************************************************************** 
CLASS zcl_caut_search_help_utl DEFINITION
   PUBLIC
   FINAL
   CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS:
      show_key_desc_sh IMPORTING it_values      TYPE STANDARD TABLE
                                 iv_key_field   TYPE clike
                                 iv_descr_field TYPE clike
                       CHANGING  cv_out         TYPE any.
ENDCLASS.

CLASS lcl_search_help_util IMPLEMENTATION.
  METHOD show_key_desc_sh.
    "SHows a Key-Description search help and assigns the selected value
    "to the changing field
    DATA: lo_sh_values TYPE REF TO data ##NEEDED, "Dynamically accessed
          lt_ret       TYPE STANDARD TABLE OF ddshretval.
    FIELD-SYMBOLS: <lt_values> TYPE STANDARD TABLE,
                   <ls_type>   TYPE any.

    CHECK it_values IS NOT INITIAL.

    DATA(lt_fields) = VALUE lcl_data_creator=>gty_t_field_list(
      ( source_field = iv_key_field    target_field = 'KEY'  )
      ( source_field = iv_descr_field  target_field = 'TEXT' )    ).


    ASSIGN it_values[ 1 ] TO <ls_type>.
    lcl_data_creator=>create_subtype(
      EXPORTING
        is_source_str = <ls_type>
        it_field_list = lt_fields
        iv_table_type = abap_true
       RECEIVING
         ro_data       = lo_sh_values
    ).

    CHECK lo_sh_values IS BOUND.
    ASSIGN lo_sh_values->* TO <lt_values>.
    CHECK sy-subrc = 0.
    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<ls_in>).
      APPEND INITIAL LINE TO <lt_values> ASSIGNING FIELD-SYMBOL(<ls_value>).
      CHECK sy-subrc = 0.
      ASSIGN COMPONENT 'KEY' OF STRUCTURE <ls_value> TO FIELD-SYMBOL(<lv_target>).
      CHECK sy-subrc = 0.
      ASSIGN COMPONENT iv_key_field OF STRUCTURE <ls_in> TO FIELD-SYMBOL(<lv_source>).
      <lv_target> = <lv_source>.
      ASSIGN COMPONENT 'TEXT' OF STRUCTURE <ls_value> TO <lv_target>.
      CHECK sy-subrc = 0.
      ASSIGN COMPONENT iv_descr_field OF STRUCTURE <ls_in> TO <lv_source>.
      CHECK sy-subrc = 0.
      <lv_target> = <lv_source>.
    ENDLOOP.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'KEY'
        value_org       = 'S'
      TABLES
        value_tab       = <lt_values>
        return_tab      = lt_ret
      EXCEPTIONS
        parameter_error = 1
        no_values_found = 2
        OTHERS          = 3.
    IF sy-subrc = 0 AND lt_ret IS NOT INITIAL.
      cv_out = lt_ret[ 1 ]-fieldval.
    ENDIF.


  ENDMETHOD.
ENDCLASS.
