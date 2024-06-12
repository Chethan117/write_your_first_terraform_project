/* Setting Up Libraries */
libname npi "/e/s/prd/npi" hostname= 'some.com' server = _1234 sapw='';
libname gen "/e/s/prd/general" hostname= 'some.com' server = _1234 sapw ='';

/* SAS Logon and Roles */
%macro sf_logon;
    PROC SQL;
    connect to SASIOSNF as SF (&sf_logon);
    EXECUTE (USE SECONDARY ROLES ALL) BY SF;
%mend;


%macro data_manipulation(case_table, fr_table, rep_table, gen_table, join_cond, join_fields, case_date_field, var_list);
    /* Delete Today's Reports */
    PROC SQL;
    DELETE FROM FT.&rep_table
    WHERE REPORT_DT=TODAY();

    /* Create Working and Unworked Tables */
    CREATE TABLE &fr_table._WKD AS
    SELECT &var_list, B.*
    FROM NPI.&fr_table AS A
    INNER JOIN GEN.&fr_table AS B ON &join_cond
    AND COALESCE(B.CASE_STATUS, 0) IN (1,2,3)
    AND DATEPART(CLOSE_SNAPDATE_TIME) = TODAY();

    CREATE TABLE &fr_table._UNWKD AS
    SELECT &var_list
    FROM NPI.&fr_table AS A
    WHERE NOT EXISTS (
        SELECT 1
        FROM &fr_table._WKD C
        WHERE A.&join_fields = C.&join_fields
    );

    /* Generate Aggregate and Processed Tables */
    CREATE TABLE &fr_table._AP1 AS
    SELECT * FROM &fr_table._WKD
    UNION
    SELECT * FROM &fr_table._UNWKD;

    /* Group by Specified Join Fields */
    CREATE TABLE COUNT AS
    SELECT &join_fields AS CASE_REF, COUNT(*) AS CASE_REF_COUNT, MIN(&case_date_field) AS CASE_DATE
    FROM &fr_table._AP1
    GROUP BY &join_fields;

    /* Join Back for Final Aggregation */
    CREATE TABLE &fr_table._AP2 AS
    SELECT 'UPCASE(&fr_table)' AS CASE_REF_QUEUE, COUNT.*, A.*
    FROM &fr_table._AP1 A
    INNER JOIN COUNT ON A.&join_fields = COUNT.&join_fields
    ORDER BY CASE_DATE, CASE_REF, &case_date_field;

    /* Assign Sequential Numbers to Cases */
    data &fr_table._AP4;
    set &fr_table._AP3;
    CASE_REF_NO + 1;
    run;

    /* Append Data to Historical Record Tables */
    PROC SQL;
    INSERT INTO FT.&gen_table
    SELECT * FROM &fr_table._AP5;
    QUIT;
%mend;



%sf_logon;
%data_manipulation(FR_182_ABA_TRAN, FRD_182_ABA_TRAN_REPORT, FR_182_ABA_TRAN_REPORT_REP, FR_182_ABA_TRAN_REPORT_GEN,
                   A.CASE_REF_NO = B.CASE_REF_NO, "ACCOUNTID, TRXN_POST_DT", TRXN_POST_DT, "A.CNUM, A.ACCOUNTID, A.TRXN_POST_DT");

%data_manipulation(FR_196_ABA_In_credit, FRD_196_ABA_INCRED_FRE_DLY_T, FR_196_ABA_In_credit_rep, FR_196_ABA_In_credit_GEN,
                   A.CNUM = B.CNUM, "CNUM, TRXN_POST_DT", TRXN_POST_DT, "A.CNUM, A.ACCOUNTID, A.TRXN_POST_DT");

%data_manipulation(FR_781_ZERO_BAL_EXP, FRD_781_EXCEPTION_RESULTS, FR_781_ZERO_BAL_EXP_rep, FR_781_ZERO_BAL_EXP_GEN,
                   A.ACCOUNTID = B.ACCOUNTID, "ACCOUNTID, FRD_DT", FRD_DT, "A.ACCOUNTID, A.FRD_DT, A.PTI");

%data_manipulation(FR_659_ABA_GEN_CREDIT, FRD_659_FREC_ABA_GEN_CREDIT, FR_659_ABA_GEN_CREDIT_rep, FR_659_ABA_GEN_CREDIT_GEN,
                   A.PTI = B.PTI, "PTI, TRXN_DT", TRXN_DT, "A.PTI, A.ASN, A.TRXN_DT");
