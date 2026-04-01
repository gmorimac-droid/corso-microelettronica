#!/usr/bin/env wish

package require Tk 8.6

namespace eval wb {
    variable ui

    # --------------------------------------------------
    # Core project data
    # --------------------------------------------------
    variable projectName "Engineering Workbench Project"
    variable projectFile "project_master.tcl"

    variable experiments {}
    variable testcases {}
    variable runs {}

    variable selectedExperimentIndex -1
    variable selectedTestIndex -1
    variable selectedRunIndex -1

    # --------------------------------------------------
    # Experiments editor
    # --------------------------------------------------
    variable expId ""
    variable expName ""
    variable expDomain "radar"
    variable expStatus "draft"
    variable expConfigPath ""
    variable expWorkflowPath ""
    variable expBaselinePath ""
    variable expNotes ""

    # --------------------------------------------------
    # Testbench editor
    # --------------------------------------------------
    variable tcId ""
    variable tcName ""
    variable tcSuite "default"
    variable tcDomain "radar"
    variable tcExpected "pass"
    variable tcStatus "draft"
    variable tcConfigPath ""
    variable tcWorkflowPath ""
    variable tcNotes ""

    # --------------------------------------------------
    # Launcher
    # --------------------------------------------------
    variable launchProfiles {
        {
            name "Radar Python Chain"
            domain "radar"
            type "python_script"
            launcher "python3"
            target "radar_chain.py"
            extra_args "--mode batch"
        }
        {
            name "Satellite Matlab Visibility"
            domain "satellite"
            type "matlab_function"
            launcher "matlab"
            target "run_visibility_case"
            extra_args ""
        }
        {
            name "Underwater C++ Detector"
            domain "underwater"
            type "cpp_executable"
            launcher "./uw_detector"
            target ""
            extra_args "--threshold auto"
        }
        {
            name "HDL Regression Runner"
            domain "hdl"
            type "hdl_runner"
            launcher "python3"
            target "run_hdl_regression.py"
            extra_args "--suite smoke --waves"
        }
    }

    variable launchProfile "Radar Python Chain"
    variable launchCaseName ""
    variable launchConfigPath ""
    variable launchOutputRoot "./runs"
    variable launchExtraArgs ""
    variable launchSourceType "manual"
    variable launchSourceId ""
    variable launchNotes ""

    # --------------------------------------------------
    # Runtime
    # --------------------------------------------------
    variable running 0
    variable processChan ""
    variable processPid ""
    variable runtimeLogChan ""
    variable currentRunningRunId ""

    # --------------------------------------------------
    # Results
    # --------------------------------------------------
    variable currentRoot ""
    variable selectedPath ""
    variable previewImage ""

    # --------------------------------------------------
    # Validation
    # --------------------------------------------------
    variable metricsData {}
    variable baselineData {}
    variable validationMetricsFile ""
    variable validationBaselineFile ""
    variable passCount 0
    variable warnCount 0
    variable failCount 0
}

# ==================================================
# GENERAL
# ==================================================
proc wb::setStatus {msg} {
    .status configure -text "Stato: $msg"
}

proc wb::openPath {path} {
    if {$path eq ""} { return }
    if {![file exists $path]} {
        tk_messageBox -icon warning -title "Percorso non trovato" \
            -message "Il percorso non esiste:\n$path"
        return
    }

    if {$::tcl_platform(platform) eq "windows"} {
        catch {exec {*}[auto_execok start] "" $path &}
    } elseif {$::tcl_platform(os) eq "Darwin"} {
        catch {exec open $path &}
    } else {
        catch {exec xdg-open $path &}
    }
}

proc wb::nowString {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

proc wb::humanSize {bytes} {
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1024*1024} {
        return [format "%.1f KB" [expr {$bytes / 1024.0}]]
    } elseif {$bytes < 1024*1024*1024} {
        return [format "%.1f MB" [expr {$bytes / (1024.0*1024.0)}]]
    } else {
        return [format "%.1f GB" [expr {$bytes / (1024.0*1024.0*1024.0)}]]
    }
}

proc wb::splitArgs {argString} {
    if {[string trim $argString] eq ""} { return {} }
    return $argString
}

# ==================================================
# SAMPLE DATA
# ==================================================
proc wb::defaultExperiments {} {
    return {
        {
            id EXP001
            name "Radar Batch Alpha"
            domain radar
            status ready
            configPath "configs/radar_alpha.json"
            workflowPath "workflows/radar_alpha.wflow"
            baselinePath "baselines/radar_alpha.csv"
            notes "Campagna nominale radar"
        }
        {
            id EXP002
            name "HDL Smoke Set"
            domain hdl
            status draft
            configPath "configs/hdl_smoke.json"
            workflowPath "workflows/hdl_smoke.wflow"
            baselinePath ""
            notes "Regression smoke HDL"
        }
    }
}

proc wb::defaultTestcases {} {
    return {
        {
            id TC001
            name "Radar nominal detect-track"
            suite "radar_smoke"
            domain radar
            expected pass
            status ready
            configPath "configs/radar_nominal.json"
            workflowPath "workflows/radar_smoke.wflow"
            notes "Caso smoke radar"
        }
        {
            id TC002
            name "HDL reset smoke"
            suite "hdl_smoke"
            domain hdl
            expected pass
            status draft
            configPath "configs/tb_reset_smoke.json"
            workflowPath "workflows/hdl_smoke.wflow"
            notes "Reset base e handshake"
        }
    }
}

proc wb::defaultRuns {} {
    return {}
}

