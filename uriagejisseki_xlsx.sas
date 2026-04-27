libname sds "C:\temp\sds";
libname mst "C:\temp\mst";

%let OUT_PATH = C:\temp\out;
libname out "&OUT_PATH";


/***
    基準年月設定
***/
%let P_KIJYUN = 200504;


%Macro Uriagejisseki_XLSX;

    data _NULL_;
        call symput('YYYY', substr("&P_KIJYUN", 1, 4));
        call symputx('MM', input(substr("&P_KIJYUN", 5, 2), 2.));
    run;

    /*** 組み合わせデータ作成 ***/
    data WORK.MISE_MSTR;
        set MST.MISE_MSTR end=last;

        output;

        if last then do;
            MISE_CD = "9999";
            MISE_NM = "店舗合計";
            output;
        end;
    run;

    proc sql;
        create table WORK.SYOHIN_MISE_MSTR as
        select
            SYOHIN_CD1,
            SYOHIN_NM1,
            MISE_CD,
            MISE_NM
        from
            WORK.MISE_MSTR , MST.SYOHIN_NAME_MSTR1
        order by
            SYOHIN_CD1,
            MISE_CD
        ;
    quit;

    %do idx = 1 %to &MM;

        %let kijun_sasdt = %sysfunc(inputn(&YYYY.01, yymmn6.));
        %let ym = %sysfunc(putn(%sysfunc(intnx(MONTH, &KIJUN_SASDT, &IDX-1)), yymmn6.));

        data WORK.URIAGE;
            merge
                MST.SYOHIN_KAKAKU_MSTR(in=in1)
                SDS.CONV_URI_&YM(in=in2)
            ;
            by SYOHIN_CD;

            if in1 and in2;

            length URI_YM $6 SYOHIN_CD1 $2;
            URI_YM = substr(put(YMD,YYMMDDN8.),1,6);

            SYOHIN_CD1 = substr(SYOHIN_CD,1,2);

            URIAGE = KOSU * SYOHIN_TANKA;

            keep
                MISE_CD SYOHIN_CD1 URI_YM URIAGE
            ;
        run;

        proc sort data=WORK.URIAGE;
            by SYOHIN_CD1 MISE_CD;
        run;

        * 売上額の合計を算出;
        data WORK.URIAGE_SUM;
            set WORK.URIAGE;
            by SYOHIN_CD1 MISE_CD;

            if first.SYOHIN_CD1 then __URIAGE_TOT = 0;
            if first.MISE_CD then __URIAGE_SUM = 0;

            __URIAGE_SUM + URIAGE;

            __URIAGE_TOT + URIAGE;

            if last.MISE_CD then output;
            if last.SYOHIN_CD1 then do;
                __URIAGE_SUM = __URIAGE_TOT;
                MISE_CD = "9999";
                output;
            end;
        run;

        %if &IDX = 1 %then %do;
            data WORK.URIAGE_ALL;
                set WORK.URIAGE_SUM(obs=0);
            run;
        %end;

        data WORK.URIAGE_ALL;
            set WORK.URIAGE_ALL
                WORK.URIAGE_SUM;
            by SYOHIN_CD1 MISE_CD;
        run;

    %end;

    proc sql;
        create table WORK.URIAGE_ALL_NM as
        select
            t1.SYOHIN_CD1,
            t1.SYOHIN_NM1,
            t1.MISE_CD,
            t1.MISE_NM,
            t2.URI_YM,
            t2.__URIAGE_SUM
        from
            WORK.SYOHIN_MISE_MSTR t1
            inner join
                WORK.URIAGE_ALL t2
            on
                t1.SYOHIN_CD1 = t2.SYOHIN_CD1
            and t1.MISE_CD = t2.MISE_CD
        order by
            t1.SYOHIN_CD1,
            t1.SYOHIN_NM1,
            t2.URI_YM,
            t1.MISE_CD
        ;
    quit;

    * 転置;
    proc transpose data=WORK.URIAGE_ALL_NM out=WORK.URIAGE_ALL_TRAN prefix=URIAGE_;
        by SYOHIN_CD1 SYOHIN_NM1 URI_YM;
        var __URIAGE_SUM;
        id MISE_CD;
        idl MISE_NM;
    run;


    data WORK.URIAGE_JISSEKI_&P_KIJYUN;
        set WORK.URIAGE_ALL_TRAN;
        by SYOHIN_CD1;

        output;

        retain URIAGE:;

        array URIAGE_(*) URIAGE_:;
        array __URI(100) _TEMPORARY_;

        if first.SYOHIN_CD1 then do;
            do i= 1 to dim(URIAGE_);
                __URI(i) = 0;
            end;
        end;

        do i= 1 to dim(URIAGE_);
            __URI(i) + URIAGE_(i) ;
        end;

        if last.SYOHIN_CD1 then do;
            do i= 1 to dim(URIAGE_);
                URIAGE_(i) = __URI(i) ;
            end;

            URI_YM = "合計";
            output;
        end;

        drop _NAME_ i;
    run;


    /*** ファイル出力処理 ***/
    proc sort data=WORK.URIAGE_JISSEKI_&P_KIJYUN out=WORK.SYOHIN nodupkey;
        by SYOHIN_CD1;
    run;

    * 商品コード（大）マクロ変数化;
    data _NULL_;
        set WORK.SYOHIN end=last nobs=obs;

        call symput(cats("S_CD",_N_),SYOHIN_CD1);

        if last then
            call symputx("S_CNT",_N_);
    run;

    * ファイル出力;
    %do idx = 1 %to &S_CNT;
        proc export
            data=WORK.URIAGE_JISSEKI_&P_KIJYUN(where=(SYOHIN_CD1 = "&&S_CD&IDX"))
            file="&OUT_PATH.\uriage_jisseki_&P_KIJYUN..xlsx"
            dbms = xlsx
            replace
            label
            ;
            sheet="&&S_CD&IDX"
            ;
        run;
    %end;

%Mend Uriagejisseki_XLSX;
%Uriagejisseki_XLSX;
