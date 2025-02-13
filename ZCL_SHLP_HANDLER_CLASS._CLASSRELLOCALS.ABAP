*"* use this source file for any type of declarations (class
*"* definitions, interfaces or type declarations) you need for
*"* components in the private section

CLASS lcl_f4_handler DEFINITION ABSTRACT.
  PUBLIC SECTION.
    METHODS:
      handle ABSTRACT
        IMPORTING
          iv_row        TYPE int4
          iv_display    TYPE flag
          iv_value      TYPE lvc_value
          id_field      TYPE REF TO ZCL_ACPF_SHLP_HANDLER=>gty_s_field_info
          io_event_data TYPE REF TO cl_alv_event_data.

  PROTECTED SECTION.
    METHODS:
      add_value_to_results
        IMPORTING
          iv_row        TYPE int4
          iv_value      TYPE any
          iv_fieldname  TYPE fieldname
          io_event_data TYPE REF TO cl_alv_event_data.
ENDCLASS.

CLASS lcl_f4_handler_date DEFINITION INHERITING FROM lcl_f4_handler.
  PUBLIC SECTION.
    METHODS:
      handle REDEFINITION.
ENDCLASS.

CLASS lcl_f4_handler_ref_table DEFINITION INHERITING FROM lcl_f4_handler.
  PUBLIC SECTION.
    METHODS:
      handle REDEFINITION.

  PROTECTED SECTION.
    METHODS:
      show_vh_for_field IMPORTING iv_table      TYPE clike
                                  iv_field      TYPE clike
                                  iv_row        TYPE int4
                                  iv_display    TYPE flag
                                  iv_value      TYPE lvc_value
                                  id_field      TYPE REF TO ZCL_ACPF_SHLP_HANDLER=>gty_s_field_info
                                  io_event_data TYPE REF TO cl_alv_event_data,
      show_value_help
        IMPORTING
          iv_row        TYPE int4
          iv_display    TYPE flag
          iv_value      TYPE lvc_value
          id_field      TYPE REF TO ZCL_ACPF_SHLP_HANDLER=>gty_s_field_info
          it_values     TYPE table
          io_event_data TYPE REF TO cl_alv_event_data.
ENDCLASS.

CLASS lcl_f4_handler_domain DEFINITION INHERITING FROM lcl_f4_handler_ref_table.
  PUBLIC SECTION.
    METHODS:
      handle REDEFINITION.
ENDCLASS.

CLASS lcl_f4_handler_time DEFINITION INHERITING FROM lcl_f4_handler.
  PUBLIC SECTION.
    METHODS:
      handle REDEFINITION.
ENDCLASS.

CLASS lcl_f4_handler_value_help DEFINITION INHERITING FROM lcl_f4_handler.
  PUBLIC SECTION.
    METHODS:
      handle REDEFINITION.
ENDCLASS.

CLASS lcl_f4_handler_valtab DEFINITION INHERITING FROM  lcl_f4_handler_ref_table.
  PUBLIC SECTION.
    METHODS:
      handle REDEFINITION.
ENDCLASS.
