CLASS lcl_email DEFINITION  .
  PUBLIC SECTION.
    TYPES: BEGIN OF gty_s_attachments,
             filename TYPE string,
             filedata TYPE xstring,
           END OF gty_s_attachments,
           gty_t_attachments TYPE STANDARD TABLE OF gty_s_attachments WITH DEFAULT KEY.
    CLASS-METHODS:
      validate_email_add IMPORTING it_addr            TYPE string_table
                         RETURNING VALUE(rt_inv_addr) TYPE string_table,
      add_sttxt_to_body  IMPORTING iv_tname TYPE clike
                                   iv_id    TYPE thead-tdid DEFAULT 'ST'
                         CHANGING  ct_body  TYPE soli_tab.
    METHODS: constructor IMPORTING  iv_subject     TYPE clike
                                    it_body        TYPE soli_tab
                                    it_attachments TYPE gty_t_attachments
                         EXCEPTIONS
                                    error_adding_attachment
                                    error_creating_document,
      send IMPORTING  it_recipients TYPE string_table
           EXCEPTIONS send_error.
  PROTECTED SECTION.
    DATA: go_document TYPE REF TO cl_document_bcs.
ENDCLASS  .
CLASS lcl_email IMPLEMENTATION.
  METHOD add_sttxt_to_body.
    CONSTANTS:       lc_object TYPE thead-tdobject VALUE 'TEXT'.
    DATA: lt_tlines TYPE STANDARD TABLE OF tline.
    FIELD-SYMBOLS: <ls_bline> TYPE soli.
    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = iv_id
        language                = sy-langu
        name                    = CONV thead-tdname( iv_tname )
        object                  = lc_object
      TABLES
        lines                   = lt_tlines
      EXCEPTIONS
        id                      = 1
        language                = 2
        name                    = 3
        not_found               = 4
        object                  = 5
        reference_check         = 6
        wrong_access_to_archive = 7
        OTHERS                  = 8.
    IF sy-subrc = 0.
      "Add customizable header to email
      LOOP AT lt_tlines ASSIGNING FIELD-SYMBOL(<ls_tl>).
        IF <ls_tl>-tdformat IS NOT INITIAL
             OR <ls_bline> IS NOT ASSIGNED
             OR ( strlen( <ls_bline>-line ) + strlen( <ls_tl>-tdline ) ) > 255.
          APPEND VALUE soli( line = <ls_tl>-tdline ) TO ct_body ASSIGNING <ls_bline>.
        ELSE.
          <ls_bline>-line = |{ <ls_bline>-line } { <ls_tl>-tdline }|.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
  METHOD validate_email_add.
    DATA(lv_regex) = |^[\\w!#$%&'*+/=?`\{\|\}~^-]+(?:\\.[\\w!#$%&'*+/=?`\{\|\}~^-]+)*@(?:[A-Z0-9-]+\\.)+[A-Z]\{2,6\}$|.
    LOOP AT it_addr ASSIGNING FIELD-SYMBOL(<lv_in>).
      DATA(lo_matcher) = cl_abap_matcher=>create( pattern = lv_regex
                                                  text    = <lv_in>
                                                  ignore_case = abap_true ).
      CHECK NOT lo_matcher->match( ).
      APPEND <lv_in> TO rt_inv_addr.
    ENDLOOP.
  ENDMETHOD.
  METHOD constructor.
    "Create the document (email)
    TRY.
        go_document = cl_document_bcs=>create_document(   i_type    = 'RAW'
                                                          i_text    = it_body
                                                          i_subject = CONV so_obj_des( iv_subject ) ).
      CATCH cx_document_bcs.
        RAISE error_creating_document.
    ENDTRY.
    LOOP AT it_attachments ASSIGNING FIELD-SYMBOL(<ls_attach>).
      "Attach the file with the F&R exceptions
      DATA(lt_attach_raw) = cl_bcs_convert=>xstring_to_solix( <ls_attach>-filedata ).
      TRY.
          go_document->add_attachment(  EXPORTING i_attachment_type     = 'BIN'
                                                  i_attachment_subject  = CONV sood-objdes( <ls_attach>-filename )
                                                  i_attachment_language = sy-langu
                                                  i_att_content_hex     = lt_attach_raw ).
        CATCH cx_document_bcs.
          RAISE error_adding_attachment.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
  METHOD send.
    DATA: lo_send_request TYPE REF TO  cl_bcs.
    TRY.
        "Create a send request
        lo_send_request = cl_bcs=>create_persistent( ).
        "Set to be sent immediatelly (no SOST)
        lo_send_request->set_send_immediately( abap_true ).
        "Set the document
        lo_send_request->set_document( go_document ).
      CATCH cx_send_req_bcs.
        RAISE send_error.
    ENDTRY.
    TRY.
        "Add recipients
        LOOP AT it_recipients ASSIGNING FIELD-SYMBOL(<lv_recipient>).
          lo_send_request->add_recipient( i_recipient = cl_cam_address_bcs=>create_internet_address( i_address_string = CONV ad_smtpadr( <lv_recipient> ) )   ).
        ENDLOOP.
        "Set the current user as the default sender
        DATA(lo_sender) = cl_sapuser_bcs=>create( sy-uname ) .
        lo_send_request->set_sender(   lo_sender  ).

        "And send!
        lo_send_request->send( i_with_error_screen = abap_false ).
      CATCH cx_send_req_bcs.
        RAISE send_error.
      CATCH cx_address_bcs.
        RAISE send_error.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.