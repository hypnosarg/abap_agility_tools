class ZCL_ACPF_SHLP_HANDLER definition
  public
  final
  create protected .

public section.

  types:
    BEGIN OF gty_s_field_info,
             field_name   TYPE fieldname,
             data_element TYPE  rollname,
             ref_table    TYPE 	reftable,
             ref_field    TYPE  reffield,
           END OF gty_s_field_info .

  methods ALV_F4
    importing
      !IV_FIELDNAME type LVC_FNAME
      !IV_FIELDVALUE type LVC_VALUE
      !IS_ROW_NO type LVC_S_ROID
      !IO_EVENT_DATA type ref to CL_ALV_EVENT_DATA
      !IT_BAD_CELLS type LVC_T_MODI
      !IV_DISPLAY type CHAR01
      !IS_FIELD_INFO type GTY_S_FIELD_INFO .
  methods DO_F4
    importing
      !IS_FIELD_INFO type GTY_S_FIELD_INFO
      !IV_FIELDVALUE type LVC_VALUE optional
      !IV_DISPLAY_ONLY type BOOLEAN default ABAP_FALSE
    returning
      value(RO_OUTPUT) type ref to LVC_T_MODI .
  class-methods GET_INSTANCE
    returning
      value(RO_INST) type ref to ZCL_ACPF_SHLP_HANDLER .
protected section.

  methods CONSTRUCTOR .
private section.

  types:
    gty_t_f4_handlers TYPE STANDARD TABLE OF REF TO lcl_f4_handler .

  data GT_F4_HANDLERS type GTY_T_F4_HANDLERS .
  class-data GO_SINGLETON type ref to ZCL_ACPF_SHLP_HANDLER .
ENDCLASS.



CLASS ZCL_ACPF_SHLP_HANDLER IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ACPF_SHLP_HANDLER->ALV_F4
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_FIELDNAME                   TYPE        LVC_FNAME
* | [--->] IV_FIELDVALUE                  TYPE        LVC_VALUE
* | [--->] IS_ROW_NO                      TYPE        LVC_S_ROID
* | [--->] IO_EVENT_DATA                  TYPE REF TO CL_ALV_EVENT_DATA
* | [--->] IT_BAD_CELLS                   TYPE        LVC_T_MODI
* | [--->] IV_DISPLAY                     TYPE        CHAR01
* | [--->] IS_FIELD_INFO                  TYPE        GTY_S_FIELD_INFO
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD alv_f4.
    GET REFERENCE OF is_field_info INTO DATA(lo_info).

    LOOP AT gt_f4_handlers INTO DATA(lo_f4_handler).
      lo_f4_handler->handle(
        iv_row = is_row_no-row_id
        iv_display = iv_display
        iv_value = iv_fieldvalue
        id_field = lo_info
        io_event_data = io_event_data ).
      CHECK io_event_data->m_event_handled = abap_true.

      RETURN.
    ENDLOOP.


  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ACPF_SHLP_HANDLER->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method CONSTRUCTOR.


     "Order of the event handlers is important! The first instance that can handle the
    "event will take care of it and others will be discarded
    APPEND NEW lcl_f4_handler_date( ) TO gt_f4_handlers.
    APPEND NEW lcl_f4_handler_time( ) TO gt_f4_handlers.
    APPEND NEW lcl_f4_handler_domain( ) TO gt_f4_handlers.
    APPEND NEW lcl_f4_handler_ref_table( ) TO gt_f4_handlers.
    APPEND NEW lcl_f4_handler_value_help( ) TO gt_f4_handlers.
    APPEND NEW lcl_f4_handler_valtab( ) TO gt_f4_handlers.


  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ACPF_SHLP_HANDLER->DO_F4
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_FIELD_INFO                  TYPE        GTY_S_FIELD_INFO
* | [--->] IV_FIELDVALUE                  TYPE        LVC_VALUE(optional)
* | [--->] IV_DISPLAY_ONLY                TYPE        BOOLEAN (default =ABAP_FALSE)
* | [<-()] RO_OUTPUT                      TYPE REF TO LVC_T_MODI
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD do_f4.
    "Willreturn an empty object when the event is not handled!
    FIELD-SYMBOLS: <lt_values> TYPE lvc_t_modi.

    DATA(lo_dummy_evt) = NEW  cl_alv_event_data( ).
    GET REFERENCE OF is_field_info INTO DATA(lo_field_info).
    CREATE DATA lo_dummy_evt->m_data TYPE lvc_t_modi.

    LOOP AT gt_f4_handlers INTO DATA(lo_f4_handler).
      lo_f4_handler->handle(
        iv_row     = 1
        iv_display = iv_display_only
        iv_value   = iv_fieldvalue
        id_field   = lo_field_info
        io_event_data = lo_dummy_evt ).
      CHECK lo_dummy_evt->m_event_handled = abap_true.
      CREATE DATA ro_output.
      ASSIGN ro_output->* TO FIELD-SYMBOL(<lt_out>).
      ASSIGN lo_dummy_evt->m_data->* TO <lt_values>.
      APPEND LINES OF <lt_values> TO <lt_out>.
      RETURN.
    ENDLOOP.


  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_ACPF_SHLP_HANDLER=>GET_INSTANCE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RO_INST                        TYPE REF TO ZCL_ACPF_SHLP_HANDLER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_instance.

    IF go_singleton IS NOT BOUND.
      go_singleton = NEW zcl_acpf_shlp_handler( ).
    ENDIF.
    ro_inst = go_singleton.

  ENDMETHOD.
ENDCLASS.
