options ps=max;

libname sds "C:\temp\sds";
libname mst "C:\temp\mst";

filename in "C:\temp\input";
filename dat1 "C:\temp\master\master_file.xlsx";

/***
    基準年月設定
***/
%let P_KIJYUN = 200512;


%Macro Read_file;

    /*** コンビニ店舗マスタ読み込み ***/
    proc import
        datafile=dat1
        out=WORK.MISE_MSTR
        dbms=xlsx
        replace
        ;
        sheet="mise_mstr";
    run;


    data WORK.MISE_MSTR;
        attrib
            MISE_CD length=$4.   label="店舗コード"
            MISE_NM length=$39.  label="店舗名称"
        ;
        set WORK.MISE_MSTR;
    run;


    proc sort data=WORK.MISE_MSTR out=MST.MISE_MSTR;
        by
            MISE_CD
        ;
    run;


    /*** コンビニ商品価格マスタ読み込み ***/
    proc import
        datafile=dat1
        out=WORK.syohin_kakaku_mstr
        dbms=xlsx
        replace
        ;
        sheet="syohin_kakaku_mstr";
    run;


    proc sort data=WORK.SYOHIN_KAKAKU_MSTR;
        by
            SYOHIN_CD UPDATE
        ;
    run;


    data MST.SYOHIN_KAKAKU_MSTR;
        attrib
            SYOHIN_CD       length=$9.  label="商品コード"
            SYOHIN_TANKA    length=8.   label="商品単価"
            UPDATE          length=8.   label="更新日付"    format=YYMMDDN8.
        ;
        set WORK.SYOHIN_KAKAKU_MSTR;
        by
            SYOHIN_CD UPDATE
        ;
        if last.SYOHIN_CD;
    run;


    /*** コンビニ商品名称マスタ（大）読み込み ***/
    proc import
        datafile=dat1
        out=WORK.SYOHIN_NAME_MSTR1
        dbms=xlsx
        replace
        ;
        sheet="syohin_name_mstr1";
    run;


    data WORK.SYOHIN_NAME_MSTR1;
        attrib
            SYOHIN_CD1 length=$2.   label="商品コード（大）"
            SYOHIN_NM1 length=$30.  label="商品名称（大）"
        ;
        set WORK.SYOHIN_NAME_MSTR1;
    run;


    proc sort data=WORK.SYOHIN_NAME_MSTR1 out=MST.SYOHIN_NAME_MSTR1;
        by
            SYOHIN_CD1
        ;
    run;


    /*** コンビニ商品売上データ読み込み ***/
    %let yyyy = %substr(&P_KIJYUN,1,4);
    %let mm = %substr(&P_KIJYUN , 5);

    %do idx = 1 %to &MM;

        %let kijun_sasdt = %sysfunc(inputn(&YYYY.01, yymmn6.));
        %let ym = %sysfunc(putn(%sysfunc(intnx(MONTH, &KIJUN_SASDT, &IDX-1)), yymmn6.));

        data WORK.URIAGE;
            infile in("conv_uri_&YM..csv") missover dsd firstobs=2;
            input
                YMD         :YYMMDD8.
                MISE_CD     :$4.
                RENO        :$8.
                SYOHIN_CD   :$9.
                KOSU        :8.
            ;
            format YMD YYMMDDN8.;
        run;


        proc sort data=WORK.URIAGE out=SDS.CONV_URI_&YM;
            by
                SYOHIN_CD
            ;
        run;

    %end;

%Mend Read_file;
%Read_file;