# ==================================================
# PROJECT PERSISTENCE
# ==================================================
proc wb::saveProject {} {
    variable projectFile
    variable projectName
    variable experiments
    variable testcases
    variable runs

    set data [dict create \
        project [dict create name $projectName savedAt [wb::nowString]] \
        experiments $experiments \
        testcases $testcases \
        runs $runs]

    if {[catch {
        set f [open $projectFile w]
        puts $f $data
        close $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Salvataggio progetto fallito:\n$err"
        return
    }
    wb::setStatus "progetto salvato"
}

proc wb::saveProjectAs {} {
    variable projectFile
    set f [tk_getSaveFile \
        -title "Salva progetto" \
        -defaultextension ".tcl" \
        -filetypes {{"Tcl project" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set projectFile $f
    wb::saveProject
}

proc wb::loadProject {} {
    variable projectFile
    variable projectName
    variable experiments
    variable testcases
    variable runs

    set f [tk_getOpenFile \
        -title "Apri progetto" \
        -filetypes {{"Tcl project" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }

    if {[catch {
        set ch [open $f r]
        set data [read $ch]
        close $ch
        set d $data
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Caricamento progetto fallito:\n$err"
        return
    }

    set projectFile $f
    if {[dict exists $d project name]} { set projectName [dict get $d project name] }
    if {[dict exists $d experiments]} { set experiments [dict get $d experiments] } else { set experiments {} }
    if {[dict exists $d testcases]}   { set testcases  [dict get $d testcases] } else { set testcases {} }
    if {[dict exists $d runs]}        { set runs       [dict get $d runs] } else { set runs {} }

    wb::refreshExperimentsTable
    wb::refreshTestsTable
    wb::refreshRunsTable
    wb::refreshProjectHub
    wb::refreshTimeline
    wb::setStatus "progetto caricato"
}

# ==================================================
# PROJECT HUB
# ==================================================
proc wb::refreshProjectHub {} {
    variable experiments
    variable testcases
    variable runs

    set running 0
    set ok 0
    set warn 0
    set fail 0
    set other 0

    foreach r $runs {
        set s [dict get $r status]
        switch -- $s {
            running { incr running }
            ok      { incr ok }
            warn    { incr warn }
            fail    { incr fail }
            default { incr other }
        }
    }

    .hubTab.info.nameV configure -text $::wb::projectName
    .hubTab.info.expV configure -text [llength $experiments]
    .hubTab.info.tcV configure -text [llength $testcases]
    .hubTab.info.runV configure -text [llength $runs]
    .hubTab.info.statV configure -text "running=$running   ok=$ok   warn=$warn   fail=$fail   other=$other"
}

# ==================================================
# EXPERIMENTS
# ==================================================
proc wb::nextExperimentId {} {
    variable experiments
    set maxNum 0
    foreach e $experiments {
        if {[regexp {^EXP([0-9]+)$} [dict get $e id] -> num]} {
            if {$num > $maxNum} { set maxNum $num }
        }
    }
    incr maxNum
    return [format "EXP%03d" $maxNum]
}

proc wb::clearExperimentEditor {} {
    set ::wb::expId ""
    set ::wb::expName ""
    set ::wb::expDomain "radar"
    set ::wb::expStatus "draft"
    set ::wb::expConfigPath ""
    set ::wb::expWorkflowPath ""
    set ::wb::expBaselinePath ""
    set ::wb::expNotes ""
}

proc wb::refreshExperimentsTable {} {
    variable ui
    variable experiments
    set tree $ui(expTree)
    foreach item [$tree children {}] { $tree delete $item }

    set idx 0
    foreach e $experiments {
        $tree insert {} end -id "exp$idx" -values [list \
            $idx \
            [dict get $e id] \
            [dict get $e name] \
            [dict get $e domain] \
            [dict get $e status]]
        incr idx
    }
}

proc wb::loadExperimentIntoEditor {index} {
    variable experiments
    variable selectedExperimentIndex
    if {$index < 0 || $index >= [llength $experiments]} { return }

    set selectedExperimentIndex $index
    set e [lindex $experiments $index]

    set ::wb::expId           [dict get $e id]
    set ::wb::expName         [dict get $e name]
    set ::wb::expDomain       [dict get $e domain]
    set ::wb::expStatus       [dict get $e status]
    set ::wb::expConfigPath   [dict get $e configPath]
    set ::wb::expWorkflowPath [dict get $e workflowPath]
    set ::wb::expBaselinePath [dict get $e baselinePath]
    set ::wb::expNotes        [dict get $e notes]

    .experimentsTab.right.notes delete 1.0 end
    .experimentsTab.right.notes insert end $::wb::expNotes
}

proc wb::onExperimentTreeSelect {} {
    variable ui
    set tree $ui(expTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set item [lindex $sel 0]
    set idx [$tree set $item 0]
    wb::loadExperimentIntoEditor $idx
}

proc wb::newExperiment {} {
    variable selectedExperimentIndex
    set selectedExperimentIndex -1
    wb::clearExperimentEditor
    set ::wb::expId [wb::nextExperimentId]
}

proc wb::saveExperiment {} {
    variable experiments
    variable selectedExperimentIndex

    set ::wb::expNotes [string trim [.experimentsTab.right.notes get 1.0 end]]
    if {[string trim $::wb::expName] eq ""} {
        tk_messageBox -icon warning -title "Validazione" -message "Nome esperimento obbligatorio."
        return
    }

    set e [dict create \
        id $::wb::expId \
        name $::wb::expName \
        domain $::wb::expDomain \
        status $::wb::expStatus \
        configPath $::wb::expConfigPath \
        workflowPath $::wb::expWorkflowPath \
        baselinePath $::wb::expBaselinePath \
        notes $::wb::expNotes]

    if {$selectedExperimentIndex < 0} {
        lappend experiments $e
        set selectedExperimentIndex [expr {[llength $experiments]-1}]
    } else {
        set out {}
        set i 0
        foreach old $experiments {
            if {$i == $selectedExperimentIndex} { lappend out $e } else { lappend out $old }
            incr i
        }
        set experiments $out
    }

    wb::refreshExperimentsTable
    wb::refreshProjectHub
}

proc wb::deleteExperiment {} {
    variable experiments
    variable selectedExperimentIndex
    if {$selectedExperimentIndex < 0} { return }

    set out {}
    set i 0
    foreach e $experiments {
        if {$i != $selectedExperimentIndex} { lappend out $e }
        incr i
    }
    set experiments $out
    set selectedExperimentIndex -1
    wb::clearExperimentEditor
    wb::refreshExperimentsTable
    wb::refreshProjectHub
}

proc wb::useExperimentInLauncher {} {
    if {[string trim $::wb::expConfigPath] eq ""} { return }
    set ::wb::launchConfigPath $::wb::expConfigPath
    set ::wb::launchCaseName $::wb::expName
    set ::wb::launchSourceType "experiment"
    set ::wb::launchSourceId $::wb::expId
    set ::wb::validationBaselineFile $::wb::expBaselinePath
    wb::selectLauncherProfileForDomain $::wb::expDomain
    wb::updateLauncherPreview
    .nb select .launcherTab
}

# ==================================================
# TESTBENCH
# ==================================================
proc wb::nextTestId {} {
    variable testcases
    set maxNum 0
    foreach t $testcases {
        if {[regexp {^TC([0-9]+)$} [dict get $t id] -> num]} {
            if {$num > $maxNum} { set maxNum $num }
        }
    }
    incr maxNum
    return [format "TC%03d" $maxNum]
}

proc wb::clearTestEditor {} {
    set ::wb::tcId ""
    set ::wb::tcName ""
    set ::wb::tcSuite "default"
    set ::wb::tcDomain "radar"
    set ::wb::tcExpected "pass"
    set ::wb::tcStatus "draft"
    set ::wb::tcConfigPath ""
    set ::wb::tcWorkflowPath ""
    set ::wb::tcNotes ""
}

proc wb::refreshTestsTable {} {
    variable ui
    variable testcases
    set tree $ui(tcTree)
    foreach item [$tree children {}] { $tree delete $item }

    set idx 0
    foreach t $testcases {
        $tree insert {} end -id "tc$idx" -values [list \
            $idx \
            [dict get $t id] \
            [dict get $t name] \
            [dict get $t suite] \
            [dict get $t domain] \
            [dict get $t status]]
        incr idx
    }
}

proc wb::loadTestIntoEditor {index} {
    variable testcases
    variable selectedTestIndex
    if {$index < 0 || $index >= [llength $testcases]} { return }

    set selectedTestIndex $index
    set t [lindex $testcases $index]

    set ::wb::tcId           [dict get $t id]
    set ::wb::tcName         [dict get $t name]
    set ::wb::tcSuite        [dict get $t suite]
    set ::wb::tcDomain       [dict get $t domain]
    set ::wb::tcExpected     [dict get $t expected]
    set ::wb::tcStatus       [dict get $t status]
    set ::wb::tcConfigPath   [dict get $t configPath]
    set ::wb::tcWorkflowPath [dict get $t workflowPath]
    set ::wb::tcNotes        [dict get $t notes]

    .testbenchTab.right.notes delete 1.0 end
    .testbenchTab.right.notes insert end $::wb::tcNotes
}

proc wb::onTestTreeSelect {} {
    variable ui
    set tree $ui(tcTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set item [lindex $sel 0]
    set idx [$tree set $item 0]
    wb::loadTestIntoEditor $idx
}

proc wb::newTest {} {
    variable selectedTestIndex
    set selectedTestIndex -1
    wb::clearTestEditor
    set ::wb::tcId [wb::nextTestId]
}

proc wb::saveTest {} {
    variable testcases
    variable selectedTestIndex

    set ::wb::tcNotes [string trim [.testbenchTab.right.notes get 1.0 end]]
    if {[string trim $::wb::tcName] eq ""} {
        tk_messageBox -icon warning -title "Validazione" -message "Nome test obbligatorio."
        return
    }

    set t [dict create \
        id $::wb::tcId \
        name $::wb::tcName \
        suite $::wb::tcSuite \
        domain $::wb::tcDomain \
        expected $::wb::tcExpected \
        status $::wb::tcStatus \
        configPath $::wb::tcConfigPath \
        workflowPath $::wb::tcWorkflowPath \
        notes $::wb::tcNotes]

    if {$selectedTestIndex < 0} {
        lappend testcases $t
        set selectedTestIndex [expr {[llength $testcases]-1}]
    } else {
        set out {}
        set i 0
        foreach old $testcases {
            if {$i == $selectedTestIndex} { lappend out $t } else { lappend out $old }
            incr i
        }
        set testcases $out
    }

    wb::refreshTestsTable
    wb::refreshProjectHub
}

proc wb::deleteTest {} {
    variable testcases
    variable selectedTestIndex
    if {$selectedTestIndex < 0} { return }

    set out {}
    set i 0
    foreach t $testcases {
        if {$i != $selectedTestIndex} { lappend out $t }
        incr i
    }
    set testcases $out
    set selectedTestIndex -1
    wb::clearTestEditor
    wb::refreshTestsTable
    wb::refreshProjectHub
}

proc wb::useTestInLauncher {} {
    if {[string trim $::wb::tcConfigPath] eq ""} { return }
    set ::wb::launchConfigPath $::wb::tcConfigPath
    set ::wb::launchCaseName $::wb::tcName
    set ::wb::launchSourceType "testcase"
    set ::wb::launchSourceId $::wb::tcId
    wb::selectLauncherProfileForDomain $::wb::tcDomain
    wb::updateLauncherPreview
    .nb select .launcherTab
}

# ==================================================
# RUN HISTORY
# ==================================================
proc wb::nextRunId {} {
    variable runs
    set maxNum 0
    foreach r $runs {
        if {[regexp {^RUN([0-9]+)$} [dict get $r runId] -> num]} {
            if {$num > $maxNum} { set maxNum $num }
        }
    }
    incr maxNum
    return [format "RUN%04d" $maxNum]
}

proc wb::createRunRecord {args} {
    variable runs
    array set p {
        name ""
        sourceType manual
        sourceId ""
        profile ""
        configPath ""
        outputDir ""
        logPath ""
        metricsPath ""
        status running
        startTime ""
        endTime ""
        notes ""
    }
    array set p $args

    if {$p(startTime) eq ""} { set p(startTime) [wb::nowString] }

    set run [dict create \
        runId [wb::nextRunId] \
        name $p(name) \
        sourceType $p(sourceType) \
        sourceId $p(sourceId) \
        profile $p(profile) \
        configPath $p(configPath) \
        outputDir $p(outputDir) \
        logPath $p(logPath) \
        metricsPath $p(metricsPath) \
        status $p(status) \
        startTime $p(startTime) \
        endTime $p(endTime) \
        notes $p(notes)]

    lappend runs $run
    wb::refreshRunsTable
    wb::refreshProjectHub
    wb::refreshTimeline
    return [dict get $run runId]
}

proc wb::findRunIndexById {runId} {
    variable runs
    set i 0
    foreach r $runs {
        if {[dict get $r runId] eq $runId} { return $i }
        incr i
    }
    return -1
}

proc wb::updateRunField {runId key value} {
    variable runs
    set idx [wb::findRunIndexById $runId]
    if {$idx < 0} { return }

    set out {}
    set i 0
    foreach r $runs {
        if {$i == $idx} {
            dict set r $key $value
            lappend out $r
        } else {
            lappend out $r
        }
        incr i
    }
    set runs $out
    wb::refreshRunsTable
    wb::refreshProjectHub
    wb::refreshTimeline
}

proc wb::refreshRunsTable {} {
    variable ui
    variable runs
    set tree $ui(runTree)
    foreach item [$tree children {}] { $tree delete $item }

    set idx 0
    foreach r $runs {
        set item [$tree insert {} end -id "run$idx" -values [list \
            $idx \
            [dict get $r runId] \
            [dict get $r name] \
            [dict get $r sourceType] \
            [dict get $r sourceId] \
            [dict get $r status] \
            [dict get $r startTime] \
            [dict get $r endTime]]]

        switch -- [dict get $r status] {
            ok      { $tree item $item -tags ok }
            warn    { $tree item $item -tags warn }
            fail    { $tree item $item -tags fail }
            running { $tree item $item -tags running }
        }
        incr idx
    }
}

proc wb::loadRunDetail {index} {
    variable runs
    variable selectedRunIndex
    if {$index < 0 || $index >= [llength $runs]} { return }

    set selectedRunIndex $index
    set r [lindex $runs $index]

    .runsTab.right.idV configure -text [dict get $r runId]
    .runsTab.right.nameV configure -text [dict get $r name]
    .runsTab.right.srcV configure -text "[dict get $r sourceType] / [dict get $r sourceId]"
    .runsTab.right.profileV configure -text [dict get $r profile]
    .runsTab.right.statusV configure -text [dict get $r status]
    .runsTab.right.startV configure -text [dict get $r startTime]
    .runsTab.right.endV configure -text [dict get $r endTime]
    .runsTab.right.cfgV configure -text [dict get $r configPath]
    .runsTab.right.outV configure -text [dict get $r outputDir]
    .runsTab.right.logV configure -text [dict get $r logPath]
    .runsTab.right.metV configure -text [dict get $r metricsPath]
}

proc wb::onRunTreeSelect {} {
    variable ui
    set tree $ui(runTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set item [lindex $sel 0]
    set idx [$tree set $item 0]
    wb::loadRunDetail $idx
}

proc wb::selectedRunDict {} {
    variable runs
    variable selectedRunIndex
    if {$selectedRunIndex < 0 || $selectedRunIndex >= [llength $runs]} { return "" }
    return [lindex $runs $selectedRunIndex]
}

proc wb::runOpenOutput {} {
    set r [wb::selectedRunDict]
    if {$r eq ""} { return }
    wb::openPath [dict get $r outputDir]
}

proc wb::runOpenLog {} {
    set r [wb::selectedRunDict]
    if {$r eq ""} { return }
    wb::openPath [dict get $r logPath]
}

proc wb::runToResults {} {
    set r [wb::selectedRunDict]
    if {$r eq ""} { return }
    set path [dict get $r outputDir]
    if {$path eq ""} { return }
    set ::wb::currentRoot $path
    .resultsTab.top.rootEntry delete 0 end
    .resultsTab.top.rootEntry insert 0 $path
    wb::populateResultsTree
    .nb select .resultsTab
}

proc wb::runToValidation {} {
    variable validationMetricsFile
    variable validationBaselineFile
    variable metricsData
    variable baselineData

    set r [wb::selectedRunDict]
    if {$r eq ""} { return }
    set mf [dict get $r metricsPath]
    if {$mf eq "" || ![file exists $mf]} { return }

    set metricsData [wb::loadCsvAsDicts $mf]
    set validationMetricsFile $mf
    .validationTab.top.metricsEntry delete 0 end
    .validationTab.top.metricsEntry insert 0 $mf

    set validationBaselineFile ""
    set baselineData {}
    .validationTab.top.baseEntry delete 0 end

    wb::refreshValidationTable
    .nb select .validationTab
}

# ==================================================
# LAUNCHER
# ==================================================
proc wb::profileNames {} {
    variable launchProfiles
    set out {}
    foreach p $launchProfiles { lappend out [dict get $p name] }
    return $out
}

proc wb::findProfileByName {name} {
    variable launchProfiles
    foreach p $launchProfiles {
        if {[dict get $p name] eq $name} { return $p }
    }
    return ""
}

proc wb::selectLauncherProfileForDomain {domain} {
    variable launchProfiles
    foreach p $launchProfiles {
        if {[dict get $p domain] eq $domain} {
            set ::wb::launchProfile [dict get $p name]
            return
        }
    }
}

proc wb::buildLauncherOutputDir {} {
    variable launchOutputRoot
    variable launchCaseName
    set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set name [string trim $launchCaseName]
    if {$name eq ""} { set name "run" }
    set safe [string map {" " "_" "/" "_" "\\" "_"} $name]
    return [file join $launchOutputRoot "${safe}_$ts"]
}

proc wb::buildLaunchCommand {} {
    variable launchProfile
    variable launchConfigPath
    variable launchExtraArgs

    set p [wb::findProfileByName $launchProfile]
    if {$p eq ""} { return [list {} ""] }

    set ptype [dict get $p type]
    set launcher [dict get $p launcher]
    set target [dict get $p target]
    set pextra [dict get $p extra_args]
    set outdir [wb::buildLauncherOutputDir]

    set cmd {}
    switch -- $ptype {
        python_script {
            lappend cmd $launcher $target --config $launchConfigPath --output $outdir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $launchExtraArgs] { lappend cmd $a }
        }
        cpp_executable {
            lappend cmd $launcher --config $launchConfigPath --output $outdir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $launchExtraArgs] { lappend cmd $a }
        }
        hdl_runner {
            lappend cmd $launcher $target --config $launchConfigPath --output $outdir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $launchExtraArgs] { lappend cmd $a }
        }
        matlab_function {
            set expr [format "%s('%s')" $target $launchConfigPath]
            lappend cmd $launcher -batch $expr
        }
    }
    return [list $cmd $outdir]
}

proc wb::updateLauncherPreview {} {
    variable ui
    lassign [wb::buildLaunchCommand] cmd outdir
    $ui(cmdPreview) configure -state normal
    $ui(cmdPreview) delete 1.0 end
    $ui(cmdPreview) insert end [join $cmd " "]
    if {$outdir ne ""} {
        $ui(cmdPreview) insert end "\n\nOutput dir: $outdir"
        $ui(cmdPreview) insert end "\nLog file: [file join $outdir run.log]"
    }
    $ui(cmdPreview) configure -state disabled
}

proc wb::runtimeTagForMessage {msg} {
    if {[string match "ERROR:*" $msg]} { return error }
    if {[string match "WARN:*" $msg]}  { return warn }
    if {[string match "OK:*" $msg]}    { return ok }
    return info
}

proc wb::configureRuntimeLogTags {} {
    variable ui
    $ui(runtimeLog) tag configure error -foreground red
    $ui(runtimeLog) tag configure warn  -foreground darkorange3
    $ui(runtimeLog) tag configure ok    -foreground darkgreen
    $ui(runtimeLog) tag configure info  -foreground black
}

proc wb::clearRuntimeLog {} {
    variable ui
    $ui(runtimeLog) delete 1.0 end
}

proc wb::openRuntimeLogFile {path} {
    variable runtimeLogChan
    if {$runtimeLogChan ne ""} { catch {close $runtimeLogChan} }
    set runtimeLogChan [open $path w]
}

proc wb::closeRuntimeLogFile {} {
    variable runtimeLogChan
    if {$runtimeLogChan ne ""} {
        catch {close $runtimeLogChan}
        set runtimeLogChan ""
    }
}

proc wb::logRuntime {msg} {
    variable ui
    variable runtimeLogChan
    set ts [clock format [clock seconds] -format "%H:%M:%S"]
    set tag [wb::runtimeTagForMessage $msg]
    $ui(runtimeLog) insert end "[$ts] $msg\n" $tag
    $ui(runtimeLog) see end
    if {$runtimeLogChan ne ""} {
        puts $runtimeLogChan "[$ts] $msg"
        flush $runtimeLogChan
    }
}

proc wb::startRun {} {
    variable running
    variable processChan
    variable processPid
    variable currentRunningRunId

    if {$running} {
        tk_messageBox -icon warning -title "Attenzione" -message "C'è già un processo in esecuzione."
        return
    }

    if {[string trim $::wb::launchConfigPath] eq ""} {
        tk_messageBox -icon warning -title "Config mancante" -message "Specifica una config."
        return
    }

    lassign [wb::buildLaunchCommand] cmd outdir
    if {[llength $cmd] == 0} { return }

    file mkdir $outdir
    set logfile [file join $outdir run.log]
    set metricsfile [file join $outdir metrics.csv]

    wb::clearRuntimeLog
    wb::openRuntimeLogFile $logfile

    set currentRunningRunId [wb::createRunRecord \
        name $::wb::launchCaseName \
        sourceType $::wb::launchSourceType \
        sourceId $::wb::launchSourceId \
        profile $::wb::launchProfile \
        configPath $::wb::launchConfigPath \
        outputDir $outdir \
        logPath $logfile \
        metricsPath $metricsfile \
        status running \
        notes $::wb::launchNotes]

    if {[catch {
        set processChan [open "|[list {*}$cmd] 2>@1" r]
        fconfigure $processChan -blocking 0 -buffering line
        fileevent $processChan readable [list wb::onLauncherReadable $processChan]
        set processPid [pid $processChan]
        set running 1
    } err]} {
        wb::updateRunField $currentRunningRunId status fail
        wb::updateRunField $currentRunningRunId endTime [wb::nowString]
        wb::closeRuntimeLogFile
        tk_messageBox -icon error -title "Errore" -message "Avvio fallito:\n$err"
        return
    }

    wb::logRuntime "OK: processo avviato"
    wb::logRuntime "CMD: [join $cmd { }]"
    wb::logRuntime "Output dir: $outdir"
    .nb select .runtimeTab
    wb::setStatus "run avviata"
}

proc wb::onLauncherReadable {chan} {
    variable running
    variable processChan
    variable processPid
    variable currentRunningRunId

    if {[eof $chan]} {
        set closeMsg ""
        if {[catch {close $chan} err]} {
            set closeMsg $err
        }

        if {$closeMsg ne ""} {
            wb::logRuntime "WARN: processo terminato: $closeMsg"
            wb::updateRunField $currentRunningRunId status warn
        } else {
            wb::logRuntime "OK: processo terminato correttamente"
            wb::updateRunField $currentRunningRunId status ok
        }
        wb::updateRunField $currentRunningRunId endTime [wb::nowString]

        set running 0
        set processChan ""
        set processPid ""
        wb::closeRuntimeLogFile
        wb::refreshRunsTable
        wb::refreshProjectHub
        wb::refreshTimeline
        wb::setStatus "run completata"
        return
    }

    if {[gets $chan line] >= 0} {
        set u [string toupper $line]
        if {[string match "*ERROR*" $u] || [string match "*FATAL*" $u]} {
            wb::logRuntime "ERROR: $line"
        } elseif {[string match "*WARN*" $u] || [string match "*WARNING*" $u]} {
            wb::logRuntime "WARN: $line"
        } else {
            wb::logRuntime $line
        }
    }
}

proc wb::stopRun {} {
    variable running
    variable processChan
    variable processPid
    variable currentRunningRunId

    if {!$running} { return }

    if {$processPid ne ""} {
        catch {exec kill $processPid}
    }
    catch {close $processChan}

    wb::updateRunField $currentRunningRunId status fail
    wb::updateRunField $currentRunningRunId endTime [wb::nowString]
    wb::logRuntime "WARN: esecuzione interrotta manualmente"

    set running 0
    set processChan ""
    set processPid ""
    wb::closeRuntimeLogFile
    wb::refreshRunsTable
    wb::refreshTimeline
}

# ==================================================
# RESULTS
# ==================================================
proc wb::isTextFile {path} {
    set ext [string tolower [file extension $path]]
    expr {$ext in {.log .txt .json .csv .tcl .md .yaml .yml .ini .cfg .conf .xml}}
}

proc wb::isImageFile {path} {
    set ext [string tolower [file extension $path]]
    expr {$ext in {.png .jpg .jpeg .gif}}
}

proc wb::clearResultsTree {} {
    variable ui
    set tree $ui(resTree)
    foreach item [$tree children {}] { $tree delete $item }
}

proc wb::populateResultsTreeRecursive {parent path} {
    variable ui
    set tree $ui(resTree)

    if {[file isdirectory $path]} {
        set id [$tree insert $parent end -text [file tail $path] -values [list $path dir]]
        foreach child [lsort -dictionary [glob -nocomplain -directory $path *]] {
            wb::populateResultsTreeRecursive $id $child
        }
        return
    } else {
        $tree insert $parent end -text [file tail $path] -values [list $path file]
    }
}

proc wb::populateResultsTree {} {
    variable currentRoot
    variable ui

    wb::clearResultsTree
    if {$currentRoot eq "" || ![file exists $currentRoot]} { return }

    set rootId [$ui(resTree) insert {} end -text [file tail $currentRoot] -open 1 -values [list $currentRoot dir]]
    foreach child [lsort -dictionary [glob -nocomplain -directory $currentRoot *]] {
        wb::populateResultsTreeRecursive $rootId $child
    }
}

proc wb::clearResultsPreview {} {
    variable ui
    variable previewImage

    $ui(resInfoPath) configure -text ""
    $ui(resInfoType) configure -text ""
    $ui(resInfoSize) configure -text ""
    $ui(resInfoMtime) configure -text ""

    $ui(resTextPreview) configure -state normal
    $ui(resTextPreview) delete 1.0 end
    $ui(resTextPreview) configure -state disabled

    catch {$ui(resImageLabel) configure -image ""}
    catch {image delete $previewImage}
    set previewImage ""
}

proc wb::updateResultsSelectionInfo {path} {
    variable ui
    variable selectedPath

    set selectedPath $path
    wb::clearResultsPreview

    if {$path eq "" || ![file exists $path]} { return }

    set kind [expr {[file isdirectory $path] ? "Directory" : "File"}]
    set size "-"
    if {![file isdirectory $path]} { set size [wb::humanSize [file size $path]] }
    set mtime [clock format [file mtime $path] -format "%Y-%m-%d %H:%M:%S"]

    $ui(resInfoPath) configure -text $path
    $ui(resInfoType) configure -text $kind
    $ui(resInfoSize) configure -text $size
    $ui(resInfoMtime) configure -text $mtime

    if {[file isdirectory $path]} {
        $ui(resTextPreview) configure -state normal
        $ui(resTextPreview) insert end "Directory selezionata."
        $ui(resTextPreview) configure -state disabled
        return
    }

    if {[wb::isImageFile $path]} {
        if {![catch {
            set img [image create photo -file $path]
            set ::wb::previewImage $img
            $ui(resImageLabel) configure -image $img
        }]} {}
    } elseif {[wb::isTextFile $path]} {
        if {![catch {
            set ch [open $path r]
            set content [read $ch 65536]
            close $ch
            $ui(resTextPreview) configure -state normal
            $ui(resTextPreview) insert end $content
            $ui(resTextPreview) configure -state disabled
        }]} {}
    } else {
        $ui(resTextPreview) configure -state normal
        $ui(resTextPreview) insert end "Anteprima non disponibile."
        $ui(resTextPreview) configure -state disabled
    }
}

proc wb::onResultsTreeSelect {} {
    variable ui
    set tree $ui(resTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set item [lindex $sel 0]
    set path [$tree set $item path]
    wb::updateResultsSelectionInfo $path
}

# ==================================================
# VALIDATION
# ==================================================
proc wb::parseCsvLine {line} {
    return [split $line ","]
}

proc wb::loadCsvAsDicts {path} {
    if {[catch {
        set ch [open $path r]
        set content [read $ch]
        close $ch
    } err]} {
        error "Impossibile leggere il file:\n$err"
    }

    set lines {}
    foreach raw [split $content "\n"] {
        set line [string trim $raw]
        if {$line ne ""} { lappend lines $line }
    }
    if {[llength $lines] < 1} { return {} }

    set header [wb::parseCsvLine [lindex $lines 0]]
    set rows {}

    foreach line [lrange $lines 1 end] {
        set cols [wb::parseCsvLine $line]
        set row [dict create]
        set i 0
        foreach h $header {
            set val ""
            if {$i < [llength $cols]} {
                set val [string trim [lindex $cols $i]]
            }
            dict set row [string trim $h] $val
            incr i
        }
        lappend rows $row
    }
    return $rows
}

proc wb::toNumber {x} {
    if {[string trim $x] eq ""} { return "" }
    if {[string is double -strict $x]} { return $x }
    return ""
}

proc wb::safeDelta {a b} {
    set na [wb::toNumber $a]
    set nb [wb::toNumber $b]
    if {$na eq "" || $nb eq ""} { return "" }
    return [format "%.6g" [expr {$na - $nb}]]
}

proc wb::baselineMap {} {
    variable baselineData
    set m [dict create]
    foreach row $baselineData {
        if {[dict exists $row metric] && [dict exists $row value]} {
            dict set m [dict get $row metric] [dict get $row value]
        }
    }
    return $m
}

proc wb::evaluateMetricRow {row baselineMap} {
    set metric [expr {[dict exists $row metric] ? [dict get $row metric] : ""}]
    set value  [expr {[dict exists $row value] ? [dict get $row value] : ""}]
    set minVal [expr {[dict exists $row min] ? [dict get $row min] : ""}]
    set maxVal [expr {[dict exists $row max] ? [dict get $row max] : ""}]

    set baseline ""
    if {[dict exists $baselineMap $metric]} {
        set baseline [dict get $baselineMap $metric]
    }

    set numValue [wb::toNumber $value]
    set numMin   [wb::toNumber $minVal]
    set numMax   [wb::toNumber $maxVal]

    set status "warn"
    if {$numValue eq ""} {
        set status "fail"
    } else {
        set hasMin [expr {$numMin ne ""}]
        set hasMax [expr {$numMax ne ""}]
        if {!$hasMin && !$hasMax} {
            set status "warn"
        } else {
            set ok 1
            if {$hasMin && $numValue < $numMin} { set ok 0 }
            if {$hasMax && $numValue > $numMax} { set ok 0 }
            if {$ok} { set status "ok" } else { set status "fail" }
        }
    }

    return [dict create \
        metric $metric \
        value $value \
        baseline $baseline \
        delta [wb::safeDelta $value $baseline] \
        min $minVal \
        max $maxVal \
        status $status]
}

proc wb::refreshValidationTable {} {
    variable metricsData
    variable ui
    variable passCount
    variable warnCount
    variable failCount

    set passCount 0
    set warnCount 0
    set failCount 0

    set tree $ui(valTree)
    foreach item [$tree children {}] { $tree delete $item }

    set bm [wb::baselineMap]
    foreach row $metricsData {
        set er [wb::evaluateMetricRow $row $bm]
        set st [dict get $er status]

        switch -- $st {
            ok   { incr passCount }
            warn { incr warnCount }
            fail { incr failCount }
        }

        set item [$tree insert {} end -values [list \
            [dict get $er metric] \
            [dict get $er value] \
            [dict get $er baseline] \
            [dict get $er delta] \
            [dict get $er min] \
            [dict get $er max] \
            [string toupper $st]]]

        $tree item $item -tags $st
    }

    $ui(valSummary) configure -text "OK=$passCount   WARN=$warnCount   FAIL=$failCount"
}

proc wb::openValidationMetricsFile {} {
    variable validationMetricsFile
    variable metricsData
    set f [tk_getOpenFile -title "Apri file metriche" -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set validationMetricsFile $f
    set metricsData [wb::loadCsvAsDicts $f]
    .validationTab.top.metricsEntry delete 0 end
    .validationTab.top.metricsEntry insert 0 $f
    wb::refreshValidationTable
}

proc wb::openValidationBaselineFile {} {
    variable validationBaselineFile
    variable baselineData
    set f [tk_getOpenFile -title "Apri file baseline" -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set validationBaselineFile $f
    set baselineData [wb::loadCsvAsDicts $f]
    .validationTab.top.baseEntry delete 0 end
    .validationTab.top.baseEntry insert 0 $f
    wb::refreshValidationTable
}

# ==================================================
# TIMELINE
# ==================================================
proc wb::refreshTimeline {} {
    variable runs
    variable ui

    set c $ui(timelineCanvas)
    $c delete all

    set left 120
    set top 30
    set rowH 34
    set zoom 24

    set i 0
    foreach r $runs {
        set y1 [expr {$top + $i*$rowH}]
        set y2 [expr {$y1 + 22}]

        set st [dict get $r startTime]
        set et [dict get $r endTime]

        # V1: tempo sintetico basato sull'ordine, non durata reale
        set x1 [expr {$left + $i*15}]
        set x2 [expr {$x1 + 80}]
        if {$et ne ""} { set x2 [expr {$x1 + 120}] }

        set status [dict get $r status]
        switch -- $status {
            ok      { set fill "#d9ead3"; set outline darkgreen }
            warn    { set fill "#fff2cc"; set outline darkorange3 }
            fail    { set fill "#f4cccc"; set outline red }
            running { set fill "#cfe2f3"; set outline blue }
            default { set fill "#eeeeee"; set outline black }
        }

        $c create text 10 [expr {$y1+11}] -anchor w -text [dict get $r runId]
        $c create rectangle $x1 $y1 $x2 $y2 -fill $fill -outline $outline -width 2
        $c create text [expr {($x1+$x2)/2}] [expr {$y1+11}] -text [dict get $r name]

        incr i
    }

    $c configure -scrollregion [list 0 0 1200 [expr {$top + ([llength $runs]+2)*$rowH}]]
}

# ==================================================
# BUDGET PLACEHOLDER
# ==================================================
proc wb::refreshBudgetPlaceholder {} {
    .budgetTab.info configure -text \
"Budget Workbench integrato in V1 come placeholder.\n\nNel passo successivo possiamo collegare:\n- budget a experiment\n- budget a testcase\n- budget a validation result\n- report sintetico nel Project Hub"
}

# ==================================================
# UI BUILDERS
# ==================================================
proc wb::buildHubTab {} {
    ttk::labelframe .hubTab.info -text "Project Hub" -padding 12
    pack .hubTab.info -fill both -expand 1 -padx 8 -pady 8

    grid columnconfigure .hubTab.info 1 -weight 1

    foreach {row lbl var} {
        0 "Project:" nameV
        1 "Experiments:" expV
        2 "Testcases:" tcV
        3 "Runs:" runV
        4 "Run status:" statV
    } {
        ttk::label .hubTab.info.l$row -text $lbl
        ttk::label .hubTab.info.$var -text ""
        grid .hubTab.info.l$row -row $row -column 0 -sticky w -pady 6
        grid .hubTab.info.$var -row $row -column 1 -sticky w -pady 6
    }
}

proc wb::buildExperimentsTab {} {
    variable ui

    ttk::panedwindow .experimentsTab.pw -orient horizontal
    pack .experimentsTab.pw -fill both -expand 1

    ttk::frame .experimentsTab.left -padding 6
    ttk::frame .experimentsTab.right -padding 6
    .experimentsTab.pw add .experimentsTab.left -weight 3
    .experimentsTab.pw add .experimentsTab.right -weight 2

    set ui(expTree) [ttk::treeview .experimentsTab.left.tree \
        -columns {idx id name domain status} -show headings -selectmode browse]
    foreach {col txt w} {
        idx "#" 50
        id "ID" 90
        name "Name" 260
        domain "Domain" 100
        status "Status" 100
    } {
        $ui(expTree) heading $col -text $txt
        $ui(expTree) column $col -width $w
    }
    pack $ui(expTree) -fill both -expand 1
    bind $ui(expTree) <<TreeviewSelect>> wb::onExperimentTreeSelect

    ttk::label .experimentsTab.right.l1 -text "ID:"
    ttk::entry .experimentsTab.right.e1 -textvariable wb::expId
    ttk::label .experimentsTab.right.l2 -text "Name:"
    ttk::entry .experimentsTab.right.e2 -textvariable wb::expName
    ttk::label .experimentsTab.right.l3 -text "Domain:"
    ttk::combobox .experimentsTab.right.c3 -state readonly -values {radar satellite underwater hdl} -textvariable wb::expDomain
    ttk::label .experimentsTab.right.l4 -text "Status:"
    ttk::combobox .experimentsTab.right.c4 -state readonly -values {draft ready running completed failed archived} -textvariable wb::expStatus
    ttk::label .experimentsTab.right.l5 -text "Config:"
    ttk::entry .experimentsTab.right.e5 -textvariable wb::expConfigPath
    ttk::label .experimentsTab.right.l6 -text "Workflow:"
    ttk::entry .experimentsTab.right.e6 -textvariable wb::expWorkflowPath
    ttk::label .experimentsTab.right.l7 -text "Baseline:"
    ttk::entry .experimentsTab.right.e7 -textvariable wb::expBaselinePath
    ttk::label .experimentsTab.right.l8 -text "Notes:"
    text .experimentsTab.right.notes -height 8 -width 30 -wrap word

    grid .experimentsTab.right.l1 -row 0 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.e1 -row 0 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.l2 -row 1 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.e2 -row 1 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.l3 -row 2 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.c3 -row 2 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.l4 -row 3 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.c4 -row 3 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.l5 -row 4 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.e5 -row 4 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.l6 -row 5 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.e6 -row 5 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.l7 -row 6 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.e7 -row 6 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.l8 -row 7 -column 0 -sticky nw -pady 4
    grid .experimentsTab.right.notes -row 7 -column 1 -sticky ew -pady 4
    grid columnconfigure .experimentsTab.right 1 -weight 1

    ttk::frame .experimentsTab.right.actions
    grid .experimentsTab.right.actions -row 8 -column 0 -columnspan 2 -sticky ew -pady 8
    ttk::button .experimentsTab.right.actions.new -text "Nuovo" -command wb::newExperiment
    ttk::button .experimentsTab.right.actions.save -text "Salva" -command wb::saveExperiment
    ttk::button .experimentsTab.right.actions.del -text "Elimina" -command wb::deleteExperiment
    ttk::button .experimentsTab.right.actions.use -text "Usa nel Launcher" -command wb::useExperimentInLauncher
    pack .experimentsTab.right.actions.new .experimentsTab.right.actions.save .experimentsTab.right.actions.del .experimentsTab.right.actions.use -side left -padx 4
}

proc wb::buildTestbenchTab {} {
    variable ui

    ttk::panedwindow .testbenchTab.pw -orient horizontal
    pack .testbenchTab.pw -fill both -expand 1

    ttk::frame .testbenchTab.left -padding 6
    ttk::frame .testbenchTab.right -padding 6
    .testbenchTab.pw add .testbenchTab.left -weight 3
    .testbenchTab.pw add .testbenchTab.right -weight 2

    set ui(tcTree) [ttk::treeview .testbenchTab.left.tree \
        -columns {idx id name suite domain status} -show headings -selectmode browse]
    foreach {col txt w} {
        idx "#" 50
        id "ID" 90
        name "Name" 240
        suite "Suite" 140
        domain "Domain" 100
        status "Status" 100
    } {
        $ui(tcTree) heading $col -text $txt
        $ui(tcTree) column $col -width $w
    }
    pack $ui(tcTree) -fill both -expand 1
    bind $ui(tcTree) <<TreeviewSelect>> wb::onTestTreeSelect

    ttk::label .testbenchTab.right.l1 -text "ID:"
    ttk::entry .testbenchTab.right.e1 -textvariable wb::tcId
    ttk::label .testbenchTab.right.l2 -text "Name:"
    ttk::entry .testbenchTab.right.e2 -textvariable wb::tcName
    ttk::label .testbenchTab.right.l3 -text "Suite:"
    ttk::entry .testbenchTab.right.e3 -textvariable wb::tcSuite
    ttk::label .testbenchTab.right.l4 -text "Domain:"
    ttk::combobox .testbenchTab.right.c4 -state readonly -values {radar satellite underwater hdl} -textvariable wb::tcDomain
    ttk::label .testbenchTab.right.l5 -text "Expected:"
    ttk::combobox .testbenchTab.right.c5 -state readonly -values {pass fail manual} -textvariable wb::tcExpected
    ttk::label .testbenchTab.right.l6 -text "Status:"
    ttk::combobox .testbenchTab.right.c6 -state readonly -values {draft ready running passed failed blocked archived} -textvariable wb::tcStatus
    ttk::label .testbenchTab.right.l7 -text "Config:"
    ttk::entry .testbenchTab.right.e7 -textvariable wb::tcConfigPath
    ttk::label .testbenchTab.right.l8 -text "Workflow:"
    ttk::entry .testbenchTab.right.e8 -textvariable wb::tcWorkflowPath
    ttk::label .testbenchTab.right.l9 -text "Notes:"
    text .testbenchTab.right.notes -height 8 -width 30 -wrap word

    grid .testbenchTab.right.l1 -row 0 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.e1 -row 0 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l2 -row 1 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.e2 -row 1 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l3 -row 2 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.e3 -row 2 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l4 -row 3 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.c4 -row 3 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l5 -row 4 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.c5 -row 4 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l6 -row 5 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.c6 -row 5 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l7 -row 6 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.e7 -row 6 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l8 -row 7 -column 0 -sticky w -pady 4
    grid .testbenchTab.right.e8 -row 7 -column 1 -sticky ew -pady 4
    grid .testbenchTab.right.l9 -row 8 -column 0 -sticky nw -pady 4
    grid .testbenchTab.right.notes -row 8 -column 1 -sticky ew -pady 4
    grid columnconfigure .testbenchTab.right 1 -weight 1

    ttk::frame .testbenchTab.right.actions
    grid .testbenchTab.right.actions -row 9 -column 0 -columnspan 2 -sticky ew -pady 8
    ttk::button .testbenchTab.right.actions.new -text "Nuovo" -command wb::newTest
    ttk::button .testbenchTab.right.actions.save -text "Salva" -command wb::saveTest
    ttk::button .testbenchTab.right.actions.del -text "Elimina" -command wb::deleteTest
    ttk::button .testbenchTab.right.actions.use -text "Usa nel Launcher" -command wb::useTestInLauncher
    pack .testbenchTab.right.actions.new .testbenchTab.right.actions.save .testbenchTab.right.actions.del .testbenchTab.right.actions.use -side left -padx 4
}

proc wb::buildLauncherTab {} {
    variable ui

    ttk::labelframe .launcherTab.form -text "Launcher" -padding 10
    pack .launcherTab.form -fill x -padx 8 -pady 8
    grid columnconfigure .launcherTab.form 1 -weight 1

    ttk::label .launcherTab.form.l1 -text "Profile:"
    ttk::combobox .launcherTab.form.c1 -state readonly -values [wb::profileNames] -textvariable wb::launchProfile
    ttk::label .launcherTab.form.l2 -text "Case name:"
    ttk::entry .launcherTab.form.e2 -textvariable wb::launchCaseName
    ttk::label .launcherTab.form.l3 -text "Config:"
    ttk::entry .launcherTab.form.e3 -textvariable wb::launchConfigPath
    ttk::label .launcherTab.form.l4 -text "Output root:"
    ttk::entry .launcherTab.form.e4 -textvariable wb::launchOutputRoot
    ttk::label .launcherTab.form.l5 -text "Extra args:"
    ttk::entry .launcherTab.form.e5 -textvariable wb::launchExtraArgs
    ttk::label .launcherTab.form.l6 -text "Source type:"
    ttk::combobox .launcherTab.form.c6 -state readonly -values {manual experiment testcase} -textvariable wb::launchSourceType
    ttk::label .launcherTab.form.l7 -text "Source id:"
    ttk::entry .launcherTab.form.e7 -textvariable wb::launchSourceId

    foreach {row lw ew} {
        0 .launcherTab.form.l1 .launcherTab.form.c1
        1 .launcherTab.form.l2 .launcherTab.form.e2
        2 .launcherTab.form.l3 .launcherTab.form.e3
        3 .launcherTab.form.l4 .launcherTab.form.e4
        4 .launcherTab.form.l5 .launcherTab.form.e5
        5 .launcherTab.form.l6 .launcherTab.form.c6
        6 .launcherTab.form.l7 .launcherTab.form.e7
    } {
        grid $lw -row $row -column 0 -sticky w -pady 4
        grid $ew -row $row -column 1 -sticky ew -pady 4
    }

    ttk::frame .launcherTab.actions -padding 6
    pack .launcherTab.actions -fill x
    ttk::button .launcherTab.actions.run -text "Avvia run" -command wb::startRun
    ttk::button .launcherTab.actions.stop -text "Stop" -command wb::stopRun
    ttk::button .launcherTab.actions.save -text "Salva progetto" -command wb::saveProject
    pack .launcherTab.actions.run .launcherTab.actions.stop .launcherTab.actions.save -side left -padx 4

    ttk::labelframe .launcherTab.cmd -text "Command preview" -padding 8
    pack .launcherTab.cmd -fill both -expand 1 -padx 8 -pady 8
    set ui(cmdPreview) [text .launcherTab.cmd.txt -height 10 -wrap word]
    $ui(cmdPreview) configure -state disabled
    pack $ui(cmdPreview) -fill both -expand 1
}

proc wb::buildRuntimeTab {} {
    variable ui
    ttk::labelframe .runtimeTab.box -text "Runtime Log" -padding 8
    pack .runtimeTab.box -fill both -expand 1 -padx 8 -pady 8

    set ui(runtimeLog) [text .runtimeTab.box.txt -wrap none]
    ttk::scrollbar .runtimeTab.box.vsb -orient vertical -command "$ui(runtimeLog) yview"
    ttk::scrollbar .runtimeTab.box.hsb -orient horizontal -command "$ui(runtimeLog) xview"
    $ui(runtimeLog) configure -yscrollcommand ".runtimeTab.box.vsb set" -xscrollcommand ".runtimeTab.box.hsb set"

    grid $ui(runtimeLog) -row 0 -column 0 -sticky nsew
    grid .runtimeTab.box.vsb -row 0 -column 1 -sticky ns
    grid .runtimeTab.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .runtimeTab.box 0 -weight 1
    grid columnconfigure .runtimeTab.box 0 -weight 1
}

proc wb::buildRunsTab {} {
    variable ui

    ttk::panedwindow .runsTab.pw -orient horizontal
    pack .runsTab.pw -fill both -expand 1

    ttk::frame .runsTab.left -padding 6
    ttk::frame .runsTab.right -padding 6
    .runsTab.pw add .runsTab.left -weight 4
    .runsTab.pw add .runsTab.right -weight 2

    set ui(runTree) [ttk::treeview .runsTab.left.tree \
        -columns {idx runId name sourceType sourceId status startTime endTime} \
        -show headings -selectmode browse]
    foreach {col txt w} {
        idx "#" 50
        runId "Run ID" 90
        name "Name" 220
        sourceType "Source Type" 100
        sourceId "Source ID" 90
        status "Status" 90
        startTime "Start" 150
        endTime "End" 150
    } {
        $ui(runTree) heading $col -text $txt
        $ui(runTree) column $col -width $w
    }
    pack $ui(runTree) -fill both -expand 1
    bind $ui(runTree) <<TreeviewSelect>> wb::onRunTreeSelect

    $ui(runTree) tag configure ok -foreground darkgreen
    $ui(runTree) tag configure warn -foreground darkorange3
    $ui(runTree) tag configure fail -foreground red
    $ui(runTree) tag configure running -foreground blue

    ttk::labelframe .runsTab.right.box -text "Run detail" -padding 10
    pack .runsTab.right.box -fill both -expand 1
    set right .runsTab.right
    foreach {row lbl var} {
        0 "Run ID:" idV
        1 "Name:" nameV
        2 "Source:" srcV
        3 "Profile:" profileV
        4 "Status:" statusV
        5 "Start:" startV
        6 "End:" endV
        7 "Config:" cfgV
        8 "Output:" outV
        9 "Log:" logV
        10 "Metrics:" metV
    } {
        ttk::label $right.l$row -text $lbl
        ttk::label $right.$var -text "" -wraplength 320 -justify left
        grid $right.l$row -in .runsTab.right.box -row $row -column 0 -sticky nw -pady 3
        grid $right.$var -in .runsTab.right.box -row $row -column 1 -sticky w -pady 3
    }

    ttk::frame .runsTab.right.actions -padding 6
    pack .runsTab.right.actions -fill x
    ttk::button .runsTab.right.actions.out -text "Vai a Results" -command wb::runToResults
    ttk::button .runsTab.right.actions.val -text "Vai a Validation" -command wb::runToValidation
    ttk::button .runsTab.right.actions.log -text "Apri log" -command wb::runOpenLog
    ttk::button .runsTab.right.actions.dir -text "Apri output" -command wb::runOpenOutput
    pack .runsTab.right.actions.out .runsTab.right.actions.val .runsTab.right.actions.log .runsTab.right.actions.dir -fill x -pady 2
}

proc wb::buildResultsTab {} {
    variable ui

    ttk::frame .resultsTab.top -padding 6
    pack .resultsTab.top -fill x
    ttk::label .resultsTab.top.rootL -text "Root:"
    entry .resultsTab.top.rootEntry
    ttk::button .resultsTab.top.openBtn -text "Apri cartella" -command {
        set d [tk_chooseDirectory -title "Seleziona cartella output"]
        if {$d ne ""} {
            set ::wb::currentRoot $d
            .resultsTab.top.rootEntry delete 0 end
            .resultsTab.top.rootEntry insert 0 $d
            wb::populateResultsTree
        }
    }
    pack .resultsTab.top.openBtn -side left -padx 4
    pack .resultsTab.top.rootEntry -side right -fill x -expand 1 -padx 4
    pack .resultsTab.top.rootL -side right

    ttk::panedwindow .resultsTab.pw -orient horizontal
    pack .resultsTab.pw -fill both -expand 1

    ttk::frame .resultsTab.left -padding 6
    ttk::frame .resultsTab.right -padding 6
    .resultsTab.pw add .resultsTab.left -weight 2
    .resultsTab.pw add .resultsTab.right -weight 3

    set ui(resTree) [ttk::treeview .resultsTab.left.tree -columns {path kind} -show tree -selectmode browse]
    pack $ui(resTree) -fill both -expand 1
    bind $ui(resTree) <<TreeviewSelect>> wb::onResultsTreeSelect

    ttk::labelframe .resultsTab.right.info -text "Info" -padding 10
    pack .resultsTab.right.info -fill x
    grid columnconfigure .resultsTab.right.info 1 -weight 1

    foreach {row lbl key} {
        0 "Path:" resInfoPath
        1 "Type:" resInfoType
        2 "Size:" resInfoSize
        3 "Modified:" resInfoMtime
    } {
        ttk::label .resultsTab.right.info.l$row -text $lbl
        ttk::label .resultsTab.right.info.v$row -text "" -wraplength 650 -justify left
        grid .resultsTab.right.info.l$row -row $row -column 0 -sticky w -pady 3
        grid .resultsTab.right.info.v$row -row $row -column 1 -sticky w -pady 3
        set ui($key) .resultsTab.right.info.v$row
    }

    ttk::notebook .resultsTab.right.nb
    pack .resultsTab.right.nb -fill both -expand 1 -pady 8
    ttk::frame .resultsTab.right.textTab
    ttk::frame .resultsTab.right.imageTab
    .resultsTab.right.nb add .resultsTab.right.textTab -text "Text"
    .resultsTab.right.nb add .resultsTab.right.imageTab -text "Image"

    set ui(resTextPreview) [text .resultsTab.right.textTab.txt -wrap none -state disabled]
    pack $ui(resTextPreview) -fill both -expand 1
    set ui(resImageLabel) [label .resultsTab.right.imageTab.img -anchor center]
    pack $ui(resImageLabel) -fill both -expand 1
}

proc wb::buildValidationTab {} {
    variable ui

    ttk::frame .validationTab.top -padding 6
    pack .validationTab.top -fill x

    ttk::button .validationTab.top.openM -text "Apri metriche" -command wb::openValidationMetricsFile
    ttk::button .validationTab.top.openB -text "Apri baseline" -command wb::openValidationBaselineFile
    ttk::label .validationTab.top.metricsL -text "Metrics:"
    entry .validationTab.top.metricsEntry
    ttk::label .validationTab.top.baseL -text "Baseline:"
    entry .validationTab.top.baseEntry

    pack .validationTab.top.openM .validationTab.top.openB -side left -padx 4
    pack .validationTab.top.baseEntry -side right -fill x -expand 1 -padx 4
    pack .validationTab.top.baseL -side right
    pack .validationTab.top.metricsEntry -side right -fill x -expand 1 -padx 4
    pack .validationTab.top.metricsL -side right

    set ui(valTree) [ttk::treeview .validationTab.tree \
        -columns {metric value baseline delta min max status} -show headings -selectmode browse]
    foreach {col txt w} {
        metric "Metric" 180
        value "Value" 100
        baseline "Baseline" 100
        delta "Delta" 100
        min "Min" 80
        max "Max" 80
        status "Status" 80
    } {
        $ui(valTree) heading $col -text $txt
        $ui(valTree) column $col -width $w
    }
    pack $ui(valTree) -fill both -expand 1 -padx 8 -pady 8
    $ui(valTree) tag configure ok -foreground darkgreen
    $ui(valTree) tag configure warn -foreground darkorange3
    $ui(valTree) tag configure fail -foreground red

    set ui(valSummary) [ttk::label .validationTab.summary -text "OK=0   WARN=0   FAIL=0" -padding 6]
    pack .validationTab.summary -fill x
}

proc wb::buildTimelineTab {} {
    variable ui
    ttk::labelframe .timelineTab.box -text "Run Timeline" -padding 8
    pack .timelineTab.box -fill both -expand 1 -padx 8 -pady 8

    set ui(timelineCanvas) [canvas .timelineTab.box.c -background white -scrollregion {0 0 1200 800}]
    ttk::scrollbar .timelineTab.box.vsb -orient vertical -command "$ui(timelineCanvas) yview"
    ttk::scrollbar .timelineTab.box.hsb -orient horizontal -command "$ui(timelineCanvas) xview"
    $ui(timelineCanvas) configure -yscrollcommand ".timelineTab.box.vsb set" -xscrollcommand ".timelineTab.box.hsb set"

    grid $ui(timelineCanvas) -row 0 -column 0 -sticky nsew
    grid .timelineTab.box.vsb -row 0 -column 1 -sticky ns
    grid .timelineTab.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .timelineTab.box 0 -weight 1
    grid columnconfigure .timelineTab.box 0 -weight 1
}

proc wb::buildBudgetTab {} {
    ttk::label .budgetTab.info -text "" -justify left -padding 20
    pack .budgetTab.info -anchor nw
    wb::refreshBudgetPlaceholder
}

proc wb::buildUI {} {
    wm title . "Workbench Final V1 + Run History"
    wm geometry . 1700x980
    wm minsize . 1300 840
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.newExp -text "Nuovo esperimento" -command wb::newExperiment
    ttk::button .toolbar.newTc  -text "Nuovo test" -command wb::newTest
    ttk::button .toolbar.saveP  -text "Salva progetto" -command wb::saveProject
    ttk::button .toolbar.saveAs -text "Salva progetto come" -command wb::saveProjectAs
    ttk::button .toolbar.openP  -text "Apri progetto" -command wb::loadProject

    pack .toolbar.newExp .toolbar.newTc .toolbar.saveP .toolbar.saveAs .toolbar.openP -side left -padx 4

    ttk::notebook .nb
    pack .nb -fill both -expand 1

    foreach tab {hubTab experimentsTab testbenchTab launcherTab runtimeTab runsTab resultsTab validationTab timelineTab budgetTab} {
        ttk::frame .$tab -padding 4
    }

    .nb add .hubTab -text "Project Hub"
    .nb add .experimentsTab -text "Experiments"
    .nb add .testbenchTab -text "Testbench"
    .nb add .launcherTab -text "Launcher"
    .nb add .runtimeTab -text "Runtime Log"
    .nb add .runsTab -text "Run History"
    .nb add .resultsTab -text "Results"
    .nb add .validationTab -text "Validation"
    .nb add .timelineTab -text "Timeline"
    .nb add .budgetTab -text "Budget"

    wb::buildHubTab
    wb::buildExperimentsTab
    wb::buildTestbenchTab
    wb::buildLauncherTab
    wb::buildRuntimeTab
    wb::buildRunsTab
    wb::buildResultsTab
    wb::buildValidationTab
    wb::buildTimelineTab
    wb::buildBudgetTab

    ttk::separator .sep -orient horizontal
    pack .sep -fill x
    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x

    foreach var {
        wb::launchProfile
        wb::launchConfigPath
        wb::launchCaseName
        wb::launchOutputRoot
        wb::launchExtraArgs
    } {
        trace add variable $var write {apply {{args} {after idle wb::updateLauncherPreview}}}
    }
}

# ==================================================
# INIT
# ==================================================
wb::buildUI
wb::configureRuntimeLogTags

set ::wb::experiments [wb::defaultExperiments]
set ::wb::testcases [wb::defaultTestcases]
set ::wb::runs [wb::defaultRuns]

wb::refreshExperimentsTable
wb::refreshTestsTable
wb::refreshRunsTable
wb::refreshProjectHub
wb::refreshTimeline
wb::updateLauncherPreview
wb::setStatus "Workbench Final V1 pronto"