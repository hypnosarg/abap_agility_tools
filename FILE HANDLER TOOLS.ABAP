

INTERFACE lif_parser.
  METHODS: parse_file
    IMPORTING  iv_data        TYPE xstring
    RETURNING  VALUE(ro_data) TYPE REF TO data
    EXCEPTIONS
               parse_error
               wrong_format.

ENDINTERFACE.


CLASS lcl_file_handler DEFINITION ABSTRACT.
  PUBLIC SECTION.
    METHODS: constructor IMPORTING iv_mask  TYPE clike OPTIONAL,
      parse_file  IMPORTING  io_parser      TYPE REF TO lif_parser OPTIONAL
                  RETURNING  VALUE(ro_data) TYPE REF TO data
                  EXCEPTIONS
                             wrong_format
                             parse_error,
      read_file   ABSTRACT IMPORTING iv_path TYPE clike RETURNING VALUE(rv_error) TYPE string,
      file_sh     ABSTRACT IMPORTING iv_root TYPE clike OPTIONAL RETURNING VALUE(rv_path) TYPE string,
      get_files_in_folder ABSTRACT IMPORTING iv_path         TYPE clike
                                   RETURNING VALUE(rt_files) TYPE string_table ,
      get_root_folder    ABSTRACT RETURNING VALUE(rv_folder) TYPE string,
      save    ABSTRACT IMPORTING iv_filename     TYPE clike  OPTIONAL
                       RETURNING VALUE(rv_error) TYPE string,
      set_binary_data IMPORTING iv_data TYPE xstring,
      get_binary_data RETURNING VALUE(rv_data) TYPE xstring,
      delete ABSTRACT RETURNING VALUE(rv_error) TYPE string,
      get_read_filename RETURNING VALUE(rv_name) TYPE string ,
      get_read_folder   RETURNING VALUE(rv_name) TYPE string ##CALLED,
      set_mask        IMPORTING  iv_mask TYPE clike,
      get_mask_for_extensions ABSTRACT IMPORTING it_ext         TYPE string_table
                                       RETURNING VALUE(rv_mask) TYPE string .
  PROTECTED SECTION.
    DATA: gv_mask      TYPE string,
          gv_file_data TYPE xstring,
          gv_read_path TYPE string.
    METHODS: remove_extension CHANGING cv_path TYPE string ##CALLED.
ENDCLASS.


CLASS lcl_file_handler IMPLEMENTATION.
  METHOD set_mask.
    gv_mask = iv_mask.
  ENDMETHOD.
  METHOD set_binary_data.
    gv_file_data = iv_data.
  ENDMETHOD.
  METHOD get_binary_data.
    rv_data = gv_file_data.
  ENDMETHOD.
  METHOD get_read_folder ##NEEDED."For design completeness
    rv_name = gv_read_path .
    REPLACE ALL OCCURRENCES OF me->get_read_filename( ) IN rv_name WITH '' .
  ENDMETHOD.
  METHOD get_read_filename ##NEEDED."For design completeness
    CHECK gv_read_path IS NOT INITIAL.
    SPLIT gv_read_path AT '/' INTO TABLE DATA(lt_parts).
    IF lines( lt_parts ) = 1.
      SPLIT gv_read_path AT '\' INTO TABLE lt_parts.
    ENDIF.
    CHECK lt_parts IS NOT INITIAL.
    rv_name = lt_parts[ lines( lt_parts ) ].
  ENDMETHOD.

  METHOD parse_file.

    io_parser->parse_file(
      EXPORTING
        iv_data      = gv_file_data
      RECEIVING
        ro_data      = ro_data
      EXCEPTIONS
        parse_error  = 1
        wrong_format = 2
        OTHERS       = 3
    ).
    IF sy-subrc = 1.
      RAISE parse_error.
    ELSEIF sy-subrc = 2.
      RAISE wrong_format.
    ENDIF.

  ENDMETHOD.

  METHOD constructor.
    gv_mask   = iv_mask.
  ENDMETHOD.

  METHOD remove_extension ##NEEEDED.
    DATA lv_remove TYPE string.
    DATA(lv_index) = strlen( cv_path ) - 1.
    WHILE lv_index >= 0 AND cv_path+lv_index(1) <> '/'  AND cv_path+lv_index(1) <> '\' .
      lv_remove = |{ cv_path+lv_index(1) }{ lv_remove }|.
      lv_index =  lv_index - 1.
    ENDWHILE.
    REPLACE ALL OCCURRENCES OF lv_remove IN cv_path WITH ''.
  ENDMETHOD.
