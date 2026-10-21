version 17
* Native Stata/Mata table engine, version 2.4.0. No Python or shell dependency.
capture program drop pt_sample
program define pt_sample
    version 17
    syntax using/, ID(varname numeric) PANEL(string) COLUMN(string) [REPLACE]
    assert "`panel'"!="" & "`column'"!=""
    assert strlen("`panel'")<=244 & strlen("`column'")<=244
    * Capture exact observation IDs without postfile or macro-length limits.
    * IDs must belong to a common observation universe, not be renumbered per model.
    preserve
    quietly keep if e(sample)
    assert _N>0
    assert !missing(`id') & `id'==floor(`id') & abs(`id')<=9007199254740991
    isid `id'
    tempname membership
    mata: `membership'=invtokens(strtrim(strofreal(sort(st_data(.,st_local("id")),1),"%21.0f"))')
    quietly keep in 1
    quietly keep `id'
    tempvar held_id
    rename `id' `held_id'
    generate str244 panel_id="`panel'"
    generate str244 column_id="`column'"
    generate strL sample_ids=""
    mata: st_sstore(1,"sample_ids",`membership')
    mata: mata drop `membership'
    drop `held_id'
    if "`replace'"=="" {
        capture confirm file `"`using'"'
        if !_rc append using `"`using'"'
    }
    isid panel_id column_id
    sort panel_id column_id
    quietly save `"`using'"', replace
    restore
end

capture program drop pt_validate
program define pt_validate
    version 17
    assert _N>0
    foreach v in panel_id panel_title column_id column_label row_id row_label row_type value_kind source {
        confirm string variable `v'
    }
    foreach v in panel_order column_order row_order b se p q p_ri value control_mean n_obs mean_dec {
        confirm numeric variable `v'
    }
    isid panel_id column_id row_id
    assert panel_id!="" & column_id!="" & row_id!=""
    foreach v in panel_order column_order row_order {
        assert !missing(`v')
    }
    assert inlist(row_type,"coef","scalar")
    assert inlist(value_kind,"number","probability","count")
    assert missing(value) if row_type=="coef"
    foreach v in b se p q p_ri {
        assert missing(`v') if row_type=="scalar"
    }
    foreach v in p q p_ri {
        assert missing(`v') | inrange(`v',0,1)
    }
    assert missing(se) | se>=0
    assert missing(n_obs) | (n_obs>=0 & n_obs==floor(n_obs))
    assert missing(value) | (value>=0 & value==floor(value)) if value_kind=="count"
    assert missing(value) | inrange(value,0,1) if value_kind=="probability"
    assert mean_dec==-1 | inrange(mean_dec,0,12) & mean_dec==floor(mean_dec)
    foreach v in panel_title panel_order {
        bysort panel_id: assert `v'==`v'[1]
    }
    bysort panel_order: assert panel_id==panel_id[1]
    foreach v in column_label column_order source control_mean n_obs mean_dec {
        bysort panel_id column_id: assert `v'==`v'[1]
    }
    bysort panel_id column_order: assert column_id==column_id[1]
    foreach v in row_label row_order row_type {
        bysort panel_id row_id: assert `v'==`v'[1]
    }
    bysort panel_id row_order: assert row_id==row_id[1]
    foreach v in display panel_title_raw column_label_raw row_label_raw {
        capture confirm variable `v'
        if _rc generate byte `v'=cond("`v'"=="display",1,0)
        assert inlist(`v',0,1)
    }
    bysort panel_id: assert panel_title_raw==panel_title_raw[1]
    bysort panel_id column_id: assert column_label_raw==column_label_raw[1]
    bysort panel_id row_id: assert row_label_raw==row_label_raw[1]
    foreach v in table_id kind caption notes {
        local m : char _dta[pt_`v']
        if `"`m'"'=="" {
            display as error "Required dataset characteristic missing: pt_`v'"
            exit 459
        }
    }
    local kind : char _dta[pt_kind]
    assert inlist("`kind'","regression","summary")
    local label : char _dta[pt_label]
    if "`label'"!="" assert regexm("`label'","^[A-Za-z0-9:._-]+$")
    local stars : char _dta[pt_stars]
    assert inlist("`stars'","","p","q","p_ri","none")
    if "`kind'"=="regression" {
        local contrasts : char _dta[pt_contrasts]
        assert inlist("`contrasts'","","optional","first_vs_rest")
        * Optional explicit header tiers. Never infer groups from display text.
        foreach tier in header1 header2 {
            foreach field in id label {
                capture confirm variable `tier'_`field'
                if _rc generate str1 `tier'_`field'=""
                confirm string variable `tier'_`field'
                bysort panel_id column_id: assert `tier'_`field'==`tier'_`field'[1]
            }
            capture confirm variable `tier'_label_raw
            if _rc generate byte `tier'_label_raw=0
            assert inlist(`tier'_label_raw,0,1)
            bysort panel_id column_id: assert `tier'_label_raw==`tier'_label_raw[1]
            assert (`tier'_id=="")==(`tier'_label=="")
            foreach field in label label_raw {
                bysort panel_id `tier'_id: assert `tier'_`field'==`tier'_`field'[1]
            }
        }
        assert header1_id!="" if header2_id!=""
        bysort panel_id header2_id: assert header1_id==header1_id[1] if header2_id!=""
        mata: pt_check_headers()
        confirm string variable effect_id test_lhs test_rhs test_method
        foreach v in effect_id test_lhs test_rhs {
            bysort panel_id row_id: assert `v'==`v'[1]
        }
        assert effect_id!="" if row_type=="coef"
        assert test_lhs=="" & test_rhs=="" if row_type=="coef"
        assert value_kind=="probability" & test_lhs!="" & test_rhs!="" & test_method!="" if row_type=="scalar"
        mata: pt_check_contrasts()
        foreach v in outcome_id outcome_definition time estimator controls fixed_effects weights sample_restrictions se_method control_group control_sample sample_ids sample_namespace {
            confirm string variable `v'
            bysort panel_id column_id: assert `v'==`v'[1]
            if !inlist("`v'","sample_ids","sample_namespace") assert `v'!=""
        }
        mata: pt_check_samples()
        local method : char _dta[pt_q_method]
        quietly count if !missing(q)
        if r(N) | "`method'"!="" {
            if "`method'"!="Anderson-BKY-grid001-ado-f762b092" error 459
            confirm variable q_source q_family q_family_n q_family_total
            assert q_source==p | (missing(q_source) & missing(p))
            tempvar fn
            bysort q_family: egen long `fn'=count(q_source)
            assert `fn'==q_family_n if row_type=="coef"
            bysort q_family: assert _N==q_family_total if row_type=="coef"
            * Verify the complete saved family before applying display filters.
            mata: pt_check_q()
        }
        quietly count if !missing(p_ri)
        if r(N) {
            foreach v in implementation version assignment_variable assignment_unit restrictions null statistic tail repetitions seed ties mc_formula {
                local m : char _dta[pt_ri_`v']
                if `"`m'"'=="" {
                    display as error "RI provenance missing: pt_ri_`v'"
                    exit 459
                }
            }
        }
    }
    else {
        assert row_type=="scalar"
        foreach v in group_id group_label statistic {
            confirm string variable `v'
        }
        confirm numeric variable group_order summary_n
        assert missing(summary_n) | (summary_n>=0 & summary_n==floor(summary_n))
        assert inlist(statistic,"n","mean","sd")
        assert value_kind=="count" if statistic=="n"
        assert value_kind=="number" if statistic!="n"
        assert missing(value) | value>=0 if statistic=="sd"
        assert value==summary_n if statistic=="n"
        foreach v in group_id group_label group_order statistic {
            bysort panel_id column_id: assert `v'==`v'[1]
        }
        bysort panel_id group_id statistic: assert column_id==column_id[1]
        foreach v in group_order group_label {
            bysort panel_id group_id: assert `v'==`v'[1]
        }
        bysort panel_id group_order: assert group_id==group_id[1]
        bysort panel_id row_id group_id: assert summary_n==summary_n[1]
        foreach v in sample_convention groups weights n_definition missing_handling sample_restrictions {
            local m : char _dta[pt_`v']
            if `"`m'"'=="" error 459
        }
        mata: pt_check_groups()
    }
    sort panel_order row_order column_order
end

capture program drop pt_adjust
program define pt_adjust
    version 17
    syntax [, FAMILY(varname)]
    * Caller must supply the entire intended hypothesis family at this step.
    confirm variable p panel_id effect_id
    tempvar planned
    if "`family'"!="" clonevar `planned'=`family'
    capture drop q_family q_source q_family_n q_family_total
    if "`family'"=="" {
        assert effect_id!="" if row_type=="coef"
        assert strlen(panel_id)+strlen(effect_id)+12<=244
        generate str244 q_family=string(strlen(panel_id))+":"+panel_id+effect_id
    }
    else {
        assert strlen(`planned')<=244
        generate str244 q_family=`planned'
    }
    replace q_family="" if row_type!="coef"
    assert q_family!="" if row_type=="coef"
    generate double q_source=p if row_type=="coef"
    bysort q_family: egen long q_family_n=count(p)
    bysort q_family: generate long q_family_total=_N
    assert q_family_n<=32740
    replace q=.
    tempvar family_id check
    egen long `family_id'=group(q_family) if row_type=="coef"
    quietly summarize `family_id', meanonly
    forvalues f=1/`r(max)' {
        quietly fdr_sharpened_qvalues p if `family_id'==`f', generate(`check')
        quietly replace q=`check' if `family_id'==`f'
        drop `check'
    }
    char _dta[pt_q_method] "Anderson-BKY-grid001-ado-f762b092"
    char _dta[pt_q_resolution] ".001"
    char _dta[pt_q_family_definition] "Complete panel by treatment-effect family, unless explicitly supplied with family()"
end

capture program drop pt_export
program define pt_export
    version 17
    syntax using/, SAVing(string) [REPLACE PROJECT(string)]
    if lower(substr(`"`saving'"',-4,.))!=".tex" error 198
    * Stata tempfile paths can end in .tmp; use below verifies the DTA format.
    local companion=substr(`"`saving'"',1,strlen(`"`saving'"')-4)+".dta"
    mata: st_local("same",strofreal(strlower(pathresolve(pwd(),st_local("using")))==strlower(pathresolve(pwd(),st_local("companion")))))
    if "`same'"=="1" {
        display as error "Use a staging DTA distinct from the delivered companion."
        exit 198
    }
    confirm file `"`using'"'
    capture confirm file `"`saving'"'
    local oldtex=(_rc==0)
    capture confirm file `"`companion'"'
    local olddta=(_rc==0)
    if `oldtex'!=`olddta' {
        display as error "Existing TeX/DTA pair is incomplete; reconcile it before replacing."
        exit 459
    }
    if `oldtex' & "`replace'"=="" error 602
    preserve
    quietly use `"`using'"', clear
    pt_validate
    tempfile newtex newdta oldtexcopy olddtacopy
    * Save validation defaults in staged results, then render that saved file.
    quietly save `newdta'
    quietly use `newdta', clear
    mata: pt_render(st_local("newtex"))
    if `oldtex' {
        copy `"`saving'"' `oldtexcopy'
        copy `"`companion'"' `olddtacopy'
        if `"`project'"'=="" local project "."
        local archive ""
        foreach dir in archive _archive {
            mata: st_local("exists",strofreal(direxists(st_local("project")+"/`dir'")))
            if "`exists'"=="1" & `"`archive'"'=="" local archive `"`project'/`dir'"'
        }
        if `"`archive'"'!="" {
            mata: st_local("stem",pathrmsuffix(pathbasename(st_local("saving"))))
            local stamp=string(clock("`c(current_date)' `c(current_time)'","DMYhms"),"%18.0f")
            local stamp=strtrim("`stamp'")
            local k=1
            local free=0
            while !`free' {
                local archived `"`archive'/`stem'-`stamp'-`k'"'
                capture confirm file `"`archived'.tex"'
                local a=(_rc!=0)
                capture confirm file `"`archived'.dta"'
                local free=`a' & (_rc!=0)
                local ++k
            }
            copy `oldtexcopy' `"`archived'.tex"'
            copy `olddtacopy' `"`archived'.dta"'
        }
    }
    capture noisily {
        copy `newdta' `"`companion'"', replace
        copy `newtex' `"`saving'"', replace
    }
    local rc=_rc
    if `rc' {
        if `oldtex' {
            * Retain persistent recovery copies even if restoring the pair fails.
            copy `oldtexcopy' `"`saving'.recovery"', replace
            copy `olddtacopy' `"`companion'.recovery"', replace
            copy `oldtexcopy' `"`saving'"', replace
            copy `olddtacopy' `"`companion'"', replace
        }
        else {
            capture erase `"`saving'"'
            capture erase `"`companion'"'
        }
        exit `rc'
    }
    restore
    display as result `"Saved `saving' and matching DTA (native Stata/Mata)."'
end

capture program drop pt_wrapper
program define pt_wrapper
    syntax, TABLE(string)
    tempname input output
    file open `input' using "assets/wrapper.tex", read text
    file open `output' using "examples/stata/output/`table'-preview.tex", write text replace
    file read `input' line
    while r(eof)==0 {
        local line=subinstr(`"`line'"',"table.tex","`table'.tex",.)
        file write `output' `"`line'"' _n
        file read `input' line
    }
    file close `input'
    file close `output'
end

capture mata: mata drop pt_*()
mata:
string scalar pt_s(real scalar i, string scalar v) return(st_sdata(i,v))
real scalar pt_n(real scalar i, string scalar v) return(st_data(i,v))
string scalar pt_m(string scalar v) return(st_global("_dta[pt_"+v+"]"))
real scalar pt_opt(string scalar v, real scalar fallback) {
    if (pt_m(v)=="") return(fallback)
    return(strtoreal(pt_m(v)))
}
void pt_fail(string scalar message) {
    errprintf("%s\n",message)
    _error(459)
}
string scalar pt_escape(string scalar s) {
    string scalar out,c,b
    real scalar i
    out=""; b=char(92)
    for(i=1;i<=strlen(s);i++) {
        c=substr(s,i,1)
        if (c==b) out=out+b+"textbackslash{}"
        else if (strpos("&%"+char(36)+"_#{}",c)) out=out+b+c
        else if(c=="~") out=out+b+"textasciitilde{}"
        else if(c=="^") out=out+b+"textasciicircum{}"
        else out=out+c
    }
    return(out)
}
string scalar pt_text(real scalar i, string scalar v) {
    if(pt_n(i,v+"_raw")) return(pt_s(i,v))
    return(pt_escape(pt_s(i,v)))
}
string scalar pt_fmt(real scalar x, string scalar kind, real scalar dec) {
    string scalar s
    real scalar endint,start,i
    if(missing(x)) return(char(92)+"mbox{-{}-}")
    if(kind=="count") dec=0
    else if(kind=="probability") dec=3
    else if(dec<0) dec=(abs(x)<1 ? 3 : (abs(x)<100 ? 2 : 1))
    s=strtrim(strofreal(x,"%24."+strofreal(dec)+"f"))
    if(substr(s,1,1)=="-" & strtoreal(s)==0) s=substr(s,2,.)
    endint=strpos(s,".")-1
    if(endint<0) endint=strlen(s)
    start=(substr(s,1,1)=="-" ? 2 : 1)
    for(i=endint-3;i>=start;i=i-3) s=substr(s,1,i)+","+substr(s,i+1,.)
    return(s)
}
string scalar pt_stars(real scalar p) {
    if(missing(p)) return("")
    if(p<.01) return("***")
    if(p<.05) return("**")
    if(p<.10) return("*")
    return("")
}
real colvector pt_unique(real colvector I,string scalar key,string scalar ord) {
    real colvector out,J
    real scalar k
    string colvector seen
    out=J(0,1,.); seen=J(0,1,"")
    if(!rows(I)) return(out)
    J=I[order(st_data(I,ord),1)]
    for(k=1;k<=rows(J);k++) if(!any(seen:==pt_s(J[k],key))) {
        out=out\J[k]; seen=seen\pt_s(J[k],key)
    }
    return(out)
}
real colvector pt_select(real colvector I,string scalar key,string scalar val) {
    real matrix found
    if(!rows(I)) return(J(0,1,.))
    found=selectindex(st_sdata(I,key):==val)
    if(!length(found)) return(J(0,1,.))
    return(I[vec(found)])
}
void pt_check_samples() {
    real scalar i
    real rowvector ids
    string scalar s
    for(i=1;i<=st_nobs();i++) {
        s=pt_s(i,"sample_ids")
        if(s!="") {
            ids=strtoreal(tokens(s))
            if(any(missing(ids)) | any(ids:!=floor(ids)) | any(abs(ids):>9007199254740991)) pt_fail("Invalid numeric observation-ID evidence")
            if(cols(ids)!=pt_n(i,"n_obs") & pt_s(i,"weights")=="none") pt_fail("Sample membership count differs from N")
            if(pt_s(i,"sample_namespace")=="") pt_fail("Sample evidence needs a namespace")
            if(cols(ids)>1) {
                if(any(ids[2..cols(ids)]:<=ids[1..cols(ids)-1])) pt_fail("Sample IDs must be sorted and unique")
            }
        }
    }
}
real colvector pt_bky(real colvector p) {
    real colvector ans,I,rank,ps,ord
    real scalar k,qgrid,a,r1,r2,den,cut
    ans=J(rows(p),1,.)
    I=selectindex(p:<.)
    if(!length(I)) return(ans)
    ord=order(p[I],1); I=I[ord]; ps=p[I]; rank=(1::rows(I))
    ans[I]=J(rows(I),1,1)
    for(k=1000;k>=1;k--) {
        // Match the identified ado's local-expression decimal round trips.
        // These affect exact rejection boundaries (for example p=1).
        qgrid=strtoreal(strofreal(k/1000,"%18.0g"))
        a=strtoreal(strofreal(qgrid/(1+qgrid),"%18.0g"))
        r1=max(rank:*(ps:<=a:*rank/rows(I)))
        den=rows(I)-r1
        cut=(den<=0 ? 1 : min((1,strtoreal(strofreal(a*(rows(I)/den),"%18.0g")))))
        r2=max(rank:*(ps:<=cut:*rank/rows(I)))
        if(r2>0) ans[I[1::r2]]=J(r2,1,qgrid)
    }
    return(ans)
}
void pt_check_q() {
    string colvector families
    real colvector I,expected,actual
    real scalar k
    families=uniqrows(st_sdata(selectindex(st_sdata(.,"row_type"):=="coef"),"q_family"))
    for(k=1;k<=rows(families);k++) {
        I=selectindex(st_sdata(.,"q_family"):==families[k])
        expected=pt_bky(st_data(I,"q_source")); actual=st_data(I,"q")
        if(any(missing(expected):!=missing(actual))) pt_fail("Missing q inconsistent with its source family")
        I=selectindex(expected:<.)
        if(length(I)) if(any(abs(expected[I]-actual[I]):>1e-12)) pt_fail("Q-values disagree with complete saved family; recompute adjustment")
    }
}
void pt_check_contrasts() {
    real colvector P,C,I,K,E,T,J
    real scalar p,c,t,u
    string scalar first,lhs,rhs
    P=pt_unique((1::st_nobs()),"panel_id","panel_order")
    for(p=1;p<=rows(P);p++) {
        I=pt_select((1::st_nobs()),"panel_id",pt_s(P[p],"panel_id"))
        C=pt_unique(I,"column_id","column_order")
        for(c=1;c<=rows(C);c++) {
            K=pt_select(I,"column_id",pt_s(C[c],"column_id"))
            E=pt_unique(pt_select(K,"row_type","coef"),"effect_id","row_order")
            T=pt_select(K,"row_type","scalar")
            if(!rows(E)) pt_fail("Regression model lacks coefficients")
            // Every supplied contrast must reference distinct, existing effects.
            // Reversing a pair does not make it a different equality hypothesis.
            for(t=1;t<=rows(T);t++) {
                lhs=pt_s(T[t],"test_lhs"); rhs=pt_s(T[t],"test_rhs")
                if(lhs==rhs | !any(st_sdata(E,"effect_id"):==lhs) | !any(st_sdata(E,"effect_id"):==rhs)) pt_fail("Invalid equality-test coefficient reference")
                for(u=1;u<t;u++) {
                    if((lhs==pt_s(T[u],"test_lhs") & rhs==pt_s(T[u],"test_rhs")) | (lhs==pt_s(T[u],"test_rhs") & rhs==pt_s(T[u],"test_lhs"))) pt_fail("Duplicate equality-test pair")
                }
            }
            if(pt_m("contrasts")!="first_vs_rest") continue
            if(rows(T)!=rows(E)-1) pt_fail("Require one first-effect equality p-value for each other effect")
            first=pt_s(E[1],"effect_id")
            for(t=2;t<=rows(E);t++) {
                J=pt_select(pt_select(T,"test_lhs",first),"test_rhs",pt_s(E[t],"effect_id"))
                if(rows(J)!=1) pt_fail("Missing or duplicate treatment-equality test")
            }
        }
    }
}
void pt_check_groups() {
    real colvector P,G,I,J
    real scalar p,g
    P=pt_unique((1::st_nobs()),"panel_id","panel_order")
    for(p=1;p<=rows(P);p++) {
        I=pt_select((1::st_nobs()),"panel_id",pt_s(P[p],"panel_id"))
        G=pt_unique(I,"group_id","group_order")
        for(g=1;g<=rows(G);g++) {
            J=pt_select(I,"group_id",pt_s(G[g],"group_id"))
            if(!any(st_sdata(J,"statistic"):=="mean") | !any(st_sdata(J,"statistic"):=="sd") | !any(st_sdata(J,"statistic"):=="n")) pt_fail("Summary groups require explicit mean, SD and N columns")
        }
    }
}
string scalar pt_cell(real scalar i,string scalar stat) {
    string scalar val,kind,source,mark
    if(missing(i)) return("")
    kind=(stat=="value" ? pt_s(i,"value_kind") : (anyof(("p","q","p_ri"),stat) ? "probability" : "number"))
    val=pt_fmt(pt_n(i,stat),kind,-1)
    if(stat=="b" & !missing(pt_n(i,stat))) {
        source=pt_m("stars"); if(source=="") source="p"
        if(source!="none") {
            if(!anyof(("p","q","p_ri"),source)) pt_fail("Unsupported star source")
            mark=pt_stars(pt_n(i,source))
            if(mark!="") val=val+char(36)+"^{"+mark+"}"+char(36)
        }
    }
    if(stat=="se") val="("+val+")"
    if(stat=="q") val="["+val+"]"
    if(stat=="p_ri") val=char(92)+"{"+val+char(92)+"}"
    return(val)
}
string scalar pt_line(string rowvector cells,real scalar keep) {
    return(invtokens(cells," & ")+" "+char(92)+char(92)+(keep ? "*" : ""))
}
void pt_check_headers() {
    real colvector P,I,C
    real scalar p,t,c
    string scalar key,last,current
    string colvector seen
    P=pt_unique((1::st_nobs()),"panel_id","panel_order")
    for(p=1;p<=rows(P);p++) {
        I=pt_select((1::st_nobs()),"panel_id",pt_s(P[p],"panel_id"))
        C=pt_unique(I,"column_id","column_order")
        for(t=1;t<=2;t++) {
            key="header"+strofreal(t)+"_id"; last=""; seen=J(0,1,"")
            for(c=1;c<=rows(C);c++) {
                current=pt_s(C[c],key)
                if(current!=last & current!="") {
                    if(any(seen:==current)) pt_fail("Header groups must occupy contiguous columns")
                    seen=seen\current
                }
                last=current
            }
        }
    }
}
// A centered paragraph span uses exactly the width of its constituent columns.
string scalar pt_span_spec(real scalar span,real scalar width) {
    real scalar fraction
    string scalar b
    b=char(92)
    fraction=span*(1-min((.6,pt_opt("row_width_cm",3.2)/(pt_opt("row_width_cm",3.2)+width*pt_opt("data_width_cm",2.1)))))/width
    return(">{"+b+"centering"+b+"arraybackslash}p{"+b+"dimexpr"+strofreal(fraction,"%9.6f")+b+"PTwidth-2"+b+"tabcolsep"+b+"relax}")
}
string colvector pt_reg_headers(real colvector C,real scalar width) {
    real scalar t,c,last,pad
    string scalar b,key,rules
    string rowvector cells
    string colvector out
    b=char(92); out=J(0,1,"")
    for(t=1;t<=2;t++) {
        key="header"+strofreal(t)
        if(!any(st_sdata(C,key+"_id"):!="")) continue
        cells=""; rules=""; c=1
        while(c<=rows(C)) {
            last=c
            if(pt_s(C[c],key+"_id")!="") {
                while(last<rows(C)) {
                    if(pt_s(C[last+1],key+"_id")!=pt_s(C[c],key+"_id")) break
                    last++
                }
                cells=cells,b+"multicolumn{"+strofreal(last-c+1)+"}{"+pt_span_spec(last-c+1,width)+"}{"+pt_text(C[c],key+"_label")+"}"
                rules=rules+b+"cmidrule(lr){"+strofreal(c+1)+"-"+strofreal(last+1)+"} "
            }
            else cells=cells,""
            c=last+1
        }
        for(pad=rows(C);pad<width;pad++) cells=cells,""
        out=out\pt_line(cells,1)\strtrim(rules)
    }
    return(out)
}
real scalar pt_find(real colvector I,string scalar col) {
    real colvector J
    J=pt_select(I,"column_id",col)
    return(rows(J) ? J[1] : .)
}
string colvector pt_head(real colvector I,real scalar width,real scalar continued,real scalar headings,real scalar panel_heading) {
    real colvector C
    string colvector out
    string rowvector labels,groups
    string scalar b,title,rules,group_spec
    real scalar c,groupfrac,padded
    b=char(92); title=pt_text(I[1],"panel_title")+(continued ? " (continued)" : "")
    out=J(0,1,"")
    if(panel_heading) out=b+"multicolumn{"+strofreal(width+1)+"}{@{}>{"+b+"centering"+b+"arraybackslash}p{"+b+"PTwidth}@{}}{"+b+"textbf{"+title+"}} "+b+b+"*" \ b+"hline"
    if(headings) {
        labels=""
        if(pt_m("kind")=="regression") {
            C=pt_unique(I,"column_id","column_order")
            out=out\pt_reg_headers(C,width)
            for(c=1;c<=rows(C);c++) labels=labels,pt_text(C[c],"column_label")
        }
        else {
            C=pt_unique(I,"group_id","group_order")
            // Each group name spans its Mean (SD) and N columns exactly once.
            // A paragraph span wraps long names within the existing two-column width.
            groupfrac=2*(1-min((.6,pt_opt("row_width_cm",3.2)/(pt_opt("row_width_cm",3.2)+width*pt_opt("data_width_cm",2.1)))))/width
            group_spec=">{"+b+"centering"+b+"arraybackslash}p{"+b+"dimexpr"+strofreal(groupfrac,"%9.6f")+b+"PTwidth-2"+b+"tabcolsep"+b+"relax}"
            groups=""; rules=""
            for(c=1;c<=rows(C);c++) {
                groups=groups,b+"multicolumn{2}{"+group_spec+"}{"+pt_escape(pt_s(C[c],"group_label"))+"}"
                rules=rules+b+"cmidrule(lr){"+strofreal(2*c)+"-"+strofreal(2*c+1)+"} "
                labels=labels,"Mean (SD)","N"
            }
            for(padded=2*rows(C);padded<width;padded++) groups=groups,""
            out=out\pt_line(groups,1)\strtrim(rules)
        }
        while(cols(labels)<width+1) labels=labels,""
        out=out\pt_line(labels,1)\b+"hline"
    }
    return(out)
}
string colvector pt_body(real colvector I,real scalar width,real scalar show_n) {
    real colvector R,C,J,K,L
    real scalar r,c,k,x
    string colvector out
    string rowvector stats,cells,sds
    string scalar b,sd
    b=char(92); out=J(0,1,"")
    R=pt_unique(I,"row_id","row_order")
    if(pt_m("kind")=="regression") R=pt_select(R,"row_type","coef")\pt_select(R,"row_type","scalar")
    C=pt_unique(I,(pt_m("kind")=="regression" ? "column_id" : "group_id"),(pt_m("kind")=="regression" ? "column_order" : "group_order"))
    for(r=1;r<=rows(R);r++) {
        J=pt_select(I,"row_id",pt_s(R[r],"row_id"))
        if(pt_m("kind")=="summary") {
            cells=pt_text(R[r],"row_label"); sds=""
            for(c=1;c<=rows(C);c++) {
                K=pt_select(J,"group_id",pt_s(C[c],"group_id"))
                L=pt_select(K,"statistic","mean"); cells=cells,pt_cell((rows(L) ? L[1] : .),"value")
                L=pt_select(K,"statistic","n"); cells=cells,pt_cell((rows(L) ? L[1] : .),"value")
                L=pt_select(K,"statistic","sd"); sd=pt_cell((rows(L) ? L[1] : .),"value")
                sds=sds,(sd=="" ? "" : "("+sd+")"),""
            }
            while(cols(cells)<width+1) {
                cells=cells,""
                sds=sds,""
            }
            out=out\pt_line(cells,1)\pt_line(sds,0)
        }
        else {
            stats="value"
            if(pt_s(R[r],"row_type")=="coef") {
                stats="b","se"
                if(any(st_data(J,"q"):<.)) stats=stats,"q"
                if(any(st_data(J,"p_ri"):<.)) stats=stats,"p_ri"
            }
            for(k=1;k<=cols(stats);k++) {
                cells=(k==1 ? pt_text(R[r],"row_label") : "")
                for(c=1;c<=rows(C);c++) cells=cells,pt_cell(pt_find(J,pt_s(C[c],"column_id")),stats[k])
                while(cols(cells)<width+1) cells=cells,""
                out=out\pt_line(cells,k<cols(stats))
            }
        }
    }
    if(pt_m("kind")=="regression") {
        cells="Control mean"
        for(c=1;c<=rows(C);c++) cells=cells,pt_fmt(pt_n(C[c],"control_mean"),"number",pt_n(C[c],"mean_dec"))
        while(cols(cells)<width+1) cells=cells,""
        out=out\b+"hline"\pt_line(cells,0)
        if(show_n) {
            cells="N"
            for(c=1;c<=rows(C);c++) cells=cells,pt_fmt(pt_n(C[c],"n_obs"),"count",0)
            while(cols(cells)<width+1) cells=cells,""
            out=out\b+"hline"\pt_line(cells,0)
        }
    }
    return(out)
}
void pt_render(string scalar destination) {
    real colvector ALL,P,I,C,firstC
    real scalar width,p,c,heads,shared,land,multi,nlines,natural,limit,tab,rowfrac,colfrac,fh,k
    string scalar b,caption,notes,source,spec,w,span,dim,control,cur,symbol,label,key
    string colvector out,body
    b=char(92); ALL=selectindex(st_data(.,"display"):==1)
    if(!rows(ALL)) pt_fail("No displayed cells")
    P=pt_unique(ALL,"panel_id","panel_order")
    width=0; heads=pt_m("kind")=="regression"; shared=heads; nlines=0
    for(p=1;p<=rows(P);p++) {
        I=pt_select(ALL,"panel_id",pt_s(P[p],"panel_id"))
        C=pt_unique(I,(pt_m("kind")=="regression" ? "column_id" : "group_id"),(pt_m("kind")=="regression" ? "column_order" : "group_order"))
        width=max((width,rows(C)*(pt_m("kind")=="summary" ? 2 : 1)))
        if(p==1) firstC=C
        if(rows(C)!=rows(firstC)) {
            heads=0
            shared=0
        }
        else if(pt_m("kind")=="regression") for(c=1;c<=rows(C);c++) {
            if(pt_n(C[c],"column_label_raw")!=pt_n(firstC[c],"column_label_raw")) heads=0
            if(pt_s(C[c],"outcome_id")!=pt_s(firstC[c],"outcome_id") | pt_s(C[c],"outcome_definition")!=pt_s(firstC[c],"outcome_definition") | pt_s(C[c],"time")!=pt_s(firstC[c],"time")) shared=0
            if(pt_s(C[c],"outcome_id")!=pt_s(firstC[c],"outcome_id") | pt_s(C[c],"outcome_definition")!=pt_s(firstC[c],"outcome_definition") | pt_s(C[c],"time")!=pt_s(firstC[c],"time") | pt_s(C[c],"column_label")!=pt_s(firstC[c],"column_label")) heads=0
            for(k=1;k<=2;k++) {
                key="header"+strofreal(k)
                if(pt_s(C[c],key+"_id")!=pt_s(firstC[c],key+"_id") | pt_s(C[c],key+"_label")!=pt_s(firstC[c],key+"_label") | pt_n(C[c],key+"_label_raw")!=pt_n(firstC[c],key+"_label_raw")) heads=0
            }
            if(pt_s(C[c],"sample_ids")=="" | pt_s(C[c],"sample_ids")!=pt_s(firstC[c],"sample_ids") | pt_s(C[c],"sample_namespace")!=pt_s(firstC[c],"sample_namespace") | pt_n(C[c],"n_obs")!=pt_n(firstC[c],"n_obs")) shared=0
        }
        nlines=nlines+rows(pt_body(I,width,1))+(pt_m("kind")=="summary" ? 9 : 7)
        if(rows(P)==1) nlines=nlines-2
        if(pt_m("kind")=="regression") nlines=nlines+rows(pt_reg_headers(C,width))
    }
    shared=shared & pt_opt("share_n",1)
    heads=heads & pt_opt("share_headings",1)
    natural=pt_opt("row_width_cm",3.2)+width*pt_opt("data_width_cm",2.1)
    if(pt_opt("row_width_cm",3.2)<=0 | pt_opt("data_width_cm",2.1)<=0 | pt_opt("small_table_width_fraction",.85)<0 | pt_opt("small_table_width_fraction",.85)>1) pt_fail("Invalid column width or minimum width fraction")
    land=(width>7 | natural>pt_opt("portrait_width_cm",16) | pt_m("orientation")=="landscape")
    if(pt_m("orientation")=="portrait") land=0
    limit=pt_opt((land ? "landscape_width_cm" : "portrait_width_cm"),(land ? 23 : 16))
    if((limit-pt_opt("row_width_cm",3.2))/width<1.25) pt_fail("Columns too narrow; split the table")
    tab=min((limit,max((natural,(width==2 | width==3 ? pt_opt("small_table_width_fraction",.85)*limit : 0)))))
    // Preserve natural proportions as small tables widen: label column grows too.
    rowfrac=min((.6,pt_opt("row_width_cm",3.2)/natural)); colfrac=(1-rowfrac)/width
    multi=(pt_m("layout")=="multipage" | nlines>pt_opt("page_lines",(land ? 32 : 48)))
    if(pt_m("layout")=="standard" & multi) pt_fail("Table height requires multipage layout")
    dim=b+"dimexpr"
    spec="@{}>{"+b+"raggedright"+b+"arraybackslash}p{"+dim+strofreal(rowfrac,"%9.6f")+b+"PTwidth-"+b+"tabcolsep"+b+"relax}*{"+strofreal(width)+"}{>{"+b+"centering"+b+"arraybackslash}p{"+dim+strofreal(colfrac,"%9.6f")+b+"PTwidth-2"+b+"tabcolsep"+b+"relax}}@{}"
    span=strofreal(width+1)
    caption=(pt_opt("caption_raw",0) ? pt_m("caption") : pt_escape(pt_m("caption")))
    label=(pt_m("label")=="" ? "" : b+"label{"+pt_m("label")+"}")
    notes=(pt_opt("notes_raw",0) ? pt_m("notes") : pt_escape(pt_m("notes")))
    if(pt_m("kind")=="regression") {
        source=pt_m("stars"); if(source=="") source="p"
        cur="Standard errors appear in round brackets. "
        if(any(st_data(ALL,"q"):<.)) cur=cur+"Square brackets contain sharpened q-values. "
        if(any(st_data(ALL,"p_ri"):<.)) cur=cur+"Curly brackets contain randomization-inference p-values. "
        if(source=="none") control="No significance stars. "
        else {
            control=(source=="p" ? "conventional p-values" : (source=="q" ? "sharpened q-values" : "RI p-values"))
            symbol=(source=="q" ? "q" : (source=="p_ri" ? "p_{RI}" : "p"))
            control="* "+char(36)+symbol+"<0.10"+char(36)+", ** "+char(36)+symbol+"<0.05"+char(36)+", *** "+char(36)+symbol+"<0.01"+char(36)+", using "+control+". "
        }
        notes=control+cur+notes
    }
    notes=b+"item "+b+"textit{Notes:} "+notes
    out="% Native Stata/Mata pt_tables 2.4.0; rendered from saved companion results."\b+"begingroup"\b+"small"\b+"setlength{"+b+"tabcolsep}{4pt}"\b+"renewcommand{"+b+"arraystretch}{1.12}"
    if(land) out=out\b+"begin{landscape}"
    out=out\b+"ifdefined"+b+"PTwidth"+b+"else"+b+"newlength{"+b+"PTwidth}"+b+"fi"\b+"setlength{"+b+"PTwidth}{"+strtrim(strofreal(tab,"%9.3f"))+"cm}"\b+"ifdim"+b+"PTwidth>"+b+"linewidth"+b+"setlength{"+b+"PTwidth}{"+b+"linewidth}"+b+"fi"
    if(!multi) {
        out=out\b+"begin{table}[htbp]"+b+"centering"\b+"begin{threeparttable}"\b+"caption{"+caption+"}"+label\b+"begin{tabular}{"+spec+"}"\b+"toprule"
        for(p=1;p<=rows(P);p++) {
            I=pt_select(ALL,"panel_id",pt_s(P[p],"panel_id"))
            if(p>1) out=out\b+"midrule"
            out=out\pt_head(I,width,0,p==1 | !heads,rows(P)>1)\pt_body(I,width,p==rows(P) | !shared)
        }
        out=out\b+"hline"\b+"bottomrule"\b+"end{tabular}"\b+"begin{tablenotes}[flushleft]"+b+"footnotesize"\notes\b+"end{tablenotes}"\b+"end{threeparttable}"\b+"end{table}"
    }
    else {
        for(p=1;p<=rows(P);p++) {
            I=pt_select(ALL,"panel_id",pt_s(P[p],"panel_id"))
            if(p>1) out=out\b+"clearpage"\b+"addtocounter{table}{-1}"
            out=out\b+"begin{ThreePartTable}"\b+"begin{longtable}{"+spec+"}"\b+"caption{"+caption+(p>1 ? " (continued)" : "")+"}"+(p==1 ? label : "")+b+b\b+(p==1 ? "toprule" : "midrule")\pt_head(I,width,0,1,rows(P)>1)\b+"endfirsthead"
            out=out\b+"caption[]{"+caption+" (continued)}"+b+b\b+"toprule"\pt_head(I,width,1,1,rows(P)>1)\b+"endhead"\b+"midrule"\b+"multicolumn{"+span+"}{r}{Continued on next page}"+b+b\b+"endfoot"\b+"noalign{"+b+"vskip0pt}"\b+"endlastfoot"
            body=pt_body(I,width,p==rows(P) | !shared)
            if(p==rows(P)) body[rows(body)]=body[rows(body)]+"*"
            out=out\body
            if(p==rows(P)) out=out\b+"multicolumn{"+span+"}{@{}l@{}}{"\b+"begin{tabular}{@{}p{"+b+"PTwidth}@{}}"\b+"hline"\b+"bottomrule"\b+"begin{minipage}{"+b+"PTwidth}"\b+"begin{tablenotes}[flushleft]"+b+"footnotesize"\notes\b+"end{tablenotes}"\b+"end{minipage}"+b+b\b+"end{tabular}}"+b+b
            out=out\b+"end{longtable}"\b+"end{ThreePartTable}"
        }
    }
    if(land) out=out\b+"end{landscape}"
    out=out\b+"endgroup"
    fh=fopen(destination,"w")
    for(k=1;k<=rows(out);k++) fput(fh,out[k])
    fclose(fh)
}
end
