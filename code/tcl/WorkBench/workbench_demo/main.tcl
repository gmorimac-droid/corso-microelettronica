
#!/usr/bin/env wish

package require Tk 8.6
package require ttk

source [file join [file dirname [info script]] "project_schema_v2_api.tcl"]

namespace eval wb {
    variable ui
    variable projectFile [file join [file dirname [info script]] "project_master.tcl"]

    variable running 0
    variable processChan ""
    variable runtimeLogChan ""
    variable currentRunningRunId ""

    variable currentRoot ""
    variable selectedPath ""
    variable previewImage ""

    variable expId ""
    variable expName ""
    variable expDomain "radar"
    variable expStatus "draft"
    variable expConfigPath ""
    variable expWorkflowPath ""
    variable expBaselinePath ""
    variable expNotes ""

    variable tcId ""
    variable tcName ""
    variable tcSuiteId ""
    variable tcDomain "radar"
    variable tcExpected "pass"
    variable tcStatus "draft"
    variable tcConfigPath ""
    variable tcWorkflowPath ""
    variable tcBaselinePath ""
    variable tcNotes ""

    variable wfId ""
    variable wfName ""
    variable wfVersion "1"
    variable wfDomain "radar"
    variable wfFilePath ""
    variable wfNotes ""
    variable workflowNodes {}
    variable workflowEdges {}

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
    variable launchWorkflowId ""
    variable launchNotes ""

    variable validationMetricsFile ""
    variable validationBaselineFile ""
    variable metricsData {}
    variable baselineData {}
    variable passCount 0
    variable warnCount 0
    variable failCount 0

    variable artifactTypeFilter "all"
    variable artifactRunFilter "all"
    variable artifactPathFilter ""

    variable timelineRunFilter "all"

    variable budgetName ""
    variable budgetOwnerType "project"
    variable budgetOwnerId ""
    variable budgetDomain ""
    variable budgetNotes ""

    variable budgetItemLabel ""
    variable budgetItemType "cost"
    variable budgetItemValue ""
    variable budgetItemUnit "EUR"
    variable budgetItemNotes ""

    variable autosaveEnabled 1
    variable autosaveIntervalMs 15000
    variable autosaveAfterId ""

    variable workflowExecActive 0
    variable workflowExecQueue {}
    variable workflowExecIndex -1
    variable workflowExecRunId ""
    variable workflowExecOutputDir ""
    variable workflowExecMetricsPath ""
    variable workflowExecLogPath ""
}

# ==================================================
# GENERAL
# ==================================================
proc wb::status {msg} {
    .status configure -text "Stato: $msg"
}

proc wb::nowString {} {
    return [project::now]
}

proc wb::safeDictGet {d key {default ""}} {
    if {[dict exists $d $key]} {
        return [dict get $d $key]
    }
    return $default
}

proc wb::normalizePath {p} {
    if {$p eq ""} { return "" }
    return [file normalize $p]
}

proc wb::ensureDir {path} {
    if {$path ne "" && ![file exists $path]} {
        file mkdir $path
    }
}

proc wb::ensureParentDir {path} {
    if {$path eq ""} { return }
    set d [file dirname $path]
    if {$d ne "" && ![file exists $d]} {
        file mkdir $d
    }
}

proc wb::safeReadFile {path {maxBytes 65536}} {
    if {$path eq "" || ![file exists $path]} { return "" }
    set ch [open $path r]
    set data [read $ch $maxBytes]
    close $ch
    return $data
}

proc wb::appendFileLine {path line} {
    wb::ensureParentDir $path
    set ch [open $path a]
    puts $ch $line
    close $ch
}

proc wb::csvQuote {s} {
    if {[string first "," $s] >= 0 || [string first "\"" $s] >= 0} {
        return "\"[string map {\" \"\"} $s]\""
    }
    return $s
}

