/*******************************************************************************
    File name:      fdr_sharpened_qvalues.ado
    Project:        tex-tables
    Date created:   2026-04-15
    Date last edited: 2026-04-15
    Author:         Sarim Zafar

    Description:    This ado-file computes Benjamini, Krieger, and Yekutieli
                    (2006) sharpened two-stage q-values following the Anderson
                    false discovery rate procedure. It is adapted into a
                    programmatic form for use in the active regression-table
                    workflow.

*******************************************************************************/

capture program drop fdr_sharpened_qvalues
program define fdr_sharpened_qvalues

    version 17

    syntax varname(numeric) [if] [in], generate(name)

    marksample touse, novarlist

    capture confirm new variable `generate'
    if (_rc != 0) {
        display as error ///
            "generate() must name a new variable for the sharpened q-values."
        exit 110
    }

    tempvar sample_flag original_order rank
    tempvar fdr_stage1 reject_stage1 reject_rank1 total_rejected1
    tempvar fdr_stage2 reject_stage2 reject_rank2 total_rejected2

    quietly generate byte `sample_flag' = `touse' & !missing(`varlist')
    quietly generate double `generate' = .

    quietly count if `sample_flag'
    local total_pvalues = r(N)

    if (`total_pvalues' == 0) {
        exit
    }

    quietly generate long `original_order' = _n
    quietly sort `sample_flag' `varlist'
    quietly generate int `rank' = sum(`sample_flag') if `sample_flag'
    quietly replace `generate' = 1 if `sample_flag'

    forvalues q_index = 1000(-1)1 {
        local q_value = `q_index' / 1000
        local q_stage1 = `q_value' / (1 + `q_value')

        quietly generate double `fdr_stage1' = ///
            `q_stage1' * `rank' / `total_pvalues' if `sample_flag'
        quietly generate byte `reject_stage1' = ///
            (`fdr_stage1' >= `varlist') if `sample_flag'
        quietly generate int `reject_rank1' = ///
            `reject_stage1' * `rank' if `sample_flag'
        quietly egen int `total_rejected1' = max(`reject_rank1')
        quietly summarize `total_rejected1', meanonly

        local rejected_stage1 = r(max)
        if (missing(`rejected_stage1')) {
            local rejected_stage1 = 0
        }

        local stage2_denom = `total_pvalues' - `rejected_stage1'
        if (`stage2_denom' <= 0) {
            local q_stage2 = 1
        }
        else {
            local q_stage2 = ///
                `q_stage1' * (`total_pvalues' / `stage2_denom')
        }

        if (`q_stage2' > 1) {
            local q_stage2 = 1
        }

        quietly generate double `fdr_stage2' = ///
            `q_stage2' * `rank' / `total_pvalues' if `sample_flag'
        quietly generate byte `reject_stage2' = ///
            (`fdr_stage2' >= `varlist') if `sample_flag'
        quietly generate int `reject_rank2' = ///
            `reject_stage2' * `rank' if `sample_flag'
        quietly egen int `total_rejected2' = max(`reject_rank2')
        quietly summarize `total_rejected2', meanonly

        local rejected_stage2 = r(max)
        if (missing(`rejected_stage2')) {
            local rejected_stage2 = 0
        }

        quietly replace `generate' = `q_value' if ///
            `rank' <= `rejected_stage2' & `rank' < .

        drop `fdr_stage1' `reject_stage1' `reject_rank1' `total_rejected1'
        drop `fdr_stage2' `reject_stage2' `reject_rank2' `total_rejected2'
    }

    quietly sort `original_order'
    drop `sample_flag' `original_order' `rank'

end
