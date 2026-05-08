libname sds "C:\temp\sds";
libname mst "C:\temp\mst";

%let OUT_PATH = C:\temp\out;
libname out "&OUT_PATH";
filename out "&OUT_PATH";

/***
    基準年月設定
***/
%let P_KIJYUN = 200504;


%Macro Uriagejisseki_csv;

    data _NULL_;
        call symput('YYYY', substr("&P_KIJYUN", 1, 4));
        call symputx('MM', input(substr("&P_KIJYUN", 5, 2), 2.));
    run;

    /*** 組み合わせデータ作成 ***/
    proc sql;
        create table WORK.SYOHIN_MISE_MSTR as
        select
            SYOHIN_CD1,
            SYOHIN_NM1,
            MISE_CD,
            MISE_NM
        from
            MST.MISE_MSTR , MST.SYOHIN_NAME_MSTR1
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

        run;


        proc summary data=WORK.URIAGE nway;
            class SYOHIN_CD1 MISE_CD;
            var URIAGE;
            output out=WORK.URIAGE_SUM&IDX(drop=_TYPE_ _FREQ_) sum=URIAGE_&IDX;
        run;

/*        data WORK.URIAGE_SUM2;*/
/*            set WORK.URIAGE_SUM2;*/
/*            if MISE_CD = "0132" then URIAGE_2 = .;*/
/*        run;*/

    %end;


    /*** 整形・保存 ***/
    data OUT.URIAGE_JISSEKI_&P_KIJYUN;
        format
            SYOHIN_CD1 SYOHIN_NM1 MISE_CD MISE_NM
        ;
        attrib
            URIAGE_1        label="1月売上"
            URIAGE_2        label="2月売上"
            URIAGE_3        label="3月売上"
            URIAGE_4        label="4月売上"
            URIAGE_5        label="5月売上"
            URIAGE_6        label="6月売上"
            URIAGE_KAMI     label="上期売上"
            URIAGE_7        label="7月売上"
            URIAGE_8        label="8月売上"
            URIAGE_9        label="9月売上"
            URIAGE_10       label="10月売上"
            URIAGE_11       label="11月売上"
            URIAGE_12       label="12月売上"
            URIAGE_SHIMO    label="下期売上"
            URIAGE_NEN      label="年間売上"
        ;
        merge
            WORK.SYOHIN_MISE_MSTR(in=in1)
            WORK.URIAGE_SUM1 - WORK.URIAGE_SUM&MM
        ;
        by SYOHIN_CD1 MISE_CD;
        if in1;

        array __URIAGE(12) URIAGE_1 - URIAGE_12;
        do i = 1 to 12;
            if i <= &MM and __URIAGE(i) = . then __URIAGE(i) = 0;

            * 1000円単位切り上げ ;
            if __URIAGE(i) ^= . then __URIAGE(i) = ceil(__URIAGE(i) / 1000);         
        end;

        * 上期・下期・年間売上算出 ;
        URIAGE_KAMI = sum(of URIAGE_1-URIAGE_6);
        if &MM >= 7 then URIAGE_SHIMO = sum(of URIAGE_7-URIAGE_12);

        URIAGE_NEN = sum(of URIAGE_1-URIAGE_12);

        drop i;
    run;


    /*** ファイル出力処理 ***/
    proc sort data=OUT.URIAGE_JISSEKI_&P_KIJYUN out=WORK.SYOHIN nodupkey;
        by SYOHIN_CD1;
    run;

    * 商品コード（大）マクロ変数化;
    data _NULL_;
        set WORK.SYOHIN end=last nobs=obs;

        call symput(cats("S_CD",_N_),SYOHIN_CD1);

        if last then
            call symputx("S_CNT",_N_);
    run;


    * ラベル・変数マクロ変数化;
    data _NULL_;
        set SASHELP.VCOLUMN end=last;
        where
            libname = "OUT" and MEMNAME = "URIAGE_JISSEKI_&P_KIJYUN"
        ;
        length LBL $1000;
        retain LBL ;
        LBL = catx(",",LBL,ktrim(LABEL));

        call symput(cats("VAR",_N_),trim(NAME));

        if last then do;
            call symput("LBL", ktrim(LBL));
            call symputx("V_CNT",_N_);
        end;
    run;

    * ファイル出力;
    %do idx = 1 %to &S_CNT;
        
        data _NULL_;
            set OUT.URIAGE_JISSEKI_&P_KIJYUN;
            where
                SYOHIN_CD1 = "&&S_CD&IDX"
            ;
            file OUT("uriage_jisseki_&&S_CD&IDX.._&P_KIJYUN..csv") dlm=",";
            
            if _N_=1 then do;
                put
                    "&LBL"
                ;
            end;

            put
                %do i = 1 %to &V_CNT;
                   &&VAR&I
                %end;
            ;
        run;
    %end;

%Mend Uriagejisseki_csv;
%Uriagejisseki_csv;