proc wb::openPath {path} {
    if {$path eq ""} { return }
    if {![file exists $path]} {
        tk_messageBox -icon warning -title "Percorso non trovato" -message "Il percorso non esiste:\n$path"
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

proc wb::humanSize {bytes} {
    if {$bytes eq ""} { return "" }
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1024*1024} {
        return [format "%.1f KB" [expr {$bytes/1024.0}]]
    } elseif {$bytes < 1024*1024*1024} {
        return [format "%.1f MB" [expr {$bytes/(1024.0*1024.0)}]]
    } else {
        return [format "%.1f GB" [expr {$bytes/(1024.0*1024.0*1024.0)}]]
    }
}

proc wb::splitArgs {argString} {
    if {[string trim $argString] eq ""} { return {} }
    return $argString
}

proc wb::projectRoot {} {
    set d [project::get_data]
    return [dict get $d project rootDir]
}

proc wb::runField {runId key {default ""}} {
    if {$runId eq ""} { return $default }
    if {[catch {set r [project::get runs $runId]}]} { return $default }
    if {[dict exists $r $key]} { return [dict get $r $key] }
    return $default
}

proc wb::setRunStatus {runId status} {
    catch {
        set run [project::get runs $runId]
        dict set run status $status
        project::upsert runs $run
    }
}

# ==================================================
# PROJECT SAVE / LOAD / AUTOSAVE
# ==================================================
proc wb::saveProject {} {
    variable projectFile
    if {$projectFile eq ""} {
        set projectFile [file join [wb::projectRoot] "project_master.tcl"]
    }

    if {[catch {
        wb::ensureParentDir $projectFile
        project::save $projectFile
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Salvataggio progetto fallito:\n$err"
        return
    }
    wb::status "progetto salvato in $projectFile"
}

proc wb::saveProjectAs {} {
    variable projectFile
    set f [tk_getSaveFile -title "Salva progetto" -defaultextension ".tcl" -filetypes {{"Tcl project" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set projectFile $f
    wb::saveProject
}

proc wb::autosaveTick {} {
    variable autosaveEnabled
    variable autosaveIntervalMs
    variable autosaveAfterId

    if {$autosaveEnabled} {
        catch {wb::saveProject}
    }
    set autosaveAfterId [after $autosaveIntervalMs wb::autosaveTick]
}

proc wb::startAutosave {} {
    variable autosaveAfterId
    if {$autosaveAfterId ne ""} {
        after cancel $autosaveAfterId
    }
    set autosaveAfterId [after 15000 wb::autosaveTick]
}

proc wb::stopAutosave {} {
    variable autosaveAfterId
    if {$autosaveAfterId ne ""} {
        after cancel $autosaveAfterId
        set autosaveAfterId ""
    }
}

proc wb::loadProjectDialog {} {
    variable projectFile
    set f [tk_getOpenFile -title "Apri progetto" -filetypes {{"Tcl project" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    if {[catch {project::load $f} err]} {
        tk_messageBox -icon error -title "Errore" -message "Caricamento progetto fallito:\n$err"
        return
    }
    set projectFile $f
    wb::refreshAll
    wb::status "progetto caricato"
}

proc wb::newProjectDialog {} {
    variable projectFile
    set root [tk_chooseDirectory -title "Root directory del progetto"]
    if {$root eq ""} { set root "." }
    project::new "Engineering Workbench Project" $root
    set projectFile [file join $root "project_master.tcl"]
    wb::seedSampleDataIfEmpty
    wb::refreshAll
    wb::status "nuovo progetto creato"
}

proc wb::autoLoadProject {} {
    variable projectFile

    if {[file exists $projectFile]} {
        if {[catch {project::load $projectFile} err]} {
            project::new "Engineering Workbench Project" "."
            wb::seedSampleDataIfEmpty
            catch {wb::saveProject}
        }
    } else {
        project::new "Engineering Workbench Project" "."
        wb::seedSampleDataIfEmpty
        catch {wb::saveProject}
    }
}

proc wb::onExit {} {
    catch {wb::stopAutosave}
    catch {wb::saveProject}
    catch {wb::closeRuntimeLogFile}
    catch {destroy .}
}

# ==================================================
# SAMPLE SEED
# ==================================================
proc wb::seedSampleDataIfEmpty {} {
    if {[llength [project::list_section experiments]] == 0} {
        project::upsert experiments [dict create \
            experimentId [project::next_id experiments] \
            name "Radar Batch Alpha" \
            domain radar \
            status ready \
            configPath "configs/radar_alpha.json" \
            workflowRef [dict create filePath "workflows/radar_alpha.wflow"] \
            baselineRef [dict create path "baselines/radar_alpha.csv"] \
            notes "Campagna nominale radar"]

        project::upsert experiments [dict create \
            experimentId [project::next_id experiments] \
            name "HDL Smoke Set" \
            domain hdl \
            status draft \
            configPath "configs/hdl_smoke.json" \
            workflowRef [dict create filePath "workflows/hdl_smoke.wflow"] \
            baselineRef [dict create path ""] \
            notes "Regression smoke HDL"]
    }

    if {[llength [project::list_section testcases]] == 0} {
        set suite [project::register_testsuite \
            -name "radar_smoke" \
            -domain radar \
            -testcaseIds {} \
            -baselineRef [dict create path "baselines/radar_smoke.csv"] \
            -description "Suite radar smoke"]

        project::upsert testcases [dict create \
            testcaseId [project::next_id testcases] \
            name "Radar nominal detect-track" \
            suiteId [dict get $suite suiteId] \
            domain radar \
            expected pass \
            status ready \
            configPath "configs/radar_nominal.json" \
            workflowRef [dict create filePath "workflows/radar_smoke.wflow"] \
            baselineRef [dict create path ""] \
            notes "Caso smoke radar"]
    }

    if {[llength [project::list_section workflows]] == 0} {
        project::register_workflow \
            -name "Radar default flow" \
            -domain radar \
            -filePath "workflows/radar_default.wflow" \
            -nodes {
                {nodeId N001 label "Prepare config" type config x 80 y 100}
                {nodeId N002 label "Execute runner" type run x 280 y 100}
                {nodeId N003 label "Collect metrics" type metrics x 500 y 100}
                {nodeId N004 label "Validate" type validation x 720 y 100}
                {nodeId N005 label "Finalize" type finalize x 940 y 100}
            } \
            -edges {
                {from N001 to N002}
                {from N002 to N003}
                {from N003 to N004}
                {from N004 to N005}
            } \
            -notes "Workflow seed"
    }

    if {[llength [project::list_section budgets]] == 0} {
        project::new_budget_set \
            -name "Radar budget baseline" \
            -ownerType project \
            -ownerId "" \
            -domain radar \
            -notes "Budget iniziale"
    }
}

# ==================================================
# PROJECT HUB
# ==================================================
proc wb::refreshProjectHub {} {
    set d [project::get_data]
    set runs [project::list_section runs]
    set exps [project::list_section experiments]
    set tcs [project::list_section testcases]
    set suites [project::list_section testsuites]
    set wfs [project::list_section workflows]
    set arts [project::list_section artifacts]
    set vals [project::list_section validationResults]
    set buds [project::list_section budgets]

    set running 0
    set ok 0
    set warn 0
    set fail 0
    set other 0
    foreach r $runs {
        set s [wb::safeDictGet $r status]
        switch -- $s {
            running { incr running }
            ok { incr ok }
            warn { incr warn }
            fail { incr fail }
            default { incr other }
        }
    }

    set txt ""
    append txt "Project: [dict get $d project name]\n"
    append txt "RootDir: [dict get $d project rootDir]\n"
    append txt "SchemaVersion: [dict get $d schemaVersion]\n"
    append txt "CreatedAt: [dict get $d project createdAt]\n"
    append txt "UpdatedAt: [dict get $d project updatedAt]\n\n"

    append txt "Experiments: [llength $exps]\n"
    append txt "Testcases: [llength $tcs]\n"
    append txt "TestSuites: [llength $suites]\n"
    append txt "Workflows: [llength $wfs]\n"
    append txt "Runs: [llength $runs]\n"
    append txt "Artifacts: [llength $arts]\n"
    append txt "ValidationResults: [llength $vals]\n"
    append txt "BudgetSets: [llength $buds]\n\n"

    append txt "Run status:\n"
    append txt "  running = $running\n"
    append txt "  ok      = $ok\n"
    append txt "  warn    = $warn\n"
    append txt "  fail    = $fail\n"
    append txt "  other   = $other\n"

    $::wb::ui(hubText) configure -state normal
    $::wb::ui(hubText) delete 1.0 end
    $::wb::ui(hubText) insert end $txt
    $::wb::ui(hubText) configure -state disabled
}

# ==================================================
# EXPERIMENTS
# ==================================================
proc wb::clearExperimentEditor {} {
    set ::wb::expId ""
    set ::wb::expName ""
    set ::wb::expDomain "radar"
    set ::wb::expStatus "draft"
    set ::wb::expConfigPath ""
    set ::wb::expWorkflowPath ""
    set ::wb::expBaselinePath ""
    set ::wb::expNotes ""
    if {[winfo exists .experimentsTab.right.e8]} {
        .experimentsTab.right.e8 delete 1.0 end
    }
}

proc wb::refreshExperimentsTable {} {
    set tree $::wb::ui(expTree)
    $tree delete [$tree children {}]
    foreach e [project::list_section experiments] {
        set id [dict get $e experimentId]
        set wfPath ""
        if {[dict exists $e workflowRef filePath]} { set wfPath [dict get $e workflowRef filePath] }
        set blPath ""
        if {[dict exists $e baselineRef path]} { set blPath [dict get $e baselineRef path] }
        $tree insert {} end -id $id -values [list \
            $id \
            [wb::safeDictGet $e name] \
            [wb::safeDictGet $e domain] \
            [wb::safeDictGet $e status] \
            [wb::safeDictGet $e configPath] \
            $wfPath \
            $blPath]
    }
}

proc wb::loadExperimentIntoEditor {id} {
    if {$id eq ""} { return }
    set e [project::get experiments $id]
    set ::wb::expId [dict get $e experimentId]
    set ::wb::expName [wb::safeDictGet $e name]
    set ::wb::expDomain [wb::safeDictGet $e domain radar]
    set ::wb::expStatus [wb::safeDictGet $e status draft]
    set ::wb::expConfigPath [wb::safeDictGet $e configPath]
    set ::wb::expWorkflowPath [expr {[dict exists $e workflowRef filePath] ? [dict get $e workflowRef filePath] : ""}]
    set ::wb::expBaselinePath [expr {[dict exists $e baselineRef path] ? [dict get $e baselineRef path] : ""}]
    set ::wb::expNotes [wb::safeDictGet $e notes]
    .experimentsTab.right.e8 delete 1.0 end
    .experimentsTab.right.e8 insert 1.0 $::wb::expNotes
}

proc wb::onExperimentTreeSelect {} {
    set tree $::wb::ui(expTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    wb::loadExperimentIntoEditor [lindex $sel 0]
}

proc wb::saveExperiment {} {
    set item [dict create \
        experimentId $::wb::expId \
        name $::wb::expName \
        domain $::wb::expDomain \
        status $::wb::expStatus \
        configPath $::wb::expConfigPath \
        workflowRef [dict create filePath $::wb::expWorkflowPath] \
        baselineRef [dict create path $::wb::expBaselinePath] \
        notes $::wb::expNotes]
    set saved [project::upsert experiments $item]
    set ::wb::expId [dict get $saved experimentId]
    wb::refreshExperimentsTable
    wb::refreshProjectHub
    wb::saveProject
    wb::status "esperimento salvato"
}

proc wb::deleteExperiment {} {
    if {$::wb::expId eq ""} { return }
    project::delete experiments $::wb::expId
    wb::clearExperimentEditor
    wb::refreshExperimentsTable
    wb::refreshProjectHub
    wb::saveProject
    wb::status "esperimento eliminato"
}

proc wb::useExperimentInLauncher {} {
    if {$::wb::expId eq ""} { return }
    set ::wb::launchSourceType experiment
    set ::wb::launchSourceId $::wb::expId
    set ::wb::launchCaseName $::wb::expName
    set ::wb::launchConfigPath $::wb::expConfigPath
    set ::wb::launchWorkflowId [wb::findWorkflowIdByFilePath $::wb::expWorkflowPath]
    wb::selectLauncherProfileForDomain $::wb::expDomain
    wb::updateLauncherPreview
    .nb select .launcherTab
}

# ==================================================
# TESTCASES
# ==================================================
proc wb::clearTestEditor {} {
    set ::wb::tcId ""
    set ::wb::tcName ""
    set ::wb::tcSuiteId ""
    set ::wb::tcDomain "radar"
    set ::wb::tcExpected "pass"
    set ::wb::tcStatus "draft"
    set ::wb::tcConfigPath ""
    set ::wb::tcWorkflowPath ""
    set ::wb::tcBaselinePath ""
    set ::wb::tcNotes ""
    if {[winfo exists .testbenchTab.right.notes]} {
        .testbenchTab.right.notes delete 1.0 end
    }
}

proc wb::refreshTestsTable {} {
    set tree $::wb::ui(tcTree)
    $tree delete [$tree children {}]
    foreach t [project::list_section testcases] {
        set wfPath ""
        if {[dict exists $t workflowRef filePath]} { set wfPath [dict get $t workflowRef filePath] }
        set blPath ""
        if {[dict exists $t baselineRef path]} { set blPath [dict get $t baselineRef path] }
        $tree insert {} end -id [dict get $t testcaseId] -values [list \
            [dict get $t testcaseId] \
            [wb::safeDictGet $t name] \
            [wb::safeDictGet $t suiteId] \
            [wb::safeDictGet $t domain] \
            [wb::safeDictGet $t expected] \
            [wb::safeDictGet $t status] \
            [wb::safeDictGet $t configPath] \
            $wfPath \
            $blPath]
    }
}

proc wb::loadTestIntoEditor {id} {
    if {$id eq ""} { return }
    set t [project::get testcases $id]
    set ::wb::tcId [dict get $t testcaseId]
    set ::wb::tcName [wb::safeDictGet $t name]
    set ::wb::tcSuiteId [wb::safeDictGet $t suiteId]
    set ::wb::tcDomain [wb::safeDictGet $t domain radar]
    set ::wb::tcExpected [wb::safeDictGet $t expected pass]
    set ::wb::tcStatus [wb::safeDictGet $t status draft]
    set ::wb::tcConfigPath [wb::safeDictGet $t configPath]
    set ::wb::tcWorkflowPath [expr {[dict exists $t workflowRef filePath] ? [dict get $t workflowRef filePath] : ""}]
    set ::wb::tcBaselinePath [expr {[dict exists $t baselineRef path] ? [dict get $t baselineRef path] : ""}]
    set ::wb::tcNotes [wb::safeDictGet $t notes]
    .testbenchTab.right.notes delete 1.0 end
    .testbenchTab.right.notes insert 1.0 $::wb::tcNotes
}

proc wb::onTestTreeSelect {} {
    set tree $::wb::ui(tcTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    wb::loadTestIntoEditor [lindex $sel 0]
}

proc wb::saveTest {} {
    set item [dict create \
        testcaseId $::wb::tcId \
        name $::wb::tcName \
        suiteId $::wb::tcSuiteId \
        domain $::wb::tcDomain \
        expected $::wb::tcExpected \
        status $::wb::tcStatus \
        configPath $::wb::tcConfigPath \
        workflowRef [dict create filePath $::wb::tcWorkflowPath] \
        baselineRef [dict create path $::wb::tcBaselinePath] \
        notes $::wb::tcNotes]
    set saved [project::upsert testcases $item]
    set ::wb::tcId [dict get $saved testcaseId]
    wb::refreshTestsTable
    wb::refreshProjectHub
    wb::saveProject
    wb::status "testcase salvato"
}

proc wb::deleteTest {} {
    if {$::wb::tcId eq ""} { return }
    project::delete testcases $::wb::tcId
    wb::clearTestEditor
    wb::refreshTestsTable
    wb::refreshProjectHub
    wb::saveProject
    wb::status "testcase eliminato"
}

proc wb::useTestInLauncher {} {
    if {$::wb::tcId eq ""} { return }
    set ::wb::launchSourceType testcase
    set ::wb::launchSourceId $::wb::tcId
    set ::wb::launchCaseName $::wb::tcName
    set ::wb::launchConfigPath $::wb::tcConfigPath
    set ::wb::launchWorkflowId [wb::findWorkflowIdByFilePath $::wb::tcWorkflowPath]
    wb::selectLauncherProfileForDomain $::wb::tcDomain
    wb::updateLauncherPreview
    .nb select .launcherTab
}

# ==================================================
# WORKFLOWS
# ==================================================
proc wb::clearWorkflowEditor {} {
    set ::wb::wfId ""
    set ::wb::wfName ""
    set ::wb::wfVersion "1"
    set ::wb::wfDomain "radar"
    set ::wb::wfFilePath ""
    set ::wb::wfNotes ""
    set ::wb::workflowNodes {}
    set ::wb::workflowEdges {}
    wb::drawWorkflowCanvas
}

proc wb::refreshWorkflowTable {} {
    set tree $::wb::ui(wfTree)
    $tree delete [$tree children {}]
    foreach wf [project::list_section workflows] {
        $tree insert {} end -id [dict get $wf workflowId] -values [list \
            [dict get $wf workflowId] \
            [wb::safeDictGet $wf name] \
            [wb::safeDictGet $wf version] \
            [wb::safeDictGet $wf domain] \
            [llength [wb::safeDictGet $wf nodes {}]] \
            [wb::safeDictGet $wf filePath]]
    }
    wb::drawWorkflowCanvas
}

proc wb::loadWorkflowIntoEditor {id} {
    if {$id eq ""} { return }
    set wf [project::get workflows $id]
    set ::wb::wfId [dict get $wf workflowId]
    set ::wb::wfName [wb::safeDictGet $wf name]
    set ::wb::wfVersion [wb::safeDictGet $wf version 1]
    set ::wb::wfDomain [wb::safeDictGet $wf domain radar]
    set ::wb::wfFilePath [wb::safeDictGet $wf filePath]
    set ::wb::wfNotes [wb::safeDictGet $wf notes]
    set ::wb::workflowNodes [wb::safeDictGet $wf nodes {}]
    set ::wb::workflowEdges [wb::safeDictGet $wf edges {}]
    wb::drawWorkflowCanvas
}

proc wb::onWorkflowTreeSelect {} {
    set tree $::wb::ui(wfTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    wb::loadWorkflowIntoEditor [lindex $sel 0]
}

proc wb::saveWorkflow {} {
    set wf [project::register_workflow \
        -workflowId $::wb::wfId \
        -name $::wb::wfName \
        -version $::wb::wfVersion \
        -filePath $::wb::wfFilePath \
        -domain $::wb::wfDomain \
        -nodes $::wb::workflowNodes \
        -edges $::wb::workflowEdges \
        -notes $::wb::wfNotes]
    set ::wb::wfId [dict get $wf workflowId]
    wb::refreshWorkflowTable
    wb::saveProject
    wb::status "workflow salvato"
}

proc wb::deleteWorkflow {} {
    if {$::wb::wfId eq ""} { return }
    project::delete workflows $::wb::wfId
    wb::clearWorkflowEditor
    wb::refreshWorkflowTable
    wb::saveProject
    wb::status "workflow eliminato"
}

proc wb::addWorkflowNode {} {
    set idx [expr {[llength $::wb::workflowNodes] + 1}]
    set id [format "N%03d" $idx]
    set node [dict create nodeId $id label "Node $idx" type generic x [expr {80 + ($idx-1)*140}] y 120]
    lappend ::wb::workflowNodes $node
    if {[llength $::wb::workflowNodes] > 1} {
        set prev [lindex $::wb::workflowNodes end-1]
        lappend ::wb::workflowEdges [dict create from [dict get $prev nodeId] to $id]
    }
    wb::drawWorkflowCanvas
}

proc wb::drawWorkflowCanvas {} {
    if {![info exists ::wb::ui(wfCanvas)]} { return }
    set c $::wb::ui(wfCanvas)
    $c delete all

    array unset pos
    foreach n $::wb::workflowNodes {
        set id [dict get $n nodeId]
        set x [wb::safeDictGet $n x 100]
        set y [wb::safeDictGet $n y 100]
        set label [wb::safeDictGet $n label $id]
        set type [wb::safeDictGet $n type generic]
        set pos($id) [list $x $y]
        $c create rectangle [expr {$x-60}] [expr {$y-28}] [expr {$x+60}] [expr {$y+28}] -fill "#dfefff" -outline "#305080" -width 2
        $c create text $x [expr {$y-6}] -text $label -font "TkDefaultFont 9 bold"
        $c create text $x [expr {$y+11}] -text $type -fill "#444444"
    }

    foreach e $::wb::workflowEdges {
        set from [dict get $e from]
        set to [dict get $e to]
        if {[info exists pos($from)] && [info exists pos($to)]} {
            lassign $pos($from) x1 y1
            lassign $pos($to) x2 y2
            $c create line [expr {$x1+60}] $y1 [expr {$x2-60}] $y2 -arrow last -width 2 -fill "#2e6f9e"
        }
    }
}

proc wb::useWorkflowInLauncher {} {
    if {$::wb::wfId eq ""} { return }
    set ::wb::launchWorkflowId $::wb::wfId
    wb::updateLauncherPreview
    .nb select .launcherTab
}

proc wb::exportSelectedWorkflow {} {
    if {$::wb::wfId eq ""} { return }
    set f [tk_getSaveFile -title "Esporta workflow" -defaultextension ".wflow" -filetypes {{"Workflow" {.wflow .tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    project::export_workflow $::wb::wfId $f
    wb::status "workflow esportato"
}

proc wb::importWorkflowDialog {} {
    set f [tk_getOpenFile -title "Importa workflow" -filetypes {{"Workflow" {.wflow .tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set wf [project::import_workflow $f]
    set ::wb::wfId [dict get $wf workflowId]
    wb::refreshWorkflowTable
    wb::saveProject
    wb::status "workflow importato"
}

# ==================================================
# LAUNCHER / WORKFLOW EXECUTION
# ==================================================
proc wb::profileNames {} {
    set out {}
    foreach p $::wb::launchProfiles { lappend out [dict get $p name] }
    return $out
}

proc wb::findProfileByName {name} {
    foreach p $::wb::launchProfiles {
        if {[dict get $p name] eq $name} { return $p }
    }
    return ""
}

proc wb::selectLauncherProfileForDomain {domain} {
    foreach p $::wb::launchProfiles {
        if {[dict get $p domain] eq $domain} {
            set ::wb::launchProfile [dict get $p name]
            return
        }
    }
}

proc wb::findWorkflowIdByFilePath {filePath} {
    if {$filePath eq ""} { return "" }
    foreach wf [project::list_section workflows] {
        if {[wb::safeDictGet $wf filePath] eq $filePath} {
            return [dict get $wf workflowId]
        }
    }
    return ""
}

proc wb::buildLauncherOutputDir {} {
    set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set name [string trim $::wb::launchCaseName]
    if {$name eq ""} { set name "run" }
    set safe [string map {" " "_" "/" "_" "\\" "_"} $name]
    return [file join $::wb::launchOutputRoot "${safe}_$ts"]
}

proc wb::buildLaunchCommand {} {
    set p [wb::findProfileByName $::wb::launchProfile]
    if {$p eq ""} { return [list {} ""] }

    set ptype [dict get $p type]
    set launcher [dict get $p launcher]
    set target [dict get $p target]
    set pextra [dict get $p extra_args]
    set outdir [wb::buildLauncherOutputDir]

    set cmd {}
    switch -- $ptype {
        python_script {
            lappend cmd $launcher $target --config $::wb::launchConfigPath --output $outdir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $::wb::launchExtraArgs] { lappend cmd $a }
        }
        cpp_executable {
            lappend cmd $launcher --config $::wb::launchConfigPath --output $outdir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $::wb::launchExtraArgs] { lappend cmd $a }
        }
        hdl_runner {
            lappend cmd $launcher $target --config $::wb::launchConfigPath --output $outdir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $::wb::launchExtraArgs] { lappend cmd $a }
        }
        matlab_function {
            set expr [format "%s('%s')" $target $::wb::launchConfigPath]
            lappend cmd $launcher -batch $expr
        }
        default {
            lappend cmd $launcher
        }
    }
    return [list $cmd $outdir]
}

proc wb::updateLauncherPreview {} {
    if {![info exists ::wb::ui(cmdPreview)]} { return }
    lassign [wb::buildLaunchCommand] cmd outdir
    set t $::wb::ui(cmdPreview)
    $t configure -state normal
    $t delete 1.0 end
    $t insert end "Profile: $::wb::launchProfile\n"
    $t insert end "SourceType: $::wb::launchSourceType\n"
    $t insert end "SourceId: $::wb::launchSourceId\n"
    $t insert end "WorkflowId: $::wb::launchWorkflowId\n\n"
    $t insert end [join $cmd " "]
    if {$outdir ne ""} {
        $t insert end "\n\nOutput dir: $outdir"
        $t insert end "\nLog file: [file join $outdir run.log]"
        $t insert end "\nMetrics file: [file join $outdir metrics.csv]"
    }
    $t configure -state disabled
}

proc wb::resolveSourceContextForLaunch {} {
    set ctx [dict create \
        sourceType $::wb::launchSourceType \
        sourceId $::wb::launchSourceId \
        experimentId "" \
        testcaseId "" \
        suiteId "" \
        workflowId $::wb::launchWorkflowId \
        domain "" \
        configPath $::wb::launchConfigPath \
        baselineHint ""]

    switch -- $::wb::launchSourceType {
        experiment {
            if {$::wb::launchSourceId ne "" && [project::exists experiments $::wb::launchSourceId]} {
                set exp [project::get experiments $::wb::launchSourceId]
                dict set ctx experimentId [dict get $exp experimentId]
                dict set ctx domain [wb::safeDictGet $exp domain]
                if {[string trim [dict get $ctx configPath]] eq ""} {
                    dict set ctx configPath [wb::safeDictGet $exp configPath]
                }
                if {[dict exists $exp workflowRef filePath] && [string trim [dict get $ctx workflowId]] eq ""} {
                    dict set ctx workflowId [wb::findWorkflowIdByFilePath [dict get $exp workflowRef filePath]]
                }
                if {[dict exists $exp baselineRef path]} {
                    dict set ctx baselineHint [dict get $exp baselineRef path]
                }
            }
        }
        testcase {
            if {$::wb::launchSourceId ne "" && [project::exists testcases $::wb::launchSourceId]} {
                set tc [project::get testcases $::wb::launchSourceId]
                dict set ctx testcaseId [dict get $tc testcaseId]
                dict set ctx suiteId [wb::safeDictGet $tc suiteId]
                dict set ctx domain [wb::safeDictGet $tc domain]
                if {[string trim [dict get $ctx configPath]] eq ""} {
                    dict set ctx configPath [wb::safeDictGet $tc configPath]
                }
                if {[dict exists $tc workflowRef filePath] && [string trim [dict get $ctx workflowId]] eq ""} {
                    dict set ctx workflowId [wb::findWorkflowIdByFilePath [dict get $tc workflowRef filePath]]
                }
                if {[dict exists $tc baselineRef path]} {
                    dict set ctx baselineHint [dict get $tc baselineRef path]
                }
            }
        }
        suite {
            if {$::wb::launchSourceId ne "" && [project::exists testsuites $::wb::launchSourceId]} {
                set ts [project::get testsuites $::wb::launchSourceId]
                dict set ctx suiteId [dict get $ts suiteId]
                dict set ctx domain [wb::safeDictGet $ts domain]
                if {[dict exists $ts baselineRef path]} {
                    dict set ctx baselineHint [dict get $ts baselineRef path]
                }
            }
        }
    }

    if {[dict get $ctx domain] eq ""} {
        set p [wb::findProfileByName $::wb::launchProfile]
        if {$p ne ""} {
            dict set ctx domain [dict get $p domain]
        }
    }

    return $ctx
}

proc wb::resolveWorkflowNodesForLaunch {ctx} {
    set wfId [dict get $ctx workflowId]
    if {$wfId ne "" && [project::exists workflows $wfId]} {
        set wf [project::get workflows $wfId]
        return [wb::safeDictGet $wf nodes {}]
    }

    return {
        {nodeId N001 label "Prepare config" type config x 80 y 100}
        {nodeId N002 label "Execute runner" type run x 280 y 100}
        {nodeId N003 label "Collect metrics" type metrics x 500 y 100}
        {nodeId N004 label "Validate" type validation x 720 y 100}
        {nodeId N005 label "Report" type report x 940 y 100}
        {nodeId N006 label "Finalize" type finalize x 1160 y 100}
    }
}

proc wb::openRuntimeLogFile {path} {
    if {$::wb::runtimeLogChan ne ""} {
        catch {close $::wb::runtimeLogChan}
    }
    set ::wb::runtimeLogChan [open $path w]
}

proc wb::closeRuntimeLogFile {} {
    if {$::wb::runtimeLogChan ne ""} {
        catch {close $::wb::runtimeLogChan}
        set ::wb::runtimeLogChan ""
    }
}

proc wb::parseLogLine {line} {
    set sev info
    set status ""
    set category log
    set label "Log line"
    set details $line

    if {[regexp -nocase {\b(ERROR|FATAL|EXCEPTION)\b} $line]} {
        set sev error
        set status fail
    } elseif {[regexp -nocase {\b(WARN|WARNING)\b} $line]} {
        set sev warn
        set status warn
    } elseif {[regexp -nocase {\b(OK|SUCCESS|DONE|COMPLETED)\b} $line]} {
        set sev info
        set status ok
    }

    if {[regexp {NODE_START[[:space:]]+nodeId=([^[:space:]]+)[[:space:]]+label=(.+)[[:space:]]+type=([^[:space:]]+)} $line -> nodeId nodeLabel nodeType]} {
        set category workflow
        set label "Node start: $nodeLabel"
        return [dict create severity $sev status running category $category label $label details $details nodeId $nodeId]
    }

    if {[regexp {NODE_END[[:space:]]+nodeId=([^[:space:]]+)[[:space:]]+label=(.+)[[:space:]]+status=([^[:space:]]+)[[:space:]]+details=(.+)} $line -> nodeId nodeLabel st det]} {
        set sev [expr {$st eq "fail" ? "error" : ($st eq "warn" ? "warn" : "info")}]
        set category workflow
        set label "Node end: $nodeLabel"
        return [dict create severity $sev status $st category $category label $label details $det nodeId $nodeId]
    }

    if {[regexp -nocase {\bvalidation\b} $line]} {
        set category validation
        set label "Validation log"
    } elseif {[regexp -nocase {\bartifact\b} $line]} {
        set category artifact
        set label "Artifact log"
    } elseif {[regexp -nocase {\bworkflow\b} $line]} {
        set category workflow
        set label "Workflow log"
    }

    return [dict create severity $sev status $status category $category label $label details $details nodeId ""]
}

proc wb::runtimeTagForMessage {msg} {
    set parsed [wb::parseLogLine $msg]
    return [dict get $parsed severity]
}

proc wb::configureRuntimeLogTags {} {
    $::wb::ui(runtimeLog) tag configure error -foreground red
    $::wb::ui(runtimeLog) tag configure warn -foreground darkorange3
    $::wb::ui(runtimeLog) tag configure info -foreground black
}

proc wb::clearRuntimeLog {} {
    $::wb::ui(runtimeLog) delete 1.0 end
}

proc wb::logRuntime {msg} {
    set tag [wb::runtimeTagForMessage $msg]
    set line "[wb::nowString]  $msg\n"
    $::wb::ui(runtimeLog) insert end $line $tag
    $::wb::ui(runtimeLog) see end
    update idletasks

    if {$::wb::runtimeLogChan ne ""} {
        puts $::wb::runtimeLogChan $line
        flush $::wb::runtimeLogChan
    }
}

proc wb::startRun {} {
    if {$::wb::running || $::wb::workflowExecActive} { return }

    set ctx [wb::resolveSourceContextForLaunch]
    set outdir [wb::buildLauncherOutputDir]
    wb::ensureDir $::wb::launchOutputRoot
    wb::ensureDir $outdir

    set logPath [file join $outdir "run.log"]
    set metricsPath [file join $outdir "metrics.csv"]

    set run [project::new_run \
        -name $::wb::launchCaseName \
        -sourceType [dict get $ctx sourceType] \
        -sourceId [dict get $ctx sourceId] \
        -experimentId [dict get $ctx experimentId] \
        -testcaseId [dict get $ctx testcaseId] \
        -suiteId [dict get $ctx suiteId] \
        -workflowId [dict get $ctx workflowId] \
        -profile $::wb::launchProfile \
        -domain [dict get $ctx domain] \
        -configPath [dict get $ctx configPath] \
        -outputDir $outdir \
        -logPath $logPath \
        -metricsPath $metricsPath \
        -notes $::wb::launchNotes]

    set runId [dict get $run runId]
    set resolved [project::resolve_baseline_for_run $runId]
    project::update_field runs $runId baselineResolvedPath [dict get $resolved path]

    set ::wb::currentRunningRunId $runId
    set ::wb::workflowExecRunId $runId
    set ::wb::workflowExecOutputDir $outdir
    set ::wb::workflowExecMetricsPath $metricsPath
    set ::wb::workflowExecLogPath $logPath
    set ::wb::workflowExecQueue [wb::resolveWorkflowNodesForLaunch $ctx]
    set ::wb::workflowExecIndex -1
    set ::wb::workflowExecActive 1
    set ::wb::running 1

    wb::clearRuntimeLog
    wb::openRuntimeLogFile $logPath
    wb::logRuntime "INFO: runId=$runId"
    wb::logRuntime "INFO: sourceType=[dict get $ctx sourceType]"
    wb::logRuntime "INFO: sourceId=[dict get $ctx sourceId]"
    wb::logRuntime "INFO: workflowId=[dict get $ctx workflowId]"
    wb::logRuntime "INFO: baseline=[dict get $resolved path] ([dict get $resolved bindingSource])"
    wb::logRuntime "INFO: outputDir=$outdir"

    if {![file exists $metricsPath]} {
        set fh [open $metricsPath w]
        puts $fh "metric,value,min,max"
        close $fh
    }

    .nb select .runtimeTab
    wb::refreshAll
    wb::status "workflow run avviato"

    after 200 wb::executeNextWorkflowNode
}

proc wb::stopRun {} {
    if {!$::wb::running} { return }

    set runId $::wb::workflowExecRunId

    set ::wb::workflowExecActive 0
    set ::wb::running 0
    set ::wb::workflowExecQueue {}
    set ::wb::workflowExecIndex -1

    wb::closeRuntimeLogFile
    if {$runId ne ""} {
        catch {project::close_run $runId fail -1}
        catch {
            project::add_timeline_event \
                -runId $runId \
                -category run \
                -label "Run stopped" \
                -status fail \
                -severity error \
                -details "Stopped by user"
        }
    }

    wb::refreshAll
    wb::status "run interrotta"
}

proc wb::executeNextWorkflowNode {} {
    if {!$::wb::workflowExecActive} { return }

    incr ::wb::workflowExecIndex
    if {$::wb::workflowExecIndex >= [llength $::wb::workflowExecQueue]} {
        wb::finalizeWorkflowRun
        return
    }

    set node [lindex $::wb::workflowExecQueue $::wb::workflowExecIndex]
    wb::executeWorkflowNode $node
}

proc wb::executeWorkflowNode {node} {
    set runId $::wb::workflowExecRunId
    set nodeId [wb::safeDictGet $node nodeId]
    set label [wb::safeDictGet $node label $nodeId]
    set type [string tolower [wb::safeDictGet $node type generic]]

    project::add_timeline_event \
        -runId $runId \
        -workflowId [wb::runField $runId workflowId] \
        -nodeId $nodeId \
        -category workflow \
        -label "Node start: $label" \
        -status running \
        -severity info \
        -details "type=$type"

    wb::logRuntime "INFO: NODE_START nodeId=$nodeId label=$label type=$type"

    switch -- $type {
        config     { wb::workflowNode_config $node }
        run        -
        matlab     -
        python     -
        hdl        { wb::workflowNode_run $node }
        artifact   { wb::workflowNode_artifact $node }
        metrics    { wb::workflowNode_metrics $node }
        validation { wb::workflowNode_validation $node }
        report     { wb::workflowNode_report $node }
        finalize   { wb::workflowNode_finalize $node }
        default    { wb::workflowNode_generic $node }
    }
}

proc wb::workflowNodeDone {node status details} {
    set runId $::wb::workflowExecRunId
    set nodeId [wb::safeDictGet $node nodeId]
    set label [wb::safeDictGet $node label $nodeId]

    set severity info
    if {$status eq "warn"} { set severity warn }
    if {$status eq "fail"} { set severity error }

    wb::logRuntime "[string toupper $severity]: NODE_END nodeId=$nodeId label=$label status=$status details=$details"

    project::add_timeline_event \
        -runId $runId \
        -workflowId [wb::runField $runId workflowId] \
        -nodeId $nodeId \
        -category workflow \
        -label "Node end: $label" \
        -status $status \
        -severity $severity \
        -details $details

    wb::refreshAll
    after 250 wb::executeNextWorkflowNode
}

proc wb::workflowNode_generic {node} {
    after 400 [list wb::workflowNodeDone $node ok "generic node completed"]
}

proc wb::workflowNode_config {node} {
    set runId $::wb::workflowExecRunId
    set outdir $::wb::workflowExecOutputDir
    set path [file join $outdir "resolved_config.json"]

    set cfg [dict create \
        runId $runId \
        sourceType [wb::runField $runId sourceType] \
        sourceId [wb::runField $runId sourceId] \
        profile [wb::runField $runId profile] \
        configPath [wb::runField $runId configPath] \
        generatedAt [wb::nowString]]

    set fh [open $path w]
    puts $fh $cfg
    close $fh

    project::register_artifact \
        -runId $runId \
        -experimentId [wb::runField $runId experimentId] \
        -testcaseId [wb::runField $runId testcaseId] \
        -workflowId [wb::runField $runId workflowId] \
        -nodeId [wb::safeDictGet $node nodeId] \
        -path $path \
        -label "Resolved config" \
        -producer workflow

    after 350 [list wb::workflowNodeDone $node ok "config generated"]
}

proc wb::workflowNode_run {node} {
    set runId $::wb::workflowExecRunId
    set outdir $::wb::workflowExecOutputDir
    set nodeId [wb::safeDictGet $node nodeId]
    set stdoutPath [file join $outdir "stdout_node_${nodeId}.log"]

    wb::appendFileLine $stdoutPath "[wb::nowString] executing run node [wb::safeDictGet $node label]"
    wb::appendFileLine $stdoutPath "[wb::nowString] launcher=$::wb::launchProfile"
    wb::appendFileLine $stdoutPath "[wb::nowString] config=[wb::runField $runId configPath]"

    project::register_artifact \
        -runId $runId \
        -experimentId [wb::runField $runId experimentId] \
        -testcaseId [wb::runField $runId testcaseId] \
        -workflowId [wb::runField $runId workflowId] \
        -nodeId $nodeId \
        -path $stdoutPath \
        -label "Node stdout $nodeId" \
        -producer workflow

    wb::logRuntime "OK: execution step completed for node=$nodeId"
    after 900 [list wb::workflowNodeDone $node ok "runner completed"]
}

proc wb::workflowNode_artifact {node} {
    set runId $::wb::workflowExecRunId
    set outdir $::wb::workflowExecOutputDir
    set nodeId [wb::safeDictGet $node nodeId]
    set path [file join $outdir "artifact_${nodeId}.txt"]

    set fh [open $path w]
    puts $fh "Artifact generated by workflow node $nodeId"
    puts $fh "RunId: $runId"
    puts $fh "Timestamp: [wb::nowString]"
    close $fh

    project::register_artifact \
        -runId $runId \
        -experimentId [wb::runField $runId experimentId] \
        -testcaseId [wb::runField $runId testcaseId] \
        -workflowId [wb::runField $runId workflowId] \
        -nodeId $nodeId \
        -path $path \
        -label "Workflow artifact $nodeId" \
        -producer workflow

    after 300 [list wb::workflowNodeDone $node ok "artifact generated"]
}

proc wb::workflowNode_metrics {node} {
    set metricsPath $::wb::workflowExecMetricsPath

    set rows {
        {latency_ms 13 0 10}
        {snr_db 22 18 40}
        {tracks 45 40 999}
        {false_alarm_rate 0.8 0 1.0}
    }

    set fh [open $metricsPath w]
    puts $fh "metric,value,min,max"
    foreach r $rows {
        lassign $r metric value min max
        puts $fh "[wb::csvQuote $metric],[wb::csvQuote $value],[wb::csvQuote $min],[wb::csvQuote $max]"
    }
    close $fh

    project::register_artifact \
        -runId $::wb::workflowExecRunId \
        -experimentId [wb::runField $::wb::workflowExecRunId experimentId] \
        -testcaseId [wb::runField $::wb::workflowExecRunId testcaseId] \
        -workflowId [wb::runField $::wb::workflowExecRunId workflowId] \
        -nodeId [wb::safeDictGet $node nodeId] \
        -path $metricsPath \
        -label "Metrics CSV" \
        -producer workflow

    after 350 [list wb::workflowNodeDone $node ok "metrics collected"]
}

proc wb::workflowNode_validation {node} {
    set runId $::wb::workflowExecRunId
    catch {project::bind_and_register_validation_stub $runId $::wb::workflowExecMetricsPath}
    catch {wb::loadValidationForRun $runId}

    set status ok
    if {$::wb::failCount > 0} {
        set status fail
    } elseif {$::wb::warnCount > 0} {
        set status warn
    }

    after 300 [list wb::workflowNodeDone $node $status "validation completed"]
}

proc wb::workflowNode_report {node} {
    set runId $::wb::workflowExecRunId
    set outdir $::wb::workflowExecOutputDir
    set reportPath [file join $outdir "summary_report.txt"]

    set fh [open $reportPath w]
    puts $fh "Engineering Workbench Summary Report"
    puts $fh "RunId: $runId"
    puts $fh "CreatedAt: [wb::nowString]"
    puts $fh "Profile: [wb::runField $runId profile]"
    puts $fh "Status: [wb::runField $runId status running]"
    puts $fh "Baseline: [wb::runField $runId baselineResolvedPath]"
    puts $fh "Metrics: $::wb::workflowExecMetricsPath"
    close $fh

    project::register_artifact \
        -runId $runId \
        -experimentId [wb::runField $runId experimentId] \
        -testcaseId [wb::runField $runId testcaseId] \
        -workflowId [wb::runField $runId workflowId] \
        -nodeId [wb::safeDictGet $node nodeId] \
        -path $reportPath \
        -label "Summary report" \
        -producer workflow

    after 300 [list wb::workflowNodeDone $node ok "report generated"]
}

proc wb::workflowNode_finalize {node} {
    project::auto_register_standard_artifacts $::wb::workflowExecRunId
    after 200 [list wb::workflowNodeDone $node ok "finalization completed"]
}

proc wb::finalizeWorkflowRun {} {
    set runId $::wb::workflowExecRunId

    set finalStatus ok
    if {$::wb::failCount > 0} {
        set finalStatus fail
    } elseif {$::wb::warnCount > 0} {
        set finalStatus warn
    }

    catch {project::close_run $runId $finalStatus 0}
    catch {
        project::add_timeline_event \
            -runId $runId \
            -workflowId [wb::runField $runId workflowId] \
            -category run \
            -label "Workflow execution completed" \
            -status $finalStatus \
            -severity [expr {$finalStatus eq "fail" ? "error" : ($finalStatus eq "warn" ? "warn" : "info")}] \
            -details "nodeCount=[llength $::wb::workflowExecQueue]"
    }

    wb::closeRuntimeLogFile
    set ::wb::workflowExecActive 0
    set ::wb::running 0
    set ::wb::workflowExecQueue {}
    set ::wb::workflowExecIndex -1

    wb::refreshAll
    wb::saveProject
    wb::status "workflow completato"
}

# ==================================================
# RUN HISTORY
# ==================================================
proc wb::refreshRunsTable {} {
    set tree $::wb::ui(runTree)
    $tree delete [$tree children {}]

    foreach r [project::list_section runs] {
        set id [dict get $r runId]
        set item [$tree insert {} end -id $id -values [list \
            $id \
            [wb::safeDictGet $r name] \
            [wb::safeDictGet $r sourceType] \
            [wb::safeDictGet $r sourceId] \
            [wb::safeDictGet $r profile] \
            [wb::safeDictGet $r status] \
            [wb::safeDictGet $r startedAt] \
            [wb::safeDictGet $r endedAt]]]

        switch -- [wb::safeDictGet $r status] {
            ok { $tree item $item -tags ok }
            warn { $tree item $item -tags warn }
            fail { $tree item $item -tags fail }
            running { $tree item $item -tags running }
        }
    }
}

proc wb::selectedRunId {} {
    set tree $::wb::ui(runTree)
    set sel [$tree selection]
    if {$sel eq ""} { return "" }
    return [lindex $sel 0]
}

proc wb::selectedRunDict {} {
    set id [wb::selectedRunId]
    if {$id eq ""} { return "" }
    return [project::get runs $id]
}

proc wb::onRunTreeSelect {} {
    set r [wb::selectedRunDict]
    if {$r eq ""} { return }

    .runsTab.right.idV configure -text [dict get $r runId]
    .runsTab.right.nameV configure -text [wb::safeDictGet $r name]
    .runsTab.right.srcV configure -text "[wb::safeDictGet $r sourceType] / [wb::safeDictGet $r sourceId]"
    .runsTab.right.profileV configure -text [wb::safeDictGet $r profile]
    .runsTab.right.statusV configure -text [wb::safeDictGet $r status]
    .runsTab.right.startV configure -text [wb::safeDictGet $r startedAt]
    .runsTab.right.endV configure -text [wb::safeDictGet $r endedAt]
    .runsTab.right.cfgV configure -text [wb::safeDictGet $r configPath]
    .runsTab.right.outV configure -text [wb::safeDictGet $r outputDir]
    .runsTab.right.logV configure -text [wb::safeDictGet $r logPath]
    .runsTab.right.metV configure -text [wb::safeDictGet $r metricsPath]
    .runsTab.right.baseV configure -text [wb::safeDictGet $r baselineResolvedPath]
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
    set ::wb::currentRoot [dict get $r outputDir]
    .resultsTab.top.rootEntry delete 0 end
    .resultsTab.top.rootEntry insert 0 $::wb::currentRoot
    wb::populateResultsTree
    .nb select .resultsTab
}

proc wb::runToValidation {} {
    set runId [wb::selectedRunId]
    if {$runId eq ""} { return }
    wb::loadValidationForRun $runId
    .nb select .validationTab
}

proc wb::runToArtifacts {} {
    set r [wb::selectedRunDict]
    if {$r eq ""} { return }
    set ::wb::artifactRunFilter [dict get $r runId]
    wb::refreshArtifactsTable
    .nb select .artifactsTab
}

proc wb::runSetBudgetContext {} {
    set r [wb::selectedRunDict]
    if {$r eq ""} { return }
    set ::wb::budgetOwnerType "run"
    set ::wb::budgetOwnerId [dict get $r runId]
    set ::wb::budgetDomain [wb::safeDictGet $r domain]
    .nb select .budgetTab
}

# ==================================================
# ARTIFACTS
# ==================================================
proc wb::artifactRunValues {} {
    set values {all}
    foreach r [project::list_section runs] {
        lappend values [dict get $r runId]
    }
    return $values
}

proc wb::artifactTypeValues {} {
    set values {all}
    foreach a [project::list_section artifacts] {
        set t [wb::safeDictGet $a type]
        if {$t ne "" && $t ni $values} {
            lappend values $t
        }
    }
    return $values
}

proc wb::refreshArtifactsFilterCombo {} {
    if {[info exists ::wb::ui(artifactTypeCombo)]} {
        $::wb::ui(artifactTypeCombo) configure -values [wb::artifactTypeValues]
    }
    if {[info exists ::wb::ui(artifactRunCombo)]} {
        $::wb::ui(artifactRunCombo) configure -values [wb::artifactRunValues]
    }
    if {$::wb::artifactTypeFilter eq ""} { set ::wb::artifactTypeFilter all }
    if {$::wb::artifactRunFilter eq ""} { set ::wb::artifactRunFilter all }
}

proc wb::refreshArtifactsTable {} {
    wb::refreshArtifactsFilterCombo
    set tree $::wb::ui(artifactTree)
    $tree delete [$tree children {}]

    set pathFilter [string tolower [string trim $::wb::artifactPathFilter]]

    foreach a [project::list_section artifacts] {
        set aid [dict get $a artifactId]
        set rid [wb::safeDictGet $a runId]
        set type [wb::safeDictGet $a type]
        set path [wb::safeDictGet $a path]
        set label [wb::safeDictGet $a label]

        if {$::wb::artifactRunFilter ne "all" && $rid ne $::wb::artifactRunFilter} {
            continue
        }
        if {$::wb::artifactTypeFilter ne "all" && $type ne $::wb::artifactTypeFilter} {
            continue
        }
        if {$pathFilter ne ""} {
            set hay [string tolower "$label $path"]
            if {[string first $pathFilter $hay] < 0} {
                continue
            }
        }

        $tree insert {} end -id $aid -values [list \
            $aid \
            $rid \
            $label \
            $type \
            [wb::safeDictGet $a category] \
            [wb::safeDictGet $a nodeId] \
            [wb::humanSize [wb::safeDictGet $a sizeBytes]] \
            [wb::safeDictGet $a createdAt] \
            $path]
    }
}

proc wb::selectedArtifactId {} {
    set tree $::wb::ui(artifactTree)
    set sel [$tree selection]
    if {$sel eq ""} { return "" }
    return [lindex $sel 0]
}

proc wb::artifactOpenPath {} {
    set id [wb::selectedArtifactId]
    if {$id eq ""} { return }
    set a [project::get artifacts $id]
    wb::openPath [dict get $a path]
}

proc wb::artifactToResults {} {
    set id [wb::selectedArtifactId]
    if {$id eq ""} { return }
    set a [project::get artifacts $id]
    set p [dict get $a path]
    if {[file isdirectory $p]} {
        set root $p
    } else {
        set root [file dirname $p]
    }
    set ::wb::currentRoot $root
    .resultsTab.top.rootEntry delete 0 end
    .resultsTab.top.rootEntry insert 0 $root
    wb::populateResultsTree
    .nb select .resultsTab
}

proc wb::artifactBindBudgetContext {} {
    set id [wb::selectedArtifactId]
    if {$id eq ""} { return }
    set a [project::get artifacts $id]
    set ::wb::budgetOwnerType "run"
    set ::wb::budgetOwnerId [wb::safeDictGet $a runId]
    .nb select .budgetTab
}

# ==================================================
# RESULTS BROWSER
# ==================================================
proc wb::isTextFile {path} {
    set ext [string tolower [file extension $path]]
    expr {$ext in {.txt .log .csv .json .yaml .yml .ini .cfg .conf .xml .html .tcl .v .sv .c .cpp .py .m .wflow}}
}

proc wb::isImageFile {path} {
    set ext [string tolower [file extension $path]]
    expr {$ext in {.png .jpg .jpeg .gif}}
}

proc wb::clearResultsTree {} {
    set t $::wb::ui(resTree)
    $t delete [$t children {}]
}

proc wb::populateResultsTreeRecursive {parent path} {
    set t $::wb::ui(resTree)
    foreach p [lsort [glob -nocomplain -directory $path *]] {
        set kind [expr {[file isdirectory $p] ? "dir" : "file"}]
        set item [$t insert $parent end -text [file tail $p] -values [list $p $kind]]
        if {$kind eq "dir"} {
            wb::populateResultsTreeRecursive $item $p
        }
    }
}

proc wb::populateResultsTree {} {
    wb::clearResultsTree
    if {$::wb::currentRoot eq "" || ![file exists $::wb::currentRoot]} { return }
    wb::populateResultsTreeRecursive {} $::wb::currentRoot
    wb::clearResultsPreview
}

proc wb::clearResultsPreview {} {
    $::wb::ui(resTextPreview) configure -state normal
    $::wb::ui(resTextPreview) delete 1.0 end
    $::wb::ui(resTextPreview) configure -state disabled
    $::wb::ui(resImageLabel) configure -image ""
    set ::wb::previewImage ""
    foreach k {resInfoPath resInfoType resInfoSize resInfoMtime} {
        $::wb::ui($k) configure -text ""
    }
}

proc wb::updateResultsSelectionInfo {path} {
    set kind [expr {[file isdirectory $path] ? "directory" : "file"}]
    set size ""
    if {![file isdirectory $path]} {
        set size [wb::humanSize [file size $path]]
    }
    set mtime [clock format [file mtime $path] -format "%Y-%m-%d %H:%M:%S"]

    $::wb::ui(resInfoPath) configure -text $path
    $::wb::ui(resInfoType) configure -text $kind
    $::wb::ui(resInfoSize) configure -text $size
    $::wb::ui(resInfoMtime) configure -text $mtime
}

proc wb::onResultsTreeSelect {} {
    set t $::wb::ui(resTree)
    set sel [$t selection]
    if {$sel eq ""} { return }
    set item [lindex $sel 0]
    set path [$t set $item 0]
    if {$path eq "" || ![file exists $path]} { return }

    set ::wb::selectedPath $path
    wb::updateResultsSelectionInfo $path

    $::wb::ui(resTextPreview) configure -state normal
    $::wb::ui(resTextPreview) delete 1.0 end
    $::wb::ui(resTextPreview) configure -state disabled
    $::wb::ui(resImageLabel) configure -image ""
    set ::wb::previewImage ""

    if {[file isdirectory $path]} { return }

    if {[wb::isTextFile $path]} {
        set data [wb::safeReadFile $path 32768]
        $::wb::ui(resTextPreview) configure -state normal
        $::wb::ui(resTextPreview) insert end $data
        $::wb::ui(resTextPreview) configure -state disabled
        .resultsTab.right.nb select .resultsTab.right.textTab
    } elseif {[wb::isImageFile $path]} {
        catch {
            set ::wb::previewImage [image create photo -file $path]
            $::wb::ui(resImageLabel) configure -image $::wb::previewImage
            .resultsTab.right.nb select .resultsTab.right.imageTab
        }
    }
}

# ==================================================
# VALIDATION
# ==================================================
proc wb::parseCsvLine {line} {
    return [split $line ","]
}

proc wb::loadCsvAsDicts {path} {
    set out {}
    if {$path eq "" || ![file exists $path]} { return $out }
    set ch [open $path r]
    set raw [split [read $ch] "\n"]
    close $ch
    set raw [lsearch -all -inline -not -exact $raw ""]
    if {[llength $raw] < 1} { return $out }

    set headers [wb::parseCsvLine [lindex $raw 0]]
    foreach line [lrange $raw 1 end] {
        set cols [wb::parseCsvLine $line]
        set row {}
        for {set i 0} {$i < [llength $headers]} {incr i} {
            dict set row [lindex $headers $i] [lindex $cols $i]
        }
        lappend out $row
    }
    return $out
}

proc wb::toNumber {x} {
    if {$x eq ""} { return "" }
    if {[catch {expr {double($x)}} v]} { return "" }
    return $v
}

proc wb::safeDelta {a b} {
    set aa [wb::toNumber $a]
    set bb [wb::toNumber $b]
    if {$aa eq "" || $bb eq ""} { return "" }
    return [format "%.3f" [expr {$aa - $bb}]]
}

proc wb::baselineMap {} {
    set map {}
    foreach row $::wb::baselineData {
        set key [wb::safeDictGet $row metric]
        if {$key eq ""} { continue }
        dict set map $key $row
    }
    return $map
}

proc wb::evaluateMetricRow {row baselineMap} {
    set metric [wb::safeDictGet $row metric]
    set value [wb::safeDictGet $row value]
    set min [wb::safeDictGet $row min]
    set max [wb::safeDictGet $row max]
    set baseline ""
    if {[dict exists $baselineMap $metric value]} {
        set baseline [dict get $baselineMap $metric value]
    }

    set status OK
    set v [wb::toNumber $value]
    set mn [wb::toNumber $min]
    set mx [wb::toNumber $max]

    if {$v ne "" && $mn ne "" && $v < $mn} { set status FAIL }
    if {$v ne "" && $mx ne "" && $v > $mx} { set status FAIL }

    if {$status eq "OK" && $baseline ne ""} {
        set d [wb::safeDelta $value $baseline]
        if {$d ne ""} {
            set ad [expr {abs(double($d))}]
            if {$ad > 2} { set status WARN }
        }
    }

    return [dict create \
        metric $metric \
        value $value \
        baseline $baseline \
        delta [wb::safeDelta $value $baseline] \
        min $min \
        max $max \
        status $status]
}

proc wb::refreshValidationTable {} {
    set tree $::wb::ui(valTree)
    $tree delete [$tree children {}]

    set ::wb::passCount 0
    set ::wb::warnCount 0
    set ::wb::failCount 0

    set bmap [wb::baselineMap]
    set rows {}
    foreach row $::wb::metricsData {
        set eval [wb::evaluateMetricRow $row $bmap]
        lappend rows $eval
        set st [dict get $eval status]
        switch -- $st {
            OK { incr ::wb::passCount }
            WARN { incr ::wb::warnCount }
            FAIL { incr ::wb::failCount }
        }

        set item [$tree insert {} end -values [list \
            [dict get $eval metric] \
            [dict get $eval value] \
            [dict get $eval baseline] \
            [dict get $eval delta] \
            [dict get $eval min] \
            [dict get $eval max] \
            [dict get $eval status]]]

        switch -- $st {
            OK { $tree item $item -tags ok }
            WARN { $tree item $item -tags warn }
            FAIL { $tree item $item -tags fail }
        }
    }

    $::wb::ui(valSummary) configure -text "OK=$::wb::passCount   WARN=$::wb::warnCount   FAIL=$::wb::failCount"

    return $rows
}

proc wb::loadValidationForRun {runId} {
    set run [project::get runs $runId]
    set mf [wb::safeDictGet $run metricsPath]
    set resolved [project::resolve_baseline_for_run $runId]
    set bf [dict get $resolved path]

    set ::wb::validationMetricsFile $mf
    set ::wb::validationBaselineFile $bf
    set ::wb::metricsData [wb::loadCsvAsDicts $mf]
    set ::wb::baselineData [wb::loadCsvAsDicts $bf]

    .validationTab.top.metricsEntry delete 0 end
    .validationTab.top.metricsEntry insert 0 $mf
    .validationTab.top.baseEntry delete 0 end
    .validationTab.top.baseEntry insert 0 $bf

    set rows [wb::refreshValidationTable]

    set overall OK
    if {$bf eq ""} {
        set overall UNBOUND
    } elseif {$::wb::failCount > 0} {
        set overall FAIL
    } elseif {$::wb::warnCount > 0} {
        set overall WARN
    }

    set existingId ""
    foreach v [project::list_section validationResults] {
        if {[wb::safeDictGet $v runId] eq $runId} {
            set existingId [dict get $v validationId]
            break
        }
    }
    if {$existingId ne ""} {
        project::delete validationResults $existingId
    }

    project::register_validation_result \
        -runId $runId \
        -sourceType [wb::safeDictGet $run sourceType] \
        -sourceId [wb::safeDictGet $run sourceId] \
        -metricsPath $mf \
        -baselinePath $bf \
        -bindingSource [dict get $resolved bindingSource] \
        -overallStatus $overall \
        -okCount $::wb::passCount \
        -warnCount $::wb::warnCount \
        -failCount $::wb::failCount \
        -detailRows $rows

    wb::refreshTimeline
    wb::saveProject
}

proc wb::openValidationMetricsFile {} {
    set f [tk_getOpenFile -title "Apri file metriche" -filetypes {{"CSV" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set ::wb::validationMetricsFile $f
    set ::wb::metricsData [wb::loadCsvAsDicts $f]
    .validationTab.top.metricsEntry delete 0 end
    .validationTab.top.metricsEntry insert 0 $f
    wb::refreshValidationTable
}

proc wb::openValidationBaselineFile {} {
    set f [tk_getOpenFile -title "Apri baseline" -filetypes {{"CSV" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set ::wb::validationBaselineFile $f
    set ::wb::baselineData [wb::loadCsvAsDicts $f]
    .validationTab.top.baseEntry delete 0 end
    .validationTab.top.baseEntry insert 0 $f
    wb::refreshValidationTable
}

# ==================================================
# LOG ANALYZER
# ==================================================
proc wb::analyzeSelectedRunLog {} {
    set runId [wb::selectedRunId]
    if {$runId eq ""} { return }

    set run [project::get runs $runId]
    set logPath [wb::safeDictGet $run logPath]
    if {$logPath eq "" || ![file exists $logPath]} {
        tk_messageBox -icon warning -title "Log Analyzer" -message "Log non disponibile."
        return
    }

    set text $::wb::ui(runtimeLog)
    $text delete 1.0 end

    set added 0
    set ch [open $logPath r]
    while {[gets $ch line] >= 0} {
        set parsed [wb::parseLogLine $line]
        $text insert end "$line\n" [dict get $parsed severity]

        project::add_timeline_event \
            -runId $runId \
            -workflowId [wb::safeDictGet $run workflowId] \
            -nodeId [dict get $parsed nodeId] \
            -category [dict get $parsed category] \
            -label [dict get $parsed label] \
            -status [dict get $parsed status] \
            -severity [dict get $parsed severity] \
            -details [dict get $parsed details] \
            -relatedPath $logPath
        incr added
    }
    close $ch

    wb::refreshTimeline
    wb::saveProject
    wb::status "log analizzato ($added eventi)"
}

# ==================================================
# TIMELINE
# ==================================================
proc wb::timelineRunValues {} {
    set vals {all}
    foreach r [project::list_section runs] {
        lappend vals [dict get $r runId]
    }
    return $vals
}

proc wb::refreshTimeline {} {
    if {[info exists ::wb::ui(timelineRunCombo)]} {
        $::wb::ui(timelineRunCombo) configure -values [wb::timelineRunValues]
    }
    if {$::wb::timelineRunFilter eq ""} {
        set ::wb::timelineRunFilter all
    }

    set tree $::wb::ui(timelineTree)
    $tree delete [$tree children {}]

    foreach ev [project::list_section timelineEvents] {
        set rid [wb::safeDictGet $ev runId]
        if {$::wb::timelineRunFilter ne "all" && $rid ne $::wb::timelineRunFilter} {
            continue
        }

        $tree insert {} end -id [dict get $ev eventId] -values [list \
            [dict get $ev eventId] \
            [wb::safeDictGet $ev createdAt] \
            [wb::safeDictGet $ev category] \
            $rid \
            [wb::safeDictGet $ev workflowId] \
            [wb::safeDictGet $ev nodeId] \
            [wb::safeDictGet $ev severity] \
            [wb::safeDictGet $ev label] \
            [wb::safeDictGet $ev details]]
    }

    set c $::wb::ui(timelineCanvas)
    $c delete all

    set runs [project::list_section runs]
    set y 40
    foreach r $runs {
        set rid [dict get $r runId]
        if {$::wb::timelineRunFilter ne "all" && $rid ne $::wb::timelineRunFilter} {
            continue
        }

        $c create text 20 $y -anchor w -text $rid -font "TkDefaultFont 9 bold"
        $c create line 120 $y 1200 $y -fill "#cccccc"

        set x 170
        foreach ev [project::list_section timelineEvents] {
            if {[wb::safeDictGet $ev runId] ne $rid} { continue }

            set sev [wb::safeDictGet $ev severity info]
            set fill "#4a90e2"
            if {$sev eq "warn"} { set fill "#e09a00" }
            if {$sev eq "error"} { set fill "#d9534f" }

            $c create oval [expr {$x-6}] [expr {$y-6}] [expr {$x+6}] [expr {$y+6}] -fill $fill -outline ""
            $c create text [expr {$x+12}] [expr {$y-10}] -anchor w -text [wb::safeDictGet $ev label]
            incr x 170
        }
        incr y 55
    }

    $c configure -scrollregion [list 0 0 1600 [expr {$y+60}]]
}

# ==================================================
# BUDGET
# ==================================================
proc wb::budgetOwnerValues {ownerType} {
    switch -- $ownerType {
        experiment {
            set vals {}
            foreach e [project::list_section experiments] { lappend vals [dict get $e experimentId] }
            return $vals
        }
        test {
            set vals {}
            foreach t [project::list_section testcases] { lappend vals [dict get $t testcaseId] }
            return $vals
        }
        run {
            set vals {}
            foreach r [project::list_section runs] { lappend vals [dict get $r runId] }
            return $vals
        }
        default {
            return {}
        }
    }
}

proc wb::refreshBudgetOwnerCombo {} {
    if {[info exists ::wb::ui(budgetOwnerIdCombo)]} {
        $::wb::ui(budgetOwnerIdCombo) configure -values [wb::budgetOwnerValues $::wb::budgetOwnerType]
    }
}

proc wb::refreshBudgetSetsTable {} {
    wb::refreshBudgetOwnerCombo
    set tree $::wb::ui(budgetTree)
    $tree delete [$tree children {}]
    foreach b [project::list_section budgets] {
        set total 0.0
        foreach it [wb::safeDictGet $b items {}] {
            set v [wb::toNumber [wb::safeDictGet $it value]]
            if {$v ne ""} { set total [expr {$total + $v}] }
        }
        $tree insert {} end -id [dict get $b budgetSetId] -values [list \
            [dict get $b budgetSetId] \
            [wb::safeDictGet $b name] \
            [wb::safeDictGet $b ownerType] \
            [wb::safeDictGet $b ownerId] \
            [wb::safeDictGet $b domain] \
            [format "%.2f" $total]]
    }
}

proc wb::onBudgetSetSelect {} {
    set tree $::wb::ui(budgetTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set id [lindex $sel 0]
    set b [project::get budgets $id]

    set itemsTree $::wb::ui(budgetItemsTree)
    $itemsTree delete [$itemsTree children {}]
    foreach it [wb::safeDictGet $b items {}] {
        $itemsTree insert {} end -values [list \
            [wb::safeDictGet $it itemId] \
            [wb::safeDictGet $it label] \
            [wb::safeDictGet $it type] \
            [wb::safeDictGet $it value] \
            [wb::safeDictGet $it unit] \
            [wb::safeDictGet $it notes]]
    }
}

proc wb::saveBudgetSet {} {
    set ownerType $::wb::budgetOwnerType
    if {$ownerType eq "test"} { set ownerType "test" }
    set b [project::new_budget_set \
        -name $::wb::budgetName \
        -ownerType $ownerType \
        -ownerId $::wb::budgetOwnerId \
        -domain $::wb::budgetDomain \
        -notes $::wb::budgetNotes]
    wb::refreshBudgetSetsTable
    wb::saveProject
    wb::status "budget set salvato ([dict get $b budgetSetId])"
}

proc wb::addBudgetItemToSelected {} {
    set tree $::wb::ui(budgetTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set setId [lindex $sel 0]

    set item [dict create \
        label $::wb::budgetItemLabel \
        type $::wb::budgetItemType \
        value $::wb::budgetItemValue \
        unit $::wb::budgetItemUnit \
        notes $::wb::budgetItemNotes]

    project::add_budget_item $setId $item
    wb::refreshBudgetSetsTable
    $tree selection set $setId
    wb::onBudgetSetSelect
    wb::saveProject
    wb::status "budget item aggiunto"
}

# ==================================================
# GLOBAL REFRESH
# ==================================================
proc wb::refreshAll {} {
    wb::refreshProjectHub
    wb::refreshExperimentsTable
    wb::refreshTestsTable
    wb::refreshWorkflowTable
    wb::refreshRunsTable
    wb::refreshArtifactsTable
    wb::refreshTimeline
    wb::refreshBudgetSetsTable
}

# ==================================================
# UI BUILDERS
# ==================================================
proc wb::buildHubTab {} {
    set ::wb::ui(hubText) [text .hubTab.txt -wrap word -state disabled]
    pack $::wb::ui(hubText) -fill both -expand 1 -padx 8 -pady 8
}

proc wb::buildExperimentsTab {} {
    ttk::panedwindow .experimentsTab.pw -orient horizontal
    pack .experimentsTab.pw -fill both -expand 1

    ttk::frame .experimentsTab.left -padding 6
    ttk::frame .experimentsTab.right -padding 6
    .experimentsTab.pw add .experimentsTab.left -weight 3
    .experimentsTab.pw add .experimentsTab.right -weight 2

    set ::wb::ui(expTree) [ttk::treeview .experimentsTab.left.tree \
        -columns {id name domain status config workflow baseline} -show headings -selectmode browse]
    foreach {c t w} {
        id "ID" 80
        name "Name" 220
        domain "Domain" 90
        status "Status" 90
        config "Config" 180
        workflow "Workflow" 160
        baseline "Baseline" 160
    } {
        $::wb::ui(expTree) heading $c -text $t
        $::wb::ui(expTree) column $c -width $w
    }
    pack $::wb::ui(expTree) -fill both -expand 1
    bind $::wb::ui(expTree) <<TreeviewSelect>> wb::onExperimentTreeSelect

    ttk::label .experimentsTab.right.l1 -text "Experiment ID"
    ttk::entry .experimentsTab.right.e1 -textvariable ::wb::expId
    ttk::label .experimentsTab.right.l2 -text "Name"
    ttk::entry .experimentsTab.right.e2 -textvariable ::wb::expName
    ttk::label .experimentsTab.right.l3 -text "Domain"
    ttk::combobox .experimentsTab.right.e3 -textvariable ::wb::expDomain -values {radar satellite underwater hdl}
    ttk::label .experimentsTab.right.l4 -text "Status"
    ttk::combobox .experimentsTab.right.e4 -textvariable ::wb::expStatus -values {draft ready running archived}
    ttk::label .experimentsTab.right.l5 -text "Config Path"
    ttk::entry .experimentsTab.right.e5 -textvariable ::wb::expConfigPath
    ttk::label .experimentsTab.right.l6 -text "Workflow Path"
    ttk::entry .experimentsTab.right.e6 -textvariable ::wb::expWorkflowPath
    ttk::label .experimentsTab.right.l7 -text "Baseline Path"
    ttk::entry .experimentsTab.right.e7 -textvariable ::wb::expBaselinePath
    ttk::label .experimentsTab.right.l8 -text "Notes"
    text .experimentsTab.right.e8 -height 8 -wrap word
    bind .experimentsTab.right.e8 <KeyRelease> { set ::wb::expNotes [%W get 1.0 "end-1c"] }

    set row 0
    foreach w {.experimentsTab.right.l1 .experimentsTab.right.e1 .experimentsTab.right.l2 .experimentsTab.right.e2 .experimentsTab.right.l3 .experimentsTab.right.e3 .experimentsTab.right.l4 .experimentsTab.right.e4 .experimentsTab.right.l5 .experimentsTab.right.e5 .experimentsTab.right.l6 .experimentsTab.right.e6 .experimentsTab.right.l7 .experimentsTab.right.e7 .experimentsTab.right.l8 .experimentsTab.right.e8} {
        grid $w -row $row -column 0 -sticky ew -pady 3
        incr row
    }
    grid columnconfigure .experimentsTab.right 0 -weight 1

    ttk::frame .experimentsTab.right.btns
    grid .experimentsTab.right.btns -row $row -column 0 -sticky ew -pady 8
    foreach {txt cmd} {
        "Nuovo" wb::clearExperimentEditor
        "Salva" wb::saveExperiment
        "Elimina" wb::deleteExperiment
        "Usa nel Launcher" wb::useExperimentInLauncher
    } {
        set safe [string map {" " "_" ":" ""} $txt]
        ttk::button .experimentsTab.right.btns.$safe -text $txt -command $cmd
        pack .experimentsTab.right.btns.$safe -side left -padx 3
    }
}

proc wb::buildTestbenchTab {} {
    ttk::panedwindow .testbenchTab.pw -orient horizontal
    pack .testbenchTab.pw -fill both -expand 1

    ttk::frame .testbenchTab.left -padding 6
    ttk::frame .testbenchTab.right -padding 6
    .testbenchTab.pw add .testbenchTab.left -weight 3
    .testbenchTab.pw add .testbenchTab.right -weight 2

    set ::wb::ui(tcTree) [ttk::treeview .testbenchTab.left.tree \
        -columns {id name suite domain expected status config workflow baseline} -show headings -selectmode browse]
    foreach {c t w} {
        id "ID" 80
        name "Name" 220
        suite "Suite" 100
        domain "Domain" 90
        expected "Expected" 80
        status "Status" 80
        config "Config" 160
        workflow "Workflow" 150
        baseline "Baseline" 150
    } {
        $::wb::ui(tcTree) heading $c -text $t
        $::wb::ui(tcTree) column $c -width $w
    }
    pack $::wb::ui(tcTree) -fill both -expand 1
    bind $::wb::ui(tcTree) <<TreeviewSelect>> wb::onTestTreeSelect

    foreach {row lbl var type values} {
        0 "Testcase ID" tcId entry {}
        1 "Name" tcName entry {}
        2 "Suite ID" tcSuiteId entry {}
        3 "Domain" tcDomain combo {radar satellite underwater hdl}
        4 "Expected" tcExpected combo {pass warn fail}
        5 "Status" tcStatus combo {draft ready disabled}
        6 "Config Path" tcConfigPath entry {}
        7 "Workflow Path" tcWorkflowPath entry {}
        8 "Baseline Path" tcBaselinePath entry {}
    } {
        ttk::label .testbenchTab.right.l$row -text $lbl
        if {$type eq "combo"} {
            ttk::combobox .testbenchTab.right.e$row -textvariable ::wb::$var -values $values
        } else {
            ttk::entry .testbenchTab.right.e$row -textvariable ::wb::$var
        }
        grid .testbenchTab.right.l$row -row $row -column 0 -sticky ew -pady 3
        grid .testbenchTab.right.e$row -row $row -column 1 -sticky ew -pady 3
    }

    ttk::label .testbenchTab.right.l9 -text "Notes"
    text .testbenchTab.right.notes -height 8 -wrap word
    bind .testbenchTab.right.notes <KeyRelease> { set ::wb::tcNotes [%W get 1.0 "end-1c"] }
    grid .testbenchTab.right.l9 -row 9 -column 0 -sticky ew -pady 3
    grid .testbenchTab.right.notes -row 9 -column 1 -sticky nsew -pady 3

    ttk::frame .testbenchTab.right.btns
    grid .testbenchTab.right.btns -row 10 -column 0 -columnspan 2 -sticky ew -pady 8
    foreach {txt cmd} {
        "Nuovo" wb::clearTestEditor
        "Salva" wb::saveTest
        "Elimina" wb::deleteTest
        "Usa nel Launcher" wb::useTestInLauncher
    } {
        set safe [string map {" " "_" ":" ""} $txt]
        ttk::button .testbenchTab.right.btns.$safe -text $txt -command $cmd
        pack .testbenchTab.right.btns.$safe -side left -padx 3
    }

    grid columnconfigure .testbenchTab.right 1 -weight 1
    grid rowconfigure .testbenchTab.right 9 -weight 1
}

proc wb::buildWorkflowTab {} {
    ttk::panedwindow .workflowTab.pw -orient horizontal
    pack .workflowTab.pw -fill both -expand 1

    ttk::frame .workflowTab.left -padding 6
    ttk::frame .workflowTab.right -padding 6
    .workflowTab.pw add .workflowTab.left -weight 2
    .workflowTab.pw add .workflowTab.right -weight 3

    set ::wb::ui(wfTree) [ttk::treeview .workflowTab.left.tree \
        -columns {id name version domain nodes file} -show headings -selectmode browse]
    foreach {c t w} {
        id "ID" 90
        name "Name" 180
        version "Ver" 50
        domain "Domain" 90
        nodes "Nodes" 70
        file "File" 180
    } {
        $::wb::ui(wfTree) heading $c -text $t
        $::wb::ui(wfTree) column $c -width $w
    }
    pack $::wb::ui(wfTree) -fill both -expand 1
    bind $::wb::ui(wfTree) <<TreeviewSelect>> wb::onWorkflowTreeSelect

    ttk::frame .workflowTab.left.form
    pack .workflowTab.left.form -fill x -pady 8

    foreach {row lbl var type values} {
        0 "Workflow ID" wfId entry {}
        1 "Name" wfName entry {}
        2 "Version" wfVersion entry {}
        3 "Domain" wfDomain combo {radar satellite underwater hdl}
        4 "File Path" wfFilePath entry {}
    } {
        ttk::label .workflowTab.left.form.l$row -text $lbl
        if {$type eq "combo"} {
            ttk::combobox .workflowTab.left.form.e$row -textvariable ::wb::$var -values $values
        } else {
            ttk::entry .workflowTab.left.form.e$row -textvariable ::wb::$var
        }
        grid .workflowTab.left.form.l$row -row $row -column 0 -sticky ew -pady 2
        grid .workflowTab.left.form.e$row -row $row -column 1 -sticky ew -pady 2
    }
    grid columnconfigure .workflowTab.left.form 1 -weight 1

    ttk::frame .workflowTab.left.btns
    pack .workflowTab.left.btns -fill x
    foreach {txt cmd} {
        "Nuovo" wb::clearWorkflowEditor
        "Add Node" wb::addWorkflowNode
        "Salva" wb::saveWorkflow
        "Elimina" wb::deleteWorkflow
        "Usa nel Launcher" wb::useWorkflowInLauncher
        "Run workflow" {
            if {$::wb::wfId ne ""} {
                set ::wb::launchWorkflowId $::wb::wfId
                if {$::wb::launchCaseName eq ""} { set ::wb::launchCaseName $::wb::wfName }
                wb::updateLauncherPreview
                .nb select .launcherTab
            }
        }
        "Export" wb::exportSelectedWorkflow
        "Import" wb::importWorkflowDialog
    } {
        set safe [string map {" " "_" ":" ""} $txt]
        ttk::button .workflowTab.left.btns.$safe -text $txt -command $cmd
        pack .workflowTab.left.btns.$safe -side left -padx 3
    }

    set ::wb::ui(wfCanvas) [canvas .workflowTab.right.c -background white -scrollregion {0 0 1800 900}]
    pack $::wb::ui(wfCanvas) -fill both -expand 1
}

proc wb::buildLauncherTab {} {
    ttk::frame .launcherTab.top -padding 8
    pack .launcherTab.top -fill x

    foreach {row lbl var type values} {
        0 "Profile" launchProfile combo {}
        1 "Case Name" launchCaseName entry {}
        2 "Config Path" launchConfigPath entry {}
        3 "Output Root" launchOutputRoot entry {}
        4 "Extra Args" launchExtraArgs entry {}
        5 "Source Type" launchSourceType combo {manual experiment testcase suite}
        6 "Source ID" launchSourceId entry {}
        7 "Workflow ID" launchWorkflowId entry {}
        8 "Notes" launchNotes entry {}
    } {
        ttk::label .launcherTab.top.l$row -text $lbl
        if {$type eq "combo"} {
            ttk::combobox .launcherTab.top.e$row -textvariable ::wb::$var
            if {$var eq "launchProfile"} {
                .launcherTab.top.e$row configure -values [wb::profileNames]
            } else {
                .launcherTab.top.e$row configure -values $values
            }
        } else {
            ttk::entry .launcherTab.top.e$row -textvariable ::wb::$var
        }
        grid .launcherTab.top.l$row -row $row -column 0 -sticky ew -pady 3
        grid .launcherTab.top.e$row -row $row -column 1 -sticky ew -pady 3
    }
    grid columnconfigure .launcherTab.top 1 -weight 1

    ttk::frame .launcherTab.actions -padding 8
    pack .launcherTab.actions -fill x
    ttk::button .launcherTab.actions.preview -text "Aggiorna preview" -command wb::updateLauncherPreview
    ttk::button .launcherTab.actions.run -text "Start Run" -command wb::startRun
    ttk::button .launcherTab.actions.stop -text "Stop Run" -command wb::stopRun
    ttk::button .launcherTab.actions.save -text "Salva progetto" -command wb::saveProject
    pack .launcherTab.actions.preview .launcherTab.actions.run .launcherTab.actions.stop .launcherTab.actions.save -side left -padx 4

    ttk::labelframe .launcherTab.cmd -text "Command preview" -padding 8
    pack .launcherTab.cmd -fill both -expand 1 -padx 8 -pady 8
    set ::wb::ui(cmdPreview) [text .launcherTab.cmd.txt -height 12 -wrap word]
    $::wb::ui(cmdPreview) configure -state disabled
    pack $::wb::ui(cmdPreview) -fill both -expand 1
}

proc wb::buildRuntimeTab {} {
    ttk::frame .runtimeTab.top -padding 6
    pack .runtimeTab.top -fill x

    ttk::button .runtimeTab.top.fromRun -text "Analyze selected run log" -command wb::analyzeSelectedRunLog
    pack .runtimeTab.top.fromRun -side left

    ttk::labelframe .runtimeTab.box -text "Runtime / Log Analyzer" -padding 8
    pack .runtimeTab.box -fill both -expand 1 -padx 8 -pady 8

    set ::wb::ui(runtimeLog) [text .runtimeTab.box.txt -wrap none]
    ttk::scrollbar .runtimeTab.box.vsb -orient vertical -command "$::wb::ui(runtimeLog) yview"
    ttk::scrollbar .runtimeTab.box.hsb -orient horizontal -command "$::wb::ui(runtimeLog) xview"
    $::wb::ui(runtimeLog) configure -yscrollcommand ".runtimeTab.box.vsb set" -xscrollcommand ".runtimeTab.box.hsb set"

    grid $::wb::ui(runtimeLog) -row 0 -column 0 -sticky nsew
    grid .runtimeTab.box.vsb -row 0 -column 1 -sticky ns
    grid .runtimeTab.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .runtimeTab.box 0 -weight 1
    grid columnconfigure .runtimeTab.box 0 -weight 1
}

proc wb::buildRunsTab {} {
    ttk::panedwindow .runsTab.pw -orient horizontal
    pack .runsTab.pw -fill both -expand 1

    ttk::frame .runsTab.left -padding 6
    ttk::frame .runsTab.right -padding 6
    .runsTab.pw add .runsTab.left -weight 4
    .runsTab.pw add .runsTab.right -weight 2

    set ::wb::ui(runTree) [ttk::treeview .runsTab.left.tree \
        -columns {runId name sourceType sourceId profile status startedAt endedAt} \
        -show headings -selectmode browse]
    foreach {col txt w} {
        runId "Run ID" 90
        name "Name" 220
        sourceType "Source Type" 90
        sourceId "Source ID" 90
        profile "Profile" 150
        status "Status" 80
        startedAt "Started" 150
        endedAt "Ended" 150
    } {
        $::wb::ui(runTree) heading $col -text $txt
        $::wb::ui(runTree) column $col -width $w
    }
    pack $::wb::ui(runTree) -fill both -expand 1
    bind $::wb::ui(runTree) <<TreeviewSelect>> wb::onRunTreeSelect

    $::wb::ui(runTree) tag configure ok -foreground darkgreen
    $::wb::ui(runTree) tag configure warn -foreground darkorange3
    $::wb::ui(runTree) tag configure fail -foreground red
    $::wb::ui(runTree) tag configure running -foreground blue

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
        11 "Baseline:" baseV
    } {
        ttk::label $right.l$row -text $lbl
        ttk::label $right.$var -text "" -wraplength 320 -justify left
        grid $right.l$row -in .runsTab.right.box -row $row -column 0 -sticky nw -pady 3
        grid $right.$var -in .runsTab.right.box -row $row -column 1 -sticky w -pady 3
    }

    ttk::frame .runsTab.right.actions -padding 6
    pack .runsTab.right.actions -fill x
    foreach {txt cmd} {
        "Vai a Results" wb::runToResults
        "Vai a Validation" wb::runToValidation
        "Vai a Artifacts" wb::runToArtifacts
        "Apri log" wb::runOpenLog
        "Apri output" wb::runOpenOutput
        "Budget context" wb::runSetBudgetContext
    } {
        set safe [string map {" " "_" ":" ""} $txt]
        ttk::button .runsTab.right.actions.$safe -text $txt -command $cmd
        pack .runsTab.right.actions.$safe -fill x -pady 2
    }
}

proc wb::buildArtifactsTab {} {
    ttk::frame .artifactsTab.top -padding 6
    pack .artifactsTab.top -fill x

    ttk::label .artifactsTab.top.lRun -text "Run:"
    ttk::combobox .artifactsTab.top.cRun -textvariable ::wb::artifactRunFilter -state readonly -values {all}
    set ::wb::ui(artifactRunCombo) .artifactsTab.top.cRun

    ttk::label .artifactsTab.top.lType -text "Type:"
    ttk::combobox .artifactsTab.top.cType -textvariable ::wb::artifactTypeFilter -state readonly -values {all}
    set ::wb::ui(artifactTypeCombo) .artifactsTab.top.cType

    ttk::label .artifactsTab.top.lPath -text "Search:"
    ttk::entry .artifactsTab.top.ePath -textvariable ::wb::artifactPathFilter

    ttk::button .artifactsTab.top.b1 -text "Refresh" -command wb::refreshArtifactsTable
    ttk::button .artifactsTab.top.b2 -text "Open" -command wb::artifactOpenPath
    ttk::button .artifactsTab.top.b3 -text "To Results" -command wb::artifactToResults
    ttk::button .artifactsTab.top.b4 -text "Budget context" -command wb::artifactBindBudgetContext

    pack .artifactsTab.top.lRun .artifactsTab.top.cRun \
         .artifactsTab.top.lType .artifactsTab.top.cType \
         .artifactsTab.top.lPath .artifactsTab.top.ePath \
         .artifactsTab.top.b1 .artifactsTab.top.b2 .artifactsTab.top.b3 .artifactsTab.top.b4 \
         -side left -padx 4

    set ::wb::ui(artifactTree) [ttk::treeview .artifactsTab.tree \
        -columns {artifactId runId label type category nodeId size createdAt path} \
        -show headings -selectmode browse]

    foreach {c t w} {
        artifactId "Artifact ID" 90
        runId "Run ID" 90
        label "Label" 180
        type "Type" 80
        category "Category" 80
        nodeId "Node" 80
        size "Size" 80
        createdAt "Created" 140
        path "Path" 420
    } {
        $::wb::ui(artifactTree) heading $c -text $t
        $::wb::ui(artifactTree) column $c -width $w
    }

    pack $::wb::ui(artifactTree) -fill both -expand 1 -padx 8 -pady 8
}

proc wb::buildResultsTab {} {
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

    set ::wb::ui(resTree) [ttk::treeview .resultsTab.left.tree -columns {path kind} -show tree -selectmode browse]
    pack $::wb::ui(resTree) -fill both -expand 1
    bind $::wb::ui(resTree) <<TreeviewSelect>> wb::onResultsTreeSelect

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
        set ::wb::ui($key) .resultsTab.right.info.v$row
    }

    ttk::notebook .resultsTab.right.nb
    pack .resultsTab.right.nb -fill both -expand 1 -pady 8
    ttk::frame .resultsTab.right.textTab
    ttk::frame .resultsTab.right.imageTab
    .resultsTab.right.nb add .resultsTab.right.textTab -text "Text"
    .resultsTab.right.nb add .resultsTab.right.imageTab -text "Image"

    set ::wb::ui(resTextPreview) [text .resultsTab.right.textTab.txt -wrap none -state disabled]
    pack $::wb::ui(resTextPreview) -fill both -expand 1
    set ::wb::ui(resImageLabel) [label .resultsTab.right.imageTab.img -anchor center]
    pack $::wb::ui(resImageLabel) -fill both -expand 1
}

proc wb::buildValidationTab {} {
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

    set ::wb::ui(valTree) [ttk::treeview .validationTab.tree \
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
        $::wb::ui(valTree) heading $col -text $txt
        $::wb::ui(valTree) column $col -width $w
    }
    pack $::wb::ui(valTree) -fill both -expand 1 -padx 8 -pady 8
    $::wb::ui(valTree) tag configure ok -foreground darkgreen
    $::wb::ui(valTree) tag configure warn -foreground darkorange3
    $::wb::ui(valTree) tag configure fail -foreground red

    set ::wb::ui(valSummary) [ttk::label .validationTab.summary -text "OK=0   WARN=0   FAIL=0" -padding 6]
    pack .validationTab.summary -fill x
}

proc wb::buildTimelineTab {} {
    ttk::frame .timelineTab.topbar -padding 6
    pack .timelineTab.topbar -fill x

    ttk::label .timelineTab.topbar.l1 -text "Run:"
    ttk::combobox .timelineTab.topbar.c1 -textvariable ::wb::timelineRunFilter -state readonly -values {all}
    set ::wb::ui(timelineRunCombo) .timelineTab.topbar.c1
    ttk::button .timelineTab.topbar.b1 -text "Refresh" -command wb::refreshTimeline

    pack .timelineTab.topbar.l1 .timelineTab.topbar.c1 .timelineTab.topbar.b1 -side left -padx 4

    ttk::panedwindow .timelineTab.pw -orient vertical
    pack .timelineTab.pw -fill both -expand 1

    ttk::frame .timelineTab.top -padding 6
    ttk::frame .timelineTab.bottom -padding 6
    .timelineTab.pw add .timelineTab.top -weight 2
    .timelineTab.pw add .timelineTab.bottom -weight 2

    set ::wb::ui(timelineTree) [ttk::treeview .timelineTab.top.tree \
        -columns {eventId createdAt category runId workflowId nodeId severity label details} -show headings]

    foreach {c t w} {
        eventId "Event ID" 90
        createdAt "Created" 140
        category "Category" 90
        runId "Run ID" 90
        workflowId "Workflow ID" 90
        nodeId "Node ID" 80
        severity "Severity" 80
        label "Label" 180
        details "Details" 420
    } {
        $::wb::ui(timelineTree) heading $c -text $t
        $::wb::ui(timelineTree) column $c -width $w
    }

    pack $::wb::ui(timelineTree) -fill both -expand 1

    set ::wb::ui(timelineCanvas) [canvas .timelineTab.bottom.c -background white -scrollregion {0 0 1600 1200}]
    ttk::scrollbar .timelineTab.bottom.vsb -orient vertical -command "$::wb::ui(timelineCanvas) yview"
    ttk::scrollbar .timelineTab.bottom.hsb -orient horizontal -command "$::wb::ui(timelineCanvas) xview"
    $::wb::ui(timelineCanvas) configure -yscrollcommand ".timelineTab.bottom.vsb set" -xscrollcommand ".timelineTab.bottom.hsb set"

    grid $::wb::ui(timelineCanvas) -row 0 -column 0 -sticky nsew
    grid .timelineTab.bottom.vsb -row 0 -column 1 -sticky ns
    grid .timelineTab.bottom.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .timelineTab.bottom 0 -weight 1
    grid columnconfigure .timelineTab.bottom 0 -weight 1
}

proc wb::buildBudgetTab {} {
    ttk::panedwindow .budgetTab.pw -orient horizontal
    pack .budgetTab.pw -fill both -expand 1

    ttk::frame .budgetTab.left -padding 6
    ttk::frame .budgetTab.right -padding 6
    .budgetTab.pw add .budgetTab.left -weight 2
    .budgetTab.pw add .budgetTab.right -weight 3

    ttk::labelframe .budgetTab.left.setForm -text "Budget Set" -padding 8
    pack .budgetTab.left.setForm -fill x
    foreach {row lbl var type values} {
        0 "Name" budgetName entry {}
        1 "OwnerType" budgetOwnerType combo {project experiment test run}
        2 "OwnerId" budgetOwnerId combo {}
        3 "Domain" budgetDomain entry {}
        4 "Notes" budgetNotes entry {}
    } {
        ttk::label .budgetTab.left.setForm.l$row -text $lbl
        if {$type eq "combo"} {
            ttk::combobox .budgetTab.left.setForm.e$row -textvariable ::wb::$var -values $values
            if {$var eq "budgetOwnerId"} {
                set ::wb::ui(budgetOwnerIdCombo) .budgetTab.left.setForm.e$row
            }
        } else {
            ttk::entry .budgetTab.left.setForm.e$row -textvariable ::wb::$var
        }
        grid .budgetTab.left.setForm.l$row -row $row -column 0 -sticky ew -pady 2
        grid .budgetTab.left.setForm.e$row -row $row -column 1 -sticky ew -pady 2
    }
    grid columnconfigure .budgetTab.left.setForm 1 -weight 1
    bind .budgetTab.left.setForm.e1 <<ComboboxSelected>> {wb::refreshBudgetOwnerCombo}

    ttk::button .budgetTab.left.saveSet -text "Salva Budget Set" -command wb::saveBudgetSet
    pack .budgetTab.left.saveSet -fill x -pady 6

    set ::wb::ui(budgetTree) [ttk::treeview .budgetTab.left.tree \
        -columns {budgetSetId name ownerType ownerId domain total} -show headings -selectmode browse]
    foreach {c t w} {
        budgetSetId "ID" 90
        name "Name" 160
        ownerType "OwnerType" 80
        ownerId "OwnerId" 80
        domain "Domain" 80
        total "Total" 80
    } {
        $::wb::ui(budgetTree) heading $c -text $t
        $::wb::ui(budgetTree) column $c -width $w
    }
    pack $::wb::ui(budgetTree) -fill both -expand 1
    bind $::wb::ui(budgetTree) <<TreeviewSelect>> wb::onBudgetSetSelect

    ttk::labelframe .budgetTab.right.itemForm -text "Budget Item" -padding 8
    pack .budgetTab.right.itemForm -fill x
    foreach {row lbl var type values} {
        0 "Label" budgetItemLabel entry {}
        1 "Type" budgetItemType combo {cost margin time resource}
        2 "Value" budgetItemValue entry {}
        3 "Unit" budgetItemUnit entry {}
        4 "Notes" budgetItemNotes entry {}
    } {
        ttk::label .budgetTab.right.itemForm.l$row -text $lbl
        if {$type eq "combo"} {
            ttk::combobox .budgetTab.right.itemForm.e$row -textvariable ::wb::$var -values $values
        } else {
            ttk::entry .budgetTab.right.itemForm.e$row -textvariable ::wb::$var
        }
        grid .budgetTab.right.itemForm.l$row -row $row -column 0 -sticky ew -pady 2
        grid .budgetTab.right.itemForm.e$row -row $row -column 1 -sticky ew -pady 2
    }
    grid columnconfigure .budgetTab.right.itemForm 1 -weight 1

    ttk::button .budgetTab.right.addItem -text "Aggiungi item al set selezionato" -command wb::addBudgetItemToSelected
    pack .budgetTab.right.addItem -fill x -pady 6

    set ::wb::ui(budgetItemsTree) [ttk::treeview .budgetTab.right.tree \
        -columns {itemId label type value unit notes} -show headings]
    foreach {c t w} {
        itemId "Item ID" 80
        label "Label" 160
        type "Type" 80
        value "Value" 90
        unit "Unit" 70
        notes "Notes" 240
    } {
        $::wb::ui(budgetItemsTree) heading $c -text $t
        $::wb::ui(budgetItemsTree) column $c -width $w
    }
    pack $::wb::ui(budgetItemsTree) -fill both -expand 1
}

proc wb::buildUI {} {
    wm title . "Engineering Workbench"
    wm geometry . 1700x980
    wm minsize . 1300 840
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    foreach {txt cmd} {
        "Nuovo Progetto" wb::newProjectDialog
        "Apri Progetto" wb::loadProjectDialog
        "Salva Progetto" wb::saveProject
        "Salva Come" wb::saveProjectAs
        "Refresh" wb::refreshAll
    } {
        set safe [string map {" " "_" ":" ""} $txt]
        ttk::button .toolbar.$safe -text $txt -command $cmd
        pack .toolbar.$safe -side left -padx 4
    }

    ttk::notebook .nb
    pack .nb -fill both -expand 1

    foreach {path text} {
        .hubTab "Project Hub"
        .experimentsTab "Experiment Manager"
        .testbenchTab "Testbench Manager"
        .workflowTab "Workflow Editor"
        .launcherTab "Launcher"
        .runtimeTab "Log Analyzer"
        .runsTab "Run History"
        .artifactsTab "Artifact Browser"
        .resultsTab "Result Browser"
        .validationTab "Validation"
        .timelineTab "Timeline"
        .budgetTab "Budget"
    } {
        ttk::frame $path
        .nb add $path -text $text
    }

    wb::buildHubTab
    wb::buildExperimentsTab
    wb::buildTestbenchTab
    wb::buildWorkflowTab
    wb::buildLauncherTab
    wb::buildRuntimeTab
    wb::buildRunsTab
    wb::buildArtifactsTab
    wb::buildResultsTab
    wb::buildValidationTab
    wb::buildTimelineTab
    wb::buildBudgetTab

    ttk::label .status -text "Stato: pronto" -anchor w -padding 6
    pack .status -fill x

    wb::configureRuntimeLogTags
    bind . <Control-s> {wb::saveProject}
    wm protocol . WM_DELETE_WINDOW wb::onExit
}

# ==================================================
# BOOT
# ==================================================
wb::buildUI
wb::autoLoadProject
wb::refreshAll
wb::updateLauncherPreview
wb::startAutosave
wb::status "workbench pronto"