ENDCLASS.


CLASS lcl_file_handler_lcl DEFINITION INHERITING FROM lcl_file_handler.
  PUBLIC SECTION.
    METHODS: read_file REDEFINITION,
      file_sh   REDEFINITION,
      get_files_in_folder REDEFINITION,
      get_root_folder REDEFINITION,
      delete REDEFINITION,
      get_mask_for_extensions REDEFINITION,
      save REDEFINITION.
ENDCLASS.
CLASS lcl_file_handler_lcl IMPLEMENTATION.
  METHOD get_root_folder.
    rv_folder =  me->get_read_folder( ).
  ENDMETHOD.
  METHOD save.
    DATA: lt_file TYPE solix_tab.


    DATA(lv_path) =  CONV string( me->get_root_folder( ) ).

    IF iv_filename IS SUPPLIED .
      lv_path = |{ lv_path }{ iv_filename }|.
    ELSE.
      lv_path = |{ lv_path }{  me->get_read_filename( ) }|.
    ENDIF.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
         filename                  = lv_path
         filetype                  = 'BIN'
      CHANGING
        data_tab                  =  lt_file
      EXCEPTIONS
        file_write_error          = 1
        no_batch                  = 2
        gui_refuse_filetransfer   = 3
        invalid_type              = 4
        no_authority              = 5
        unknown_error             = 6
        header_not_allowed        = 7
        separator_not_allowed     = 8
        filesize_not_allowed      = 9
        header_too_long           = 10
        dp_error_create           = 11
        dp_error_send             = 12
        dp_error_write            = 13
        unknown_dp_error          = 14
        access_denied             = 15
        dp_out_of_memory          = 16
        disk_full                 = 17
        dp_timeout                = 18
        file_not_found            = 19
        dataprovider_exception    = 20
        control_flush_error       = 21
        not_supported_by_gui      = 22
        error_no_gui              = 23
        OTHERS                    = 24
    ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO rv_error.
    ENDIF.
  ENDMETHOD.

  METHOD delete.
    DATA lv_rc TYPE i.

    cl_gui_frontend_services=>file_delete(
      EXPORTING
        filename             = gv_read_path
      CHANGING
        rc                   = lv_rc
      EXCEPTIONS
        file_delete_failed   = 1
        cntl_error           = 2
        error_no_gui         = 3
        file_not_found       = 4
        access_denied        = 5
        unknown_error        = 6
        not_supported_by_gui = 7
        wrong_parameter      = 8
        others               = 9
    ).
    IF sy-subrc <> 0 OR lv_rc <> 0.
     MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
       WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO rv_error.
    ENDIF.
  ENDMETHOD.
  METHOD get_mask_for_extensions .
    "(*.XML)|*.XML   <<< mask format example
    LOOP AT it_ext ASSIGNING FIELD-SYMBOL(<lv_ext>).
      rv_mask = |{ rv_mask }\|(*.{ <lv_ext> } )\|*.{ <lv_ext> }|.
    ENDLOOP.
    rv_mask = rv_mask+1.
  ENDMETHOD.
  METHOD get_files_in_folder ##NEEDED.
    DATA lv_count TYPE i.
    cl_gui_frontend_services=>directory_list_files(
      EXPORTING
        directory                   = CONV string( iv_path )
        filter                      =  gv_mask
      CHANGING
        file_table                  = rt_files
        count                       = lv_count
      EXCEPTIONS
        cntl_error                  = 1                " Control error
        directory_list_files_failed = 2                " Could not list files in the directory
        wrong_parameter             = 3                " Incorrect parameter combination
        error_no_gui                = 4                " No GUI available
        not_supported_by_gui        = 5                " GUI does not support this
        OTHERS                      = 6
    ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
  ENDMETHOD.
  METHOD read_file.
    DATA: lt_file TYPE solix_tab.
    gv_read_path = iv_path.
    cl_gui_frontend_services=>gui_upload(
      EXPORTING
         filename                = CONV string( iv_path )
         filetype                = 'BIN'
      CHANGING
        data_tab                =   lt_file
      EXCEPTIONS
        file_open_error         = 1                " File does not exist and cannot be opened
        file_read_error         = 2                " Error when reading file
        no_batch                = 3                " Cannot execute front-end function in background
        gui_refuse_filetransfer = 4                " Incorrect front end or error on front end
        invalid_type            = 5                " Incorrect parameter FILETYPE
        no_authority            = 6                " No upload authorization
        unknown_error           = 7                " Unknown error
        bad_data_format         = 8                " Cannot Interpret Data in File
        header_not_allowed      = 9                " Invalid header
        separator_not_allowed   = 10               " Invalid separator
        header_too_long         = 11               " Header information currently restricted to 1023 bytes
        unknown_dp_error        = 12               " Error when calling data provider
        access_denied           = 13               " Access to File Denied
        dp_out_of_memory        = 14               " Not enough memory in data provider
        disk_full               = 15               " Storage medium is full.
        dp_timeout              = 16               " Data provider timeout
        not_supported_by_gui    = 17               " GUI does not support this
        error_no_gui            = 18               " GUI not available
        OTHERS                  = 19
    ).
    IF sy-subrc <> 0.
      rv_error = |UPLOAD SUBRC = { sy-subrc }|.
    ELSE.
      TRY.
          gv_file_data = cl_bcs_convert=>xtab_to_xstring( lt_file ).
        CATCH cx_bcs.
          rv_error = 'CONVERSION TO XSTRING'.
      ENDTRY.
    ENDIF.
  ENDMETHOD.
  METHOD file_sh.
    DATA: lt_filetab TYPE filetable,
          lv_rc      TYPE i.

    CALL METHOD cl_gui_frontend_services=>file_open_dialog
      EXPORTING
        file_filter             = gv_mask
        initial_directory       = CONV string( iv_root )
      CHANGING
        file_table              = lt_filetab
        rc                      = lv_rc
      EXCEPTIONS
        file_open_dialog_failed = 1
        cntl_error              = 2
        error_no_gui            = 3
        not_supported_by_gui    = 4
        OTHERS                  = 5.
    IF sy-subrc <> 0  OR lv_rc = 0.
      CLEAR rv_path.
    ELSEIF lt_filetab IS NOT INITIAL.
      rv_path = lt_filetab[ 1 ].
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS lcl_file_handler_srv DEFINITION  INHERITING FROM lcl_file_handler.
  PUBLIC SECTION.
    CLASS-METHODS:
      lpath_get_folder IMPORTING iv_path TYPE clike  RETURNING VALUE(rv_folder) TYPE string.
    METHODS: constructor IMPORTING iv_mask  TYPE string OPTIONAL
                                   iv_lpath TYPE string OPTIONAL,
      read_file           REDEFINITION,
      file_sh             REDEFINITION,
      get_files_in_folder REDEFINITION,
      get_root_folder     REDEFINITION,
      get_mask_for_extensions REDEFINITION,
      delete REDEFINITION,
      save   REDEFINITION.
  PROTECTED SECTION.
    DATA: gv_logical_path  TYPE fileintern,
          gv_phisical_path TYPE string,
          gv_name_temp     TYPE string,
          gv_ext_temp      TYPE string,
          gv_ext_lc        TYPE string,
          gv_filename_temp TYPE string,
          gv_part          TYPE text50,
          gt_fileparts     TYPE STANDARD TABLE OF text50.

ENDCLASS.
CLASS lcl_file_handler_srv IMPLEMENTATION.

  DEFINE mac_security_overhead.
    "Verify authorization to read the file
    CALL FUNCTION 'AUTHORITY_CHECK_DATASET'
      EXPORTING
        activity         = &3
        filename         = CONV fileextern( &1 )
      EXCEPTIONS
        no_authority     = 1
        activity_unknown = 2
        OTHERS           = 3.
    IF sy-subrc <> 0.
     &2 = 'NO_AUTH'.
    ENDIF.

    IF  gv_logical_path IS NOT INITIAL.
      "Protection against transversal attacks custom request
      CALL FUNCTION 'FILE_GET_NAME_USING_PATH'
        EXPORTING
          logical_path               = gv_logical_path
          file_name                  = '@'
        IMPORTING
          file_name_with_path        = gv_phisical_path
        EXCEPTIONS
          path_not_found             = 1
          missing_parameter          = 2
          operating_system_not_found = 3
          file_system_not_found      = 4
          OTHERS                     = 5.
      IF   sy-subrc <> 0.
        &2 = 'NAME_ERROR_1'.
      ELSE.
        "Validate that the provided file is in the appropiate folder
        REPLACE ALL OCCURRENCES OF '/@' IN gv_phisical_path WITH ''.
        IF NOT &1  CS gv_phisical_path.
          "The selected file is not in the correct folder, error
          &2 = 'NAME_ERROR_2'.
        ENDIF.
      ENDIF.

      "Protection against transversal attacks: Part 2, Active Control requirement
      "Separate the file name
      SPLIT &1 AT '/' INTO TABLE gt_fileparts.
      IF gt_fileparts IS NOT INITIAL.
        READ TABLE gt_fileparts INDEX  lines( gt_fileparts ) INTO gv_part.
        IF sy-subrc = 0 .
          SPLIT gv_part AT '.' INTO gv_name_temp gv_ext_temp.
        ENDIF.
      ENDIF.


      "Before validating, convert the extension to lower case, as
      "the FM below is case sensitive and we actually don't care about caps of the file
      gv_ext_temp = |.{ gv_ext_temp }|.
      gv_ext_lc = gv_ext_temp.
      TRANSLATE gv_ext_lc TO LOWER CASE.


      "The validation below is safe as the location of the actual file inside the root folder for this WRICEF
      "Was validated in the step aboce using FILE_GET_NAME_USING_PATH
      gv_filename_temp = |{ gv_phisical_path }/{ gv_name_temp }{ gv_ext_lc }|.

      "Validate the file name
      CALL FUNCTION 'FILE_VALIDATE_NAME'
        EXPORTING
*         CLIENT                     = SY-MANDT
          logical_filename           = gv_logical_path
*         OPERATING_SYSTEM           = SY-OPSYS
          parameter_2                = gv_name_temp
*         PARAMETER_3                = ' '
*         WITH_FILE_EXTENSION        = lv_ext
*         USE_BUFFER                 = ' '
*         ELIMINATE_BLANKS           = 'X'
*       IMPORTING
*         VALIDATION_ACTIVE          =
*         TS_ALIAS                   =
        CHANGING
          physical_filename          = gv_filename_temp
        EXCEPTIONS
          logical_filename_not_found = 1
          validation_failed          = 2
          OTHERS                     = 3.
      IF sy-subrc <> 0.
         &2 = 'NAME_ERROR_3'.
      ENDIF.

    ENDIF.


  END-OF-DEFINITION.
  METHOD get_mask_for_extensions .
    LOOP AT it_ext ASSIGNING FIELD-SYMBOL(<lv_ext>).
      gv_mask = |{ gv_mask }\|*.{ <lv_ext> }|.
    ENDLOOP.
    "Remove first pipe
    gv_mask = gv_mask+1.
  ENDMETHOD.
  METHOD save.

    DATA(lv_path) =  me->get_root_folder( ).

    IF iv_filename IS SUPPLIED .
      lv_path = |{ lv_path }{ iv_filename }|.
    ELSE.
      lv_path = |{ lv_path }{  me->get_read_filename( ) }|.
    ENDIF.

    "Authorizations and security in a macro as QC tools might
    "need the code to be on the same subroutine
    mac_security_overhead  lv_path rv_error 'WRITE'.
    IF rv_error IS NOT INITIAL.
      RETURN.
    ENDIF.



    OPEN DATASET  lv_path FOR OUTPUT IN BINARY MODE.
    IF sy-subrc <> 0.
      rv_error = 'OPEN_DATASET'.
      RETURN.
    ENDIF.
    TRANSFER gv_file_data TO  lv_path.
    IF sy-subrc <> 0.
      rv_error = 'TRANSFER'.
      RETURN.
    ENDIF.
    CLOSE DATASET  lv_path.
    IF sy-subrc <> 0.
      rv_error = 'CLOSE_DATASET'.
      RETURN.
    ENDIF.

  ENDMETHOD.

  METHOD delete.
    "Authorizations and security in a macro as QC tools might
    "need the code to be on the same subroutine

    mac_security_overhead gv_read_path rv_error 'DELETE'.
    IF rv_error IS NOT INITIAL.
      RETURN.
    ENDIF.

    OPEN DATASET gv_read_path FOR OUTPUT IN BINARY MODE.
    IF sy-subrc <> 0.
      rv_error = 'OPEN_DATASET'.
      RETURN.
    ENDIF.
    DELETE DATASET gv_read_path.
    IF sy-subrc <> 0.
      rv_error = 'DEETE_DATASET'.
      RETURN.
    ENDIF.
    CLOSE DATASET gv_read_path.
    IF sy-subrc <> 0.
      rv_error = 'CLOSE_DATASET'.
      RETURN.
    ENDIF.

  ENDMETHOD.
  METHOD constructor.
    super->constructor( iv_mask = iv_mask  ).
    gv_logical_path = iv_lpath.
  ENDMETHOD.
  METHOD lpath_get_folder.
    CHECK iv_path IS NOT INITIAL.
    CALL FUNCTION 'FILE_GET_NAME_USING_PATH'
      EXPORTING
*       CLIENT                     = SY-MANDT
        logical_path               = CONV fileintern( iv_path )
*       OPERATING_SYSTEM           = SY-OPSYS
*       PARAMETER_1                = ' '
*       PARAMETER_2                = ' '
*       PARAMETER_3                = ' '
*       USE_BUFFER                 = ' '
        file_name                  = '@'
*       USE_PRESENTATION_SERVER    = ' '
*       ELEMINATE_BLANKS           = 'X'
      IMPORTING
        file_name_with_path        = rv_folder
      EXCEPTIONS
        path_not_found             = 1
        missing_parameter          = 2
        operating_system_not_found = 3
        file_system_not_found      = 4
        OTHERS                     = 5.
    IF sy-subrc = 0.
      REPLACE ALL OCCURRENCES OF '/@' IN rv_folder WITH '/'.
    ENDIF.

  ENDMETHOD.
  METHOD get_root_folder.
    rv_folder = lpath_get_folder( gv_logical_path ).
  ENDMETHOD.
  METHOD get_files_in_folder.
    DATA lt_files TYPE STANDARD TABLE OF epsfili.


    CALL FUNCTION 'EPS_GET_DIRECTORY_LISTING'
      EXPORTING
        dir_name               = CONV epsf-epsdirnam( iv_path )
      TABLES
        dir_list               = lt_files
      EXCEPTIONS
        invalid_eps_subdir     = 1
        sapgparam_failed       = 2
        build_directory_failed = 3
        no_authorization       = 4
        read_directory_failed  = 5
        too_many_read_errors   = 6
        empty_directory_list   = 7
        OTHERS                 = 8.

    IF sy-subrc = 0.
      LOOP AT lt_files ASSIGNING FIELD-SYMBOL(<ls_file>).
        APPEND INITIAL LINE TO rt_files ASSIGNING FIELD-SYMBOL(<lv_output>).
        <lv_output> = |{ iv_path }/{ <ls_file>-name }|.
        REPLACE ALL OCCURRENCES OF '//' IN <lv_output> WITH '/'.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
  METHOD read_file.
    DATA(lv_path) = CONV string( iv_path ).
    gv_read_path = lv_path.


    "Authorizations and security in a macro as QC tools might
    "need the code to be on the same subroutine
    mac_security_overhead gv_read_path rv_error 'READ'.
    IF rv_error IS NOT INITIAL.
      RETURN.
    ENDIF.


    OPEN DATASET lv_path FOR INPUT IN BINARY MODE  .
    IF sy-subrc <> 0.
      rv_error = 'OPEN_DATASET'.
      RETURN.
    ENDIF.

    "Start reading the file
    DATA lv_file_data TYPE xstring.
    WHILE sy-subrc = 0.
      READ DATASET lv_path  INTO lv_file_data.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      gv_file_data = |{ gv_file_data }{ lv_file_data }|.
    ENDWHILE.

    CLOSE DATASET lv_path.
    IF sy-subrc <> 0.
      rv_error = 'CLOSE_DATASET'.
      RETURN.
    ENDIF.

  ENDMETHOD.
  METHOD file_sh.
    "Have we already got the  phisical path?
    DATA lv_root TYPE string.
    IF iv_root IS NOT SUPPLIED.
      lv_root = me->get_root_folder( ).
    ELSE.
      lv_root = iv_root.
    ENDIF.



    "IF the logical path is available, set the root to that
    DATA lv_path TYPE dxfields-longpath.
    CALL FUNCTION 'F4_DXFILENAME_TOPRECURSION'
      EXPORTING
        i_location_flag       = 'A'
        i_server              = ' '
        i_path                = CONV dxfields-longpath( lv_root )
        "filemask              = CONV dxfields-filemask( gv_mask )
      IMPORTING
        o_path                = lv_path
*       abend_flag            = lv_abend_flag
      EXCEPTIONS
        communication_failure = 1
        system_failure        = 2
        rfc_error             = 3.
    IF sy-subrc = 0.
      rv_path = lv_path.
    ENDIF.

  ENDMETHOD.
ENDCLASS.

CLASS lcl_file_copier DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      copy_file   IMPORTING  io_source_hdlr  TYPE REF TO lcl_file_handler
                             iv_target_lpath TYPE clike OPTIONAL
                             iv_new_name     TYPE clike OPTIONAL
                             iv_appl         TYPE boolean
                  EXCEPTIONS no_data
                             copy_error,
      move_file   IMPORTING  io_source_hdlr  TYPE REF TO lcl_file_handler
                             iv_target_lpath TYPE clike OPTIONAL
                             iv_appl         TYPE boolean
                  EXCEPTIONS no_data
                             copy_error
                             delete_error.
ENDCLASS.
CLASS lcl_file_copier IMPLEMENTATION.
  METHOD copy_file.
    DATA: lo_new  TYPE  REF TO lcl_file_handler,
          lv_name TYPE string.

    IF io_source_hdlr IS NOT BOUND OR io_source_hdlr->get_binary_data( ) IS INITIAL.
      RAISE no_data.
    ENDIF.

    IF iv_appl = abap_true.
      lo_new ?= NEW lcl_file_handler_srv(   iv_lpath =  iv_target_lpath ).
    ELSE.
      lo_new ?= NEW lcl_file_handler_lcl( ).
    ENDIF.

    IF iv_new_name IS SUPPLIED.
      lv_name = iv_new_name.
    ELSE.
      lv_name = io_source_hdlr->get_read_filename( )..
    ENDIF.

    lo_new->set_binary_data( io_source_hdlr->get_binary_data( ) ).
    lo_new->save( iv_filename = lv_name  ).


  ENDMETHOD.
  METHOD move_file.
    copy_file(
      EXPORTING
        io_source_hdlr  = io_source_hdlr
        iv_target_lpath = iv_target_lpath
        iv_appl         = iv_appl
      EXCEPTIONS
        no_data         = 1
        copy_error      = 2
        OTHERS          = 3
    ).
    IF sy-subrc <> 0.
      RAISE copy_error.
    ENDIF.

    "Now delete the source
    IF io_source_hdlr->delete( ) IS NOT INITIAL.
      RAISE delete_error.
    ENDIF.

  ENDMETHOD.
ENDCLASS.

*****EXAMPLES
*------------Instantiation and search help----------
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
*"---- Parsing ----
*"File read OK, proceed with parsing
*     go_handler->parse_file(
*       EXPORTING
*         io_parser    =  NEW lcl_parser_boa( )
*       RECEIVING
*         ro_data      =  DATA(lo_filedata)
*       EXCEPTIONS
*         wrong_format = 1
*         parse_error  = 2
*         OTHERS       = 3
*     ).
*     IF sy-subrc <> 0.
*       mac_add_message  abap_true 'File parsing error. Wrong file format'(f21).
*       CONTINUE.
*     ENDIF.
***PArser class
*CLASS lcl_parser_boa DEFINITION.
*  "Parser class for the XML file of the Bank of America
*  PUBLIC SECTION.
*    INTERFACES: lif_parser.
*    TYPES: BEGIN OF gty_s_item,
*             status             TYPE text10,
*             orig_payinfo_id    TYPE text50,
*             end_to_end_id      TYPE text50,
*             amount             TYPE text50,
*             currency           TYPE text3,
*             executiondt        TYPE text12,
*             erdat              TYPE text50,
*             description_reason TYPE text128,
*             name               TYPE text128,
*           END OF gty_s_item,
*           gty_t_items TYPE STANDARD TABLE OF gty_s_item WITH DEFAULT KEY,
*           BEGIN OF gty_s_fomatted,
*             bank_id      TYPE string,
*             client_id    TYPE string,
*             origmsg_id   TYPE string,
*             tot_txn_rcvd TYPE i,
*             tot_amt_rcvd TYPE string,
*             tot_txn_accp TYPE i,
*             tot_amt_accp TYPE string,
*             tot_txn_rjt  TYPE i,
*             tot_amt_rjt  TYPE string,
*             tot_txn_chg  TYPE i,
*             tot_amt_chg  TYPE string,
*             items        TYPE gty_t_items,
*           END OF gty_s_fomatted.
*ENDCLASS.
*
*CLASS lcl_parser_boa IMPLEMENTATION.
*
*
*  METHOD lif_parser~parse_file.
*    DATA: lt_parsed    TYPE STANDARD TABLE OF  smum_xmltb,
*          lt_ret       TYPE bapiret2_tab,
*          lv_payinf_id TYPE text50,
*          lv_date      TYPE char10,
*          lv_time      TYPE char8,
*          lv_saved_val TYPE string.
*
*    DATA : "lt_rjct_records TYPE STANDARD TABLE OF zta_i19_boa_ack,
*      lv_datetime TYPE text50,
*      lv_line_no  TYPE int4.
*
*    FIELD-SYMBOLS: <ls_formatted> TYPE gty_s_fomatted.
*    CALL FUNCTION 'SMUM_XML_PARSE'
*      EXPORTING
*        xml_input = iv_data
*      TABLES
*        xml_table = lt_parsed
*        return    = lt_ret.
*    READ TABLE lt_ret WITH KEY type = 'S' TRANSPORTING NO FIELDS  .
*    IF sy-subrc <> 0 OR  lt_parsed IS INITIAL.
*      RAISE parse_error.
*    ENDIF.
*
*
*    CREATE DATA ro_data TYPE gty_s_fomatted.
*    ASSIGN ro_data->* TO <ls_formatted>.
*
*    DATA(lv_fgr) = 0.
*    lv_line_no = 0.
*    LOOP AT lt_parsed ASSIGNING FIELD-SYMBOL(<ls_parsed>).
*      CASE <ls_parsed>-cname.
*        WHEN 'GrpHdr'.                 "Switch to Header fields
*          lv_fgr = 1.
*        WHEN 'OrgnlGrpInfAndSts'.      "Switch to group Totals a stats fields
*          lv_fgr = 2.
*        WHEN 'OrgnlPmtInfAndSts'.      "Switch to Item info and stats
*          lv_fgr = 3.
*        WHEN OTHERS.
*          "Process subnodes
*          IF lv_fgr = 1.
*            "We are searching for the customer and bank id here
*            IF <ls_parsed>-cname = 'Id'.
*              "Save the id,alter the schema will tell what it is
*              lv_saved_val = <ls_parsed>-cvalue.
*            ELSEIF  <ls_parsed>-cname = 'Cd'.
*              "NOw we know what the previous ID was
*              IF <ls_parsed>-cvalue = 'BANK'.
*                <ls_formatted>-bank_id = lv_saved_val.
*              ELSEIF <ls_parsed>-cvalue = 'CUST'.
*                <ls_formatted>-client_id = lv_saved_val.
*              ELSE.
*                CLEAR lv_saved_val.
*              ENDIF.
*            ELSEIF <ls_parsed>-cname = 'CreDtTm'.
*              lv_datetime = <ls_parsed>-cvalue.
*              SPLIT lv_datetime AT 'T' INTO lv_date lv_time.
*            ENDIF.
*          ELSEIF lv_fgr = 2.
*            CASE <ls_parsed>-cname.
*              WHEN 'OrgnlMsgId'.
*                <ls_formatted>-origmsg_id   = <ls_parsed>-cvalue.
*              WHEN 'OrgnlNbOfTxs'.
*                <ls_formatted>-tot_txn_rcvd = <ls_parsed>-cvalue.
*              WHEN 'OrgnlCtrlSum'.
*                <ls_formatted>-tot_amt_rcvd = <ls_parsed>-cvalue.
*                "The logic below is a mess, but the xml does not guaranteee the order the fields will appear, so I neeed to cover all cases
*              WHEN 'NbOfTxsPerSts'.
*                "This means a new stat group is comming, clean all variables.
*                DATA: lv_dtldnboftxs TYPE string.
*                FIELD-SYMBOLS: <lv_dtldnboftxs> TYPE any,
*                               <lv_dtldctrlsum> TYPE any.
*                UNASSIGN  : <lv_dtldnboftxs>,
*                            <lv_dtldctrlsum>.
*
*              WHEN 'DtldSts'.
*                "THis node defines what the two stats of the nodes below refer to
*                "Take into account that it appears in between them
*                IF <ls_parsed>-cvalue     = 'RJCT'.
*                  ASSIGN COMPONENT 'tot_txn_rjt' OF STRUCTURE <ls_formatted> TO <lv_dtldnboftxs>.
*                  ASSIGN COMPONENT 'tot_amt_rjt' OF STRUCTURE <ls_formatted> TO <lv_dtldctrlsum>.
*                ELSEIF <ls_parsed>-cvalue = 'ACWC'.
*                  ASSIGN COMPONENT 'tot_txn_chg' OF STRUCTURE <ls_formatted> TO <lv_dtldnboftxs>.
*                  ASSIGN COMPONENT 'tot_amt_chg' OF STRUCTURE <ls_formatted> TO <lv_dtldctrlsum>.
*                ELSEIF <ls_parsed>-cvalue = 'ACCP'.
*                  ASSIGN COMPONENT 'tot_txn_accp' OF STRUCTURE <ls_formatted> TO <lv_dtldnboftxs>.
*                  ASSIGN COMPONENT 'tot_amt_accp' OF STRUCTURE <ls_formatted> TO <lv_dtldctrlsum>.
*                ENDIF.
*              WHEN 'DtldNbOfTxs'.
*                "When this field appears we still don't know what it belongs to, save the value for now
*                lv_dtldnboftxs = <ls_parsed>-cvalue.
*              WHEN 'DtldCtrlSum'.
*                "This appears after we have determined the data group we are refering, so we assign all values now
*                IF <lv_dtldctrlsum> IS ASSIGNED.
*                  <lv_dtldctrlsum> = <ls_parsed>-cvalue.
*                  <lv_dtldnboftxs> = lv_dtldnboftxs.
*                ENDIF.
*              WHEN OTHERS.
*                CONTINUE.
*            ENDCASE.
*          ELSE.
*
*            "Items already in parsing
*            CASE <ls_parsed>-cname.
*              WHEN 'TxInfAndSts'.
*                "A new item is starting, add a new item record to the utput
*                APPEND INITIAL LINE TO <ls_formatted>-items ASSIGNING FIELD-SYMBOL(<ls_item>).
*                <ls_item>-orig_payinfo_id = lv_payinf_id.
*                <ls_item>-erdat = lv_datetime.
*                lv_line_no = lv_line_no + 1.
*              WHEN 'OrgnlPmtInfId'."Original Payment Infor ID
*                lv_payinf_id = <ls_parsed>-cvalue.
*              WHEN 'OrgnlEndToEndId'."Item id
*                <ls_item>-end_to_end_id = <ls_parsed>-cvalue.
*              WHEN 'TxSts'.          "Itemn Status
*                <ls_item>-status = <ls_parsed>-cvalue.
*              WHEN 'InstdAmt'.       "Item ammount and currency
*                <ls_item>-amount = <ls_parsed>-cvalue.
*              WHEN 'Ccy'.
*                <ls_item>-currency = <ls_parsed>-cvalue.
*              WHEN 'ReqdExctnDt'.     "Execution date
*                <ls_item>-executiondt = <ls_parsed>-cvalue.
*              WHEN 'Nm'.
*                <ls_item>-name = <ls_parsed>-cvalue.
*              WHEN 'Cd'.            "Reason code comes first, we want to format REASON:CODE
*                <ls_item>-description_reason = |{ <ls_parsed>-cvalue }:|.
*              WHEN 'AddtlInf'.     "REason text comes second, add to the value starteed above
*                <ls_item>-description_reason = |{ <ls_item>-description_reason }{ <ls_parsed>-cvalue }|.
*              WHEN OTHERS.
*                CONTINUE.
*            ENDCASE.
*          ENDIF.
*      ENDCASE.
*    ENDLOOP  .
*
*    IF lv_fgr <> 3.
*      RAISE wrong_format.
*    ENDIF.
*
*
*
*  ENDMETHOD.
*ENDCLASS.

