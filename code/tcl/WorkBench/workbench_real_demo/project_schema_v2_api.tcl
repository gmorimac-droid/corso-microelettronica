namespace eval project {
    variable data {}

    # --------------------------------------------------
    # Basic utilities
    # --------------------------------------------------
    proc now {} {
        return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    }

    proc _normalize_list_section {section} {
        variable data
        if {![dict exists $data $section]} {
            dict set data $section {}
        }
    }

    proc _root_defaults {} {
        return [dict create \
            schemaVersion 2 \
            project [dict create \
                projectId PRJ001 \
                name "Engineering Workbench Project" \
                description "" \
                rootDir "." \
                createdAt [project::now] \
                updatedAt [project::now] \
                owner "" \
                domains {radar satellite underwater hdl} \
                tags {}] \
            settings [dict create \
                defaultOutputRoot "./runs" \
                defaultBaselineDir "./baselines" \
                defaultWorkflowDir "./workflows" \
                defaultConfigDir "./configs" \
                autoRegisterArtifacts 1 \
                autoBindBaseline 1 \
                autoCreateTimelineEvents 1 \
                preferredValidationMode "thresholds"] \
            experiments {} \
            testcases {} \
            testsuites {} \
            workflows {} \
            runs {} \
            artifacts {} \
            validationResults {} \
            timelineEvents {} \
            budgets {} \
            indexes [dict create]]
    }

    proc reset {} {
        variable data
        set data [project::_root_defaults]
        return $data
    }

    proc get_data {} {
        variable data
        return $data
    }

    proc set_data {newData} {
        variable data
        set data $newData
        return $data
    }

    proc touch_project {} {
        variable data
        dict set data project updatedAt [project::now]
    }

    # --------------------------------------------------
    # Project load/save
    # --------------------------------------------------
    proc new {{name "Engineering Workbench Project"} {rootDir "."}} {
        variable data
        set data [project::_root_defaults]
        dict set data project name $name
        dict set data project rootDir $rootDir
        dict set data project createdAt [project::now]
        dict set data project updatedAt [project::now]
        return $data
    }

    proc save {path} {
        variable data
        project::touch_project
        set ch [open $path w]
        puts $ch $data
        close $ch
        return $path
    }

    proc load {path} {
        variable data
        set ch [open $path r]
        set raw [read $ch]
        close $ch

        # Raw Tcl dict serialization
        set loaded $raw

        if {![dict exists $loaded schemaVersion]} {
            error "Project file senza schemaVersion"
        }

        set data $loaded

        foreach sec {experiments testcases testsuites workflows runs artifacts validationResults timelineEvents budgets} {
            project::_normalize_list_section $sec
        }
        if {![dict exists $data indexes]} {
            dict set data indexes [dict create]
        }

        return $data
    }

    # --------------------------------------------------
    # Generic list-section helpers
    # --------------------------------------------------
    proc _section_id_key {section} {
        switch -- $section {
            experiments       { return experimentId }
            testcases         { return testcaseId }
            testsuites        { return suiteId }
            workflows         { return workflowId }
            runs              { return runId }
            artifacts         { return artifactId }
            validationResults { return validationId }
            timelineEvents    { return eventId }
            budgets           { return budgetSetId }
            default { error "Sezione non supportata: $section" }
        }
    }

    proc _prefix_for_section {section} {
        switch -- $section {
            experiments       { return EXP }
            testcases         { return TC }
            testsuites        { return TS }
            workflows         { return WF }
            runs              { return RUN }
            artifacts         { return ART }
            validationResults { return VAL }
            timelineEvents    { return EV }
            budgets           { return BSET }
            default { error "Sezione non supportata: $section" }
        }
    }

    proc next_id {section} {
        variable data
        project::_normalize_list_section $section

        set idKey [project::_section_id_key $section]
        set prefix [project::_prefix_for_section $section]

        set maxNum 0
        foreach item [dict get $data $section] {
            if {![dict exists $item $idKey]} { continue }
            set id [dict get $item $idKey]
            if {[regexp "^${prefix}([0-9]+)$" $id -> num]} {
                if {$num > $maxNum} { set maxNum $num }
            }
        }
        incr maxNum

        switch -- $section {
            runs { return [format "%s%04d" $prefix $maxNum] }
            artifacts - validationResults - timelineEvents {
                return [format "%s%04d" $prefix $maxNum]
            }
            default {
                return [format "%s%03d" $prefix $maxNum]
            }
        }
    }

    proc list_section {section} {
        variable data
        project::_normalize_list_section $section
        return [dict get $data $section]
    }

    proc find_index {section id} {
        variable data
        project::_normalize_list_section $section
        set idKey [project::_section_id_key $section]

        set idx 0
        foreach item [dict get $data $section] {
            if {[dict exists $item $idKey] && [dict get $item $idKey] eq $id} {
                return $idx
            }
            incr idx
        }
        return -1
    }

    proc exists {section id} {
        expr {[project::find_index $section $id] >= 0}
    }

    proc get {section id} {
        variable data
        set idx [project::find_index $section $id]
        if {$idx < 0} {
            error "Oggetto non trovato in $section: $id"
        }
        return [lindex [dict get $data $section] $idx]
    }

    proc upsert {section item} {
        variable data
        project::_normalize_list_section $section
        set idKey [project::_section_id_key $section]

        if {![dict exists $item $idKey] || [string trim [dict get $item $idKey]] eq ""} {
            dict set item $idKey [project::next_id $section]
        }

        set id [dict get $item $idKey]
        set idx [project::find_index $section $id]

        set current [dict get $data $section]
        if {$idx < 0} {
            lappend current $item
        } else {
            set out {}
            set i 0
            foreach old $current {
                if {$i == $idx} {
                    lappend out $item
                } else {
                    lappend out $old
                }
                incr i
            }
            set current $out
        }

        dict set data $section $current
        project::touch_project
        project::rebuild_indexes
        return $item
    }

    proc delete {section id} {
        variable data
        project::_normalize_list_section $section
        set idKey [project::_section_id_key $section]

        set out {}
        foreach item [dict get $data $section] {
            if {![dict exists $item $idKey] || [dict get $item $idKey] ne $id} {
                lappend out $item
            }
        }

        dict set data $section $out
        project::touch_project
        project::rebuild_indexes
        return 1
    }

    proc update_field {section id key value} {
        set item [project::get $section $id]
        dict set item $key $value
        return [project::upsert $section $item]
    }

    proc query {section key value} {
        variable data
        project::_normalize_list_section $section
        set out {}
        foreach item [dict get $data $section] {
            if {[dict exists $item $key] && [dict get $item $key] eq $value} {
                lappend out $item
            }
        }
        return $out
    }

    proc query_in {section key values} {
        variable data
        project::_normalize_list_section $section
        set out {}
        foreach item [dict get $data $section] {
            if {[dict exists $item $key] && [lsearch -exact $values [dict get $item $key]] >= 0} {
                lappend out $item
            }
        }
        return $out
    }

    # --------------------------------------------------
    # Index rebuild
    # --------------------------------------------------
    proc rebuild_indexes {} {
        variable data

        set runsByExperiment [dict create]
        set runsByTestcase   [dict create]
        set runsBySuite      [dict create]
        set artifactsByRun   [dict create]
        set validationsByRun [dict create]

        foreach r [dict get $data runs] {
            set runId [dict get $r runId]

            if {[dict exists $r experimentId] && [dict get $r experimentId] ne ""} {
                dict lappend runsByExperiment [dict get $r experimentId] $runId
            }
            if {[dict exists $r testcaseId] && [dict get $r testcaseId] ne ""} {
                dict lappend runsByTestcase [dict get $r testcaseId] $runId
            }
            if {[dict exists $r suiteId] && [dict get $r suiteId] ne ""} {
                dict lappend runsBySuite [dict get $r suiteId] $runId
            }
        }

        foreach a [dict get $data artifacts] {
            if {[dict exists $a runId] && [dict get $a runId] ne ""} {
                dict lappend artifactsByRun [dict get $a runId] [dict get $a artifactId]
            }
        }

        foreach v [dict get $data validationResults] {
            if {[dict exists $v runId] && [dict get $v runId] ne ""} {
                dict set validationsByRun [dict get $v runId] [dict get $v validationId]
            }
        }

        dict set data indexes [dict create \
            runsByExperiment $runsByExperiment \
            runsByTestcase $runsByTestcase \
            runsBySuite $runsBySuite \
            artifactsByRun $artifactsByRun \
            validationsByRun $validationsByRun]
    }

    # --------------------------------------------------
    # Baseline resolution
    # --------------------------------------------------
    proc resolve_baseline_for_run {runId} {
        set run [project::get runs $runId]

        if {[dict exists $run baselineResolvedPath] && [dict get $run baselineResolvedPath] ne ""} {
            return [dict create path [dict get $run baselineResolvedPath] bindingSource run]
        }

        if {[dict exists $run testcaseId] && [dict get $run testcaseId] ne ""} {
            set tcId [dict get $run testcaseId]
            if {[project::exists testcases $tcId]} {
                set tc [project::get testcases $tcId]
                if {[dict exists $tc baselineRef path] && [dict get $tc baselineRef path] ne ""} {
                    return [dict create path [dict get $tc baselineRef path] bindingSource testcase]
                }

                if {[dict exists $tc suiteId] && [dict get $tc suiteId] ne ""} {
                    set suiteId [dict get $tc suiteId]
                    if {[project::exists testsuites $suiteId]} {
                        set suite [project::get testsuites $suiteId]
                        if {[dict exists $suite baselineRef path] && [dict get $suite baselineRef path] ne ""} {
                            return [dict create path [dict get $suite baselineRef path] bindingSource suite]
                        }
                    }
                }
            }
        }

        if {[dict exists $run experimentId] && [dict get $run experimentId] ne ""} {
            set expId [dict get $run experimentId]
            if {[project::exists experiments $expId]} {
                set exp [project::get experiments $expId]
                if {[dict exists $exp baselineRef path] && [dict get $exp baselineRef path] ne ""} {
                    return [dict create path [dict get $exp baselineRef path] bindingSource experiment]
                }
            }
        }

        return [dict create path "" bindingSource unbound]
    }

    # --------------------------------------------------
    # Run APIs
    # --------------------------------------------------
    proc new_run {args} {
        array set p {
            name ""
            sourceType manual
            sourceId ""
            experimentId ""
            testcaseId ""
            suiteId ""
            workflowId ""
            profile ""
            domain ""
            configPath ""
            outputDir ""
            logPath ""
            metricsPath ""
            baselineResolvedPath ""
            status running
            exitCode ""
            startedAt ""
            endedAt ""
            durationSec ""
            notes ""
        }
        array set p $args

        if {$p(startedAt) eq ""} {
            set p(startedAt) [project::now]
        }

        if {$p(testcaseId) eq "" && $p(sourceType) eq "testcase"} {
            set p(testcaseId) $p(sourceId)
        }
        if {$p(experimentId) eq "" && $p(sourceType) eq "experiment"} {
            set p(experimentId) $p(sourceId)
        }

        set run [dict create \
            runId [project::next_id runs] \
            name $p(name) \
            sourceType $p(sourceType) \
            sourceId $p(sourceId) \
            experimentId $p(experimentId) \
            testcaseId $p(testcaseId) \
            suiteId $p(suiteId) \
            workflowId $p(workflowId) \
            profile $p(profile) \
            domain $p(domain) \
            configPath $p(configPath) \
            outputDir $p(outputDir) \
            logPath $p(logPath) \
            metricsPath $p(metricsPath) \
            baselineResolvedPath $p(baselineResolvedPath) \
            status $p(status) \
            exitCode $p(exitCode) \
            startedAt $p(startedAt) \
            endedAt $p(endedAt) \
            durationSec $p(durationSec) \
            notes $p(notes)]

        set run [project::upsert runs $run]

        if {[dict get [dict get $::project::data settings] autoCreateTimelineEvents]} {
            project::add_timeline_event \
                -runId [dict get $run runId] \
                -experimentId [dict get $run experimentId] \
                -testcaseId [dict get $run testcaseId] \
                -workflowId [dict get $run workflowId] \
                -category run \
                -label "Run started" \
                -status running \
                -severity info \
                -start 0 \
                -end "" \
                -details [dict get $run name]
        }

        return $run
    }

    proc close_run {runId status {exitCode ""} {endedAt ""}} {
        set run [project::get runs $runId]

        if {$endedAt eq ""} {
            set endedAt [project::now]
        }

        set durationSec ""
        if {[dict exists $run startedAt] && [dict get $run startedAt] ne ""} {
            catch {
                set t1 [clock scan [dict get $run startedAt]]
                set t2 [clock scan $endedAt]
                set durationSec [expr {$t2 - $t1}]
            }
        }

        dict set run status $status
        dict set run exitCode $exitCode
        dict set run endedAt $endedAt
        dict set run durationSec $durationSec

        set run [project::upsert runs $run]

        if {[dict get [dict get $::project::data settings] autoCreateTimelineEvents]} {
            project::add_timeline_event \
                -runId $runId \
                -experimentId [dict get $run experimentId] \
                -testcaseId [dict get $run testcaseId] \
                -workflowId [dict get $run workflowId] \
                -category run \
                -label "Run ended" \
                -status $status \
                -severity [expr {$status eq "fail" ? "error" : ($status eq "warn" ? "warn" : "info")}] \
                -start "" \
                -end "" \
                -details "exitCode=$exitCode"
        }

        return $run
    }

    # --------------------------------------------------
    # Artifact APIs
    # --------------------------------------------------
    proc infer_artifact_type {path} {
        set ext [string tolower [file extension $path]]
        switch -- $ext {
            .log - .txt - .out { return [dict create type log category text] }
            .csv { return [dict create type metrics category data] }
            .json - .yaml - .yml - .ini - .cfg - .conf { return [dict create type config category data] }
            .png - .jpg - .jpeg - .gif { return [dict create type image category image] }
            .xml - .html - .pdf { return [dict create type report category report] }
            .vcd - .wlf { return [dict create type waveform category waveform] }
            default { return [dict create type data category binary] }
        }
    }

    proc register_artifact {args} {
        array set p {
            runId ""
            experimentId ""
            testcaseId ""
            workflowId ""
            type ""
            category ""
            label ""
            path ""
            extension ""
            sizeBytes ""
            createdAt ""
            producer launcher
            nodeId ""
            tags {}
        }
        array set p $args

        if {$p(path) eq ""} {
            error "register_artifact richiede -path"
        }

        if {$p(createdAt) eq ""} {
            set p(createdAt) [project::now]
        }
        if {$p(extension) eq ""} {
            set p(extension) [file extension $p(path)]
        }
        if {$p(sizeBytes) eq "" && [file exists $p(path)] && ![file isdirectory $p(path)]} {
            set p(sizeBytes) [file size $p(path)]
        }

        if {$p(type) eq "" || $p(category) eq ""} {
            set inferred [project::infer_artifact_type $p(path)]
            if {$p(type) eq ""} { set p(type) [dict get $inferred type] }
            if {$p(category) eq ""} { set p(category) [dict get $inferred category] }
        }

        if {$p(label) eq ""} {
            set p(label) [file tail $p(path)]
        }

        set artifact [dict create \
            artifactId [project::next_id artifacts] \
            runId $p(runId) \
            experimentId $p(experimentId) \
            testcaseId $p(testcaseId) \
            workflowId $p(workflowId) \
            type $p(type) \
            category $p(category) \
            label $p(label) \
            path $p(path) \
            extension $p(extension) \
            sizeBytes $p(sizeBytes) \
            createdAt $p(createdAt) \
            producer $p(producer) \
            nodeId $p(nodeId) \
            tags $p(tags)]

        return [project::upsert artifacts $artifact]
    }

    proc auto_register_standard_artifacts {runId} {
        set run [project::get runs $runId]
        set out {}

        foreach key {logPath metricsPath} {
            if {[dict exists $run $key]} {
                set path [dict get $run $key]
                if {$path ne "" && [file exists $path]} {
                    lappend out [project::register_artifact \
                        -runId $runId \
                        -experimentId [dict get $run experimentId] \
                        -testcaseId [dict get $run testcaseId] \
                        -workflowId [dict get $run workflowId] \
                        -path $path \
                        -producer launcher]
                }
            }
        }
        return $out
    }

    # --------------------------------------------------
    # Validation APIs
    # --------------------------------------------------
    proc register_validation_result {args} {
        array set p {
            runId ""
            sourceType ""
            sourceId ""
            metricsPath ""
            baselinePath ""
            bindingSource unbound
            mode thresholds
            overallStatus UNBOUND
            okCount 0
            warnCount 0
            failCount 0
            detailRows {}
            createdAt ""
        }
        array set p $args

        if {$p(createdAt) eq ""} {
            set p(createdAt) [project::now]
        }

        set v [dict create \
            validationId [project::next_id validationResults] \
            runId $p(runId) \
            sourceType $p(sourceType) \
            sourceId $p(sourceId) \
            metricsPath $p(metricsPath) \
            baselinePath $p(baselinePath) \
            bindingSource $p(bindingSource) \
            mode $p(mode) \
            overallStatus $p(overallStatus) \
            okCount $p(okCount) \
            warnCount $p(warnCount) \
            failCount $p(failCount) \
            detailRows $p(detailRows) \
            createdAt $p(createdAt)]

        set v [project::upsert validationResults $v]

        if {$p(runId) ne ""} {
            project::add_timeline_event \
                -runId $p(runId) \
                -category validation \
                -label "Validation completed" \
                -status [string tolower $p(overallStatus)] \
                -severity [expr {$p(overallStatus) eq "FAIL" ? "error" : ($p(overallStatus) eq "WARN" ? "warn" : "info")}] \
                -details "bindingSource=$p(bindingSource)"
        }

        return $v
    }

    proc bind_and_register_validation_stub {runId metricsPath} {
        set run [project::get runs $runId]
        set resolved [project::resolve_baseline_for_run $runId]

        return [project::register_validation_result \
            -runId $runId \
            -sourceType [dict get $run sourceType] \
            -sourceId [dict get $run sourceId] \
            -metricsPath $metricsPath \
            -baselinePath [dict get $resolved path] \
            -bindingSource [dict get $resolved bindingSource] \
            -overallStatus [expr {[dict get $resolved path] eq "" ? "UNBOUND" : "WARN"}]]
    }

    # --------------------------------------------------
    # Timeline APIs
    # --------------------------------------------------
    proc add_timeline_event {args} {
        array set p {
            runId ""
            experimentId ""
            testcaseId ""
            workflowId ""
            nodeId ""
            category generic
            label ""
            status ""
            severity info
            start ""
            end ""
            details ""
            relatedPath ""
            createdAt ""
        }
        array set p $args

        if {$p(createdAt) eq ""} {
            set p(createdAt) [project::now]
        }

        set ev [dict create \
            eventId [project::next_id timelineEvents] \
            runId $p(runId) \
            experimentId $p(experimentId) \
            testcaseId $p(testcaseId) \
            workflowId $p(workflowId) \
            nodeId $p(nodeId) \
            category $p(category) \
            label $p(label) \
            status $p(status) \
            severity $p(severity) \
            start $p(start) \
            end $p(end) \
            details $p(details) \
            relatedPath $p(relatedPath) \
            createdAt $p(createdAt)]

        return [project::upsert timelineEvents $ev]
    }

    # --------------------------------------------------
    # Budget APIs
    # --------------------------------------------------
    proc new_budget_set {args} {
        array set p {
            name ""
            ownerType project
            ownerId ""
            domain ""
            items {}
            notes ""
            createdAt ""
        }
        array set p $args

        if {$p(createdAt) eq ""} {
            set p(createdAt) [project::now]
        }

        set setObj [dict create \
            budgetSetId [project::next_id budgets] \
            name $p(name) \
            ownerType $p(ownerType) \
            ownerId $p(ownerId) \
            domain $p(domain) \
            items $p(items) \
            notes $p(notes) \
            createdAt $p(createdAt)]

        return [project::upsert budgets $setObj]
    }

    proc add_budget_item {budgetSetId itemDict} {
        set b [project::get budgets $budgetSetId]
        set items [dict get $b items]

        if {![dict exists $itemDict itemId] || [dict get $itemDict itemId] eq ""} {
            set maxNum 0
            foreach it $items {
                if {[dict exists $it itemId] && [regexp {^BITEM([0-9]+)$} [dict get $it itemId] -> n]} {
                    if {$n > $maxNum} { set maxNum $n }
                }
            }
            incr maxNum
            dict set itemDict itemId [format "BITEM%03d" $maxNum]
        }

        lappend items $itemDict
        dict set b items $items
        return [project::upsert budgets $b]
    }

    # --------------------------------------------------
    # Workflow / suite convenience APIs
    # --------------------------------------------------
    proc register_workflow {args} {
        array set p {
            workflowId ""
            name ""
            version "1"
            filePath ""
            domain ""
            nodes {}
            edges {}
            tags {}
            notes ""
            createdAt ""
            updatedAt ""
        }
        array set p $args

        if {$p(createdAt) eq ""} { set p(createdAt) [project::now] }
        if {$p(updatedAt) eq ""} { set p(updatedAt) [project::now] }

        set wf [dict create \
            workflowId $p(workflowId) \
            name $p(name) \
            version $p(version) \
            filePath $p(filePath) \
            domain $p(domain) \
            nodes $p(nodes) \
            edges $p(edges) \
            tags $p(tags) \
            notes $p(notes) \
            createdAt $p(createdAt) \
            updatedAt $p(updatedAt)]

        return [project::upsert workflows $wf]
    }

    proc register_testsuite {args} {
        array set p {
            suiteId ""
            name ""
            domain ""
            testcaseIds {}
            baselineRef {}
            description ""
            tags {}
            createdAt ""
            updatedAt ""
        }
        array set p $args

        if {$p(createdAt) eq ""} { set p(createdAt) [project::now] }
        if {$p(updatedAt) eq ""} { set p(updatedAt) [project::now] }

        set suite [dict create \
            suiteId $p(suiteId) \
            name $p(name) \
            domain $p(domain) \
            testcaseIds $p(testcaseIds) \
            baselineRef $p(baselineRef) \
            description $p(description) \
            tags $p(tags) \
            createdAt $p(createdAt) \
            updatedAt $p(updatedAt)]

        return [project::upsert testsuites $suite]
    }

    # --------------------------------------------------
    # Import/export helpers
    # --------------------------------------------------
    proc export_workflow {workflowId path} {
        set wf [project::get workflows $workflowId]
        set ch [open $path w]
        puts $ch $wf
        close $ch
        return $path
    }

    proc import_workflow {path} {
        set ch [open $path r]
        set raw [read $ch]
        close $ch
        set wf $raw
        return [project::upsert workflows $wf]
    }

    proc export_testsuite {suiteId path} {
        set suite [project::get testsuites $suiteId]
        set ch [open $path w]
        puts $ch $suite
        close $ch
        return $path
    }

    proc import_testsuite {path} {
        set ch [open $path r]
        set raw [read $ch]
        close $ch
        set suite $raw
        return [project::upsert testsuites $suite]
    }
}